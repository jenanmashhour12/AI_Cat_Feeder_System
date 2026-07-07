"""
errors.py — Custom exceptions.

Each subsystem raises its own exception type, so when something fails the log
tells you EXACTLY which part broke (PumpError vs SensorError vs CameraError ...).
"""


class FeederError(Exception):
    """Base class for every error in this project."""


class ConfigError(FeederError):
    """Invalid configuration in config.py."""


class HardwareError(FeederError):
    """Base class for any physical-hardware failure."""


class PumpError(HardwareError):
    """Water pump / relay failure."""


class SensorError(HardwareError):
    """HC-SR04 level-sensor failure."""


class CameraError(HardwareError):
    """Camera failure."""


class VoiceError(HardwareError):
    """DFPlayer / speaker failure."""


class GateError(HardwareError):
    """Servo food-gate failure."""


class RecognitionError(FeederError):
    """AI detector / embedder / matcher failure."""


class CloudError(FeederError):
    """Firebase / cloud failure."""
