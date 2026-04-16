"""
Voice Style system — shapes the character of a vocal without ML.

Each style is a combination of:
  - Saturation curve (harmonic distortion)
  - Stereo processing (width, delay, mid/side)
  - Chorus effect (subtle doubling)
  - Style-specific EQ + dynamics tweaks via Pedalboard

All operations are vectorized numpy — <1s for a 3-minute track.

Styles:
  trap       — hard, aggressive, in-your-face
  pop        — polished, airy, wide
  dark       — lo-fi, moody, intimate
  wide_star  — AURIX signature: bright, wide, larger-than-life
"""

import logging
import numpy as np
from pedalboard import (
    Pedalboard,
    Compressor,
    HighpassFilter,
    LowShelfFilter,
    PeakFilter,
    HighShelfFilter,
    Reverb,
    Limiter,
    Chorus,
    Delay,
)

logger = logging.getLogger("aurix-audio.style")


# ─── Saturation curves ───

def _soft_clip(audio: np.ndarray, drive: float = 1.0) -> np.ndarray:
    """Warm soft-clip saturation (tape-like)."""
    return np.tanh(audio * drive)


def _hard_clip(audio: np.ndarray, drive: float = 1.0, ceiling: float = 0.95) -> np.ndarray:
    """Aggressive hard-clip saturation."""
    driven = audio * drive
    return np.clip(driven, -ceiling, ceiling)


def _tube_warmth(audio: np.ndarray, drive: float = 1.0) -> np.ndarray:
    """Asymmetric tube-style saturation — adds even harmonics."""
    x = audio * drive
    pos = np.tanh(x)
    neg = np.tanh(x * 0.8) * 0.9
    return np.where(x >= 0, pos, neg)


# ─── Stereo processing ───

def _to_stereo_delay(mono: np.ndarray, sr: int, delay_ms: float = 15.0) -> np.ndarray:
    """Create stereo from mono by delaying one channel (Haas effect)."""
    delay_samples = int(sr * delay_ms / 1000.0)
    left = mono.copy()
    right = np.zeros_like(mono)
    if delay_samples < len(mono):
        right[delay_samples:] = mono[:-delay_samples] if delay_samples > 0 else mono
    else:
        right = mono.copy()
    return np.column_stack([left, right])


def _mid_side_width(stereo: np.ndarray, width: float = 1.5) -> np.ndarray:
    """Adjust stereo width via mid/side processing. width>1 = wider."""
    if stereo.ndim == 1:
        return stereo
    left, right = stereo[:, 0], stereo[:, 1]
    mid = (left + right) * 0.5
    side = (left - right) * 0.5
    side = side * width
    return np.column_stack([mid + side, mid - side])


def _simple_chorus(mono: np.ndarray, sr: int, depth_ms: float = 8.0, rate_hz: float = 1.2) -> np.ndarray:
    """Subtle chorus: modulated delay mixed with original."""
    n = len(mono)
    t = np.arange(n, dtype=np.float64) / sr
    mod = np.sin(2 * np.pi * rate_hz * t) * (depth_ms / 1000.0 * sr)
    base_delay = int(sr * 0.02)  # 20ms base
    indices = np.arange(n, dtype=np.float64) - base_delay - mod
    indices = np.clip(indices, 0, n - 1).astype(np.int64)
    chorus_signal = mono[indices]
    return mono * 0.7 + chorus_signal * 0.3


# ─── Style definitions ───

STYLES = {
    "trap": {
        "saturation": ("hard", 1.3),
        "stereo_delay_ms": 12.0,
        "stereo_width": 1.1,
        "chorus": False,
        "autotune_override": 0.9,
        "chain": {
            "highpass_hz": 100,
            "compressor": {"threshold_db": -14, "ratio": 5.5, "attack_ms": 2.0, "release_ms": 40.0},
            "eq": {"low_shelf_hz": 250, "low_shelf_gain_db": -3, "mid_hz": 2200, "mid_gain_db": 3.0, "mid_q": 1.3, "high_shelf_hz": 7500, "high_shelf_gain_db": 5.0},
            "reverb": {"room_size": 0.12, "damping": 0.85, "wet_level": 0.06, "dry_level": 1.0},
            "limiter_db": -0.5,
        },
    },
    "pop": {
        "saturation": ("soft", 1.05),
        "stereo_delay_ms": 18.0,
        "stereo_width": 1.4,
        "chorus": False,
        "autotune_override": 0.5,
        "chain": {
            "highpass_hz": 70,
            "compressor": {"threshold_db": -20, "ratio": 2.8, "attack_ms": 8.0, "release_ms": 100.0},
            "eq": {"low_shelf_hz": 200, "low_shelf_gain_db": -1, "mid_hz": 3500, "mid_gain_db": -1.5, "mid_q": 1.0, "high_shelf_hz": 10000, "high_shelf_gain_db": 4.5},
            "reverb": {"room_size": 0.35, "damping": 0.5, "wet_level": 0.25, "dry_level": 1.0},
            "limiter_db": -1.0,
        },
    },
    "dark": {
        "saturation": ("tube", 1.5),
        "stereo_delay_ms": 8.0,
        "stereo_width": 0.9,
        "chorus": False,
        "autotune_override": 0.35,
        "chain": {
            "highpass_hz": 60,
            "compressor": {"threshold_db": -16, "ratio": 4.0, "attack_ms": 5.0, "release_ms": 60.0},
            "eq": {"low_shelf_hz": 300, "low_shelf_gain_db": 3, "mid_hz": 1800, "mid_gain_db": 2.0, "mid_q": 0.8, "high_shelf_hz": 6000, "high_shelf_gain_db": -4.0},
            "reverb": {"room_size": 0.20, "damping": 0.9, "wet_level": 0.15, "dry_level": 1.0},
            "limiter_db": -1.5,
        },
    },
    "wide_star": {
        "saturation": ("soft", 1.15),
        "stereo_delay_ms": 22.0,
        "stereo_width": 1.6,
        "chorus": True,
        "chorus_depth_ms": 6.0,
        "chorus_rate_hz": 0.8,
        "autotune_override": 0.6,
        "chain": {
            "highpass_hz": 80,
            "compressor": {"threshold_db": -18, "ratio": 3.2, "attack_ms": 4.0, "release_ms": 70.0},
            "eq": {"low_shelf_hz": 200, "low_shelf_gain_db": -1, "mid_hz": 2800, "mid_gain_db": 2.5, "mid_q": 1.2, "high_shelf_hz": 9000, "high_shelf_gain_db": 4.0},
            "reverb": {"room_size": 0.30, "damping": 0.55, "wet_level": 0.18, "dry_level": 1.0},
            "limiter_db": -0.8,
        },
    },
    "lofi": {
        "saturation": ("tube", 1.6),
        "stereo_delay_ms": 10.0,
        "stereo_width": 0.85,
        "chorus": True,
        "chorus_depth_ms": 10.0,
        "chorus_rate_hz": 0.5,
        "autotune_override": 0.15,
        "chain": {
            "highpass_hz": 100,
            "compressor": {"threshold_db": -20, "ratio": 2.5, "attack_ms": 15.0, "release_ms": 150.0},
            "eq": {"low_shelf_hz": 300, "low_shelf_gain_db": 2, "mid_hz": 1500, "mid_gain_db": -2.0, "mid_q": 0.7, "high_shelf_hz": 5000, "high_shelf_gain_db": -5.0},
            "reverb": {"room_size": 0.4, "damping": 0.85, "wet_level": 0.2, "dry_level": 1.0},
            "limiter_db": -2.0,
        },
    },
    "rnb": {
        "saturation": ("soft", 1.08),
        "stereo_delay_ms": 20.0,
        "stereo_width": 1.35,
        "chorus": False,
        "autotune_override": 0.45,
        "chain": {
            "highpass_hz": 65,
            "compressor": {"threshold_db": -22, "ratio": 2.2, "attack_ms": 12.0, "release_ms": 130.0},
            "eq": {"low_shelf_hz": 180, "low_shelf_gain_db": 1, "mid_hz": 3200, "mid_gain_db": 2.0, "mid_q": 1.0, "high_shelf_hz": 11000, "high_shelf_gain_db": 3.5},
            "reverb": {"room_size": 0.4, "damping": 0.45, "wet_level": 0.28, "dry_level": 1.0},
            "limiter_db": -1.0,
        },
    },
    "phonk": {
        "saturation": ("hard", 1.5),
        "stereo_delay_ms": 8.0,
        "stereo_width": 1.0,
        "chorus": False,
        "autotune_override": 0.7,
        "chain": {
            "highpass_hz": 120,
            "compressor": {"threshold_db": -12, "ratio": 7.0, "attack_ms": 1.0, "release_ms": 30.0},
            "eq": {"low_shelf_hz": 300, "low_shelf_gain_db": -4, "mid_hz": 1800, "mid_gain_db": 4.0, "mid_q": 1.8, "high_shelf_hz": 6000, "high_shelf_gain_db": 3.0},
            "reverb": {"room_size": 0.1, "damping": 0.9, "wet_level": 0.04, "dry_level": 1.0},
            "limiter_db": -0.3,
        },
    },
    "drill": {
        "saturation": ("hard", 1.25),
        "stereo_delay_ms": 15.0,
        "stereo_width": 1.15,
        "chorus": False,
        "autotune_override": 0.8,
        "chain": {
            "highpass_hz": 90,
            "compressor": {"threshold_db": -15, "ratio": 5.0, "attack_ms": 3.0, "release_ms": 45.0},
            "eq": {"low_shelf_hz": 220, "low_shelf_gain_db": -2, "mid_hz": 2500, "mid_gain_db": 3.0, "mid_q": 1.4, "high_shelf_hz": 8000, "high_shelf_gain_db": 4.5},
            "reverb": {"room_size": 0.2, "damping": 0.7, "wet_level": 0.1, "dry_level": 1.0},
            "limiter_db": -0.5,
        },
    },
}


def get_style(name: str) -> dict:
    return STYLES.get(name, STYLES["wide_star"])


def get_autotune_strength_for_style(style_name: str) -> float:
    """Get the recommended autotune strength for a voice style."""
    return get_style(style_name).get("autotune_override", 0.5)


def build_style_chain(style_def: dict) -> Pedalboard:
    """Build a Pedalboard FX chain from a voice style definition."""
    c = style_def["chain"]
    plugins = [
        HighpassFilter(cutoff_frequency_hz=c["highpass_hz"]),
        Compressor(
            threshold_db=c["compressor"]["threshold_db"],
            ratio=c["compressor"]["ratio"],
            attack_ms=c["compressor"]["attack_ms"],
            release_ms=c["compressor"]["release_ms"],
        ),
        LowShelfFilter(cutoff_frequency_hz=c["eq"]["low_shelf_hz"], gain_db=c["eq"]["low_shelf_gain_db"]),
        PeakFilter(cutoff_frequency_hz=c["eq"]["mid_hz"], gain_db=c["eq"]["mid_gain_db"], q=c["eq"]["mid_q"]),
        HighShelfFilter(cutoff_frequency_hz=c["eq"]["high_shelf_hz"], gain_db=c["eq"]["high_shelf_gain_db"]),
        Reverb(
            room_size=c["reverb"]["room_size"],
            damping=c["reverb"]["damping"],
            wet_level=c["reverb"]["wet_level"],
            dry_level=c["reverb"]["dry_level"],
        ),
        Limiter(threshold_db=c["limiter_db"]),
    ]
    return Pedalboard(plugins)


def apply_voice_style(audio: np.ndarray, sr: int, style_name: str = "wide_star") -> np.ndarray:
    """
    Apply a voice style to mono audio.

    Returns stereo float32 numpy array (N, 2).
    """
    style = get_style(style_name)

    # 1. Saturation
    sat_type, sat_drive = style["saturation"]
    if sat_type == "hard":
        audio = _hard_clip(audio, drive=sat_drive)
    elif sat_type == "tube":
        audio = _tube_warmth(audio, drive=sat_drive)
    else:
        audio = _soft_clip(audio, drive=sat_drive)

    # Safety normalize after saturation
    peak = np.max(np.abs(audio))
    if peak > 0.98:
        audio = audio * (0.95 / peak)

    # 2. Style-specific FX chain (Pedalboard — runs on C++)
    chain = build_style_chain(style)
    audio_2d = audio.reshape(1, -1).astype(np.float32)
    audio = chain(audio_2d, sr).squeeze()

    # 3. Chorus (before stereo)
    if style.get("chorus", False):
        depth = style.get("chorus_depth_ms", 6.0)
        rate = style.get("chorus_rate_hz", 1.0)
        audio = _simple_chorus(audio, sr, depth_ms=depth, rate_hz=rate)

    # 4. Create stereo field
    stereo = _to_stereo_delay(audio, sr, delay_ms=style["stereo_delay_ms"])

    # 5. Mid/Side width
    width = style.get("stereo_width", 1.0)
    if width != 1.0:
        stereo = _mid_side_width(stereo, width=width)

    # 6. Final clip
    stereo = np.clip(stereo, -1.0, 1.0).astype(np.float32)

    logger.info(f"Voice style '{style_name}' applied: sat={sat_type}/{sat_drive}, "
                f"width={width}, stereo_delay={style['stereo_delay_ms']}ms")

    return stereo
