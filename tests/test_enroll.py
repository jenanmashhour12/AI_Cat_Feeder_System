import unittest

from enroll import is_diverse


class EnrollTests(unittest.TestCase):
    def test_is_diverse_returns_true_when_history_is_empty(self):
        self.assertTrue(is_diverse([0.2, 0.8], []))

    def test_is_diverse_returns_false_for_similar_embedding(self):
        self.assertFalse(is_diverse([1.0, 0.0], [[1.0, 0.0], [0.0, 1.0]]))


if __name__ == "__main__":
    unittest.main()
