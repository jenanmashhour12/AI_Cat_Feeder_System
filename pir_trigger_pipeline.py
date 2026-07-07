from servo_gate import dispense_food
import sys
import cv2
import time
from picamera2 import Picamera2
from gpiozero import MotionSensor

sys.path.append("/home/pi/cat_feeder")

from ai.detector.face_detector import CatFaceDetector
from ai.embedder.embedder import CatFaceEmbedder
from ai.matcher.matcher import CatMatcher


PIR_PIN = 17
BURST_FRAMES = 20
COOLDOWN_SECONDS = 10


detector = CatFaceDetector()
embedder = CatFaceEmbedder()
matcher = CatMatcher()

pir = MotionSensor(PIR_PIN)


def get_best_embedding(frame_bgr):
    rois, boxes = detector.detect(frame_bgr)
    qualities = [detector.assess_quality(roi) for roi in rois]

    best_idx = -1
    best_q = 0

    for i, (score, passed, reason) in enumerate(qualities):
        if passed and score > best_q:
            best_q = score
            best_idx = i

    if best_idx == -1:
        return None

    return embedder.extract(rois[best_idx])


def run_ai_verification():
    picam2 = Picamera2()
    config = picam2.create_preview_configuration(
        main={"size": (640, 480), "format": "RGB888"}
    )
    picam2.configure(config)

    print("Camera starting...")
    picam2.start()
    time.sleep(2)

    print("Collecting 20 frames for verification...")

    frame_results = []

    while len(frame_results) < BURST_FRAMES:
        frame = picam2.capture_array()
        frame_bgr = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

        embedding = get_best_embedding(frame_bgr)

        if embedding is not None:
            cat_id, score, all_scores = matcher.match_single_frame(embedding)
            frame_results.append((cat_id, score))
            print(
                "Frame",
                len(frame_results),
                "matched:",
                cat_id,
                "score:",
                round(score, 4)
            )
        else:
            print("No valid face detected in this frame")

        time.sleep(0.1)

    picam2.stop()
    picam2.close()
    authorized, identity, confidence, reason = matcher.multi_frame_decision(frame_results)

    print("\n=== FINAL RESULT ===")
    print("Authorized:", authorized)
    print("Identity:  ", identity)
    print("Confidence:", round(confidence, 4))
    print("Reason:    ", reason)

    if authorized and identity:
        settings = matcher.get_cat_settings(identity)
        print("Cat name:  ", settings["name"])
        print("Portion:   ", settings["portion_grams"], "g food")
        print("Water:     ", settings["water_grams"], "g water")
        print("Next step later: start servo dispensing.")
        dispense_food()
    else:
        print("Access denied. Do not feed.")

    return authorized, identity, confidence, reason


print("PIR-triggered AI pipeline started.")
print("System is IDLE. Waiting for motion...")

while True:
    pir.wait_for_motion()

    print("\nPIR motion detected!")
    print("Switching from IDLE to VERIFICATION state...")

    run_ai_verification()

    print(f"\nCooldown for {COOLDOWN_SECONDS} seconds...")
    time.sleep(COOLDOWN_SECONDS)

    print("Back to IDLE. Waiting for motion...")
