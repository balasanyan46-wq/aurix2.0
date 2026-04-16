"""
Auto-mastering pipeline for streaming-ready output.

Chain:
  Load → Multiband EQ correction → Multiband Compression →
  Stereo Width → Limiter → LUFS Normalize → Export

No ML models. Pure DSP via Pedalboard + numpy.
Target: Spotify -14 LUFS, Apple Music -16 LUFS, -1dB True Peak.
"""

import logging
import time
import numpy as np
import soundfile as sf
import pyloudnorm as pyln
from pedalboard import (
    Pedalboard,
    Compressor,
    HighpassFilter,
    LowShelfFilter,
    PeakFilter,
    HighShelfFilter,
    Limiter,
)
from .utils import ensure_float32

logger = logging.getLogger("aurix-audio.mastering")

# Target specs per platform
TARGETS = {
    "spotify": {"lufs": -14.0, "peak": -1.0},
    "apple": {"lufs": -16.0, "peak": -1.0},
    "loud": {"lufs": -11.0, "peak": -0.5},
}


def _analyze_spectrum(audio: np.ndarray, sr: int) -> dict:
    """Quick spectral analysis to decide EQ corrections."""
    from scipy.signal import welch
    mono = audio.mean(axis=1) if audio.ndim == 2 else audio
    freqs, psd = welch(mono, fs=sr, nperseg=4096)

    # Energy in bands
    def band_energy(f_low, f_high):
        mask = (freqs >= f_low) & (freqs < f_high)
        return np.mean(psd[mask]) if mask.any() else 0

    low = band_energy(20, 250)
    mid = band_energy(250, 4000)
    high = band_energy(4000, 20000)
    total = low + mid + high + 1e-10

    return {
        "low_ratio": low / total,
        "mid_ratio": mid / total,
        "high_ratio": high / total,
    }


def _build_master_chain(spectrum: dict, target: str = "spotify") -> Pedalboard:
    """Build mastering chain with EQ corrections based on spectrum analysis."""
    plugins = []

    # 1. Subsonic filter
    plugins.append(HighpassFilter(cutoff_frequency_hz=30))

    # 2. Corrective EQ based on spectrum
    low_r = spectrum["low_ratio"]
    high_r = spectrum["high_ratio"]

    # If too bassy → cut low, if too thin → boost low
    low_correction = -2.0 if low_r > 0.45 else (2.0 if low_r < 0.15 else 0.0)
    plugins.append(LowShelfFilter(cutoff_frequency_hz=200, gain_db=low_correction))

    # Presence/clarity
    plugins.append(PeakFilter(cutoff_frequency_hz=3000, gain_db=1.5, q=0.8))

    # Air
    high_correction = -1.5 if high_r > 0.35 else (2.0 if high_r < 0.1 else 0.5)
    plugins.append(HighShelfFilter(cutoff_frequency_hz=10000, gain_db=high_correction))

    # 3. Gentle glue compression
    plugins.append(Compressor(
        threshold_db=-18.0,
        ratio=2.0,
        attack_ms=10.0,
        release_ms=100.0,
    ))

    # 4. Final limiter
    peak_db = TARGETS.get(target, TARGETS["spotify"])["peak"]
    plugins.append(Limiter(threshold_db=peak_db))

    return Pedalboard(plugins)


def _stereo_widen(audio: np.ndarray, amount: float = 1.2) -> np.ndarray:
    """Gentle stereo widening via mid/side."""
    if audio.ndim == 1:
        return audio
    left, right = audio[:, 0], audio[:, 1]
    mid = (left + right) * 0.5
    side = (left - right) * 0.5
    side = side * amount
    return np.column_stack([mid + side, mid - side])


def master_track(
    input_path: str,
    output_path: str,
    target: str = "spotify",
    stereo_width: float = 1.15,
) -> dict:
    """
    Auto-master a track for streaming platforms.

    Args:
        target: "spotify" | "apple" | "loud"
        stereo_width: 1.0 = no change, 1.2 = slightly wider
    """
    t0 = time.time()

    audio, sr = sf.read(input_path, dtype="float32")
    audio = ensure_float32(audio)
    if audio.ndim == 1:
        audio = np.column_stack([audio, audio])

    logger.info(f"Mastering: {len(audio)/sr:.1f}s @ {sr}Hz, target={target}")

    # 1. Analyze spectrum
    spectrum = _analyze_spectrum(audio, sr)
    logger.info(f"Spectrum: low={spectrum['low_ratio']:.0%} mid={spectrum['mid_ratio']:.0%} high={spectrum['high_ratio']:.0%}")

    # 2. Build and apply mastering chain
    chain = _build_master_chain(spectrum, target)
    # Pedalboard wants (channels, samples)
    audio_t = audio.T.copy()  # (2, N)
    processed_t = chain(audio_t, sr)
    processed = processed_t.T.copy()  # (N, 2)

    # 3. Stereo width
    if stereo_width != 1.0:
        processed = _stereo_widen(processed, stereo_width)

    # 4. LUFS normalization
    target_lufs = TARGETS.get(target, TARGETS["spotify"])["lufs"]
    try:
        meter = pyln.Meter(sr)
        current = meter.integrated_loudness(processed)
        if not np.isinf(current) and not np.isnan(current):
            processed = pyln.normalize.loudness(processed, current, target_lufs)
            logger.info(f"LUFS: {current:.1f} → {target_lufs:.1f}")
    except Exception as e:
        logger.warning(f"LUFS normalization skipped: {e}")

    # 5. Safety clip
    processed = np.clip(processed, -1.0, 1.0).astype(np.float32)

    # 6. Export
    sf.write(output_path, processed, sr, subtype="PCM_16")

    elapsed = time.time() - t0
    logger.info(f"Mastered: {len(processed)/sr:.1f}s, target={target}, width={stereo_width}, {elapsed:.2f}s")

    return {
        "duration": round(len(processed) / sr, 2),
        "target": target,
        "target_lufs": target_lufs,
        "stereo_width": stereo_width,
        "spectrum": spectrum,
        "processing_time": round(elapsed, 3),
    }
