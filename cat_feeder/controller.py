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
