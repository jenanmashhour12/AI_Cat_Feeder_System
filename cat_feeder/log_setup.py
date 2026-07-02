"""
log_setup.py — One consistent logging setup for the whole project.

Every module gets a logger via get_logger(name). Logs go to BOTH the console
and a rotating file (config.LOG_FILE), each line tagged with the component name
and severity, e.g.:

    2026-06-29 08:00:01 | INFO    | pump   | Dispensing water for 3.0s
    2026-06-29 08:00:05 | ERROR   | level.water | water read failed: ...

This makes errors easy to find after the fact (open the log file).
"""

import logging
import logging.handlers

import config

_CONFIGURED = False


def setup_logging():
    """Configure root logging once. Safe to call multiple times."""
    global _CONFIGURED
    root = logging.getLogger()
    if _CONFIGURED:
        return root

    root.setLevel(getattr(logging, config.LOG_LEVEL, logging.INFO))
    fmt = logging.Formatter(
        "%(asctime)s | %(levelname)-7s | %(name)-12s | %(message)s",
        "%Y-%m-%d %H:%M:%S",
    )

    # Console handler
    console = logging.StreamHandler()
    console.setFormatter(fmt)
    root.addHandler(console)

    # Rotating file handler (1 MB x 3 backups). Non-fatal if it can't open.
    try:
        file_handler = logging.handlers.RotatingFileHandler(
            config.LOG_FILE, maxBytes=1_000_000, backupCount=3
        )
        file_handler.setFormatter(fmt)
        root.addHandler(file_handler)
    except Exception as exc:  # noqa: BLE001
        root.warning("Could not open log file %s: %s", config.LOG_FILE, exc)

    _CONFIGURED = True
    return root


def get_logger(name):
    """Return a named logger (call setup_logging() once at program start)."""
    return logging.getLogger(name)
