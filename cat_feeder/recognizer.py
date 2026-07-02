"""
recognizer.py — Clean wrapper around the existing AI pipeline.

Hides the detector + embedder + matcher behind one simple method:

    authorized, identity, confidence = recognizer.verify(camera, voice)

so the controller never deals with frames or embeddings directly.
"""

import time

import config
from errors import RecognitionError
from log_setup import get_logger


class CatRecognizer:
    def __init__(self):
        self.log = get_logger("ai")
        self.detector = None
        self.embedder = None
        self.matcher = None
        if config.SIMULATION:
            self.log.info("SIMULATION: AI recognizer (always authorizes cat_001)")
            return
        try:
            from ai.detector.face_detector import CatFaceDetector
            from ai.embedder.embedder import CatFaceEmbedder
            from ai.matcher.matcher import CatMatcher
            self.detector = CatFaceDetector()
            self.embedder = CatFaceEmbedder()
            self.matcher = CatMatcher()
        except Exception as exc:  # noqa: BLE001
            raise RecognitionError(f"Failed to load AI modules: {exc}") from exc

    def _best_embedding(self, frame_bgr):
        """Detect the highest-quality face in a frame and return its embedding (or None)."""
        rois, _boxes = self.detector.detect(frame_bgr)
        best_idx, best_q = -1, 0
        for i, roi in enumerate(rois):
            score, passed, _reason = self.detector.assess_quality(roi)
            if passed and score > best_q:
                best_q, best_idx = score, i
        if best_idx == -1:
            return None
        return self.embedder.extract(rois[best_idx])

    def verify(self, camera, voice=None, frames=None):
        """
        Capture frames and run the multi-frame decision.
        Stops the voice as soon as the first face appears.
        Returns (authorized: bool, identity: str|None, confidence: float).

        Uses print() (flushed immediately) IN ADDITION to the logger, so the
        debug output is impossible to miss and shows up even if something
        hangs partway through -- you will see exactly which frame it's on.
        """
        frames = frames or config.BURST_FRAMES

        if config.SIMULATION:
            if voice:
                voice.stop()
            return True, "cat_001", 0.9

        print(f">>> Verifying ({frames} frames)...", flush=True)

        results = []
        voice_stopped = False
        frame_num = 0
        while len(results) < frames:
            frame_num += 1

            try:
                bgr = camera.capture_bgr()
                embedding = self._best_embedding(bgr)
            except Exception as exc:  # noqa: BLE001
                self.log.error("frame processing error: %s", exc)
                embedding = None

            if embedding is not None:
                if voice and not voice_stopped:
                    voice.stop()
                    voice_stopped = True
                cat_id, score, _ = self.matcher.match_single_frame(embedding)
                results.append((cat_id, score))
                msg = f"Frame {frame_num}: {cat_id} | score: {round(score, 4)}"
                print(msg, flush=True)
                self.log.info(msg)
            else:
                msg = f"Frame {frame_num}: no face"
                print(msg, flush=True)
                self.log.info(msg)
            time.sleep(config.FRAME_DELAY)

        if voice and not voice_stopped:
            voice.stop()

        if not results:
            print(">>> NO FACES captured in any frame -- denying.", flush=True)
            self.log.warning("no faces captured during verification")
            return False, None, 0.0

        authorized, identity, confidence, reason = self.matcher.multi_frame_decision(results)
        print("\n=== FINAL RESULT ===", flush=True)
        print(f"Authorized: {authorized}", flush=True)
        print(f"Identity:   {identity}", flush=True)
        print(f"Confidence: {round(confidence, 4)}", flush=True)
        print(f"Reason:     {reason}\n", flush=True)
        self.log.info("FINAL: authorized=%s identity=%s confidence=%s reason=%s",
                      authorized, identity, round(confidence, 4), reason)
        return authorized, identity, confidence

    def cat_settings(self, identity):
        """Return the per-cat settings dict (name, portion_grams, water_grams, ...)."""
        if config.SIMULATION:
            return {"name": identity, "portion_grams": config.DEFAULT_PORTION_G, "water_grams": 150}
        try:
            return self.matcher.get_cat_settings(identity)
        except Exception as exc:  # noqa: BLE001
            raise RecognitionError(f"cat settings lookup failed for {identity}: {exc}") from exc
