"""
drivers.py — Hardware driver classes.

Each physical component is wrapped in a small class with:
  - safe initialisation (clear error if the GPIO/library is missing),
  - a clean public method or two,
  - a close() that releases the hardware,
  - SIMULATION support (config.SIMULATION = True runs with no real hardware).

Heavy libraries (gpiozero, picamera2, cv2) are imported INSIDE __init__ so this
file can be inspected/compiled on a normal PC without them installed.
"""

import time

import config
from errors import PumpError, SensorError, CameraError, GateError, HardwareError
from log_setup import get_logger


# ════════════════════════════════════════════════════════════════
#  WATER PUMP (via relay)
# ════════════════════════════════════════════════════════════════
class WaterPump:
    """Controls the water pump through a relay. Pump amount = run time."""

    def __init__(self):
        self.log = get_logger("pump")
        self._dev = None
        if config.SIMULATION:
            self.log.info("SIMULATION: water pump (no GPIO)")
            return
        try:
            from gpiozero import OutputDevice
            self._dev = OutputDevice(
                config.PUMP_RELAY_PIN,
                active_high=config.RELAY_ACTIVE_HIGH,
                initial_value=False,  # guaranteed OFF at startup
            )
        except Exception as exc:  # noqa: BLE001
            raise PumpError(
                f"Failed to init pump on GPIO {config.PUMP_RELAY_PIN}: {exc}"
            ) from exc

    def on(self):
        if self._dev:
            self._dev.on()

    def off(self):
        if self._dev:
            self._dev.off()

    def dispense(self, seconds=None):
        """Run the pump for `seconds` (defaults to config.PUMP_RUN_SECONDS)."""
        seconds = config.PUMP_RUN_SECONDS if seconds is None else seconds
        self.log.info("Dispensing water for %.1fs", seconds)
        if config.SIMULATION:
            return
        try:
            self.on()
            time.sleep(seconds)
        except Exception as exc:  # noqa: BLE001
            raise PumpError(f"Pump dispense failed: {exc}") from exc
        finally:
            self.off()  # never leave the pump running

    def close(self):
        try:
            self.off()
            if self._dev:
                self._dev.close()
        except Exception:  # noqa: BLE001
            pass


# ════════════════════════════════════════════════════════════════
#  LEVEL SENSOR (HC-SR04)
# ════════════════════════════════════════════════════════════════
class LevelSensor:
    """One HC-SR04 ultrasonic sensor → fill percentage for a container."""

    def __init__(self, name, trig_pin, echo_pin, empty_cm, full_cm):
        self.name = name
        self.empty_cm = empty_cm
        self.full_cm = full_cm
        self.log = get_logger(f"level.{name}")
        self._dev = None
        if config.SIMULATION:
            self.log.info("SIMULATION: %s level sensor", name)
            return
        try:
            from gpiozero import DistanceSensor
            self._dev = DistanceSensor(
                echo=echo_pin, trigger=trig_pin, max_distance=1.0
            )
        except Exception as exc:  # noqa: BLE001
            raise SensorError(
                f"Failed to init {name} HC-SR04 (trig={trig_pin}, echo={echo_pin}): {exc}"
            ) from exc

    def distance_cm(self, samples=5):
        """Median distance in cm (averaged to reduce ultrasonic noise)."""
        if config.SIMULATION:
            return (self.empty_cm + self.full_cm) / 2.0
        try:
            reads = []
            for _ in range(samples):
                reads.append(self._dev.distance * 100.0)  # metres → cm
                time.sleep(0.05)
            reads.sort()
            return reads[len(reads) // 2]
        except Exception as exc:  # noqa: BLE001
            raise SensorError(f"{self.name} sensor read failed: {exc}") from exc

    def level_pct(self):
        """Convert the measured distance to a 0–100 fill percentage."""
        span = self.empty_cm - self.full_cm
        if span <= 0:
            raise SensorError(
                f"{self.name} bad calibration: empty ({self.empty_cm}) <= full ({self.full_cm})"
            )
        distance = self.distance_cm()
        pct = (self.empty_cm - distance) / span * 100.0
        return int(max(0, min(100, pct)))

    def close(self):
        try:
            if self._dev:
                self._dev.close()
        except Exception:  # noqa: BLE001
            pass


# ════════════════════════════════════════════════════════════════
#  PIR MOTION SENSOR
# ════════════════════════════════════════════════════════════════
class PirMotion:
    """PIR motion sensor wrapper."""

    def __init__(self):
        self.log = get_logger("pir")
        self._dev = None
        if config.SIMULATION:
            self.log.info("SIMULATION: PIR (always reports motion)")
            return
        try:
            from gpiozero import MotionSensor
            self._dev = MotionSensor(config.PIR_PIN)
        except Exception as exc:  # noqa: BLE001
            raise HardwareError(
                f"Failed to init PIR on GPIO {config.PIR_PIN}: {exc}"
            ) from exc

    @property
    def motion(self):
        if config.SIMULATION:
            return True
        return bool(self._dev.motion_detected)

    def wait_for_motion(self, timeout):
        """Block until motion, or until `timeout` seconds pass. Returns True/False."""
        if config.SIMULATION:
            return True
        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.motion:
                return True
            time.sleep(0.2)
        return False

    def close(self):
        try:
            if self._dev:
                self._dev.close()
        except Exception:  # noqa: BLE001
            pass


# ════════════════════════════════════════════════════════════════
#  CAMERA
# ════════════════════════════════════════════════════════════════
class CatCamera:
    """Pi camera wrapper. Initialised once, captures BGR frames on demand."""

    def __init__(self):
        self.log = get_logger("camera")
        self._cam = None
        if config.SIMULATION:
            self.log.info("SIMULATION: camera (returns blank frames)")
            return
        try:
            from picamera2 import Picamera2
            self._cam = Picamera2()
            self._cam.configure(
                self._cam.create_preview_configuration(
                    main={"size": (config.CAM_WIDTH, config.CAM_HEIGHT), "format": "RGB888"}
                )
            )
            self._cam.start()
            time.sleep(config.CAM_WARMUP_SEC)
        except Exception as exc:  # noqa: BLE001
            raise CameraError(f"Failed to init camera: {exc}") from exc

    def capture_bgr(self):
        """Return one frame as a BGR numpy array (the format OpenCV expects)."""
        if config.SIMULATION:
            import numpy as np
            return np.zeros((config.CAM_HEIGHT, config.CAM_WIDTH, 3), dtype="uint8")
        try:
            import cv2
            return cv2.cvtColor(self._cam.capture_array(), cv2.COLOR_RGB2BGR)
        except Exception as exc:  # noqa: BLE001
            raise CameraError(f"Camera capture failed: {exc}") from exc

    def close(self):
        try:
            if self._cam:
                self._cam.stop()
                self._cam.close()
        except Exception:  # noqa: BLE001
            pass


# ════════════════════════════════════════════════════════════════
#  VOICE (DFPlayer Mini)  — non-critical: never crash the system
# ════════════════════════════════════════════════════════════════
class Voice:
    """Calls the cat via the existing dfplayer module. Failures are logged, not fatal."""

    def __init__(self):
        self.log = get_logger("voice")
        self._play = None
        self._stop = None
        if config.SIMULATION:
            self.log.info("SIMULATION: voice")
            return
        try:
            from dfplayer import play_voice, stop_voice
            self._play = play_voice
            self._stop = stop_voice
        except Exception as exc:  # noqa: BLE001
            self.log.error("DFPlayer unavailable (continuing without voice): %s", exc)

    def call(self, track=None):
        track = track or config.CALL_TRACK
        if config.SIMULATION or not self._play:
            self.log.info("(no voice) would call cat with track %s", track)
            return
        try:
            self._play(track)
        except Exception as exc:  # noqa: BLE001
            self.log.error("play_voice failed: %s", exc)

    def stop(self):
        if config.SIMULATION or not self._stop:
            return
        try:
            self._stop()
        except Exception as exc:  # noqa: BLE001
            self.log.error("stop_voice failed: %s", exc)

    def close(self):
        self.stop()


# ════════════════════════════════════════════════════════════════
#  FOOD GATE (servo)  — wraps the existing servo_gate.dispense_food()
# ════════════════════════════════════════════════════════════════
class FoodGate:
    """
    Controls the food gate servo DIRECTLY (no dependency on any external
    servo_gate.py module). Behaviour:

        open gate -> wait SERVO_OPEN_SECONDS -> close gate -> detach

    Uses gpiozero.AngularServo so the exact open/closed angles and timing
    are fully controlled here, in config.py.
    """

    def __init__(self):
        self.log = get_logger("gate")
        self._servo = None
        if config.SIMULATION:
            self.log.info("SIMULATION: food gate")
            return
        try:
            from gpiozero import AngularServo
            self._servo = AngularServo(
                config.SERVO_PIN,
                min_angle=-90,
                max_angle=90,
                initial_angle=config.SERVO_CLOSED_ANGLE,
            )
        except Exception as exc:  # noqa: BLE001
            raise GateError(
                f"Failed to init servo on GPIO {config.SERVO_PIN}: {exc}"
            ) from exc

    def dispense(self):
        """Open the gate, wait SERVO_OPEN_SECONDS, close it, then detach."""
        self.log.info("Opening gate...")
        if config.SIMULATION:
            self.log.info("Dispensing food (simulated)")
            return
        try:
            self._servo.angle = config.SERVO_OPEN_ANGLE
            time.sleep(config.SERVO_OPEN_SECONDS)

            self.log.info("Closing gate...")
            self._servo.angle = config.SERVO_CLOSED_ANGLE
            time.sleep(0.5)  # give the servo time to actually reach closed

            self._servo.detach()  # stop sending PWM so the servo doesn't jitter/hum
            self.log.info("Gate closed, servo detached.")
        except Exception as exc:  # noqa: BLE001
            # Safety: always try to close + detach even if something failed mid-way.
            try:
                self._servo.angle = config.SERVO_CLOSED_ANGLE
                time.sleep(0.5)
                self._servo.detach()
            except Exception:  # noqa: BLE001
                pass
            raise GateError(f"Gate dispense failed: {exc}") from exc

    def close(self):
        try:
            if self._servo:
                self._servo.angle = config.SERVO_CLOSED_ANGLE
                time.sleep(0.3)
                self._servo.detach()
                self._servo.close()
        except Exception:  # noqa: BLE001
            pass
