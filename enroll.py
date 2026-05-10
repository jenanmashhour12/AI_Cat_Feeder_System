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

TARGET_EMBEDDINGS   = 40
DIVERSITY_THRESHOLD = 0.95


def is_diverse(new_embedding, stored_embeddings):
    if len(stored_embeddings) == 0:
        return True
    existing     = np.array(stored_embeddings)
    similarities = np.dot(existing, new_embedding)
    return float(np.max(similarities)) < DIVERSITY_THRESHOLD


cat_name = input("Enter cat name: ").strip()
cat_id   = "cat_" + str(len(matcher.galleries) + 1).zfill(3)
matcher.enroll_cat(cat_id, cat_name)

print("")
print("Enrolling: " + cat_name + " as " + cat_id)
print("Target: " + str(TARGET_EMBEDDINGS) + " diverse embeddings")
print("Hold the cat in front of the camera")
print("Move it slightly between captures for better coverage")
print("Press Q to finish early")
print("")

picam2 = Picamera2()
config = picam2.create_preview_configuration(
    main={"size": (640, 480), "format": "RGB888"}
)
picam2.configure(config)
picam2.start()
time.sleep(2)

stored_embeddings  = []
frame_count        = 0
rejected_quality   = 0
rejected_diversity = 0

while len(stored_embeddings) < TARGET_EMBEDDINGS:
    frame       = picam2.capture_array()
    frame_bgr   = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
    rois, boxes = detector.detect(frame_bgr)
    qualities   = [detector.assess_quality(roi) for roi in rois]
    frame_count += 1

    output = frame_bgr.copy()

    if len(rois) > 0:
        best_idx = 0
        best_q   = 0
        for i, (score, passed, reason) in enumerate(qualities):
            if passed and score > best_q:
                best_q   = score
                best_idx = i

        score, passed, reason = qualities[best_idx]
        x, y, w, h           = boxes[best_idx]
        color                 = (0, 255, 0) if passed else (0, 0, 255)
        cv2.rectangle(output, (x, y), (x + w, y + h), color, 2)

        if passed:
            embedding = embedder.extract(rois[best_idx])

            if is_diverse(embedding, stored_embeddings):
                stored_embeddings.append(embedding)
                matcher.add_embedding(cat_id, embedding)
                print("Stored " + str(len(stored_embeddings)) +
                      "/" + str(TARGET_EMBEDDINGS) +
                      " | quality=" + str(round(score, 2)))
            else:
                rejected_diversity += 1
        else:
            rejected_quality += 1

    count    = len(stored_embeddings)
    progress = int((count / TARGET_EMBEDDINGS) * 30)
    bar      = "#" * progress + "-" * (30 - progress)
    msg      = "[" + bar + "] " + str(count) + "/" + str(TARGET_EMBEDDINGS)

    cv2.putText(output, msg, (10, 30),
               cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 0), 2)
    cv2.putText(output, "Q-fail: " + str(rejected_quality) +
               " | Redundant: " + str(rejected_diversity),
               (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (200, 200, 0), 1)

    cv2.imshow("Enrolling: " + cat_name + " | Q to stop early", output)

    key = cv2.waitKey(1) & 0xFF
    if key == ord("q"):
        print("Stopped early at " + str(len(stored_embeddings)) + " embeddings")
        break

picam2.stop()
cv2.destroyAllWindows()

if len(stored_embeddings) < 5:
    print("Not enough embeddings. Try again with better lighting.")
else:
    summary = matcher.finalize_enrollment(cat_id)
    print("")
    print("=== Enrollment Complete ===")
    print("Cat name:           " + cat_name)
    print("Embeddings stored:  " + str(summary["embeddings_stored"]))
    print("Self-similarity:    " + str(summary["intra_similarity"]))
    print("Adaptive threshold: " + str(summary["adaptive_threshold"]))
    print("")
    print("Frames processed:   " + str(frame_count))
    print("Quality rejected:   " + str(rejected_quality))
    print("Redundant rejected: " + str(rejected_diversity))
    print("")
    print(cat_name + " is ready for recognition")
