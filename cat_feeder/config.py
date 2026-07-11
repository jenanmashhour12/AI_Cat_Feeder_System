"""
config.py — Central configuration for the AI Cat Feeder.

Everything you might need to change lives here in ONE place.
After wiring the hardware, edit every value marked  # SET THIS.

Run `python3 selftest.py` after editing to confirm the values are sane.
"""

# ── Where the existing AI / Firebase / DFPlayer / servo modules live ──
PROJECT_PATHS = [
    "/home/raspberry/GP/AI_Cat_Feeder_System-main",
    "/home/raspberry/cat_feeder",
]

# ── Run mode ──
SIMULATION = False                  # True = run the logic with NO real hardware (test on a PC)
LOG_FILE   = "/home/raspberry/cat_feeder/feeder.log"
LOG_LEVEL  = "INFO"                 # DEBUG | INFO | WARNING | ERROR

# ── GPIO pins (BCM numbering) ──
PIR_PIN        = 17
PUMP_RELAY_PIN = 22
FOOD_TRIG_PIN  = 23
FOOD_ECHO_PIN  = 24
WATER_TRIG_PIN = 25
WATER_ECHO_PIN = 8
SERVO_PIN      = 18

# ── Relay logic ──
RELAY_ACTIVE_HIGH = True

# ── Pump calibration ──
# Pump spec: 120 L/hour at 6V
# 120,000 ml / 3600 sec = 33.3 ml/sec
# So: pump_seconds = water_ml / PUMP_ML_PER_SECOND
PUMP_ML_PER_SECOND = 33.3          # ml delivered per second at 6V (from pump datasheet)
PUMP_MIN_SECONDS   = 1.0           # never run shorter than this (pump needs time to prime)
PUMP_MAX_SECONDS   = 15.0          # safety cap — never run longer than this (~500ml max)

# ── Dispense calibration ──
# PUMP_RUN_SECONDS is the FALLBACK only — used when water_g is unknown.
# In normal operation the pump time is calculated from water_g / PUMP_ML_PER_SECOND.
PUMP_RUN_SECONDS   = 4.5           # fallback: ~150ml at 33.3 ml/sec
SERVO_OPEN_SECONDS = 3.0           # seconds the food gate stays open
SERVO_CLOSED_ANGLE = 0             # angle when the gate is CLOSED (degrees)
SERVO_OPEN_ANGLE   = 90            # angle when the gate is OPEN (degrees)

# ── Level-sensor calibration (cm from the sensor down to the surface) ──
FOOD_EMPTY_CM  = 20.0
FOOD_FULL_CM   = 2.0
WATER_EMPTY_CM = 18.0
WATER_FULL_CM  = 3.0
LOW_LEVEL_PCT  = 14

# ── Camera ──
CAM_WIDTH      = 640
CAM_HEIGHT     = 480
CAM_WARMUP_SEC = 2

# ── AI verification ──
BURST_FRAMES = 20
FRAME_DELAY  = 0.1

# ── Behaviour ──
DEVICE_DOC        = "devices/feeder_001"
CALL_TRACK        = "cat_001"
CALL_TIMEOUT_SEC  = 60
COOLDOWN_SECONDS  = 10
PIR_WARMUP_SEC    = 15
BACKGROUND_EVERY  = 30
DEFAULT_PORTION_G = 30
DEFAULT_WATER_G   = 150            # fallback water amount (ml) if not set per cat


def validate():
    """Return a list of human-readable problems with the config (empty = OK)."""
    problems = []
    if FOOD_EMPTY_CM <= FOOD_FULL_CM:
        problems.append("FOOD_EMPTY_CM must be GREATER than FOOD_FULL_CM.")
    if WATER_EMPTY_CM <= WATER_FULL_CM:
        problems.append("WATER_EMPTY_CM must be GREATER than WATER_FULL_CM.")
    if PUMP_ML_PER_SECOND <= 0:
        problems.append("PUMP_ML_PER_SECOND must be greater than 0.")
    if PUMP_MIN_SECONDS <= 0:
        problems.append("PUMP_MIN_SECONDS must be greater than 0.")
    if PUMP_MAX_SECONDS <= PUMP_MIN_SECONDS:
        problems.append("PUMP_MAX_SECONDS must be greater than PUMP_MIN_SECONDS.")
    if BURST_FRAMES < 1:
        problems.append("BURST_FRAMES must be at least 1.")
    if not (0 <= LOW_LEVEL_PCT <= 100):
        problems.append("LOW_LEVEL_PCT must be between 0 and 100.")
    if LOG_LEVEL not in ("DEBUG", "INFO", "WARNING", "ERROR"):
        problems.append("LOG_LEVEL must be one of DEBUG, INFO, WARNING, ERROR.")
    return problems
