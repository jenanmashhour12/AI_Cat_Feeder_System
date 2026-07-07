import sys
import cv2
import numpy as np
import time
from picamera2 import Picamera2

sys.path.append("/home/pi/cat_feeder")
from ai.detector.face_detector import CatFaceDetector
from ai.embedder.embedder import CatFaceEmbedder

detector = CatFaceDetector()
embedder = CatFaceEmbedder()

picam2 = Picamera2()
config = picam2.create_preview_configuration(main={"size": (640, 480), "format": "RGB888"})
picam2.configure(config)
picam2.start()
print("Camera started")
print("Hold a cat photo in front of the camera")
print("Press Q to quit")
time.sleep(2)

frame_count = 0
detections = 0

while True:
    frame = picam2.capture_array()
    frame_bgr = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
    rois, boxes = detector.detect(frame_bgr)
    qualities = [detector.assess_quality(roi) for roi in rois]
    frame_count += 1

    output = frame_bgr.copy()

    if len(rois) > 0:
        detections += 1
        best_idx = 0
        best_q = 0
        for i, (score, passed, reason) in enumerate(qualities):
            if passed and score > best_q:
                best_q = score
                best_idx = i
        score, passed, reason = qualities[best_idx]

        for (x, y, w, h) in boxes:
            color = (0, 255, 0) if passed else (0, 0, 255)
            cv2.rectangle(output, (x, y), (x+w, y+h), color, 2)

        label = "Quality: " + str(round(score, 2)) + " " + reason
        cv2.putText(output, label, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

        if passed:
            emb = embedder.extract(rois[best_idx])
            norm = round(float(np.linalg.norm(emb)), 4)
            cv2.putText(output, "Embedding norm: " + str(norm), (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
            print("Frame", frame_count, "FACE DETECTED quality=", round(score,2), "norm=", norm)
    else:
        cv2.putText(output, "No face detected", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

    stats = "Frames: " + str(frame_count) + " Detections: " + str(detections)
    cv2.putText(output, stats, (10, 460), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)

    cv2.imshow("Cat Feeder Camera Test - Press Q to quit", output)

    key = cv2.waitKey(1) & 0xFF
    if key == ord("q"):
        break

picam2.stop()
cv2.destroyAllWindows()
print("Done. Frames:", frame_count, "Detections:", detections)
print("Detection rate:", round(detections/frame_count*100, 1), "%")
