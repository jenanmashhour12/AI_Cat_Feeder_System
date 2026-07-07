import numpy as np
import json
import cv2
import sys
from pathlib import Path
from datetime import datetime

# Fix import path so we can find detector and embedder
ROOT_DIR = Path(__file__).parent.parent.parent
sys.path.append(str(ROOT_DIR))

from ai.detector.face_detector import CatFaceDetector
from ai.embedder.embedder import CatFaceEmbedder


class CatMatcher:
    """
    Stage 3 of the recognition pipeline.
    Manages enrolled cat galleries and performs
    multi-frame identity matching.
    """

    SAME_CAT_MIN       = 0.70
    DIVERSITY_MAX      = 0.97
    MIN_VALID_FRAMES   = 5
    MAJORITY_THRESHOLD = 0.70

    def __init__(self, galleries_dir=None):
        if galleries_dir is None:
            galleries_dir = ROOT_DIR / "data" / "galleries"

        self.galleries_dir = Path(galleries_dir)
        self.galleries_dir.mkdir(parents=True, exist_ok=True)
        self.galleries = {}
        self._load_all_galleries()

        print(f"✅ Matcher initialized")
        print(f"   Galleries directory: {self.galleries_dir}")
        print(f"   Cats enrolled: {len(self.galleries)}")

    def enroll_cat(self, cat_id, cat_name, portion_grams=80, water_grams=150):
        if cat_id in self.galleries:
            print(f"⚠️  Cat {cat_id} already exists — resetting gallery")

        self.galleries[cat_id] = {
            "cat_id":         cat_id,
            "name":           cat_name,
            "enrolled_date":  datetime.now().isoformat(),
            "embeddings":     [],
            "centroid":       None,
            "threshold":      self.SAME_CAT_MIN,
            "portion_grams":  portion_grams,
            "water_grams":    water_grams,
            "total_feedings": 0
        }

        print(f"✅ Created gallery for {cat_name} ({cat_id})")
        return cat_id

    def add_embedding(self, cat_id, embedding):
        if cat_id not in self.galleries:
            return False, f"Cat {cat_id} not found"

        gallery    = self.galleries[cat_id]
        embeddings = gallery["embeddings"]

        if len(embeddings) >= 100:
            return False, "Gallery full"

        if len(embeddings) > 0:
            existing     = np.array(embeddings)
            similarities = np.dot(existing, embedding)
            if np.max(similarities) > self.DIVERSITY_MAX:
                return False, "Redundant embedding"

        embeddings.append(embedding.tolist())
        gallery["centroid"] = np.mean(
            np.array(embeddings), axis=0
        ).tolist()

        return True, "OK"

    def finalize_enrollment(self, cat_id):
        if cat_id not in self.galleries:
            return {"error": f"Cat {cat_id} not found"}

        gallery    = self.galleries[cat_id]
        embeddings = np.array(gallery["embeddings"])
        count      = len(embeddings)

        if count < 5:
            return {"error": f"Not enough embeddings ({count}). Minimum is 5."}

        similarities = []
        for i in range(count):
            for j in range(i + 1, count):
                sim = float(np.dot(embeddings[i], embeddings[j]))
                similarities.append(sim)

        mean_sim = float(np.mean(similarities))
        std_sim  = float(np.std(similarities))

        adaptive_threshold = max(
            self.SAME_CAT_MIN,
            mean_sim - (2 * std_sim)
        )

        gallery["threshold"] = adaptive_threshold
        self._save_gallery(cat_id)

        summary = {
            "cat_id":             cat_id,
            "name":               gallery["name"],
            "embeddings_stored":  count,
            "intra_similarity":   round(mean_sim, 4),
            "std_similarity":     round(std_sim, 4),
            "adaptive_threshold": round(adaptive_threshold, 4)
        }

        print(f"\n=== Enrollment Complete: {gallery['name']} ===")
        print(f"   Embeddings stored:    {count}")
        print(f"   Mean self-similarity: {mean_sim:.4f}")
        print(f"   Adaptive threshold:   {adaptive_threshold:.4f}")

        return summary

    def match_single_frame(self, live_embedding):
        if len(self.galleries) == 0:
            return None, 0.0, {}

        all_scores  = {}
        best_cat_id = None
        best_score  = 0.0

        for cat_id, gallery in self.galleries.items():
            if gallery["centroid"] is None:
                continue

            embeddings   = np.array(gallery["embeddings"])
            centroid     = np.array(gallery["centroid"])
            centroid_sim = float(np.dot(centroid, live_embedding))
            gallery_sims = np.dot(embeddings, live_embedding)
            top_k        = min(5, len(gallery_sims))
            top_mean     = float(np.mean(np.sort(gallery_sims)[-top_k:]))
            score        = (centroid_sim * 0.4) + (top_mean * 0.6)

            all_scores[cat_id] = round(score, 4)

            if score > best_score:
                best_score  = score
                best_cat_id = cat_id

        return best_cat_id, best_score, all_scores

    def multi_frame_decision(self, frame_results):
        if len(frame_results) < self.MIN_VALID_FRAMES:
            return (
                False, None, 0.0,
                f"Not enough valid frames ({len(frame_results)}/{self.MIN_VALID_FRAMES})"
            )

        vote_counts = {}
        score_sums  = {}

        for cat_id, score in frame_results:
            if cat_id is None:
                continue
            vote_counts[cat_id] = vote_counts.get(cat_id, 0) + 1
            score_sums[cat_id]  = score_sums.get(cat_id, 0.0) + score

        if len(vote_counts) == 0:
            return False, None, 0.0, "No cat detected in any frame"

        winner_id     = max(vote_counts, key=vote_counts.get)
        winner_votes  = vote_counts[winner_id]
        winner_score  = score_sums[winner_id] / winner_votes
        vote_fraction = winner_votes / len(frame_results)

        if vote_fraction < self.MAJORITY_THRESHOLD:
            return (
                False, None, winner_score,
                f"No majority — {vote_fraction:.0%} votes (need {self.MAJORITY_THRESHOLD:.0%})"
            )

        cat_threshold = self.galleries[winner_id]["threshold"]
        if winner_score < cat_threshold:
            return (
                False, None, winner_score,
                f"Score {winner_score:.4f} below threshold {cat_threshold:.4f}"
            )

        return True, winner_id, winner_score, "Authorized"

    def dynamic_update(self, cat_id, embedding, confidence):
        if confidence < 0.90:
            return False, "Confidence too low"

        added, reason = self.add_embedding(cat_id, embedding)
        if added:
            self._save_gallery(cat_id)
            return True, "Gallery updated"

        return False, reason

    def log_feeding(self, cat_id):
        if cat_id in self.galleries:
            self.galleries[cat_id]["total_feedings"] += 1
            self._save_gallery(cat_id)

    def get_cat_settings(self, cat_id):
        if cat_id not in self.galleries:
            return None

        gallery = self.galleries[cat_id]
        return {
            "cat_id":         cat_id,
            "name":           gallery["name"],
            "portion_grams":  gallery["portion_grams"],
            "water_grams":    gallery["water_grams"],
            "total_feedings": gallery["total_feedings"]
        }

    def list_cats(self):
        result = []
        for cat_id, gallery in self.galleries.items():
            result.append({
                "cat_id":           cat_id,
                "name":             gallery["name"],
                "embeddings_count": len(gallery["embeddings"]),
                "threshold":        gallery["threshold"],
                "total_feedings":   gallery["total_feedings"],
                "enrolled_date":    gallery["enrolled_date"]
            })
        return result

    def delete_cat(self, cat_id):
        if cat_id not in self.galleries:
            return False, f"Cat {cat_id} not found"

        del self.galleries[cat_id]

        gallery_file = self.galleries_dir / f"{cat_id}.json"
        if gallery_file.exists():
            gallery_file.unlink()

        return True, f"Cat {cat_id} deleted"

    def _save_gallery(self, cat_id):
        gallery      = self.galleries[cat_id]
        gallery_file = self.galleries_dir / f"{cat_id}.json"

        with open(gallery_file, 'w') as f:
            json.dump(gallery, f, indent=2)

    def _load_all_galleries(self):
        gallery_files = list(self.galleries_dir.glob("*.json"))

        for gallery_file in gallery_files:
            try:
                with open(gallery_file, 'r') as f:
                    gallery = json.load(f)

                cat_id = gallery["cat_id"]
                self.galleries[cat_id] = gallery
                print(f"   Loaded: {gallery['name']} "
                      f"({len(gallery['embeddings'])} embeddings)")

            except Exception as e:
                print(f"⚠️  Failed to load {gallery_file.name}: {e}")


def get_best_embedding(frame, detector, embedder):
    """Detect face and extract embedding from best ROI in frame."""
    rois, boxes = detector.detect(frame)
    qualities   = [detector.assess_quality(roi) for roi in rois]

    best_idx     = -1
    best_quality = 0.0

    for i, (score, passed, reason) in enumerate(qualities):
        if passed and score > best_quality:
            best_quality = score
            best_idx     = i

    if best_idx == -1:
        return None, rois, boxes, qualities

    embedding = embedder.extract(rois[best_idx])
    return embedding, rois, boxes, qualities


def enrollment_session(cat_name, matcher, detector, embedder):
    """Run enrollment for one cat using webcam."""
    cat_id = f"cat_{len(matcher.galleries) + 1:03d}"
    matcher.enroll_cat(cat_id, cat_name)

    print(f"\nEnrolling '{cat_name}' as {cat_id}")
    print("Hold cat photo in front of webcam")
    print("Target: 30 embeddings — closes automatically when done")
    print("Press Q to stop early\n")

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("❌ Could not open webcam")
        return None

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        embedding, rois, boxes, qualities = get_best_embedding(
            frame, detector, embedder
        )
        output = detector.draw_detections(frame, boxes, qualities)
        count  = len(matcher.galleries[cat_id]['embeddings'])

        if embedding is not None:
            added, reason = matcher.add_embedding(cat_id, embedding)
            if added:
                count = len(matcher.galleries[cat_id]['embeddings'])

        progress = int((count / 30) * 20)
        bar      = "#" * progress + "-" * (20 - progress)
        msg      = f"Embeddings: [{bar}] {count}/30"

        cv2.putText(output, msg, (10, 30),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 0), 2)
        cv2.putText(output, "Q = finish early",
                   (10, 60), cv2.FONT_HERSHEY_SIMPLEX,
                   0.4, (200, 200, 200), 1)
        cv2.imshow("Enrollment — " + cat_name, output)

        key = cv2.waitKey(1) & 0xFF
        if key == ord('q') or count >= 30:
            break

    cap.release()
    cv2.destroyAllWindows()

    summary = matcher.finalize_enrollment(cat_id)

    if "error" in summary:
        print(f"❌ Enrollment failed: {summary['error']}")
        return None

    print(f"\n✅ Enrollment complete")
    print(f"   Embeddings stored:  {summary['embeddings_stored']}")
    print(f"   Self-similarity:    {summary['intra_similarity']:.4f}")
    print(f"   Adaptive threshold: {summary['adaptive_threshold']:.4f}")
    return cat_id


def verification_session(matcher, detector, embedder):
    """Run one verification attempt using webcam."""
    if len(matcher.galleries) == 0:
        print("❌ No cats enrolled yet — enroll a cat first")
        return

    print("\nVerifying — hold cat photo in front of webcam")
    print("Collecting 15 frames automatically...\n")

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("❌ Could not open webcam")
        return

    frame_results = []

    while len(frame_results) < 15:
        ret, frame = cap.read()
        if not ret:
            break

        embedding, rois, boxes, qualities = get_best_embedding(
            frame, detector, embedder
        )
        output = detector.draw_detections(frame, boxes, qualities)

        if embedding is not None:
            cat_id, score, all_scores = matcher.match_single_frame(embedding)
            frame_results.append((cat_id, score))

        progress = int((len(frame_results) / 15) * 20)
        bar      = "█" * progress + "░" * (20 - progress)
        msg      = f"Verifying: [{bar}] {len(frame_results)}/15"

        cv2.putText(output, msg, (10, 30),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 255), 2)
        cv2.imshow("Verification", output)
        cv2.waitKey(1)

    cap.release()
    cv2.destroyAllWindows()

    authorized, identity, confidence, reason = \
        matcher.multi_frame_decision(frame_results)

    print(f"\n=== Verification Result ===")
    print(f"Authorized:  {authorized}")
    print(f"Confidence:  {confidence:.4f}")
    print(f"Reason:      {reason}")

    if authorized and identity:
        settings = matcher.get_cat_settings(identity)
        print(f"Cat name:    {settings['name']}")
        print(f"Portion:     {settings['portion_grams']}g food")
        print(f"Water:       {settings['water_grams']}g water")
        print(f"Feedings:    {settings['total_feedings'] + 1}")
        matcher.log_feeding(identity)
    else:
        print("❌ Access denied")


def main():
    print("Loading AI components...")

    try:
        detector = CatFaceDetector()
        embedder = CatFaceEmbedder(use_tflite=False)
        matcher  = CatMatcher()
    except Exception as e:
        print(f"❌ Failed to load components: {e}")
        return

    print("\n=== Cat Feeder Matcher Test ===")

    while True:
        print("\n--- Menu ---")
        print("1. Enroll a new cat")
        print("2. Verify a cat")
        print("3. List enrolled cats")
        print("4. Delete a cat")
        print("5. Quit")

        choice = input("\nEnter choice (1-5): ").strip()

        if choice == "1":
            name = input("Enter cat name: ").strip()
            if name:
                enrollment_session(name, matcher, detector, embedder)
            else:
                print("❌ Name cannot be empty")

        elif choice == "2":
            verification_session(matcher, detector, embedder)

        elif choice == "3":
            cats = matcher.list_cats()
            if len(cats) == 0:
                print("\nNo cats enrolled yet")
            else:
                print(f"\n=== Enrolled Cats ({len(cats)}) ===")
                for cat in cats:
                    print(f"  {cat['cat_id']}: {cat['name']} | "
                          f"{cat['embeddings_count']} embeddings | "
                          f"threshold: {cat['threshold']:.4f} | "
                          f"feedings: {cat['total_feedings']}")

        elif choice == "4":
            cats = matcher.list_cats()
            if len(cats) == 0:
                print("\nNo cats enrolled yet")
            else:
                print("\nEnrolled cats:")
                for cat in cats:
                    print(f"  {cat['cat_id']}: {cat['name']}")
                cat_id  = input("Enter cat_id to delete: ").strip()
                success, msg = matcher.delete_cat(cat_id)
                print(msg)

        elif choice == "5":
            print("Goodbye")
            break

        else:
            print("Invalid choice — enter 1 to 5")


if __name__ == "__main__":
    main()