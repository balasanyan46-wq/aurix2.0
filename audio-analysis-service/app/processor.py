"""
Core vocal processor.

Pipeline:
  Load → Mono → Normalize → Pitch Correction → Voice Style (sat+FX+stereo) → LUFS → Export

When style="none": uses preset-based FX chain (no saturation/stereo).
When style is set:  voice_style replaces the generic FX chain entirely.
"""

import logging
import time

import numpy as np
import soundfile as sf
import pyloudnorm as pyln

from .presets import get_preset
from .fx_chain import build_chain
from .pitch_correction import pitch_correct
from .voice_style import apply_voice_style, get_autotune_strength_for_style
from .utils import to_mono, normalize_peak, ensure_float32

logger = logging.getLogger("aurix-audio.processor")


def process_vocal(
    input_path: str,
    output_path: str,
    preset_name: str = "hit",
    sample_rate: int = 44100,
    autotune: bool = False,
    autotune_strength: float = 0.5,
    autotune_key: str = "C_major",
    style: str = "none",
) -> dict:
    """
    Process a vocal file through the full pipeline.

    Args:
        style: "none" | "trap" | "pop" | "dark" | "wide_star"
               If set, overrides the preset FX chain with a voice style.
    """
    t0 = time.time()

    # 1. Load
    audio, sr = sf.read(input_path, dtype="float32")
    logger.info(f"Loaded: {len(audio)/sr:.1f}s @ {sr}Hz, shape={audio.shape}")

    # 2. Mono
    audio = to_mono(audio)
    audio = ensure_float32(audio)

    # 3. Resample
    if sr != sample_rate:
        try:
            import librosa
            audio = librosa.resample(audio, orig_sr=sr, target_sr=sample_rate)
            sr = sample_rate
        except ImportError:
            sample_rate = sr

    # 4. Normalize
    audio = normalize_peak(audio, target_peak=0.9)

    # 5. Pitch correction
    #    If a voice style is set and autotune is "auto", use style's recommended strength
    pitch_applied = False
    actual_strength = autotune_strength
    if style != "none" and autotune:
        actual_strength = get_autotune_strength_for_style(style)

    if autotune and actual_strength > 0.01:
        try:
            t_pitch = time.time()
            audio = pitch_correct(audio, sr, scale=autotune_key, strength=actual_strength)
            pitch_applied = True
            logger.info(f"Pitch: key={autotune_key}, strength={actual_strength:.0%}, {time.time()-t_pitch:.2f}s")
        except Exception as e:
            logger.warning(f"Pitch correction failed: {e}")

    # 6. Processing path
    is_stereo_output = False
    if style != "none":
        # Voice style: saturation + style FX chain + stereo
        t_style = time.time()
        processed = apply_voice_style(audio, sr, style_name=style)
        is_stereo_output = processed.ndim == 2
        logger.info(f"Style '{style}': {time.time()-t_style:.2f}s, stereo={is_stereo_output}")
    else:
        # Classic preset-only path (mono)
        preset = get_preset(preset_name)
        chain = build_chain(preset)
        audio_2d = audio.reshape(1, -1)
        processed = chain(audio_2d, sr).squeeze()

    # 7. LUFS normalization
    preset = get_preset(preset_name)
    target_lufs = preset.get("target_lufs", -14.0)
    try:
        # pyloudnorm needs mono or interleaved stereo
        meter = pyln.Meter(sr)
        lufs_input = processed if processed.ndim == 1 else processed.mean(axis=1)
        current_lufs = meter.integrated_loudness(lufs_input)
        if not np.isinf(current_lufs) and not np.isnan(current_lufs):
            gain_db = target_lufs - current_lufs
            gain_linear = 10 ** (gain_db / 20.0)
            processed = processed * gain_linear
            logger.info(f"LUFS: {current_lufs:.1f} → {target_lufs:.1f} (gain {gain_db:+.1f}dB)")
    except Exception as e:
        logger.warning(f"LUFS skip: {e}")

    # 8. Safety clip
    processed = np.clip(processed, -1.0, 1.0).astype(np.float32)

    # 9. Export
    sf.write(output_path, processed, sr, subtype="PCM_16")

    elapsed = time.time() - t0
    n_samples = processed.shape[0] if processed.ndim == 1 else processed.shape[0]
    duration = n_samples / sr

    logger.info(
        f"Done: {duration:.1f}s, preset={preset_name}, style={style}, "
        f"autotune={'on' if pitch_applied else 'off'}, "
        f"stereo={is_stereo_output}, "
        f"took {elapsed:.2f}s ({elapsed/max(duration,0.1):.1f}x)"
    )

    return {
        "duration": round(duration, 2),
        "sample_rate": sr,
        "preset": preset_name,
        "style": style if style != "none" else None,
        "stereo": is_stereo_output,
        "autotune": pitch_applied,
        "autotune_key": autotune_key if pitch_applied else None,
        "autotune_strength": actual_strength if pitch_applied else None,
        "processing_time": round(elapsed, 3),
        "target_lufs": target_lufs,
    }
