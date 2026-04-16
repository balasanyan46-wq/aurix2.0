"""
Mix beat + processed vocal into a single stereo track.
"""

import logging
import time
import numpy as np
import soundfile as sf
from .utils import to_mono, ensure_float32

logger = logging.getLogger("aurix-audio.mixer")


def mix_tracks(
    beat_path: str,
    vocal_path: str,
    output_path: str,
    beat_volume: float = 0.85,
    vocal_volume: float = 1.0,
    sample_rate: int = 44100,
) -> dict:
    """Mix beat and vocal into a single stereo WAV."""
    t0 = time.time()

    # Load beat
    beat, beat_sr = sf.read(beat_path, dtype="float32")
    if beat.ndim == 1:
        beat = np.column_stack([beat, beat])  # mono → stereo
    if beat_sr != sample_rate:
        import librosa
        beat_l = librosa.resample(beat[:, 0], orig_sr=beat_sr, target_sr=sample_rate)
        beat_r = librosa.resample(beat[:, 1], orig_sr=beat_sr, target_sr=sample_rate)
        beat = np.column_stack([beat_l, beat_r])

    # Load vocal
    vocal, vocal_sr = sf.read(vocal_path, dtype="float32")
    if vocal.ndim == 1:
        vocal = np.column_stack([vocal, vocal])  # mono → stereo
    if vocal_sr != sample_rate:
        import librosa
        vocal_l = librosa.resample(vocal[:, 0], orig_sr=vocal_sr, target_sr=sample_rate)
        vocal_r = librosa.resample(vocal[:, 1], orig_sr=vocal_sr, target_sr=sample_rate)
        vocal = np.column_stack([vocal_l, vocal_r])

    # Match lengths (pad shorter with silence)
    max_len = max(len(beat), len(vocal))
    if len(beat) < max_len:
        beat = np.pad(beat, ((0, max_len - len(beat)), (0, 0)))
    if len(vocal) < max_len:
        vocal = np.pad(vocal, ((0, max_len - len(vocal)), (0, 0)))

    # Mix
    mixed = beat * beat_volume + vocal * vocal_volume
    mixed = np.clip(mixed, -1.0, 1.0).astype(np.float32)

    sf.write(output_path, mixed, sample_rate, subtype="PCM_16")

    elapsed = time.time() - t0
    logger.info(f"Mixed: {max_len/sample_rate:.1f}s, beat_vol={beat_volume}, vocal_vol={vocal_volume}, {elapsed:.2f}s")

    return {
        "duration": round(max_len / sample_rate, 2),
        "processing_time": round(elapsed, 3),
    }
