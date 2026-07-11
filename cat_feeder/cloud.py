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

  feedings/{feedingId}
      cat_id, cat_name, authorized, confidence, portion_g, timestamp

  notifications/{notifId}
      cat_id, title, message, type, is_read, timestamp

  commands/{catId}            <- manual feed per cat
      type: "manual_feed", portion_g, consumed: false, created_at

  commands/enroll             <- enrollment triggered by the app
      status: "pending"|"capturing"|"done"|"failed"|"cancelled"|"idle"
      frames_done, frames_needed, instruction
      cat_id   (present when status=done or status=cancelled)
      reason   (present when status=failed)
"""

import datetime as dt
import os
import glob

import config
from log_setup import get_logger

GALLERY_DIR = "/home/raspberry/GP/AI_Cat_Feeder_System-main/data/galleries"


class Cloud:
    def __init__(self):
        self.log = get_logger("cloud")
        self.online = False
        self.db = None

        if config.SIMULATION:
            self.log.info("SIMULATION: cloud (no Firebase)")
            return

        try:
            import firebase_logger  # noqa: F401
            from firebase_admin import firestore
            self.db = firestore.client()
            self.online = True
            self.log.info("Firebase connected")
        except Exception as exc:
            self.log.error("Firebase unavailable (running offline): %s", exc)

    # ─────────────────────────────────────────────
    #  CATS
    # ─────────────────────────────────────────────
    def get_cats(self):
        if not self.online:
            return {}
        try:
            docs = self.db.collection("cats").stream()
            return {d.id: d.to_dict() for d in docs}
        except Exception as exc:
            self.log.error("get_cats failed: %s", exc)
            return {}

    def get_cat(self, cat_id):
        if not self.online:
            return None
        try:
            doc = self.db.collection("cats").document(cat_id).get()
            return doc.to_dict() if doc.exists else None
        except Exception as exc:
            self.log.error("get_cat(%s) failed: %s", cat_id, exc)
            return None

    def get_cat_ids(self):
        """
        Return a set of all cat IDs currently in Firebase.
        Used by _sync_galleries() to detect deleted cats.
        Returns empty set if Firebase is offline — caller must NOT delete
        gallery files when this returns empty.
        """
        if not self.online:
            return set()
        try:
            docs = self.db.collection("cats").stream()
            return {d.id for d in docs}
        except Exception as exc:
            self.log.error("get_cat_ids failed: %s", exc)
            return set()

    def touch_cat_last_seen(self, cat_id):
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
    #  SCHEDULES
    # ─────────────────────────────────────────────
    def get_schedules(self):
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
    #  SYSTEM STATUS
    # ─────────────────────────────────────────────
    def update_system_status(self, cat_id, food_pct, water_pct):
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
    #  FEEDINGS
    # ─────────────────────────────────────────────
    def log_feeding(self, cat_id, cat_name, authorized, confidence, portion_g):
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
    #  NOTIFICATIONS
    # ─────────────────────────────────────────────
    def add_notification(self, cat_id, title, message, notif_type="info"):
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
    #  COMMANDS (manual feed)
    # ─────────────────────────────────────────────
    def get_pending_command(self, cat_id):
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
        if not self.online:
            return
        try:
            self.db.collection("commands").document(cat_id).update({
                "consumed": True
            })
        except Exception as exc:
            self.log.error("consume_command(%s) failed: %s", cat_id, exc)

    # ─────────────────────────────────────────────
    #  ENROLLMENT
    # ─────────────────────────────────────────────
    def get_enroll_command(self):
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

    def complete_enrollment(self, cat_id):
        if not self.online:
            return
        try:
            self.db.collection("commands").document("enroll").set({
                "status": "done",
                "cat_id": cat_id,
            }, merge=True)
        except Exception as exc:
            self.log.error("complete_enrollment failed: %s", exc)

    def fail_enrollment(self, reason):
        if not self.online:
            return
        try:
            self.db.collection("commands").document("enroll").set({
                "status": "failed",
                "reason": reason,
            }, merge=True)
        except Exception as exc:
            self.log.error("fail_enrollment failed: %s", exc)

    def get_cancelled_enrollment(self):
        if not self.online:
            return None
        try:
            doc = self.db.collection("commands").document("enroll").get()
            if doc.exists:
                data = doc.to_dict()
                if data.get("status") == "cancelled" and data.get("cat_id"):
                    return data["cat_id"]
        except Exception as exc:
            self.log.error("get_cancelled_enrollment failed: %s", exc)
        return None

    def clear_enroll_command(self):
        if not self.online:
            return
        try:
            self.db.collection("commands").document("enroll").set({
                "status": "idle",
            })
        except Exception as exc:
            self.log.error("clear_enroll_command failed: %s", exc)

    def next_cat_id(self):
        """
        Generate the next available cat ID by looking at existing gallery files.
        e.g. if cat_001.json and cat_002.json exist -> returns 'cat_003'
        """
        try:
            existing = glob.glob(os.path.join(GALLERY_DIR, "cat_*.json"))
            numbers = []
            for f in existing:
                base = os.path.basename(f)
                num_str = base.replace("cat_", "").replace(".json", "")
                if num_str.isdigit():
                    numbers.append(int(num_str))
            next_num = max(numbers) + 1 if numbers else 1
            return f"cat_{next_num:03d}"
        except Exception as exc:
            self.log.error("next_cat_id failed: %s", exc)
            return "cat_999"

    def close(self):
        pass
