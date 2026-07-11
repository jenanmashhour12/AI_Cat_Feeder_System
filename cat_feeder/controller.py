"""
controller.py — The Finite State Machine (the brain loop).

States:
  Normal feeding:   SLEEP -> CALL_CAT -> WAIT_FOR_MOTION -> VERIFY -> DISPENSE -> LOG -> SLEEP
  Enrollment:       SLEEP -> ENROLL -> SLEEP

Water dispensing:
  The pump run time is calculated from the cat's water_g value stored in Firebase.
  Formula: pump_seconds = water_g / config.PUMP_ML_PER_SECOND
  Clamped between config.PUMP_MIN_SECONDS and config.PUMP_MAX_SECONDS for safety.

The ENROLL state is triggered by the app writing commands/enroll = { status: "pending" }
to Firebase. The Pi detects this in _background_tasks(), runs the full headless
enrollment (voice -> PIR -> camera -> 40 frames -> gallery saved), then writes
the result back to Firebase for the app to read.

Gallery sync:
  Every background cycle, _sync_galleries() compares gallery files on disk with
  cats in Firebase. If a gallery file has no matching Firebase document (cat was
  deleted from the app), the file is deleted and the matcher is reloaded so the
  deleted cat is no longer recognized.
"""

import glob
import os
import time
import numpy as np
from datetime import datetime
from enum import Enum, auto

import config
from errors import PumpError, GateError, SensorError
from log_setup import get_logger

# Gallery directory — must match cloud.py's GALLERY_DIR
GALLERY_DIR        = "/home/raspberry/GP/AI_Cat_Feeder_System-main/data/galleries"
TARGET_EMBEDDINGS  = 40
DIVERSITY_THRESHOLD = 0.95


class State(Enum):
    SLEEP           = auto()
    CALL_CAT        = auto()
    WAIT_FOR_MOTION = auto()
    VERIFY          = auto()
    DISPENSE        = auto()
    LOG             = auto()
    ENROLL          = auto()


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
        self._fed_slots = set()
        self._last_bg   = 0.0

    # ─────────────────────────────────────────────
    #  PUMP TIME CALCULATION
    # ─────────────────────────────────────────────
    def _water_seconds(self, water_g):
        """
        Convert a water amount (ml) into pump run time (seconds).

        Formula: seconds = water_g / PUMP_ML_PER_SECOND
        The pump delivers 33.3 ml/sec at 6V (120 L/hour from datasheet).

        The result is clamped:
          - minimum: PUMP_MIN_SECONDS  (so pump always has time to prime)
          - maximum: PUMP_MAX_SECONDS  (safety cap — prevents flooding)

        Examples at 33.3 ml/sec:
          50 ml  ->  1.5 sec
          100 ml ->  3.0 sec
          150 ml ->  4.5 sec
          200 ml ->  6.0 sec
          300 ml ->  9.0 sec
        """
        if not water_g or water_g <= 0:
            self.log.warning("water_g is %s — using fallback PUMP_RUN_SECONDS", water_g)
            return config.PUMP_RUN_SECONDS

        raw_seconds = water_g / config.PUMP_ML_PER_SECOND
        clamped     = max(config.PUMP_MIN_SECONDS,
                          min(config.PUMP_MAX_SECONDS, raw_seconds))

        self.log.info(
            "Water calculation: %gml / %.1fml·s⁻¹ = %.2fs  (clamped to %.2fs)",
            water_g, config.PUMP_ML_PER_SECOND, raw_seconds, clamped
        )
        return round(clamped, 2)

    # ─────────────────────────────────────────────
    #  LEVELS
    # ─────────────────────────────────────────────
    def read_levels(self):
        """Read both HC-SR04 sensors. Returns (food_pct, water_pct).
        Either can be None if its sensor failed."""
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
        (hardware is shared, so all cats see the same levels).
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
    #  GALLERY SYNC — auto-delete when cat removed from app
    # ─────────────────────────────────────────────
    def _sync_galleries(self):
        """
        Compare gallery files on disk with cats in Firebase.
        If a gallery file exists for a cat that is no longer in Firebase
        (the user deleted it from the app), delete the file and reload
        the matcher so that cat is no longer recognized.

        Safety: if Firebase is offline (get_cat_ids returns empty set),
        nothing is deleted — we never delete based on empty data.
        """
        firebase_cat_ids = self.cloud.get_cat_ids()
        if not firebase_cat_ids:
            # Firebase offline or no cats — don't delete anything
            return

        gallery_files  = glob.glob(os.path.join(GALLERY_DIR, "cat_*.json"))
        deleted_any    = False

        for gallery_path in gallery_files:
            cat_id = os.path.basename(gallery_path).replace(".json", "")
            if cat_id not in firebase_cat_ids:
                try:
                    os.remove(gallery_path)
                    self.log.info(
                        "Gallery deleted: %s (cat was removed from app)", cat_id
                    )
                    deleted_any = True
                except Exception as exc:
                    self.log.error(
                        "Could not delete gallery %s: %s", gallery_path, exc
                    )

        if deleted_any:
            # Reload matcher so deleted cat is no longer active
            try:
                self.recognizer.matcher.load_galleries()
                self.log.info("Matcher reloaded after gallery sync")
            except Exception as exc:
                self.log.warning("Matcher reload after gallery sync failed: %s", exc)

    # ─────────────────────────────────────────────
    #  DISPENSING
    # ─────────────────────────────────────────────
    def dispense(self, water_g=None):
        """
        Dispense water then food.

        water_g — ml of water to deliver (read from Firebase cats/{cat_id}.water_g).
                  If None, falls back to config.PUMP_RUN_SECONDS.

        The pump run time is calculated by _water_seconds() so the amount
        delivered matches what the user set in the app as closely as possible.
        """
        self.state = State.DISPENSE
        pump_seconds = self._water_seconds(water_g)
        try:
            self.log.info("Dispensing water: %.2fs (target %sml)", pump_seconds, water_g)
            self.pump.dispense(seconds=pump_seconds)
        except PumpError as exc:
            self.log.error("water dispense failed: %s", exc)
        try:
            self.gate.dispense()
        except GateError as exc:
            self.log.error("food dispense failed: %s", exc)

    # ─────────────────────────────────────────────
    #  ENROLLMENT HELPERS
    # ─────────────────────────────────────────────
    @staticmethod
    def _is_diverse(new_embedding, stored_embeddings):
        """Return True if new_embedding is different enough from all stored ones."""
        if len(stored_embeddings) == 0:
            return True
        existing     = np.array(stored_embeddings)
        similarities = np.dot(existing, new_embedding)
        return float(np.max(similarities)) < DIVERSITY_THRESHOLD

    @staticmethod
    def _enrollment_instruction(frames_done, frames_needed,
                                face_found, quality_passed, quality_reason):
        """Generate a human-readable instruction for the app to show the owner."""
        if frames_done >= frames_needed - 5:
            return "Almost done! Just a few more seconds"
        if not face_found:
            return "Bring your cat closer to the camera"
        if not quality_passed:
            if quality_reason and "small" in quality_reason.lower():
                return "Move your cat a little closer"
            if quality_reason and ("blur" in quality_reason.lower()
                                   or "sharp" in quality_reason.lower()):
                return "Ask your cat to stay still"
            if quality_reason and ("dark" in quality_reason.lower()
                                   or "bright" in quality_reason.lower()):
                return "Try adding more light near the feeder"
        return "Perfect! Keep your cat in this position"

    # ─────────────────────────────────────────────
    #  HEADLESS ENROLLMENT
    # ─────────────────────────────────────────────
    def enroll_from_command(self):
        """
        Run the full enrollment process without any screen or keyboard.
        Triggered when _background_tasks() detects commands/enroll status='pending'.
        """
        self.state = State.ENROLL
        self.log.info("=== ENROLLMENT STARTED (triggered by app) ===")

        cat_id = self.cloud.next_cat_id()
        self.log.info("New cat will be enrolled as: %s", cat_id)

        self.cloud.update_enroll_progress(0, TARGET_EMBEDDINGS,
                                          "Bring your cat to the feeder")

        if config.SIMULATION:
            self.log.info("SIMULATION: enrollment skipped")
            self.cloud.complete_enrollment(cat_id)
            self.state = State.SLEEP
            return

        detector = self.recognizer.detector
        embedder = self.recognizer.embedder
        matcher  = self.recognizer.matcher

        if detector is None or embedder is None or matcher is None:
            self.log.error("AI modules not loaded — cannot enroll")
            self.cloud.fail_enrollment("AI modules are not available on the Pi")
            self.state = State.SLEEP
            return

        self.log.info("Playing voice to call the cat...")
        self.voice.call(track="cat_001")

        self.log.info("Waiting for motion (timeout %ss)...", config.CALL_TIMEOUT_SEC)
        if not self.pir.wait_for_motion(config.CALL_TIMEOUT_SEC):
            self.log.warning("No motion detected during enrollment — aborting")
            self.voice.stop()
            self.cloud.fail_enrollment(
                "No cat was detected at the feeder. Please try again."
            )
            self.state = State.SLEEP
            return

        self.voice.stop()
        self.log.info("Motion detected — starting frame capture")

        try:
            matcher.enroll_cat(cat_id, cat_id)
        except Exception as exc:
            self.log.error("matcher.enroll_cat failed: %s", exc)
            self.cloud.fail_enrollment(f"Matcher setup failed: {exc}")
            self.state = State.SLEEP
            return

        stored_embeddings  = []
        frame_count        = 0
        rejected_quality   = 0
        rejected_diversity = 0
        last_progress_push = 0

        while len(stored_embeddings) < TARGET_EMBEDDINGS:
            frame_count += 1

            try:
                bgr = self.camera.capture_bgr()
            except Exception as exc:
                self.log.error("Camera error during enrollment (frame %d): %s",
                               frame_count, exc)
                self.cloud.fail_enrollment(
                    "Camera stopped working during enrollment. Please try again."
                )
                self.state = State.SLEEP
                return

            try:
                rois, boxes = detector.detect(bgr)
            except Exception as exc:
                self.log.warning("Detector error on frame %d: %s", frame_count, exc)
                rois, boxes = [], []

            face_found     = len(rois) > 0
            quality_passed = False
            quality_reason = ""
            embedding      = None

            if face_found:
                best_idx, best_q = -1, 0
                qualities = [detector.assess_quality(roi) for roi in rois]
                for i, (score, passed, reason) in enumerate(qualities):
                    if passed and score > best_q:
                        best_q   = score
                        best_idx = i

                if best_idx >= 0:
                    quality_passed = True
                    quality_reason = ""
                    try:
                        embedding = embedder.extract(rois[best_idx])
                    except Exception as exc:
                        self.log.warning("Embedder error on frame %d: %s",
                                         frame_count, exc)
                        embedding = None
                else:
                    _, _, quality_reason = qualities[0]
                    rejected_quality += 1

            if embedding is not None:
                if self._is_diverse(embedding, stored_embeddings):
                    stored_embeddings.append(embedding)
                    matcher.add_embedding(cat_id, embedding)
                    count = len(stored_embeddings)
                    self.log.info("Enrollment frame stored %d/%d",
                                  count, TARGET_EMBEDDINGS)

                    if count - last_progress_push >= 5 or count == TARGET_EMBEDDINGS:
                        instruction = self._enrollment_instruction(
                            count, TARGET_EMBEDDINGS,
                            face_found, quality_passed, quality_reason
                        )
                        self.cloud.update_enroll_progress(
                            count, TARGET_EMBEDDINGS, instruction
                        )
                        last_progress_push = count
                else:
                    rejected_diversity += 1

            time.sleep(0.1)

        self.log.info(
            "Enrollment capture complete: %d stored | %d quality-rejected "
            "| %d diversity-rejected | %d total frames",
            len(stored_embeddings), rejected_quality,
            rejected_diversity, frame_count
        )

        try:
            summary = matcher.finalize_enrollment(cat_id)
            self.log.info(
                "Gallery saved for %s | intra_sim=%.4f | threshold=%.4f",
                cat_id,
                summary.get("intra_similarity", 0),
                summary.get("adaptive_threshold", 0),
            )
        except Exception as exc:
            self.log.error("finalize_enrollment failed: %s", exc)
            self.cloud.fail_enrollment(
                f"Could not save the cat's recognition data: {exc}"
            )
            self.state = State.SLEEP
            return

        try:
            matcher.load_galleries()
            self.log.info("Matcher reloaded — %s is now active", cat_id)
        except Exception as exc:
            self.log.warning("Matcher reload failed (new cat may need restart): %s", exc)

        self.cloud.complete_enrollment(cat_id)
        self.log.info("=== ENROLLMENT DONE: %s is ready for recognition ===", cat_id)
        self.state = State.SLEEP

    # ─────────────────────────────────────────────
    #  BACKGROUND TASKS  (every BACKGROUND_EVERY seconds)
    # ─────────────────────────────────────────────
    def _background_tasks(self):
        if time.time() - self._last_bg < config.BACKGROUND_EVERY:
            return

        self.sync_levels()

        # ── Sync galleries — delete files for cats removed from app ─────
        self._sync_galleries()

        # ── Check for app-requested enrollment ──────────────────────────
        enroll_cmd = self.cloud.get_enroll_command()
        if enroll_cmd:
            self.log.info("Enrollment request from app detected — starting enrollment")
            self.enroll_from_command()
            self._last_bg = time.time()
            return

        # ── Check for orphan cleanup (user cancelled after Pi finished) ──
        orphan_cat_id = self.cloud.get_cancelled_enrollment()
        if orphan_cat_id:
            gallery_path = os.path.join(GALLERY_DIR, f"{orphan_cat_id}.json")
            if os.path.exists(gallery_path):
                try:
                    os.remove(gallery_path)
                    self.log.info("Deleted orphan gallery: %s", gallery_path)
                except Exception as exc:
                    self.log.error("Could not delete orphan gallery %s: %s",
                                   gallery_path, exc)
            try:
                self.recognizer.matcher.load_galleries()
                self.log.info("Matcher reloaded after orphan cleanup")
            except Exception as exc:
                self.log.warning("Matcher reload after cleanup failed: %s", exc)
            self.cloud.clear_enroll_command()

        # ── Check every registered cat for a pending manual-feed command ──
        for cat_id, cat_data in self.cloud.get_cats().items():
            cmd = self.cloud.get_pending_command(cat_id)
            if cmd:
                portion  = cmd.get("portion_g", config.DEFAULT_PORTION_G)
                water_g  = cat_data.get("water_g", config.DEFAULT_WATER_G)
                cat_name = cat_data.get("name", cat_id)
                self.log.info("MANUAL feed from app -> %s portion=%sg water=%gml",
                              cat_name, portion, water_g)
                self.dispense(water_g=water_g)
                self.sync_levels()
                self.cloud.log_feeding(cat_id, cat_name, True, 1.0, portion)
                self.cloud.consume_command(cat_id)
                self.state = State.SLEEP

        self._last_bg = time.time()

    # ─────────────────────────────────────────────
    #  SCHEDULE — find the due schedule
    # ─────────────────────────────────────────────
    def _due_schedule(self):
        """
        Check every schedule in Firebase. A schedule fires if:
          - enabled is True
          - hour:minute matches right now
          - today's weekday flag in active_days is True
          - this (date, schedule_id) hasn't already fired today
        """
        now     = datetime.now()
        today   = now.strftime("%Y-%m-%d")
        day_idx = now.isoweekday() - 1   # 0=Mon .. 6=Sun

        for sched in self.cloud.get_schedules():
            if not sched.get("enabled", True):
                continue
            if sched.get("hour") != now.hour or sched.get("minute") != now.minute:
                continue

            active_days = sched.get("active_days", [True] * 7)
            if day_idx >= len(active_days) or not active_days[day_idx]:
                continue

            slot_key = (today, sched["id"])
            if slot_key in self._fed_slots:
                continue

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
        Reads water_g from Firebase cats/{cat_id} so the pump time matches
        exactly what the user set in the app.
        """
        expected_cat_id   = sched.get("cat_id")
        portion_g         = sched.get("portion_g", config.DEFAULT_PORTION_G)
        label             = sched.get("label", "Feeding")
        cat_data          = self.cloud.get_cat(expected_cat_id) or {}
        expected_cat_name = cat_data.get("name", expected_cat_id)
        water_g           = cat_data.get("water_g", config.DEFAULT_WATER_G)

        # -- CALL_CAT --
        self.state = State.CALL_CAT
        self.log.info("[%02d:%02d] %s for %s (water=%gml) -> CALL_CAT",
                      sched.get("hour", 0), sched.get("minute", 0),
                      label, expected_cat_name, water_g)
        self.voice.call(track=expected_cat_id)

        # -- WAIT_FOR_MOTION --
        self.state = State.WAIT_FOR_MOTION
        self.log.info("WAIT_FOR_MOTION (timeout %ss)", config.CALL_TIMEOUT_SEC)
        if not self.pir.wait_for_motion(config.CALL_TIMEOUT_SEC):
            self.log.info("%s did not arrive -> cancel, back to SLEEP",
                          expected_cat_name)
            self.voice.stop()
            self.state = State.SLEEP
            return

        # -- VERIFY --
        self.state = State.VERIFY
        self.log.info("motion detected -> VERIFY (expecting %s)", expected_cat_name)
        print(f"\n{'='*50}\nMOTION DETECTED -- starting camera + AI verification\n{'='*50}",
              flush=True)
        authorized, identity, confidence = self.recognizer.verify(self.camera, self.voice)

        # -- DECISION --
        correct_cat = authorized and (identity == expected_cat_id)
        wrong_cat   = authorized and (identity != expected_cat_id)

        if correct_cat:
            self.log.info("AUTHORIZED: %s (conf=%.4f) -> DISPENSE %gml",
                          expected_cat_name, confidence, water_g)
            self.dispense(water_g=water_g)
            self.sync_levels()
            self.state = State.LOG
            self.cloud.log_feeding(identity, expected_cat_name, True, confidence, portion_g)
            self.log.info("feeding logged for %s", expected_cat_name)

        elif wrong_cat:
            wrong_data = self.cloud.get_cat(identity) or {}
            wrong_name = wrong_data.get("name", identity)
            self.log.warning("WRONG CAT: %s arrived at %s's meal time -> DENIED",
                             wrong_name, expected_cat_name)
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
            try:
                self.cloud.mark_pi_online(self.cloud.get_cats().keys(), online=False)
            except Exception:
                pass
