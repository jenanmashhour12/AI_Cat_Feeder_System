import cv2
import numpy as np
from pathlib import Path


class CatFaceDetector:
    """
    Stage 1 of the recognition pipeline.
    Detects cat faces in a frame and returns cropped ROIs.
    Uses CLAHE for better performance in low light and
    uneven lighting conditions.
    """

    def __init__(self, min_face_size=80, padding=20):
        self.min_face_size = min_face_size
        self.padding       = padding

        # CLAHE for better contrast enhancement than basic equalizeHist
        self.clahe = cv2.createCLAHE(
            clipLimit=2.0,
            tileGridSize=(8, 8)
        )

        # Detect OS and set cascade path accordingly
        import platform
        if platform.system() == "Linux":
            # Raspberry Pi path
            cascade_path = "/usr/share/opencv4/haarcascades/haarcascade_frontalcatface_extended.xml"
        else:
            # Windows/laptop path
            cascade_path = cv2.data.haarcascades + "haarcascade_frontalcatface_extended.xml"

        self.detector = cv2.CascadeClassifier(cascade_path)

        if self.detector.empty():
            raise RuntimeError(
                "Could not load cat face cascade from " + cascade_path
            )

        print("Cat face detector loaded successfully")

    def _preprocess_for_detection(self, frame):
        """
        Preprocess frame for better face detection.
        Uses CLAHE instead of basic histogram equalization
        for better handling of low light and uneven lighting.
        """
        # Convert to LAB color space
        lab = cv2.cvtColor(frame, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)

        # Apply CLAHE to the L channel only
        # This improves contrast without affecting color balance
        l_enhanced = self.clahe.apply(l)

        # Merge back
        enhanced_lab = cv2.merge((l_enhanced, a, b))
        enhanced_bgr = cv2.cvtColor(enhanced_lab, cv2.COLOR_LAB2BGR)

        # Convert to grayscale for the cascade detector
        gray = cv2.cvtColor(enhanced_bgr, cv2.COLOR_BGR2GRAY)

        return gray, enhanced_bgr

    def detect(self, frame):
        """
        Detect cat faces in a frame.

        Args:
            frame: BGR image as numpy array

        Returns:
            rois:  List of cropped face images
            boxes: List of (x, y, w, h) tuples
        """
        gray, enhanced = self._preprocess_for_detection(frame)

        faces = self.detector.detectMultiScale(
            gray,
            scaleFactor=1.1,
            minNeighbors=4,
            minSize=(self.min_face_size, self.min_face_size)
        )

        rois  = []
        boxes = []

        if len(faces) == 0:
            return rois, boxes

        for (x, y, w, h) in faces:
            x1 = max(0, x - self.padding)
            y1 = max(0, y - self.padding)
            x2 = min(frame.shape[1], x + w + self.padding)
            y2 = min(frame.shape[0], y + h + self.padding)

            # Crop from enhanced frame for better embedding quality
            roi = enhanced[y1:y2, x1:x2]

            if roi.shape[0] < self.min_face_size or roi.shape[1] < self.min_face_size:
                continue

            rois.append(roi)
            boxes.append((x1, y1, x2 - x1, y2 - y1))

        return rois, boxes

    def assess_quality(self, roi):
        """
        Assess the quality of a detected face ROI.

        Returns:
            quality_score: Float between 0 and 1
            passed:        Boolean
            reason:        String
        """
        if roi.shape[0] < self.min_face_size or roi.shape[1] < self.min_face_size:
            return 0.0, False, "ROI too small"

        gray      = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
        sharpness = cv2.Laplacian(gray, cv2.CV_64F).var()

        # Lower sharpness threshold since CLAHE already enhances the image
        if sharpness < 30:
            return sharpness / 100, False, "Too blurry"

        mean_brightness = gray.mean()
        if mean_brightness < 20:
            return 0.0, False, "Too dark"
        if mean_brightness > 245:
            return 0.0, False, "Too bright"

        sharpness_score  = min(sharpness / 400, 1.0)
        brightness_score = 1.0 - abs(mean_brightness - 128) / 128
        quality_score    = (sharpness_score * 0.7) + (brightness_score * 0.3)

        return quality_score, True, "OK"

    def draw_detections(self, frame, boxes, qualities=None):
        """
        Draw bounding boxes on frame for visualization.
        """
        output = frame.copy()

        for i, (x, y, w, h) in enumerate(boxes):
            color = (0, 255, 0)

            if qualities is not None and i < len(qualities):
                score, passed, reason = qualities[i]
                color = (0, 255, 0) if passed else (0, 0, 255)
                label = "Q:" + str(round(score, 2)) + " " + reason
                cv2.putText(
                    output, label, (x, y - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1
                )

            cv2.rectangle(output, (x, y), (x + w, y + h), color, 2)

        return output
