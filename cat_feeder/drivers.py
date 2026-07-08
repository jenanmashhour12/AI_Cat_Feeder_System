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


def _enable_pigpio_if_available():
    """Use pigpio for gpiozero when it is installed on the Pi."""
    try:
        from gpiozero import Device
        from gpiozero.pins.pigpio import PiGPIOFactory

        if Device.pin_factory is None:
            Device.pin_factory = PiGPIOFactory()
    except Exception:
        # Fall back to gpiozero's default pin factory if pigpio is unavailable.
        pass


# ════════════════════════════════════════════════════════════════
#  WATER PUMP (via relay)
# ════════════════════════════════════════════════════════════════
class WaterPump:
    """
    Controls the water pump through the relay.

    IMPORTANT (hardware-specific): on this board, testing showed the pump is
    ON whenever the GPIO pin is actively driven, REGARDLESS of whether it is
    driven HIGH or LOW. The pump is only OFF when the pin is fully released
    (floating / not held by anything). This is not how a normal relay is
    supposed to behave -- it points to a wiring issue (see
    pump_relay_problem_diagnosis.md) -- but we work around it here:

        IDLE:      no pin object exists at all  -> pin floats   -> pump OFF
        DISPENSE:  create the pin, hold it briefly -> pump ON   -> release it

    So instead of a persistent on()/off() device, the pin is created fresh
    for each dispense() call and fully closed (released) immediately after,
    rather than just set to a logical "off" value.
    """

    def __init__(self):
        self.log = get_logger("pump")
        if config.SIMULATION:
            self.log.info("SIMULATION: water pump (no GPIO)")
            return
        _enable_pigpio_if_available()
        # NOTE: deliberately NOT creating a persistent gpiozero device here.
        # Holding the pin open at all (even set "off") was keeping the pump
        # on for this hardware -- the pin must be fully released when idle.

    def dispense(self, seconds=None):
        """Briefly hold the pin (pump ON) for `seconds`, then fully release it (pump OFF)."""
        seconds = config.PUMP_RUN_SECONDS if seconds is None else seconds
        self.log.info("Dispensing water for %.1fs", seconds)
        if config.SIMULATION:
            return
        dev = None
        try:
            from gpiozero import OutputDevice
            dev = OutputDevice(config.PUMP_RELAY_PIN, initial_value=True)
            self.log.info("Pump pin held -> pump ON")
            time.sleep(seconds)
        except Exception as exc:  # noqa: BLE001
            raise PumpError(f"Pump dispense failed: {exc}") from exc
        finally:
            # Fully release the pin (NOT just set to a logical "off" value) --
            # this is what actually turns the pump off on this hardware.
            if dev is not None:
                dev.close()
            self.log.info("Pump pin released -> pump OFF")

    def close(self):
        # Nothing to release here -- the pin is never held outside of
        # dispense(), by design (see class docstring).
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
        _enable_pigpio_if_available()
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
        _enable_pigpio_if_available()
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
#  FOOD GATE (servo via RPi.GPIO PWM — no vibration)
# ════════════════════════════════════════════════════════════════
class FoodGate:
    """
    Controls the food gate servo using RPi.GPIO PWM directly.

    Why RPi.GPIO instead of gpiozero AngularServo:
      gpiozero software PWM causes constant servo jitter/vibration at idle.
      RPi.GPIO PWM with ChangeDutyCycle(0) after each move stops the signal
      completely once the servo reaches position — zero vibration when idle.

    Confirmed working on real hardware:
      - 50Hz PWM frequency
      - duty = 2.5 + (angle / 180.0) * 10.0
      - ChangeDutyCycle(0) after move = servo holds position, no vibration

    Angles from config.py:
      SERVO_CLOSED_ANGLE = 0   (gate closed)
      SERVO_OPEN_ANGLE   = 90  (gate open)
    """

    def __init__(self):
        self.log = get_logger("gate")
        self._pwm = None
        self._GPIO = None
        if config.SIMULATION:
            self.log.info("SIMULATION: food gate")
            return
        _enable_pigpio_if_available()
        try:
            import RPi.GPIO as GPIO
            self._GPIO = GPIO
            GPIO.setmode(GPIO.BCM)
            GPIO.setup(config.SERVO_PIN, GPIO.OUT)
            self._pwm = GPIO.PWM(config.SERVO_PIN, 50)  # 50Hz for servo
            self._pwm.start(0)
            self._set_angle(config.SERVO_CLOSED_ANGLE)  # move to closed
            self.log.info("Gate ready at closed position, no vibration")
        except Exception as exc:  # noqa: BLE001
            raise GateError(
                f"Failed to init servo on GPIO {config.SERVO_PIN}: {exc}"
            ) from exc

    def _set_angle(self, angle):
        """Move servo to angle then stop PWM signal to prevent vibration."""
        if self._pwm is None:
            return
        duty = 2.5 + (angle / 180.0) * 10.0
        self._pwm.ChangeDutyCycle(duty)
        time.sleep(0.5)              # wait for servo to reach position
        self._pwm.ChangeDutyCycle(0) # stop signal → no vibration

    def dispense(self):
        """Open the gate, wait SERVO_OPEN_SECONDS, close it. No vibration."""
        self.log.info("Opening gate...")
        if config.SIMULATION:
            self.log.info("Dispensing food (simulated)")
            return
        try:
            self._set_angle(config.SERVO_OPEN_ANGLE)
            time.sleep(config.SERVO_OPEN_SECONDS)
            self.log.info("Closing gate...")
            self._set_angle(config.SERVO_CLOSED_ANGLE)
            self.log.info("Gate closed.")
        except Exception as exc:  # noqa: BLE001
            try:
                self._set_angle(config.SERVO_CLOSED_ANGLE)
            except Exception:  # noqa: BLE001
                pass
            raise GateError(f"Gate dispense failed: {exc}") from exc

    def close(self):
        try:
            if self._pwm:
                self._set_angle(config.SERVO_CLOSED_ANGLE)
                self._pwm.stop()
            if self._GPIO:
                self._GPIO.cleanup(config.SERVO_PIN)
        except Exception:  # noqa: BLE001
            pass
