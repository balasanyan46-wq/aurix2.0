"""
Pitch correction (autotune-lite) using librosa pitch detection + pyrubberband.

Pipeline:
  1. Detect pitch per frame (librosa.pyin — probabilistic YIN)
  2. Map each pitch to nearest note in target scale
  3. Calculate correction in semitones per frame
  4. Apply strength factor (0 = off, 1 = hard snap)
  5. Smooth corrections (avoid glitchy jumps)
  6. Apply pitch shift per segment via pyrubberband

Why not basic-pitch: it's a neural model (150MB+, slow startup, overkill for
monophonic vocal correction). librosa.pyin is fast, accurate for vocals, and
runs in <1s for a 3-minute track.
"""

import logging
import time

import numpy as np
import librosa

logger = logging.getLogger("aurix-audio.pitch")

# ─── Musical scales (semitone offsets from C) ───

def _build_scale(root: int, intervals: list[int]) -> list[int]:
    """Build scale from root semitone and interval pattern."""
    return [(root + i) % 12 for i in intervals]

_MAJ = [0, 2, 4, 5, 7, 9, 11]
_MIN = [0, 2, 3, 5, 7, 8, 10]

# All 24 major + minor scales
SCALES = {
    # C
    "C_major":  _build_scale(0, _MAJ),
    "C_minor":  _build_scale(0, _MIN),
    # Db / C#
    "Db_major": _build_scale(1, _MAJ),
    "Cs_minor": _build_scale(1, _MIN),
    # D
    "D_major":  _build_scale(2, _MAJ),
    "D_minor":  _build_scale(2, _MIN),
    # Eb
    "Eb_major": _build_scale(3, _MAJ),
    "Eb_minor": _build_scale(3, _MIN),
    # E
    "E_major":  _build_scale(4, _MAJ),
    "E_minor":  _build_scale(4, _MIN),
    # F
    "F_major":  _build_scale(5, _MAJ),
    "F_minor":  _build_scale(5, _MIN),
    # F# / Gb
    "Fs_major": _build_scale(6, _MAJ),
    "Fs_minor": _build_scale(6, _MIN),
    # G
    "G_major":  _build_scale(7, _MAJ),
    "G_minor":  _build_scale(7, _MIN),
    # Ab
    "Ab_major": _build_scale(8, _MAJ),
    "Ab_minor": _build_scale(8, _MIN),
    # A
    "A_major":  _build_scale(9, _MAJ),
    "A_minor":  _build_scale(9, _MIN),
    # Bb
    "Bb_major": _build_scale(10, _MAJ),
    "Bb_minor": _build_scale(10, _MIN),
    # B
    "B_major":  _build_scale(11, _MAJ),
    "B_minor":  _build_scale(11, _MIN),
}


def _hz_to_midi(hz: float) -> float:
    """Convert frequency in Hz to MIDI note number."""
    if hz <= 0:
        return 0.0
    return 12.0 * np.log2(hz / 440.0) + 69.0


def _midi_to_hz(midi: float) -> float:
    """Convert MIDI note number to frequency in Hz."""
    return 440.0 * (2.0 ** ((midi - 69.0) / 12.0))


def _nearest_scale_note(midi_note: float, scale_semitones: list[int]) -> float:
    """Find the nearest note in the scale (returns MIDI note)."""
    pitch_class = midi_note % 12
    octave = int(midi_note) // 12

    best_dist = 999.0
    best_note = midi_note

    for offset in scale_semitones:
        # Check same octave and adjacent
        for oct_shift in [-1, 0, 1]:
            candidate = (octave + oct_shift) * 12 + offset
            dist = abs(midi_note - candidate)
            if dist < best_dist:
                best_dist = dist
                best_note = candidate

    return best_note


def detect_pitch(audio: np.ndarray, sr: int) -> tuple[np.ndarray, np.ndarray]:
    """
    Detect pitch per frame using pYIN (probabilistic YIN).

    Returns:
        pitches_hz: array of pitch values in Hz (0 = unvoiced)
        voiced_flags: boolean array (True = voiced frame)
    """
    f0, voiced_flag, _ = librosa.pyin(
        audio,
        fmin=librosa.note_to_hz("C2"),   # ~65 Hz
        fmax=librosa.note_to_hz("C6"),   # ~1047 Hz
        sr=sr,
        frame_length=2048,
        hop_length=512,
    )

    # Replace NaN with 0
    f0 = np.nan_to_num(f0, nan=0.0)
    voiced_flag = np.nan_to_num(voiced_flag, nan=False).astype(bool)

    return f0, voiced_flag


def pitch_correct(
    audio: np.ndarray,
    sr: int,
    scale: str = "C_major",
    strength: float = 0.5,
) -> np.ndarray:
    """
    Apply pitch correction to vocal audio.

    Args:
        audio: mono float32 audio
        sr: sample rate
        scale: target musical scale name
        strength: 0.0 (no correction) to 1.0 (hard snap to nearest note)

    Returns:
        pitch-corrected audio (same length, same tempo)
    """
    t0 = time.time()
    duration = len(audio) / sr

    # Skip if too short or too quiet
    if duration < 2.0:
        logger.info("Pitch correction skipped: audio < 2s")
        return audio

    rms = np.sqrt(np.mean(audio ** 2))
    if rms < 0.005:
        logger.info("Pitch correction skipped: RMS too low")
        return audio

    if strength <= 0.01:
        return audio

    scale_notes = SCALES.get(scale, SCALES["C_major"])

    # 1. Detect pitch
    f0, voiced = detect_pitch(audio, sr)
    voiced_ratio = voiced.sum() / max(len(voiced), 1)
    logger.info(f"Pitch detected: {len(f0)} frames, {voiced_ratio:.0%} voiced")

    if voiced_ratio < 0.05:
        logger.info("Pitch correction skipped: <5% voiced frames")
        return audio

    # 2. Calculate correction per frame
    hop = 512
    corrections_semitones = np.zeros(len(f0), dtype=np.float64)

    for i in range(len(f0)):
        if not voiced[i] or f0[i] < 50:
            continue

        midi = _hz_to_midi(f0[i])
        target_midi = _nearest_scale_note(midi, scale_notes)
        diff = target_midi - midi  # semitones to shift

        # Apply strength (0 = no shift, 1 = full snap)
        corrections_semitones[i] = diff * strength

    # 3. Smooth corrections (avoid glitchy frame-to-frame jumps)
    # Median filter + exponential smoothing
    from scipy.signal import medfilt
    kernel = min(7, len(corrections_semitones) | 1)  # must be odd
    if kernel >= 3:
        corrections_semitones = medfilt(corrections_semitones, kernel_size=kernel)

    # Exponential smoothing
    alpha = 0.3
    smoothed = np.zeros_like(corrections_semitones)
    smoothed[0] = corrections_semitones[0]
    for i in range(1, len(smoothed)):
        smoothed[i] = alpha * corrections_semitones[i] + (1 - alpha) * smoothed[i - 1]

    # 4. Apply pitch shifts in segments (rubberband)
    # Group consecutive frames with similar correction into segments
    try:
        import pyrubberband as pyrb
    except ImportError:
        logger.warning("pyrubberband not available, skipping pitch correction")
        return audio

    output = audio.copy()
    segment_size = sr * 2  # process 2-second chunks for speed
    num_segments = max(1, len(audio) // segment_size)

    for seg_idx in range(num_segments):
        start_sample = seg_idx * segment_size
        end_sample = min(start_sample + segment_size, len(audio))
        segment = audio[start_sample:end_sample]

        if len(segment) < sr // 4:  # skip tiny tail segments
            continue

        # Average correction for this segment
        frame_start = start_sample // hop
        frame_end = min(end_sample // hop, len(smoothed))
        if frame_start >= frame_end:
            continue

        seg_corrections = smoothed[frame_start:frame_end]
        # Only consider voiced frames
        seg_voiced = voiced[frame_start:frame_end]
        voiced_corrections = seg_corrections[seg_voiced]

        if len(voiced_corrections) == 0:
            continue

        avg_shift = np.median(voiced_corrections)

        # Skip tiny corrections (< 5 cents)
        if abs(avg_shift) < 0.05:
            continue

        # Apply pitch shift (preserves tempo)
        try:
            shifted = pyrb.pitch_shift(segment, sr, n_steps=avg_shift)
            # Match length exactly
            if len(shifted) >= len(segment):
                output[start_sample:end_sample] = shifted[:len(segment)]
            else:
                output[start_sample:start_sample + len(shifted)] = shifted
        except Exception as e:
            logger.warning(f"Pitch shift failed for segment {seg_idx}: {e}")
            continue

    elapsed = time.time() - t0
    avg_correction = np.mean(np.abs(smoothed[voiced]))
    logger.info(
        f"Pitch corrected: {duration:.1f}s, scale={scale}, strength={strength:.0%}, "
        f"avg_correction={avg_correction:.2f} semitones, took {elapsed:.2f}s"
    )

    return output.astype(np.float32)
