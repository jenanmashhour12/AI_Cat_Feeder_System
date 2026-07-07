import sys
import cv2
import numpy as np
import time
from picamera2 import Picamera2

sys.path.append("/home/pi/cat_feeder")
from ai.detector.face_detector import CatFaceDetector
from ai.embedder.embedder import CatFaceEmbedder
from ai.matcher.matcher import CatMatcher

detector = CatFaceDetector()
embedder = CatFaceEmbedder()
matcher  = CatMatcher()

def get_best_embedding(frame):
    rois, boxes = detector.detect(frame)
    qualities   = [detector.assess_quality(roi) for roi in rois]
    best_idx    = -1
    best_q      = 0
    for i, (score, passed, reason) in enumerate(qualities):
        if passed and score > best_q:
            best_q   = score
            best_idx = i
    if best_idx == -1:
        return None, rois, boxes, qualities
    return embedder.extract(rois[best_idx]), rois, boxes, qualities

picam2 = Picamera2()
config = picam2.create_preview_configuration(main={"size": (640, 480), "format": "RGB888"})
picam2.configure(config)
picam2.start()
time.sleep(2)

print("Full pipeline test started")
print("Enrolled cats:", [g["name"] for g in matcher.galleries.values()])
print("Running verification - hold cat in front of camera")
print("Collecting 20 frames...")

frame_results = []
frame_count   = 0

while len(frame_results) < 20:
    frame     = picam2.capture_array()
    frame_bgr = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

    embedding, rois, boxes, qualities = get_best_embedding(frame_bgr)

    if embedding is not None:
        cat_id, score, all_scores = matcher.match_single_frame(embedding)
        frame_results.append((cat_id, score))
        print("Frame", len(frame_results), "matched:", cat_id, "score:", round(score, 4))

    frame_count += 1
    time.sleep(0.1)

authorized, identity, confidence, reason = matcher.multi_frame_decision(frame_results)

print("")
print("=== FINAL RESULT ===")
print("Authorized:", authorized)
print("Identity:  ", identity)
print("Confidence:", round(confidence, 4))
print("Reason:    ", reason)

if authorized and identity:
    settings = matcher.get_cat_settings(identity)
    print("Cat name:  ", settings["name"])
    print("Portion:   ", settings["portion_grams"], "g food")
    print("Water:     ", settings["water_grams"], "g water")

picam2.stop()
