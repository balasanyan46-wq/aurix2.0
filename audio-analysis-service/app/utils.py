"""Utility functions for audio processing."""

import numpy as np
import tempfile
import os


def to_mono(audio: np.ndarray) -> np.ndarray:
    """Convert stereo to mono by averaging channels."""
    if audio.ndim == 1:
        return audio
    return audio.mean(axis=1)


def normalize_peak(audio: np.ndarray, target_peak: float = 0.95) -> np.ndarray:
    """Normalize audio to target peak level."""
    peak = np.max(np.abs(audio))
    if peak < 1e-6:
        return audio
    return audio * (target_peak / peak)


def ensure_float32(audio: np.ndarray) -> np.ndarray:
    """Ensure audio is float32 in [-1, 1] range."""
    if audio.dtype != np.float32:
        if np.issubdtype(audio.dtype, np.integer):
            info = np.iinfo(audio.dtype)
            audio = audio.astype(np.float32) / max(abs(info.min), abs(info.max))
        else:
            audio = audio.astype(np.float32)
    return audio


def safe_temp_path(suffix: str = ".wav") -> str:
    """Create a safe temporary file path."""
    fd, path = tempfile.mkstemp(suffix=suffix)
    os.close(fd)
    return path


def cleanup(*paths: str):
    """Silently remove temp files."""
    for p in paths:
        try:
            if p and os.path.exists(p):
                os.unlink(p)
        except OSError:
            pass
