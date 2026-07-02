#!/usr/bin/env python3
"""
selftest.py — Check each part of the system INDEPENDENTLY.

  python3 selftest.py

It tests config, pump, both level sensors, PIR, camera, voice, food gate, the
AI modules, and Firebase one by one, and prints PASS/FAIL for each — so when
something is wrong you immediately know WHICH part to fix.

⚠ Note: this actually clicks the pump briefly and dispenses a little food,
because that is the only way to truly test those actuators. Run it deliberately.
"""

import sys
import time

import config

for _path in config.PROJECT_PATHS:
    if _path not in sys.path:
        sys.path.append(_path)

from log_setup import setup_logging  # noqa: E402


def run_check(name, fn):
    """Run one check; print PASS/FAIL and return a bool."""
    try:
        fn()
        print(f"[ PASS ] {name}")
        return True
    except Exception as exc:  # noqa: BLE001
        print(f"[ FAIL ] {name}: {exc}")
        return False


def main():
    setup_logging()
    print("\n========== CAT FEEDER SELF-TEST ==========")
    if config.SIMULATION:
        print("(SIMULATION mode is ON — hardware is faked)\n")

    results = []
    import drivers

    # 1. Config
    problems = config.validate()
    ok = not problems
    print(f"[ {'PASS' if ok else 'FAIL'} ] config" + ("" if ok else f": {problems}"))
    results.append(("config", ok))

    # 2. Water pump (brief click)
    def t_pump():
        p = drivers.WaterPump()
        p.on(); time.sleep(0.4); p.off(); p.close()
    results.append(("pump", run_check("water pump (relay click)", t_pump)))

    # 3. Food level sensor
    def t_food():
        s = drivers.LevelSensor("food", config.FOOD_TRIG_PIN, config.FOOD_ECHO_PIN,
                                config.FOOD_EMPTY_CM, config.FOOD_FULL_CM)
        d = s.distance_cm()
        print(f"         food: {d:.1f} cm → {s.level_pct()}%")
        s.close()
    results.append(("food sensor", run_check("food HC-SR04", t_food)))

    # 4. Water level sensor
    def t_water():
        s = drivers.LevelSensor("water", config.WATER_TRIG_PIN, config.WATER_ECHO_PIN,
                                config.WATER_EMPTY_CM, config.WATER_FULL_CM)
        d = s.distance_cm()
        print(f"         water: {d:.1f} cm → {s.level_pct()}%")
        s.close()
    results.append(("water sensor", run_check("water HC-SR04", t_water)))

    # 5. PIR
    def t_pir():
        pir = drivers.PirMotion()
        print(f"         PIR currently reads motion = {pir.motion}")
        pir.close()
    results.append(("pir", run_check("PIR motion sensor", t_pir)))

    # 6. Camera
    def t_cam():
        c = drivers.CatCamera()
        frame = c.capture_bgr()
        print(f"         captured frame shape = {frame.shape}")
        c.close()
    results.append(("camera", run_check("camera capture", t_cam)))

    # 7. Voice
    def t_voice():
        v = drivers.Voice()
        v.call(); time.sleep(1.0); v.stop()
    results.append(("voice", run_check("DFPlayer voice", t_voice)))

    # 8. Food gate (servo)
    def t_gate():
        g = drivers.FoodGate()
        g.dispense()
    results.append(("gate", run_check("servo food gate", t_gate)))

    # 9. AI modules
    def t_ai():
        from recognizer import CatRecognizer
        CatRecognizer()
    results.append(("ai", run_check("AI modules load", t_ai)))

    # 10. Firebase
    def t_cloud():
        from cloud import Cloud
        c = Cloud()
        cats = c.get_cats()
        schedules = c.get_schedules()
        print(f"         cats in Firebase      = {list(cats.keys())}")
        print(f"         schedules in Firebase = {len(schedules)} found")
    results.append(("cloud", run_check("Firebase connection", t_cloud)))

    # Summary
    print("\n================== SUMMARY ==================")
    passed = sum(1 for _, r in results if r)
    for name, r in results:
        print(f"  {'OK ' if r else 'X  '} {name}")
    print(f"\n{passed}/{len(results)} checks passed")
    print("============================================\n")


if __name__ == "__main__":
    main()
