# AI Smart Cat Feeder — System Code

Clean, modular controller for the smart cat feeder. It reads meal times from
Firebase and, at each meal time, calls the cat, verifies it with the AI camera,
and dispenses water + food only to authorized cats — logging everything to the
cloud and reading real food/water levels from two HC-SR04 sensors.

## File layout

| File | What it does |
|------|--------------|
| `config.py` | **All settings in one place.** Edit the `# SET THIS` values. Has `validate()`. |
| `errors.py` | Custom exceptions per subsystem (PumpError, SensorError, …) for clear logs. |
| `log_setup.py` | Logging to console **and** a rotating file (`feeder.log`). |
| `drivers.py` | Hardware classes: `WaterPump`, `LevelSensor`, `PirMotion`, `CatCamera`, `Voice`, `FoodGate`. |
| `recognizer.py` | Wraps the existing detector + embedder + matcher into one `verify()` call. |
| `cloud.py` | Firebase wrapper: schedule, commands, level updates, feeding logs. |
| `controller.py` | The **state machine**: SLEEP → CALL_CAT → WAIT → VERIFY → DISPENSE → LOG. |
| `main.py` | Entry point. Builds everything, runs the FSM, guarantees cleanup. |
| `selftest.py` | **Tests each component independently** — run this first to debug hardware. |
| `firebase_logger.py` | Firebase connection, feeding log, per-cat system status updates. |
| `dfplayer.py` | DFPlayer Mini serial controller — plays voice to call the cat. |
| `read_firebase_data.py` | Reads and prints everything from Firebase for debugging. |
| `fierMeal.py` | One-time test script — sets a live test schedule 1 minute from now. |
| `water_level.py` | Old standalone water level script — superseded by `drivers.py LevelSensor`. |
| `catfeeder.service` | systemd unit to auto-start on boot. |

The existing project modules are reused, not rewritten:
`ai.detector`, `ai.embedder`, `ai.matcher`, `firebase_logger`, `dfplayer`.

> Note: `servo_gate.py` is no longer used. The servo is now controlled directly
> inside `drivers.py FoodGate` using `RPi.GPIO PWM` (see Hardware drivers section).

---

## How the code works — in detail

This section explains every file, every class, every function, and how they
connect. Read it top to bottom to understand the full code flow.

### Startup flow (`main.py`)

When you run `python3 main.py`, this is what happens in order:

1. **`sys.path` is extended** with the project paths from `config.PROJECT_PATHS`
   so Python can find the existing AI, Firebase, DFPlayer modules
   that live in separate folders on the Pi.

2. **`setup_logging()`** (from `log_setup.py`) is called ONCE. It creates a
   root logger with two handlers:
   - a **console handler** (prints to the terminal), and
   - a **rotating file handler** (writes to `feeder.log`, max 1 MB,
     keeps 3 backup files so old logs aren't lost).
   Every log line includes the timestamp, severity, component name, and message,
   e.g. `2026-06-29 08:00:01 | INFO | pump | Dispensing water for 2.0s`.

3. **`config.validate()`** runs. It checks that `FOOD_EMPTY_CM > FOOD_FULL_CM`,
   that `PUMP_RUN_SECONDS > 0`, etc. If anything is wrong, it prints every
   problem and raises a `ConfigError` — the program stops before touching
   any hardware, so you can fix `config.py` first.

4. **`build()`** constructs every component one by one (see below). If any
   hardware fails to initialise (e.g. a sensor is not wired), it raises
   a specific exception (`PumpError`, `SensorError`, `CameraError`, etc.)
   so the log tells you exactly which part broke.

5. **`controller.run()`** starts the infinite state-machine loop.

6. **`finally` block** — no matter how the program exits (Ctrl+C, crash,
   fatal error), this block runs and:
   - releases the pump GPIO pin (pump turns OFF),
   - stops the DFPlayer voice,
   - stops and closes the camera,
   - closes every sensor and GPIO device.
   This guarantees clean hardware release every time.

### Component construction (`build()` in `main.py`)

`build()` creates these objects in order and returns them:

```
pump         = WaterPump()         → relay + pump (drivers.py)
food_level   = LevelSensor("food") → HC-SR04 #1  (drivers.py)
water_level  = LevelSensor("water")→ HC-SR04 #2  (drivers.py)
pir          = PirMotion()         → PIR sensor   (drivers.py)
camera       = CatCamera()         → Pi camera    (drivers.py)
voice        = Voice()             → DFPlayer     (drivers.py)
gate         = FoodGate()          → servo        (drivers.py)
recognizer   = CatRecognizer()     → AI pipeline  (recognizer.py)
cloud        = Cloud()             → Firebase     (cloud.py)
controller   = FeederController(all of the above)  (controller.py)
```

The pump is built FIRST so it appears first in the cleanup list — if anything
later fails, the pump is the first thing turned off.

### Configuration (`config.py`)

Every tunable value lives here in one place. The file has:

- `PROJECT_PATHS` — where the existing AI/Firebase/DFPlayer code lives.
- `SIMULATION` — set `True` to run the entire logic on a PC with no hardware.
- `LOG_FILE` / `LOG_LEVEL` — where the log goes and how verbose it is.
- **GPIO pins** — one variable per pin.
- `PUMP_RUN_SECONDS` — how long the pump runs per water serving (currently 2.0s).
- `SERVO_OPEN_SECONDS` — how long the food gate stays open (currently 3.0s).
- `SERVO_CLOSED_ANGLE` / `SERVO_OPEN_ANGLE` — servo positions in degrees.
- **Level calibration** — `*_EMPTY_CM` and `*_FULL_CM` per container.
- `LOW_LEVEL_PCT` — below this %, the log prints a WARNING for low food/water.
- **Behaviour** — `BURST_FRAMES`, `CALL_TIMEOUT_SEC`, `COOLDOWN_SECONDS`, etc.
- `validate()` — returns a list of human-readable problems (empty = all good).

**Current confirmed GPIO pin assignments:**

| Pin name | BCM GPIO | Physical pin |
|---|---|---|
| `PIR_PIN` | 17 | 11 |
| `PUMP_RELAY_PIN` | 22 | 15 |
| `FOOD_TRIG_PIN` | 23 | 16 |
| `FOOD_ECHO_PIN` | 24 | 18 |
| `WATER_TRIG_PIN` | 25 | 22 |
| `WATER_ECHO_PIN` | 8 | 24 |
| `SERVO_PIN` | 18 | 12 |

> Note: The pump relay was moved from GPIO 27 (pin 13) to GPIO 22 (pin 15)
> because GPIO 27 has a permanent HIGH voltage at Pi boot time which was
> keeping the relay permanently activated regardless of code.

### Custom exceptions (`errors.py`)

Every subsystem has its own exception type, all inheriting from `FeederError`:

```
FeederError
├── ConfigError         (bad config.py values)
├── HardwareError
│   ├── PumpError       (relay / pump failure)
│   ├── SensorError     (HC-SR04 failure)
│   ├── CameraError     (camera failure)
│   ├── VoiceError      (DFPlayer failure)
│   └── GateError       (servo failure)
├── RecognitionError    (AI detector/embedder/matcher failure)
└── CloudError          (Firebase failure)
```

When something fails, the log line says e.g. `PumpError: pump dispense failed`
— you immediately know it's the pump, not the sensor or the camera.

### Hardware drivers (`drivers.py`)

Each hardware component is a class. Every class follows the same pattern:

1. **`__init__`** — tries to initialise the hardware. If `config.SIMULATION`
   is True, it skips real GPIO and logs "SIMULATION: ...". If the hardware
   fails, it raises the matching exception (e.g. `PumpError`).
2. **Public methods** — do the actual work (e.g. `pump.dispense()`).
3. **`close()`** — releases the hardware safely. Never raises.

Here is what each class does:

**`WaterPump`**

Controls the pump through the relay using a create/release GPIO approach.

This relay module (JQC3F-05VDC-C on a PCB driver board) was found through
testing to activate whenever the GPIO pin is actively driven (regardless of
HIGH or LOW), and deactivate only when the pin is completely released (floating).
The code works with this behavior:

- **IDLE:** no `OutputDevice` object exists → pin floats → relay inactive → pump OFF
- **DISPENSE:** creates a fresh `OutputDevice` with `initial_value=True` → pin driven → relay activates → pump ON → waits `PUMP_RUN_SECONDS` → calls `dev.close()` → pin released → pump OFF

The `finally` block inside `dispense()` guarantees the pin is always released
even if something goes wrong mid-dispense, so the pump can never be left running.

**`LevelSensor`**
- Uses `gpiozero.DistanceSensor` (TRIG + ECHO pins).
- `distance_cm(samples=5)` — takes 5 readings 50 ms apart, sorts them,
  returns the **median** (middle value). The median filters out the occasional
  wild ultrasonic misread that would make a single reading unreliable.
- `level_pct()` — converts the median distance to a 0–100 percentage using
  the calibrated empty/full distances:
  `pct = (empty_cm - measured_cm) / (empty_cm - full_cm) * 100`,
  clamped to 0–100. If calibration is wrong (empty ≤ full), raises `SensorError`.

**`PirMotion`**
- Uses `gpiozero.MotionSensor`.
- `motion` (property) — returns True/False right now.
- `wait_for_motion(timeout)` — blocks until motion is detected or timeout
  expires. Checks every 200 ms. Returns True (motion) or False (timeout).

**`CatCamera`**
- Uses `picamera2.Picamera2`. Initialised ONCE at startup (not re-created
  per feeding).
- `capture_bgr()` — grabs one frame as a BGR numpy array (the format OpenCV
  and the AI detector expect). Converts from RGB888 using `cv2.cvtColor`.

**`Voice`**
- Imports `play_voice` and `stop_voice` from `dfplayer.py`.
- Treated as **non-critical**: if the DFPlayer is broken or missing, the
  system logs a warning and keeps working — it just can't call the cat.
- `call(track)` — plays the call audio in a background thread (loops repeatedly).
- `stop()` — stops playback.

**`FoodGate`**

Controls the servo using `RPi.GPIO PWM` directly — NOT gpiozero AngularServo.

Why: gpiozero's software PWM causes constant servo jitter/vibration at idle.
`RPi.GPIO PWM` with `ChangeDutyCycle(0)` after each move stops the signal
completely once the servo reaches its position, eliminating vibration.

- Uses 50Hz PWM frequency.
- `duty = 2.5 + (angle / 180.0) * 10.0` converts angle to duty cycle.
- `_set_angle(angle)` — sends duty cycle, waits 0.5s for servo to reach
  position, then calls `ChangeDutyCycle(0)` to stop signal → no vibration.
- `dispense()` — opens gate (`SERVO_OPEN_ANGLE`), waits `SERVO_OPEN_SECONDS`,
  closes gate (`SERVO_CLOSED_ANGLE`). Brief vibration only during movement.

### Firebase cloud (`cloud.py`)

Wraps Firebase Firestore. Uses these top-level collections matching the
Flutter app's `firebase_service.dart`:

```
cats/{catId}            → name, portion_g, water_g, total_feedings, last_seen
settings/{catId}        → notification preferences per cat
system_status/{catId}   → food_level_pct, water_level_pct, pi_online, last_updated
schedules/{scheduleId}  → cat_id, label, hour, minute, portion_g, enabled, active_days
feedings/{feedingId}    → cat_id, cat_name, authorized, confidence, portion_g, timestamp
notifications/{notifId} → cat_id, title, message, type, is_read, timestamp
commands/{catId}        → type, portion_g, consumed (for manual feed from app)
```

**Important confirmed field names** (from live Firebase data — these are exact):

| Field | Correct name | Wrong name (do NOT use) |
|---|---|---|
| Schedule enabled flag | `enabled` | `isEnabled` |
| Schedule active days | `active_days` | `activeDays` |
| Schedule portion | `portion_g` | `portion_grams` |

`system_status` is written **per cat** (one document per cat_id), not as a
single shared document. This matches what the app reads.

### Firebase logger (`firebase_logger.py`)

Handles the Firebase connection using `serviceAccountKey.json` from the
`config/` folder. Key functions:

- `log_feeding(...)` — writes a feeding event to the `feedings` collection.
- `update_system_status(food_pct, water_pct)` — **FIXED**: now writes to
  `system_status/{cat_id}` for every registered cat (previously wrote to a
  single `system_status/status` document that the app could never read).
- `check_for_commands()` — checks the `commands` collection for pending
  manual feed requests from the app.

### AI recognizer (`recognizer.py`)

Wraps the three existing AI modules into one clean class. The `verify()` method:

1. Captures `BURST_FRAMES` (20) frames from the camera.
2. For each frame: detects the cat face, extracts the 128-dim embedding.
3. Calls `matcher.match_single_frame(embedding)` → gets `(cat_id, score)`.
4. Stops the voice the moment the first face is detected.
5. After 20 frames: `matcher.multi_frame_decision(results)` → majority vote.
6. Prints per-frame scores live to the terminal for debugging:
   ```
   Frame 1: cat_001 | score: 0.8555
   Frame 2: no face
   ...
   === FINAL RESULT ===
   Authorized: True
   Identity:   cat_001
   Confidence: 0.8758
   Reason:     Authorized
   ```

### The state machine (`controller.py`)

**States:**
```
SLEEP → CALL_CAT → WAIT_FOR_MOTION → VERIFY → DISPENSE → LOG → SLEEP
```

**Schedule format** (confirmed from live Firebase data):
```json
{
  "cat_id":      "cat_001",
  "label":       "Morning Feeding",
  "hour":        8,
  "minute":      0,
  "portion_g":   30,
  "enabled":     true,
  "active_days": [true, true, true, true, true, false, false]
}
```

A schedule fires only if `enabled` is True AND `active_days[weekday-1]` is True.

**Three possible outcomes after VERIFY:**

| Who arrived | Result |
|---|---|
| Expected cat (correct) | FEED — dispense water + food, log authorized |
| Registered cat but wrong time | DENY — log + send notification |
| Unknown animal | DENY — log + send notification |

**`sync_levels()`** reads both HC-SR04 sensors and pushes the real percentages
to `system_status/{cat_id}` in Firebase for every registered cat.

**`_background_tasks()`** runs every 30 seconds: syncs levels + checks for
manual feed commands from the app.

---

## Wiring — every component to the Raspberry Pi 4

### Power rails used

| Rail | Source | Feeds |
|------|--------|-------|
| **5V (Pi)** | USB charger → Pi 5V pins | Pi itself, camera (via CSI) |
| **5V (external)** | 12V adapter → LM2596 buck set to 5V | servo, relay, pump, HC-SR04 ×2, DFPlayer |
| **GND (shared)** | Pi GND + buck GND **must be tied together** | all components share this ground |

> ⚠ **Shared ground is mandatory.** Without it, GPIO signals from the Pi
> won't be read by the externally powered devices.

### GPIO pin map (confirmed on real hardware)

| Component | Wire / function | BCM GPIO | Physical pin | Notes |
|-----------|----------------|----------|--------------|-------|
| **PIR sensor** | OUT (signal) | 17 | 11 | 3.3V compatible. |
| | VCC | — | — | Pi 5V (pin 2 or 4) |
| | GND | — | — | Pi GND |
| **DFPlayer Mini** | RX (receives from Pi TX) | 14 (TX) | 8 | Pi TX → DFPlayer RX |
| | TX (sends to Pi RX) | 15 (RX) | 10 | DFPlayer TX → Pi RX |
| | VCC | — | — | External 5V rail |
| | GND | — | — | Shared GND |
| | SPK_1 / SPK_2 | — | — | Speaker wires |
| **Servo motor (SG90)** | Signal (orange/white) | 18 | 12 | Controlled by RPi.GPIO PWM |
| | VCC (red) | — | — | External 5V rail (NOT from Pi!) |
| | GND (brown/black) | — | — | Shared GND |
| **Relay module (JQC3F-05VDC-C)** | IN (control signal) | **22** | **15** | Changed from GPIO 27 — see note below |
| | VCC | — | — | External 5V rail |
| | GND | — | — | Shared GND |
| | COM | — | — | System GND |
| | NO (normally open) | — | — | → pump GND (black wire) |
| **Water pump** | VCC (red) | — | — | External 5V rail (always connected) |
| | GND (black) | — | — | Relay NO terminal |
| **HC-SR04 #1 (food)** | TRIG | 23 | 16 | |
| | ECHO | 24 | 18 | **must use voltage divider** (see below) |
| | VCC | — | — | External 5V rail |
| | GND | — | — | Shared GND |
| **HC-SR04 #2 (water)** | TRIG | 25 | 22 | |
| | ECHO | 8 | 24 | **must use voltage divider** (see below) |
| | VCC | — | — | External 5V rail |
| | GND | — | — | Shared GND |
| **Pi Camera** | CSI ribbon | — | CSI port | Flat cable into camera connector |

> ⚠ **Relay IN pin changed from GPIO 27 (pin 13) to GPIO 22 (pin 15).**
> GPIO 27 has a permanent HIGH voltage at Pi boot time which was keeping
> the relay activated before any code ran. GPIO 22 starts LOW at boot
> and gives correct behavior.

### Relay wiring detail (confirmed)

```
Pump VCC (red)   → external 5V rail  (always powered, never switched)
Pump GND (black) → Relay NO terminal (ground path switched by relay)
Relay COM        → System GND
Relay IN         → GPIO 22 (Pi physical pin 15)
Relay VCC        → External 5V rail
Relay GND        → System GND
```

The relay switches the **ground path** of the pump (not the power path).
When the relay activates (NO closes to COM), the pump's ground path completes
and the pump runs. When the relay deactivates, the ground path opens and the
pump stops.

**How the pump is controlled in code:**

The relay module (JQC3F-05VDC-C) activates whenever the GPIO pin is driven
(regardless of HIGH or LOW level), and deactivates only when the pin is fully
released (floating). The code uses this behavior:

```python
# Pump ON: create the GPIO connection → pin driven → relay activates
dev = OutputDevice(22, initial_value=True)

# Pump OFF: release the GPIO connection completely → pin floats → relay deactivates
dev.close()
```

At idle, no GPIO object exists on pin 22 — the pin floats and the pump stays off.

### HC-SR04 ECHO voltage divider (important!)

The HC-SR04 ECHO pin outputs **5V**, but the Pi GPIO is **3.3V only** — 5V
will damage the Pi. You must add a simple voltage divider on each ECHO line:

```
HC-SR04 ECHO ──┬── 1kΩ resistor ──► Pi GPIO (ECHO pin)
               │
              2kΩ resistor
               │
              GND
```

This drops the 5V to ~3.3V safely.

### Physical wiring diagram (text)

```
                    ┌──────────────── RASPBERRY PI 4 ────────────────┐
                    │                                                │
  USB 5V ──────────►│ USB-C power                                    │
                    │                                                │
                    │ GPIO HEADER (selected pins):                   │
                    │                                                │
                    │  pin 8  (BCM 14 TX)  ───► DFPlayer RX          │
                    │  pin 10 (BCM 15 RX)  ◄─── DFPlayer TX          │
                    │  pin 11 (BCM 17)     ◄─── PIR OUT              │
                    │  pin 12 (BCM 18)     ───► Servo signal (PWM)   │
                    │  pin 15 (BCM 22)     ───► Relay IN  ← CHANGED  │
                    │  pin 16 (BCM 23)     ───► Food HC-SR04 TRIG    │
                    │  pin 18 (BCM 24)     ◄─── Food HC-SR04 ECHO *  │
                    │  pin 22 (BCM 25)     ───► Water HC-SR04 TRIG   │
                    │  pin 24 (BCM 8)      ◄─── Water HC-SR04 ECHO * │
                    │  pin 6/9/14/etc      ─── GND (shared)          │
                    │                                                │
                    │  CSI port            ◄──► Camera ribbon         │
                    └────────────────────────────────────────────────┘

   12V adapter ──► LM2596 buck (set to 5V) ──► external 5V rail
                                               ├── servo VCC (red)
                                               ├── relay VCC
                                               ├── pump VCC (red)
                                               ├── DFPlayer VCC
                                               ├── food HC-SR04 VCC
                                               └── water HC-SR04 VCC

   Relay COM ──► system GND    Relay NO ──► pump GND (black)
   Servo GND ──► shared GND    DFPlayer GND ──► shared GND
   Both HC-SR04 GND ──► shared GND

   * = through voltage divider (1kΩ + 2kΩ to GND)
```

### Quick checklist before powering on

- [ ] Pi GND and buck converter GND are tied together (shared ground).
- [ ] Both HC-SR04 ECHO lines go through a voltage divider (not direct to Pi).
- [ ] Servo VCC is on the external 5V rail, NOT on the Pi's 5V pin.
- [ ] Relay IN wire is on physical pin 15 (GPIO 22) — NOT pin 13 (GPIO 27).
- [ ] Pump VCC (red) goes to external 5V rail.
- [ ] Pump GND (black) goes to relay NO terminal.
- [ ] Relay COM goes to system GND.
- [ ] DFPlayer RX connects to Pi TX (pin 8), DFPlayer TX to Pi RX (pin 10).
- [ ] Camera ribbon is fully seated in the CSI connector.
- [ ] The LM2596 output is set to 5.0V (measure with a multimeter).
- [ ] External power source is plugged in and switched ON before running.

---

## Setup

1. Copy this folder to the Pi at `/home/raspberry/cat_feeder/`.
2. The `config/serviceAccountKey.json` file must be present for Firebase.
3. Install pigpiod (reduces servo jitter — optional but recommended):
   ```bash
   cd ~ && wget https://github.com/joan2937/pigpio/archive/master.zip
   unzip master.zip && cd pigpio-master && make && sudo make install
   sudo cp util/pigpiod.service /etc/systemd/system/
   sudo nano /etc/systemd/system/pigpiod.service
   # Change ExecStart=/usr/bin/pigpiod to ExecStart=/usr/local/bin/pigpiod
   sudo systemctl daemon-reload && sudo systemctl enable pigpiod && sudo systemctl start pigpiod
   ```

## Calibrate

- **Food sensor:** measure distance (cm) from sensor to food surface when
  container is empty → set `FOOD_EMPTY_CM`. Fill container, measure again →
  set `FOOD_FULL_CM`. Run `python3 selftest.py` to verify percentages.
- **Water sensor:** same process for `WATER_EMPTY_CM` / `WATER_FULL_CM`.
- **Water amount:** adjust `PUMP_RUN_SECONDS` (currently 2.0s) until one
  run pours the correct amount of water.
- **Food amount:** adjust `SERVO_OPEN_SECONDS` (currently 3.0s) and
  `SERVO_OPEN_ANGLE` / `SERVO_CLOSED_ANGLE` to control how much food drops.

## Run

```bash
cd /home/raspberry/cat_feeder
python3 selftest.py      # check hardware piece-by-piece first
python3 main.py          # run the full system
```

Stop with `Ctrl+C` once — wait for "Shutdown complete" before closing terminal.

## Set a test schedule (for testing without waiting for a real meal time)

```bash
python3 fierMeal.py
```

This sets a schedule in Firebase for 1 minute from now. After testing, delete it:

```bash
python3 -c "
import config, sys
for p in config.PROJECT_PATHS: sys.path.append(p)
from cloud import Cloud
Cloud().db.collection('schedules').document('live_test').delete()
print('Removed')
"
```

## Check Firebase data

```bash
python3 read_firebase_data.py
```

Shows cats, schedules, system status, settings, recent feedings, notifications,
and pending commands — all in a readable format.

## Auto-start on boot

```bash
sudo cp catfeeder.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable catfeeder.service
sudo systemctl start catfeeder.service
journalctl -u catfeeder.service -f    # watch live logs
```

## Test without hardware

Set `SIMULATION = True` in `config.py` to run the whole logic on a normal PC
(no GPIO/camera/Firebase needed). Useful for testing the state machine.

## Troubleshooting

- **A component fails:** run `selftest.py` — it tells you exactly which part.
- **Pump stays ON after code ends:** check the external power source is off,
  then check the relay IN wire is on GPIO 22 (pin 15), not GPIO 27 (pin 13).
- **Pump ON immediately when code starts:** the GPIO pin may have boot-time
  HIGH voltage. Try a different GPIO pin and update `PUMP_RELAY_PIN` in `config.py`.
- **Servo vibrates constantly:** this is software PWM jitter. Install pigpiod
  (see Setup above) or accept it — the servo still opens/closes correctly.
- **Levels show 0% always:** calibrate `*_EMPTY_CM` and `*_FULL_CM` in
  `config.py` — the real distances must be measured with a ruler.
- **Food sensor reads ~3x the real distance:** the sensor is picking up a
  triple echo reflection. Move the sensor slightly or add a baffle.
- **Schedule never triggers:** confirm the app writes schedules with fields
  `enabled`, `active_days`, `hour`, `minute`, `portion_g`, `cat_id` to the
  `schedules` collection. Check Pi clock with `timedatectl`.
- **Voice not playing:** check DFPlayer serial connection (TX→RX, RX→TX),
  SD card is inserted with mp3 files in the `mp3/` folder, and speaker wires
  are connected to SPK_1/SPK_2.
- **Read the log:** `tail -f feeder.log` — every action and error is recorded
  with the component name and timestamp.
