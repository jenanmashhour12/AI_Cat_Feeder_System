#!/usr/bin/env python3
"""
main.py — Entry point for the AI Cat Feeder.

  python3 main.py

It validates the config, builds every component, runs the state machine, and
on ANY exit (Ctrl+C, crash, fatal error) guarantees the pump is OFF and the
hardware is released.
"""

import sys

import config

# Make the existing AI / Firebase / DFPlayer / servo modules importable.
for _path in config.PROJECT_PATHS:
    if _path not in sys.path:
        sys.path.append(_path)

from log_setup import setup_logging, get_logger  # noqa: E402
from errors import FeederError, ConfigError      # noqa: E402
import drivers                                    # noqa: E402
from recognizer import CatRecognizer              # noqa: E402
from cloud import Cloud                           # noqa: E402
from controller import FeederController           # noqa: E402


def build():
    """Validate config and construct every component. Returns (controller, closeables)."""
    log = get_logger("main")

    problems = config.validate()
    if problems:
        for p in problems:
            log.error("CONFIG: %s", p)
        raise ConfigError("Invalid configuration — fix the items listed above in config.py.")

    log.info("building components...")
    pump = drivers.WaterPump()
    food = drivers.LevelSensor("food", config.FOOD_TRIG_PIN, config.FOOD_ECHO_PIN,
                               config.FOOD_EMPTY_CM, config.FOOD_FULL_CM)
    water = drivers.LevelSensor("water", config.WATER_TRIG_PIN, config.WATER_ECHO_PIN,
                                config.WATER_EMPTY_CM, config.WATER_FULL_CM)
    pir = drivers.PirMotion()
    camera = drivers.CatCamera()
    voice = drivers.Voice()
    gate = drivers.FoodGate()
    recognizer = CatRecognizer()
    cloud = Cloud()

    controller = FeederController(pump, food, water, pir, camera, voice, gate, recognizer, cloud)

    # pump FIRST so cleanup turns it off before anything else.
    closeables = [pump, food, water, pir, camera, voice, gate, cloud]
    return controller, closeables


def main():
    setup_logging()
    log = get_logger("main")
    closeables = []
    try:
        controller, closeables = build()
        controller.run()
    except KeyboardInterrupt:
        log.info("stopped by user (Ctrl+C)")
    except ConfigError as exc:
        log.critical("configuration error: %s", exc)
    except FeederError as exc:
        log.critical("fatal feeder error: %s", exc)
    except Exception as exc:  # noqa: BLE001
        log.exception("unexpected error: %s", exc)
    finally:
        print("\nShutting down -- please wait a moment, do not press Ctrl+C again...", flush=True)
        for c in closeables:
            try:
                c.close()
            except (Exception, KeyboardInterrupt):  # noqa: BLE001
                # A second Ctrl+C during cleanup must NOT crash with a
                # traceback -- swallow it and keep closing the rest.
                pass
        log.info("cleanup complete — goodbye")
        print("Shutdown complete. Safe to close the terminal.", flush=True)


if __name__ == "__main__":
    main()
