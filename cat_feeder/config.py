"""
config.py — Central configuration for the AI Cat Feeder.

Everything you might need to change lives here in ONE place.
After wiring the hardware, edit every value marked  # SET THIS.

Run `python3 selftest.py` after editing to confirm the values are sane.
"""

# ── Where the existing AI / Firebase / DFPlayer / servo modules live ──
# (so we can import them without copying them around)
PROJECT_PATHS = [
    "/home/raspberry/GP/AI_Cat_Feeder_System-main",
    "/home/raspberry/cat_feeder",
]

# ── Run mode ──
SIMULATION = False                  # True = run the logic with NO real hardware (test on a PC)
LOG_FILE   = "/home/raspberry/cat_feeder/feeder.log"
LOG_LEVEL  = "INFO"                 # DEBUG | INFO | WARNING | ERROR

# ── GPIO pins (BCM numbering) ──
PIR_PIN        = 17                 # PIR motion sensor (already wired)
PUMP_RELAY_PIN = 22                 # SET THIS — relay IN pin that switches the water pump
FOOD_TRIG_PIN  = 23                 # SET THIS — HC-SR04 #1 (food)  TRIG
FOOD_ECHO_PIN  = 24                 # SET THIS — HC-SR04 #1 (food)  ECHO  (voltage divider 5V→3.3V!)
WATER_TRIG_PIN = 25                 # SET THIS — HC-SR04 #2 (water) TRIG
WATER_ECHO_PIN = 8                  # SET THIS — HC-SR04 #2 (water) ECHO  (voltage divider 5V→3.3V!)
SERVO_PIN      = 18                 # SET THIS — servo signal pin (food gate)

# ── Relay logic ──
# Confirmed on real hardware: this relay board is ACTIVE-HIGH (HIGH = pump ON).
RELAY_ACTIVE_HIGH = True

# ── Dispense calibration ──
PUMP_RUN_SECONDS  = 2.0             # seconds to run the pump for one water serving (2s on, then off)
SERVO_OPEN_SECONDS = 3.0            # seconds the food gate stays open (3s open, then close)
SERVO_CLOSED_ANGLE = 0              # SET THIS — angle when the gate is CLOSED (degrees, -90..90)
SERVO_OPEN_ANGLE   = 90             # SET THIS — angle when the gate is OPEN (degrees, -90..90)

# ── Level-sensor calibration (cm from the sensor down to the surface) ──
FOOD_EMPTY_CM  = 25.0              # SET THIS — distance when FOOD container is EMPTY
FOOD_FULL_CM   = 5.0              # SET THIS — distance when FOOD container is FULL
WATER_EMPTY_CM = 25.0              # SET THIS — distance when WATER tank is EMPTY
WATER_FULL_CM  = 5.0              # SET THIS — distance when WATER tank is FULL
LOW_LEVEL_PCT  = 15               # warn (and flag in logs) below this %

# ── Camera ──
CAM_WIDTH      = 640
CAM_HEIGHT     = 480
CAM_WARMUP_SEC = 2

# ── AI verification ──
BURST_FRAMES = 20                 # frames captured per verification
FRAME_DELAY  = 0.1                # seconds between frames

# ── Behaviour ──
DEVICE_DOC        = "devices/feeder_001"   # MUST match the doc path firebase_logger uses
CALL_TRACK        = "cat_001"              # DFPlayer track used to call the cat
CALL_TIMEOUT_SEC  = 60                     # how long to call before giving up on the cat
COOLDOWN_SECONDS  = 10                     # pause after a feeding
PIR_WARMUP_SEC    = 15                     # PIR settle time at startup
BACKGROUND_EVERY  = 30                     # seconds between level-sync / command checks
DEFAULT_PORTION_G = 30                     # portion logged for manual feeds


def validate():
    """Return a list of human-readable problems with the config (empty = OK)."""
    problems = []
    if FOOD_EMPTY_CM <= FOOD_FULL_CM:
        problems.append("FOOD_EMPTY_CM must be GREATER than FOOD_FULL_CM (empty = farther away).")
    if WATER_EMPTY_CM <= WATER_FULL_CM:
        problems.append("WATER_EMPTY_CM must be GREATER than WATER_FULL_CM (empty = farther away).")
    if PUMP_RUN_SECONDS <= 0:
        problems.append("PUMP_RUN_SECONDS must be greater than 0.")
    if BURST_FRAMES < 1:
        problems.append("BURST_FRAMES must be at least 1.")
    if not (0 <= LOW_LEVEL_PCT <= 100):
        problems.append("LOW_LEVEL_PCT must be between 0 and 100.")
    if LOG_LEVEL not in ("DEBUG", "INFO", "WARNING", "ERROR"):
        problems.append("LOG_LEVEL must be one of DEBUG, INFO, WARNING, ERROR.")
    return problems
