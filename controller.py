"""
controller.py — The Finite State Machine (the brain loop).

States:  SLEEP -> CALL_CAT -> WAIT_FOR_MOTION -> VERIFY -> DISPENSE -> LOG -> SLEEP

Reads schedules from the 'schedules' collection exactly as the Flutter app
writes them (see schedule_form_sheet.dart / firebase_service.dart):

    {
      "cat_id":        "cat_001",
      "label":         "Morning Feeding",
      "hour":          8,
      "minute":        0,
      "portion_grams": 30,
      "isEnabled":     true,
      "activeDays":    [true, true, true, true, true, true, true]  # Mon..Sun
    }

A schedule fires only if isEnabled is True AND today's weekday is True in
activeDays. Python's datetime.isoweekday() returns 1=Mon .. 7=Sun, so
activeDays[isoweekday() - 1] is today's flag.
"""

import time
import datetime as dt
from datetime import datetime
from enum import Enum, auto

import config
from errors import PumpError, GateError, SensorError
from log_setup import get_logger


class State(Enum):
    SLEEP           = auto()
    CALL_CAT        = auto()
    WAIT_FOR_MOTION = auto()
    VERIFY          = auto()
    DISPENSE        = auto()
    LOG             = auto()
    ENROLL          = auto()   # enrollment mode: capturing face for a new cat


class FeederController:
    def __init__(self, pump, food_level, water_level,
                 pir, camera, voice, gate, recognizer, cloud):
        self.pump        = pump
        self.food_level  = food_level
        self.water_level = water_level
        self.pir         = pir
        self.camera      = camera
        self.voice       = voice
        self.gate        = gate
        self.recognizer  = recognizer
        self.cloud       = cloud

        self.log        = get_logger("fsm")
        self.state      = State.SLEEP
        self._fed_slots = set()   # {(YYYY-MM-DD, schedule_id)} already served today
        self._last_bg   = 0.0     # timestamp of last background-task run

    # ─────────────────────────────────────────────
    #  LEVELS  (per-cat, since system_status is keyed by cat_id in the app)
    # ─────────────────────────────────────────────
    def read_levels(self):
        """Read both HC-SR04 sensors. Returns (food_pct, water_pct).
        Either can be None if its sensor failed -- both are guarded independently."""
        food = water = None
        try:
            food = self.food_level.level_pct()
        except SensorError as exc:
            self.log.error("food level read failed: %s", exc)
        try:
            water = self.water_level.level_pct()
        except SensorError as exc:
            self.log.error("water level read failed: %s", exc)
        return food, water

    def sync_levels(self):
        """
        Read real levels and push them to Firebase for EVERY registered cat
        (the app's system_status is per-cat, but the feeder hardware is
        shared, so all cats see the same levels).
        """
        food, water = self.read_levels()
        if food is None and water is None:
            return food, water

        cats = self.cloud.get_cats()
        for cat_id in cats:
            self.cloud.update_system_status(cat_id, food, water)

        self.log.info("levels -> food %s%% | water %s%%", food, water)
        if food is not None and food <= config.LOW_LEVEL_PCT:
            self.log.warning("LOW FOOD: %s%%", food)
            for cat_id in cats:
                self.cloud.add_notification(
                    cat_id, "Low Food", f"Food level is at {food}%.", "low_food"
                )
        if water is not None and water <= config.LOW_LEVEL_PCT:
            self.log.warning("LOW WATER: %s%%", water)
            for cat_id in cats:
                self.cloud.add_notification(
                    cat_id, "Low Water", f"Water level is at {water}%.", "low_water"
                )
        return food, water

    # ─────────────────────────────────────────────
    #  DISPENSING
    # ─────────────────────────────────────────────
    def dispense(self):
        """Water first, then food. Each is guarded independently."""
        self.state = State.DISPENSE
        try:
            self.pump.dispense()
        except PumpError as exc:
            self.log.error("water dispense failed: %s", exc)
        try:
            self.gate.dispense()
        except GateError as exc:
            self.log.error("food dispense failed: %s", exc)

    # ─────────────────────────────────────────────
    #  BACKGROUND TASKS  (every BACKGROUND_EVERY seconds)
    # ─────────────────────────────────────────────
    def _background_tasks(self):
        if time.time() - self._last_bg < config.BACKGROUND_EVERY:
            return
        self.sync_levels()

        # Check for a pending enrollment command from the app.
        # Enrollment is handled before manual feed so it takes priority.
        enroll_cmd = self.cloud.get_enroll_command()
        if enroll_cmd:
            self.log.info("ENROLL command detected from app -> starting enrollment")
            self.enroll_from_command()
            self._last_bg = time.time()
            return

        # Check if the user cancelled after enrollment succeeded (orphan cleanup).
        # This happens when the Pi saved a gallery but the user did not enter
        # the cat name in the app (they tapped Cancel on the info form).
        # The orphan gallery must be deleted so it doesn't get loaded by the
        # matcher and recognize a cat that doesn't exist in the app.
        cancelled_cat_id = self.cloud.get_cancelled_enrollment()
        if cancelled_cat_id:
            import os
            galleries_dir = (
                "/home/raspberry/GP/AI_Cat_Feeder_System-main/data/galleries"
            )
            gallery_path = f"{galleries_dir}/{cancelled_cat_id}.json"
            try:
                if os.path.exists(gallery_path):
                    os.remove(gallery_path)
                    self.log.info(
                        "Removed orphan gallery after user cancel: %s",
                        gallery_path,
                    )
                else:
                    self.log.info(
                        "Orphan gallery not found (already removed?): %s",
                        gallery_path,
                    )
                # Reload the matcher so the deleted cat is no longer active
                try:
                    self.recognizer.matcher.__init__(galleries_dir)
                    self.log.info("Matcher reloaded after orphan cleanup")
                except Exception as exc:
                    self.log.error("Matcher reload failed: %s", exc)
            except Exception as exc:
                self.log.error(
                    "Could not remove orphan gallery %s: %s", gallery_path, exc
                )
            finally:
                # Always reset the enroll command to idle
                self.cloud.clear_enroll_command()

        # Check every registered cat for a pending manual-feed command
        for cat_id, cat_data in self.cloud.get_cats().items():
            cmd = self.cloud.get_pending_command(cat_id)
            if cmd:
                portion  = cmd.get("portion_g", config.DEFAULT_PORTION_G)
                cat_name = cat_data.get("name", cat_id)
                self.log.info("MANUAL feed from app -> %s portion=%sg", cat_name, portion)
                self.dispense()
                self.sync_levels()
                self.cloud.log_feeding(cat_id, cat_name, True, 1.0, portion)
                self.cloud.consume_command(cat_id)
                self.state = State.SLEEP

        self._last_bg = time.time()

    # ─────────────────────────────────────────────
    #  ENROLLMENT MODE
    # ─────────────────────────────────────────────
    def enroll_from_command(self):
        """
        Full enrollment flow triggered by the app.

        Flow:
          1. Play voice to attract the cat to the camera.
          2. Wait for PIR motion (up to CALL_TIMEOUT_SEC seconds).
          3. Capture frames one by one from the Pi camera.
          4. For each frame: detect face, extract embedding, apply quality
             and diversity filters (same logic as enroll.py).
          5. Every 5 good frames: update Firebase with progress + instruction.
             The instruction is generated from what the face detector sees:
               - no face       -> "Bring your cat closer to the camera"
               - face too small -> "Move your cat a little closer"
               - face blurry   -> "Ask your cat to stay still"
               - face dark     -> "Try adding more light near the feeder"
               - face good     -> "Perfect! Keep your cat in this position"
               - almost done   -> "Almost done, just a few more seconds"
          6. After 40 good embeddings: save gallery, write done to Firebase.
          7. On any failure: write reason to Firebase so app shows Try Again.
        """
        self.state = State.ENROLL
        self.log.info("=== ENROLLMENT MODE STARTED ===")

        NEEDED = 40          # target number of embeddings
        UPDATE_EVERY = 5     # update Firebase every N good frames

        # ── Step 1: call the cat ──
        self.voice.call(track=config.CALL_TRACK)
        self.cloud.update_enroll_progress(0, NEEDED,
            "Bring your cat to the feeder camera")

        # ── Step 2: wait for motion ──
        self.log.info("ENROLL: waiting for cat (timeout %ss)", config.CALL_TIMEOUT_SEC)
        if not self.pir.wait_for_motion(config.CALL_TIMEOUT_SEC):
            self.voice.stop()
            self.log.warning("ENROLL: cat did not arrive -> failed")
            self.cloud.fail_enrollment(
                "Your cat did not arrive at the feeder within 60 seconds. "
                "Please try again and bring your cat closer."
            )
            self.state = State.SLEEP
            return

        self.voice.stop()
        self.log.info("ENROLL: motion detected -> starting capture")

        # ── Step 3-5: capture frames ──
        embeddings = []
        frame_num  = 0

        # Import the AI modules directly (same as recognizer.py does).
        try:
            from ai.detector.face_detector import CatFaceDetector
            from ai.embedder.embedder import CatFaceEmbedder
            import numpy as np

            detector = CatFaceDetector()
            embedder = CatFaceEmbedder()
        except Exception as exc:
            self.log.error("ENROLL: failed to load AI modules: %s", exc)
            self.cloud.fail_enrollment(
                "The AI system could not be loaded. Please restart the feeder."
            )
            self.state = State.SLEEP
            return

        while len(embeddings) < NEEDED:
            frame_num += 1

            # Safety: stop if too many total frames (cat keeps leaving)
            if frame_num > NEEDED * 5:
                self.log.warning("ENROLL: too many frames without enough good faces")
                self.cloud.fail_enrollment(
                    "Not enough clear frames could be captured. "
                    "Try better lighting or hold your cat still."
                )
                self.state = State.SLEEP
                return

            try:
                frame_bgr = self.camera.capture_bgr()
                rois, _   = detector.detect(frame_bgr)
            except Exception as exc:
                self.log.error("ENROLL: frame capture error: %s", exc)
                time.sleep(0.1)
                continue

            # ── Generate instruction based on what the detector sees ──
            good_frames = len(embeddings)
            if not rois:
                instruction = "Bring your cat closer to the camera"
            else:
                quality_score, passed, reason = detector.assess_quality(rois[0])
                if not passed:
                    if "blur" in reason.lower() or "sharp" in reason.lower():
                        instruction = "Ask your cat to stay still for a moment"
                    elif "dark" in reason.lower() or "bright" in reason.lower():
                        instruction = "Try adding more light near the feeder"
                    elif "small" in reason.lower() or "size" in reason.lower():
                        instruction = "Move your cat a little closer"
                    else:
                        instruction = "Try to get your cat to face the camera directly"
                elif good_frames >= NEEDED - 5:
                    instruction = "Almost done! Just a few more seconds"
                else:
                    instruction = "Perfect! Keep your cat in this position"

            # ── Extract embedding if face passed quality ──
            if rois:
                quality_score, passed, _ = detector.assess_quality(rois[0])
                if passed:
                    try:
                        embedding = embedder.extract(rois[0])

                        # Diversity filter: reject if too similar to existing
                        # embeddings (same as enroll.py — avoids near-duplicates)
                        is_diverse = True
                        if embeddings:
                            import numpy as np
                            emb_norm = embedding / (np.linalg.norm(embedding) + 1e-8)
                            for existing in embeddings:
                                ex_norm = existing / (np.linalg.norm(existing) + 1e-8)
                                similarity = float(np.dot(emb_norm, ex_norm))
                                if similarity > 0.97:
                                    is_diverse = False
                                    break

                        if is_diverse:
                            embeddings.append(embedding)
                            self.log.debug(
                                "ENROLL: good frame %d/%d", len(embeddings), NEEDED
                            )
                    except Exception as exc:
                        self.log.error("ENROLL: embedding error: %s", exc)

            # Update Firebase every UPDATE_EVERY good frames
            if len(embeddings) % UPDATE_EVERY == 0 and len(embeddings) > 0:
                self.cloud.update_enroll_progress(
                    len(embeddings), NEEDED, instruction
                )
                print(f"ENROLL: {len(embeddings)}/{NEEDED} frames | {instruction}",
                      flush=True)

            time.sleep(0.1)

        # ── Step 6: save gallery ──
        self.log.info("ENROLL: %d embeddings captured -> saving gallery", len(embeddings))
        try:
            import json, numpy as np

            cat_id   = self.cloud._next_cat_id()
            cat_data = self.recognizer.matcher  # access matcher to compute threshold

            # Compute centroid and adaptive threshold (same as enroll.py finalize)
            embs_array  = np.array(embeddings)
            centroid    = embs_array.mean(axis=0)
            centroid   /= (np.linalg.norm(centroid) + 1e-8)

            # Compute pairwise intra-class similarities for threshold
            norms = embs_array / (
                np.linalg.norm(embs_array, axis=1, keepdims=True) + 1e-8
            )
            sims = []
            for i in range(len(norms)):
                for j in range(i + 1, len(norms)):
                    sims.append(float(np.dot(norms[i], norms[j])))
            mu_intra    = float(np.mean(sims)) if sims else 0.75
            sigma_intra = float(np.std(sims))  if sims else 0.05
            threshold   = max(0.70, mu_intra - 2 * sigma_intra)

            gallery = {
                "cat_id":    cat_id,
                "name":      cat_id,        # app will set the real name
                "threshold": round(threshold, 4),
                "centroid":  centroid.tolist(),
                "embeddings": [e.tolist() for e in embeddings],
                "enrolled_at": dt.datetime.now().isoformat(),
                "portion_grams": config.DEFAULT_PORTION_G,
                "water_grams":   150,
            }

            galleries_dir = (
                "/home/raspberry/GP/AI_Cat_Feeder_System-main/data/galleries"
            )
            gallery_path = f"{galleries_dir}/{cat_id}.json"
            with open(gallery_path, "w") as f:
                json.dump(gallery, f, indent=2)

            self.log.info("ENROLL: gallery saved to %s", gallery_path)

            # Reload the matcher so the new cat is active immediately
            try:
                self.recognizer.matcher.__init__(galleries_dir)
            except Exception:
                pass

        except Exception as exc:
            self.log.error("ENROLL: failed to save gallery: %s", exc)
            self.cloud.fail_enrollment(
                "The cat was recognized but could not be saved. "
                "Please try again."
            )
            self.state = State.SLEEP
            return

        # ── Step 7: write success to Firebase ──
        self.cloud.complete_enrollment(cat_id, NEEDED)
        self.log.info("=== ENROLLMENT COMPLETE: %s ===", cat_id)
        self.state = State.SLEEP

    # ─────────────────────────────────────────────
    #  SCHEDULE -- find the due schedule
    # ─────────────────────────────────────────────
    def _due_schedule(self):
        """
        Check every schedule in Firebase. A schedule fires if:
          - enabled is True
          - hour:minute matches right now
          - today's weekday flag in active_days is True
          - this (date, schedule_id) hasn't already fired today

        NOTE: field names below match the REAL data confirmed on the Pi:
          'enabled' (not isEnabled), 'active_days' (not activeDays),
          'portion_g' (not portion_grams).

        Returns the matching schedule dict, or None.
        """
        now      = datetime.now()
        today    = now.strftime("%Y-%m-%d")
        weekday  = now.isoweekday()        # 1=Mon .. 7=Sun
        day_idx  = weekday - 1             # 0=Mon .. 6=Sun (matches active_days)

        schedules = self.cloud.get_schedules()

        for sched in schedules:
            if not sched.get("enabled", True):
                continue
            if sched.get("hour") != now.hour or sched.get("minute") != now.minute:
                continue

            active_days = sched.get("active_days", [True] * 7)
            if day_idx >= len(active_days) or not active_days[day_idx]:
                continue   # not scheduled for today

            slot_key = (today, sched["id"])
            if slot_key in self._fed_slots:
                continue   # already served this exact minute today

            self._fed_slots.add(slot_key)
            self._fed_slots = {s for s in self._fed_slots if s[0] == today}
            return sched

        return None

    # ─────────────────────────────────────────────
    #  ONE FULL FEEDING CYCLE
    # ─────────────────────────────────────────────
    def _feeding_cycle(self, sched):
        """
        Run one complete feeding attempt for a specific schedule.

        sched dict example:
          { id, cat_id, label, hour, minute, portion_g,
            enabled, active_days }
        """
        expected_cat_id = sched.get("cat_id")
        portion_g       = sched.get("portion_g", config.DEFAULT_PORTION_G)
        label           = sched.get("label", "Feeding")

        cat_data         = self.cloud.get_cat(expected_cat_id) or {}
        expected_cat_name = cat_data.get("name", expected_cat_id)

        # -- CALL_CAT --
        self.state = State.CALL_CAT
        self.log.info("[%02d:%02d] %s for %s -> CALL_CAT",
                      sched.get("hour", 0), sched.get("minute", 0),
                      label, expected_cat_name)
        self.voice.call(track=expected_cat_id)

        # -- WAIT_FOR_MOTION --
        self.state = State.WAIT_FOR_MOTION
        self.log.info("WAIT_FOR_MOTION (timeout %ss)", config.CALL_TIMEOUT_SEC)
        if not self.pir.wait_for_motion(config.CALL_TIMEOUT_SEC):
            self.log.info("%s did not arrive -> cancel, back to SLEEP", expected_cat_name)
            self.voice.stop()
            self.state = State.SLEEP
            return

        # -- VERIFY --
        self.state = State.VERIFY
        self.log.info("motion detected -> VERIFY (expecting %s)", expected_cat_name)
        print(f"\n{'='*50}\nMOTION DETECTED -- starting camera + AI verification\n{'='*50}", flush=True)
        authorized, identity, confidence = self.recognizer.verify(self.camera, self.voice)

        # -- DECISION --
        # A) authorized AND identity == expected_cat_id -> FEED (correct cat)
        # B) authorized AND identity != expected_cat_id -> DENY (wrong cat's turn)
        # C) not authorized                              -> DENY (unknown animal)
        correct_cat = authorized and (identity == expected_cat_id)
        wrong_cat   = authorized and (identity != expected_cat_id)

        if correct_cat:
            self.log.info("AUTHORIZED: %s (conf=%.4f) -> DISPENSE", expected_cat_name, confidence)
            self.dispense()
            self.sync_levels()

            self.state = State.LOG
            self.cloud.log_feeding(identity, expected_cat_name, True, confidence, portion_g)
            self.log.info("feeding logged for %s", expected_cat_name)

        elif wrong_cat:
            wrong_data = self.cloud.get_cat(identity) or {}
            wrong_name = wrong_data.get("name", identity)
            self.log.warning(
                "WRONG CAT: %s arrived at %s's meal time -> DENIED",
                wrong_name, expected_cat_name
            )
            self.state = State.LOG
            self.cloud.log_feeding(identity, wrong_name, False, confidence, 0)
            self.cloud.add_notification(
                expected_cat_id, "Wrong Cat Detected",
                f"{wrong_name} showed up at {expected_cat_name}'s feeding time.",
                "unrecognized_animal",
            )

        else:
            self.log.info("ACCESS DENIED (unknown animal, conf=%.4f)", confidence)
            self.state = State.LOG
            self.cloud.log_feeding("unknown", "unknown", False, confidence, 0)
            self.cloud.add_notification(
                expected_cat_id, "Unrecognized Animal",
                "An unrecognized animal was detected at the feeder.",
                "unrecognized_animal",
            )

        self.log.info("cooldown %ss -> SLEEP", config.COOLDOWN_SECONDS)
        time.sleep(config.COOLDOWN_SECONDS)
        self.state = State.SLEEP

    # ─────────────────────────────────────────────
    #  MAIN LOOP
    # ─────────────────────────────────────────────
    def run(self):
        self.log.info("=== Cat Feeder FSM starting ===")

        self.log.info("PIR warm-up %ss...", config.PIR_WARMUP_SEC)
        time.sleep(config.PIR_WARMUP_SEC)

        cats = self.cloud.get_cats()
        self.cloud.mark_pi_online(cats.keys(), online=True)
        self.log.info("found %d cat(s) in Firebase", len(cats))

        self.sync_levels()
        self.log.info("READY -> SLEEP")

        try:
            while True:
                self._background_tasks()
                sched = self._due_schedule()
                if sched:
                    self._feeding_cycle(sched)
                else:
                    self.state = State.SLEEP
                    time.sleep(1)
        finally:
            # Best-effort: tell the app the Pi went offline.
            try:
                self.cloud.mark_pi_online(self.cloud.get_cats().keys(), online=False)
            except Exception:
                pass
