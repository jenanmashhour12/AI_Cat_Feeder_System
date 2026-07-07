import numpy as np
import cv2
from pathlib import Path

# Use ai-edge-litert instead of TensorFlow on Pi
from ai_edge_litert.interpreter import Interpreter


class CatFaceEmbedder:
    """
    Stage 2 of the recognition pipeline.
    Pi version uses TFLite via ai-edge-litert.
    """

    INPUT_SIZE    = (224, 224)
    EMBEDDING_DIM = 128

    def __init__(self, use_tflite=True):
        base_dir = Path(__file__).parent

        tflite_path = base_dir / "cat_feeder_embedding.tflite"
        if not tflite_path.exists():
            raise FileNotFoundError(
                f"TFLite model not found at {tflite_path}"
            )

        print(f"Loading TFLite model from {tflite_path.name}...")
        self.interpreter = Interpreter(model_path=str(tflite_path))
        self.interpreter.allocate_tensors()
        self.input_details  = self.interpreter.get_input_details()
        self.output_details = self.interpreter.get_output_details()

        print(f"? TFLite model loaded")
        print(f"   Input shape:  {self.input_details[0]['shape']}")
        print(f"   Output shape: {self.output_details[0]['shape']}")

    def preprocess(self, roi):
        """
        Preprocess a face ROI for the TFLite model.
        """
        resized = cv2.resize(roi, self.INPUT_SIZE)
        rgb     = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)
        img     = rgb.astype(np.float32)
        img     = (img / 127.5) - 1.0
        return np.expand_dims(img, axis=0)

    def extract(self, roi):
        """
        Extract a normalized embedding vector from a face ROI.
        """
        input_data = self.preprocess(roi)

        self.interpreter.set_tensor(
            self.input_details[0]['index'], input_data
        )
        self.interpreter.invoke()

        raw_embedding = self.interpreter.get_tensor(
            self.output_details[0]['index']
        )[0]

        return self._l2_normalize(raw_embedding)

    def extract_batch(self, rois):
        """Extract embeddings from a list of ROIs."""
        if len(rois) == 0:
            return np.array([])
        return np.array([self.extract(roi) for roi in rois])

    def _l2_normalize(self, embedding):
        """L2 normalize an embedding vector."""
        norm = np.linalg.norm(embedding)
        if norm == 0:
            return embedding
        return embedding / norm

    def cosine_similarity(self, embedding_a, embedding_b):
        """
        Cosine similarity between two L2-normalized embeddings.
        Returns float between -1 and 1.
        """
        return float(np.dot(embedding_a, embedding_b))

    def similarity_to_gallery(self, live_embedding, gallery_embeddings):
        """
        Compare live embedding against a stored gallery.
        """
        if len(gallery_embeddings) == 0:
            return 0.0, 0.0, -1

        similarities = np.dot(gallery_embeddings, live_embedding)
        best_idx     = int(np.argmax(similarities))
        max_score    = float(similarities[best_idx])
        top_k        = min(5, len(similarities))
        top_scores   = np.sort(similarities)[-top_k:]
        mean_score   = float(np.mean(top_scores))

        return max_score, mean_score, best_idx
