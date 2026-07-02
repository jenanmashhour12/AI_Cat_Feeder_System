#!/usr/bin/env python3
"""
read_firebase_data.py — Show EVERYTHING the Pi can currently read from Firebase.

  python3 read_firebase_data.py

This does NOT touch any hardware (no pump, no servo, no camera). It only
connects to Firebase and prints out every collection the system uses, in a
clean readable format, so you can confirm the app's data is actually there
and in the format the Pi expects.
"""

import sys
import json

import config

for _path in config.PROJECT_PATHS:
    if _path not in sys.path:
        sys.path.append(_path)

from log_setup import setup_logging  # noqa: E402

DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


def line(char="─", n=60):
    print(char * n)


def header(title):
    print()
    line("═")
    print(f"  {title}")
    line("═")


def pretty(value):
    try:
        return json.dumps(value, indent=2, default=str)
    except Exception:
        return str(value)


def show_cats(cloud):
    header("CATS  (collection: cats)")
    cats = cloud.get_cats()
    if not cats:
        print("  (no cats found)")
        return cats

    print(f"  Total cats: {len(cats)}\n")
    for cat_id, data in cats.items():
        print(f"  ── {cat_id} ──")
        print(f"     name:           {data.get('name')}")
        print(f"     portion_g:      {data.get('portion_g')}")
        print(f"     water_g:        {data.get('water_g')}")
        print(f"     total_feedings: {data.get('total_feedings')}")
        print(f"     enrolled_at:    {data.get('enrolled_at')}")
        print(f"     last_seen:      {data.get('last_seen')}")
        print(f"     image_url:      {data.get('image_url')}")
        print(f"     voice_url:      {data.get('voice_url')}")
        print()
    return cats


def show_schedules(cloud, cats):
    header("SCHEDULES  (collection: schedules)")
    schedules = cloud.get_schedules()
    if not schedules:
        print("  (no schedules found)")
        return

    print(f"  Total schedules: {len(schedules)}\n")
    schedules.sort(key=lambda s: (s.get("hour", 0), s.get("minute", 0)))

    for s in schedules:
        cat_id   = s.get("cat_id")
        cat_name = cats.get(cat_id, {}).get("name", cat_id)
        hh = s.get("hour", 0)
        mm = s.get("minute", 0)

        # FIXED: use real field names confirmed from live Firebase data:
        # 'active_days' not 'activeDays'
        # 'enabled'     not 'isEnabled'
        # 'portion_g'   not 'portion_grams'
        days     = s.get("active_days", [])
        enabled  = s.get("enabled", True)
        portion  = s.get("portion_g", 0)
        active_day_names = [DAY_NAMES[i] for i, on in enumerate(days) if on] if days else []

        print(f"  ── {s.get('id')} ──")
        print(f"     time:        {hh:02d}:{mm:02d}")
        print(f"     cat:         {cat_name}  ({cat_id})")
        print(f"     label:       {s.get('label')}")
        print(f"     portion_g:   {portion}")
        print(f"     enabled:     {enabled}")
        print(f"     active_days: {days}  ->  {', '.join(active_day_names) or 'none'}")
        print()


def show_system_status(cloud, cats):
    header("SYSTEM STATUS  (collection: system_status, per cat)")
    if not cats:
        print("  (no cats, nothing to show)")
        return

    for cat_id, cat_data in cats.items():
        try:
            doc  = cloud.db.collection("system_status").document(cat_id).get()
            data = doc.to_dict() if doc.exists else None
        except Exception as exc:
            print(f"  {cat_id}: ERROR reading status ({exc})")
            continue

        print(f"  ── {cat_data.get('name', cat_id)}  ({cat_id}) ──")
        if not data:
            print("     (no system_status document yet)")
        else:
            print(f"     food_level_pct:  {data.get('food_level_pct')}")
            print(f"     water_level_pct: {data.get('water_level_pct')}")
            print(f"     pi_online:       {data.get('pi_online')}")
            print(f"     last_updated:    {data.get('last_updated')}")
        print()


def show_settings(cloud, cats):
    header("SETTINGS  (collection: settings, per cat)")
    if not cats:
        print("  (no cats, nothing to show)")
        return

    for cat_id, cat_data in cats.items():
        try:
            doc  = cloud.db.collection("settings").document(cat_id).get()
            data = doc.to_dict() if doc.exists else None
        except Exception as exc:
            print(f"  {cat_id}: ERROR reading settings ({exc})")
            continue

        print(f"  ── {cat_data.get('name', cat_id)}  ({cat_id}) ──")
        if not data:
            print("     (no settings document yet)")
        else:
            for k, v in data.items():
                print(f"     {k}: {v}")
        print()


def show_recent_feedings(cloud, cats, limit=10):
    header(f"RECENT FEEDINGS  (collection: feedings, last {limit})")
    try:
        docs = list(
            cloud.db.collection("feedings")
            .order_by("timestamp", direction="DESCENDING")
            .limit(limit)
            .stream()
        )
    except Exception as exc:
        print(f"  ERROR reading feedings: {exc}")
        print("  (may need a Firestore composite index — check Firebase console)")
        return

    if not docs:
        print("  (no feedings logged yet)")
        return

    for d in docs:
        data   = d.to_dict()
        status = "AUTHORIZED" if data.get("authorized") else "DENIED"
        print(f"  [{data.get('timestamp')}] {status:10} "
              f"cat={data.get('cat_name')} conf={data.get('confidence')} "
              f"portion={data.get('portion_g')}g")


def show_notifications(cloud, cats, limit=10):
    header(f"RECENT NOTIFICATIONS  (collection: notifications, last {limit})")
    try:
        docs = list(
            cloud.db.collection("notifications")
            .order_by("timestamp", direction="DESCENDING")
            .limit(limit)
            .stream()
        )
    except Exception as exc:
        print(f"  ERROR reading notifications: {exc}")
        return

    if not docs:
        print("  (no notifications yet)")
        return

    for d in docs:
        data      = d.to_dict()
        read_flag = "read" if data.get("is_read") else "UNREAD"
        print(f"  [{data.get('timestamp')}] ({read_flag}) "
              f"{data.get('title')}: {data.get('message')}")


def show_pending_commands(cloud, cats):
    header("PENDING COMMANDS  (collection: commands, per cat)")
    if not cats:
        print("  (no cats, nothing to show)")
        return

    found_any = False
    for cat_id, cat_data in cats.items():
        cmd = cloud.get_pending_command(cat_id)
        if cmd:
            found_any = True
            print(f"  -- {cat_data.get('name', cat_id)}  ({cat_id}) --")
            print(f"     {pretty(cmd)}")
            print()

    if not found_any:
        print("  (no pending manual-feed commands)")


def main():
    setup_logging()

    print("\n" + "=" * 60)
    print("  FIREBASE DATA READER — shows everything the Pi can read")
    print("=" * 60)

    from cloud import Cloud
    cloud = Cloud()

    if not cloud.online:
        print("\n  Could not connect to Firebase.")
        print("  Check serviceAccountKey.json and your internet connection.\n")
        return

    print("\n  Connected to Firebase\n")

    cats = show_cats(cloud)
    show_schedules(cloud, cats)
    show_system_status(cloud, cats)
    show_settings(cloud, cats)
    show_recent_feedings(cloud, cats)
    show_notifications(cloud, cats)
    show_pending_commands(cloud, cats)

    print()
    line("═")
    print("  DONE")
    line("═")
    print()


if __name__ == "__main__":
    main()
