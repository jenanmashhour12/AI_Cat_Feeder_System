"""
cloud.py — Firebase wrapper, matching the Flutter app's REAL Firestore structure.

Collections used (all TOP-LEVEL, matching firebase_service.dart):

  cats/{catId}
      name, portion_g, water_g, total_feedings,
      enrolled_at, last_seen, image_url, voice_url

  settings/{catId}
      notifications_enabled, low_food_alert, low_water_alert,
      feeding_complete_alert, unrecognized_animal_alert,
      device_offline_alert, default_portion, call_sound_url

  system_status/{catId}
      food_level_pct, water_level_pct, pi_online, last_updated

  schedules/{scheduleId}
      cat_id, label, hour, minute, portion_g,
      enabled (bool), active_days (7 bools, Mon..Sun)
      [CONFIRMED on real Pi data 2026-06-30 -- field names below MUST
       match exactly: 'enabled' not 'isEnabled', 'active_days' not
       'activeDays', 'portion_g' not 'portion_grams']

  feedings/{feedingId}
      cat_id, cat_name, authorized, confidence, portion_g, timestamp

  notifications/{notifId}
      cat_id, title, message, type, is_read, timestamp

  commands/{catId}            <- NEW, needed for manual feed from the app
      type: "manual_feed", portion_g, consumed: false, created_at

The cloud is NON-CRITICAL: every method catches its own errors and logs them
instead of crashing. If Firebase is down the feeder keeps working offline.
"""

import datetime as dt

import config
from log_setup import get_logger


class Cloud:
    def __init__(self):
        self.log = get_logger("cloud")
        self.online = False
        self.db = None

        if config.SIMULATION:
            self.log.info("SIMULATION: cloud (no Firebase)")
            return

        try:
            # Import only for the side effect of initialising the Firebase app
            # (firebase_logger already calls firebase_admin.initialize_app()).
            import firebase_logger  # noqa: F401

            from firebase_admin import firestore
            self.db = firestore.client()
            self.online = True
            self.log.info("Firebase connected")
        except Exception as exc:
            self.log.error("Firebase unavailable (running offline): %s", exc)

    # ─────────────────────────────────────────────
    #  CATS   ->  collection "cats"
    # ─────────────────────────────────────────────
    def get_cats(self):
        """
        Return all cats as a dict: { cat_id: {name, portion_g, water_g, ...} }
        Matches cat_profile.dart's CatProfile.fromMap fields.
        """
        if not self.online:
            return {}
        try:
            docs = self.db.collection("cats").stream()
            return {d.id: d.to_dict() for d in docs}
        except Exception as exc:
            self.log.error("get_cats failed: %s", exc)
            return {}

    def get_cat(self, cat_id):
        """Return one cat's data dict, or None."""
        if not self.online:
            return None
        try:
            doc = self.db.collection("cats").document(cat_id).get()
            return doc.to_dict() if doc.exists else None
        except Exception as exc:
            self.log.error("get_cat(%s) failed: %s", cat_id, exc)
            return None

    def touch_cat_last_seen(self, cat_id):
        """Update last_seen + increment total_feedings after a successful feed."""
        if not self.online:
            return
        try:
            from google.cloud.firestore_v1 import Increment
            self.db.collection("cats").document(cat_id).update({
                "last_seen": dt.datetime.now().isoformat(),
                "total_feedings": Increment(1),
            })
        except Exception as exc:
            self.log.error("touch_cat_last_seen(%s) failed: %s", cat_id, exc)

    # ─────────────────────────────────────────────
    #  SCHEDULES   ->  collection "schedules"
    # ─────────────────────────────────────────────
    def get_schedules(self):
        """
        Return ALL schedules across all cats as a list of dicts:
          { id, cat_id, label, hour, minute, portion_grams,
            isEnabled, activeDays:[7 bools, Mon..Sun] }
        Matches FeedingSchedule.toMap() in the app.
        """
        if not self.online:
            return []
        try:
            docs = self.db.collection("schedules").stream()
            result = []
            for d in docs:
                data = d.to_dict()
                data["id"] = d.id
                result.append(data)
            return result
        except Exception as exc:
            self.log.error("get_schedules failed: %s", exc)
            return []

    # ─────────────────────────────────────────────
    #  SYSTEM STATUS (per cat)   ->  collection "system_status"
    # ─────────────────────────────────────────────
    def update_system_status(self, cat_id, food_pct, water_pct):
        """
        Push real food/water levels for ONE cat's feeder.
        Matches SystemStatus.fromMap() field names in the app.
        """
        if not self.online:
            return
        try:
            self.db.collection("system_status").document(cat_id).set({
                "food_level_pct":  food_pct,
                "water_level_pct": water_pct,
                "pi_online": True,
                "last_updated": dt.datetime.now().isoformat(),
            }, merge=True)
        except Exception as exc:
            self.log.error("update_system_status(%s) failed: %s", cat_id, exc)

    def mark_pi_online(self, cat_ids, online=True):
        """Set pi_online=True/False for every cat's system_status doc."""
        if not self.online:
            return
        try:
            batch = self.db.batch()
            for cat_id in cat_ids:
                ref = self.db.collection("system_status").document(cat_id)
                batch.set(ref, {
                    "pi_online": online,
                    "last_updated": dt.datetime.now().isoformat(),
                }, merge=True)
            batch.commit()
        except Exception as exc:
            self.log.error("mark_pi_online failed: %s", exc)

    # ─────────────────────────────────────────────
    #  FEEDINGS (activity log)   ->  collection "feedings"
    # ─────────────────────────────────────────────
    def log_feeding(self, cat_id, cat_name, authorized, confidence, portion_g):
        """
        Write one feeding event as a NEW document in the 'feedings' collection.
        Matches ActivityLog.fromFeeding() expectations in the app.
        """
        if not self.online:
            return
        try:
            self.db.collection("feedings").add({
                "cat_id":     cat_id,
                "cat_name":   cat_name,
                "authorized": authorized,
                "confidence": confidence,
                "portion_g":  portion_g,
                "timestamp":  dt.datetime.now().isoformat(),
            })
            if authorized and cat_id not in ("manual", "unknown"):
                self.touch_cat_last_seen(cat_id)
        except Exception as exc:
            self.log.error("log_feeding failed: %s", exc)

    # ─────────────────────────────────────────────
    #  NOTIFICATIONS   ->  collection "notifications"
    # ─────────────────────────────────────────────
    def add_notification(self, cat_id, title, message, notif_type="info"):
        """
        Write a notification the app can show (e.g. low food, unrecognized
        animal). Matches NotificationItem.fromMap() in the app.
        """
        if not self.online:
            return
        try:
            self.db.collection("notifications").add({
                "cat_id":    cat_id,
                "title":     title,
                "message":   message,
                "type":      notif_type,
                "is_read":   False,
                "timestamp": dt.datetime.now().isoformat(),
            })
        except Exception as exc:
            self.log.error("add_notification failed: %s", exc)

    # ─────────────────────────────────────────────
    #  COMMANDS (manual feed)   ->  collection "commands"
    #  NOTE: this collection does not exist yet in firebase_service.dart --
    #  it needs to be added to the app for manual feed to work. See the
    #  companion .md file for the exact Dart code to add.
    # ─────────────────────────────────────────────
    def get_pending_command(self, cat_id):
        """
        Return an unconsumed manual-feed command for this cat, or None.
        Looks for: commands/{cat_id} = { type, portion_g, consumed: false }
        """
        if not self.online:
            return None
        try:
            doc = self.db.collection("commands").document(cat_id).get()
            if doc.exists:
                data = doc.to_dict()
                if data.get("type") == "manual_feed" and not data.get("consumed", True):
                    return data
        except Exception as exc:
            self.log.error("get_pending_command(%s) failed: %s", cat_id, exc)
        return None

    def consume_command(self, cat_id):
        """Mark a command as handled so it doesn't trigger again."""
        if not self.online:
            return
        try:
            self.db.collection("commands").document(cat_id).update({
                "consumed": True
            })
        except Exception as exc:
            self.log.error("consume_command(%s) failed: %s", cat_id, exc)

    # ─────────────────────────────────────────────
    #  ENROLLMENT   ->  document "commands/enroll"
    #
    #  The app writes { status: "pending" } to start enrollment.
    #  The Pi reads it, captures frames, updates progress, and writes
    #  the result (done/failed) back to the same document.
    # ─────────────────────────────────────────────
    def get_enroll_command(self):
        """
        Check if the app has sent an enrollment request.
        Returns the document dict if status is 'pending', else None.
        """
        if not self.online:
            return None
        try:
            doc = self.db.collection("commands").document("enroll").get()
            if doc.exists:
                data = doc.to_dict()
                if data.get("status") == "pending":
                    return data
        except Exception as exc:
            self.log.error("get_enroll_command failed: %s", exc)
        return None

    def update_enroll_progress(self, frames_done, frames_needed, instruction):
        """
        Write live progress to Firebase so the app can show the user
        what is happening in real time (progress bar + instruction text).
        Called every 5 frames during enrollment.
        """
        if not self.online:
            return
        try:
            self.db.collection("commands").document("enroll").set({
                "status":        "capturing",
                "frames_done":   frames_done,
                "frames_needed": frames_needed,
                "instruction":   instruction,
            }, merge=True)
        except Exception as exc:
            self.log.error("update_enroll_progress failed: %s", exc)

    def complete_enrollment(self, cat_id, frames_needed=40):
        """
        Write enrollment success to Firebase.
        The app detects status='done' and cat_id, then shows the
        cat info form so the user can name the cat.
        """
        if not self.online:
            return
        try:
            self.db.collection("commands").document("enroll").set({
                "status":        "done",
                "cat_id":        cat_id,
                "frames_done":   frames_needed,
                "frames_needed": frames_needed,
                "instruction":   "Your cat has been recognized successfully!",
            }, merge=True)
            self.log.info("enrollment complete -> cat_id=%s", cat_id)
        except Exception as exc:
            self.log.error("complete_enrollment failed: %s", exc)

    def get_cancelled_enrollment(self):
        """
        Check if the user cancelled after enrollment succeeded (i.e. they
        did not enter the cat name on the info form).

        When this happens:
          - The gallery JSON already exists on the Pi (cat_003.json)
          - Firebase cats/cat_003 was never written (user cancelled)
          - The app wrote status='cancelled' + cat_id to commands/enroll

        Returns the cat_id of the orphan gallery that needs to be deleted,
        or None if no cancellation is pending.
        """
        if not self.online:
            return None
        try:
            doc = self.db.collection("commands").document("enroll").get()
            if doc.exists:
                data = doc.to_dict()
                if data.get("status") == "cancelled" and data.get("cat_id"):
                    return data.get("cat_id")
        except Exception as exc:
            self.log.error("get_cancelled_enrollment failed: %s", exc)
        return None

    def clear_enroll_command(self):
        """Reset the enroll command to idle after cleanup."""
        if not self.online:
            return
        try:
            self.db.collection("commands").document("enroll").set(
                {"status": "idle"}, merge=True
            )
        except Exception as exc:
            self.log.error("clear_enroll_command failed: %s", exc)

    def fail_enrollment(self, reason):
        """
        Write enrollment failure to Firebase with a human-readable reason.
        The app shows the reason and a 'Try Again' button.
        """
        if not self.online:
            return
        try:
            self.db.collection("commands").document("enroll").set({
                "status":  "failed",
                "reason":  reason,
                "instruction": "Enrollment failed. Please try again.",
            }, merge=True)
            self.log.warning("enrollment failed: %s", reason)
        except Exception as exc:
            self.log.error("fail_enrollment failed: %s", exc)

    def _next_cat_id(self):
        """
        Generate the next available cat ID by finding the highest existing
        numbered gallery and incrementing it (e.g. cat_002 -> cat_003).
        Falls back to cat_001 if no numbered cats exist yet.
        """
        import os, re
        galleries_dir = "/home/raspberry/GP/AI_Cat_Feeder_System-main/data/galleries"
        try:
            files = os.listdir(galleries_dir)
            numbers = []
            for f in files:
                match = re.match(r"cat_(\d+)\.json", f)
                if match:
                    numbers.append(int(match.group(1)))
            if numbers:
                return f"cat_{max(numbers) + 1:03d}"
        except Exception as exc:
            self.log.error("_next_cat_id failed: %s", exc)
        return "cat_001"

    def close(self):
        pass