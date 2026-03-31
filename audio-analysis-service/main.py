"""
AURIX Audio Analysis Service v4.0
FastAPI + librosa + faster-whisper
— accurate BPM (multi-method validation)
— major/minor key detection (Krumhansl-Schmuckler)
— genre classification (heuristic from spectral features)
— lyrics transcription (Whisper)
— improved hook detection (repetition + energy)
"""

import os
import tempfile
import logging
from typing import Optional

import numpy as np
import librosa
from scipy.signal import medfilt
from scipy.spatial.distance import cosine as cosine_dist
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("aurix-audio")

app = FastAPI(title="AURIX Audio Analysis", version="4.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Whisper model (lazy load) ────────────────────────────────

_whisper_model = None

def _get_whisper():
    global _whisper_model
    if _whisper_model is None:
        try:
            from faster_whisper import WhisperModel
            model_size = os.environ.get("WHISPER_MODEL", "base")
            logger.info(f"Loading Whisper model: {model_size}")
            _whisper_model = WhisperModel(
                model_size,
                device="cpu",
                compute_type="int8",
            )
            logger.info("Whisper model loaded")
        except Exception as e:
            logger.error(f"Failed to load Whisper: {e}")
            _whisper_model = "failed"
    return _whisper_model if _whisper_model != "failed" else None


# ── Health check ─────────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "ok", "service": "audio-analysis", "version": "4.0"}


# ── Main endpoint ────────────────────────────────────────────

@app.post("/analyze")
async def analyze_audio(file: UploadFile = File(...)):
    if not file.content_type or not file.content_type.startswith("audio/"):
        raise HTTPException(status_code=400, detail="Only audio files are accepted")

    suffix = _guess_suffix(file.filename or "track.mp3")
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
    try:
        content = await file.read()
        if len(content) > 150 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="File too large (max 150 MB)")

        tmp.write(content)
        tmp.flush()
        tmp.close()

        logger.info(f"Analyzing: {file.filename} ({len(content)} bytes)")
        result = _analyze(tmp.name)
        logger.info(
            f"Done: BPM={result['bpm']}, key={result['estimated_key']}, "
            f"genre={result['genre']}, hook={result['hook_time']}s, "
            f"hit_score={result['hit_score']}, "
            f"lyrics={'yes' if result.get('lyrics') else 'no'}"
        )
        return result

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Analysis failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")
    finally:
        try:
            os.unlink(tmp.name)
        except OSError:
            pass


# ══════════════════════════════════════════════════════════════
# Core analysis
# ══════════════════════════════════════════════════════════════

def _analyze(path: str) -> dict:
    y, sr = librosa.load(path, sr=22050, mono=True)
    duration = librosa.get_duration(y=y, sr=sr)

    # ── BPM (multi-method) ──
    bpm = _detect_bpm(y, sr)

    # ── Tempo stability ──
    _, beat_frames = librosa.beat.beat_track(y=y, sr=sr)
    if len(beat_frames) > 2:
        beat_times = librosa.frames_to_time(beat_frames, sr=sr)
        ibis = np.diff(beat_times)
        tempo_stability = max(0.0, 1.0 - float(np.std(ibis) / (np.mean(ibis) + 1e-6)))
    else:
        tempo_stability = 0.5

    # ── Energy (RMS) ──
    rms = librosa.feature.rms(y=y)[0]
    energy_mean = float(np.mean(rms))
    energy_max = float(np.max(rms))
    energy_normalized = min(1.0, energy_mean / 0.15)

    # ── Dynamic range ──
    rms_db = librosa.amplitude_to_db(rms, ref=np.max)
    dynamic_range = float(np.max(rms_db) - np.percentile(rms_db, 10))

    # ── Brightness (spectral centroid) ──
    centroid = librosa.feature.spectral_centroid(y=y, sr=sr)[0]
    brightness_hz = float(np.mean(centroid))
    brightness_normalized = min(1.0, max(0.0, (brightness_hz - 1000) / 7000))

    # ── Spectral contrast ──
    contrast = librosa.feature.spectral_contrast(y=y, sr=sr)
    spectral_contrast = float(np.mean(contrast))

    # ── Onset density ──
    onsets = librosa.onset.onset_detect(y=y, sr=sr)
    onset_density = len(onsets) / max(1.0, duration)

    # ── Spectral features for genre ──
    spectral_rolloff = float(np.mean(librosa.feature.spectral_rolloff(y=y, sr=sr)[0]))
    spectral_bandwidth = float(np.mean(librosa.feature.spectral_bandwidth(y=y, sr=sr)[0]))
    zcr = float(np.mean(librosa.feature.zero_crossing_rate(y=y)[0]))
    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
    mfcc_means = [float(np.mean(mfcc[i])) for i in range(13)]

    # ── Key estimation (Krumhansl-Schmuckler) ──
    estimated_key = _detect_key(y, sr)

    # ── Genre classification ──
    genre = _classify_genre(
        bpm=bpm,
        brightness_hz=brightness_hz,
        onset_density=onset_density,
        spectral_rolloff=spectral_rolloff,
        spectral_bandwidth=spectral_bandwidth,
        spectral_contrast=spectral_contrast,
        zcr=zcr,
        energy_mean=energy_mean,
        dynamic_range=dynamic_range,
        mfcc_means=mfcc_means,
        duration=duration,
    )

    # ── Energy curve (50 points) ──
    n_points = 50
    hop = max(1, len(rms) // n_points)
    energy_curve = [round(float(rms[i * hop]), 4) for i in range(min(n_points, len(rms) // hop))]

    # ── Sections ──
    sections = _detect_sections(rms, sr, duration)

    # ── Structure ──
    structure = _analyze_structure(rms, sr, duration)

    # ── Hook detection (improved: repetition + energy) ──
    hook_time = _find_hook_advanced(y, sr, rms, duration)

    # ── Drop detection ──
    drop_time = _find_drop(rms, sr, duration)

    # ── Intro assessment ──
    intro_weak = _assess_intro(rms, sr, duration)

    # ── Hit predictor metrics ──
    energy_std = float(np.std(rms))
    peak_energy = float(np.max(rms))
    energy_variation = float(np.std(rms) / (np.mean(rms) + 1e-6))

    hop_length = 512
    fps = sr / hop_length
    early_frames = min(int(10.0 * fps), len(rms))
    early_energy = float(np.mean(rms[:early_frames])) if early_frames > 0 else 0.0
    early_energy_ratio = early_energy / (float(np.mean(rms)) + 1e-6)

    hit_score = _calculate_hit_score(
        hook_time=hook_time,
        intro_weak=intro_weak,
        energy_variation=energy_variation,
        early_energy_ratio=early_energy_ratio,
        peak_energy=peak_energy,
        energy_mean=energy_mean,
        bpm=bpm,
        dynamic_range=dynamic_range,
        tempo_stability=tempo_stability,
        duration=duration,
    )

    # ── Lyrics transcription (Whisper) ──
    lyrics = _transcribe(path)

    return {
        "bpm": round(bpm, 1),
        "duration": round(duration, 2),
        "energy": round(energy_normalized, 3),
        "energy_mean": round(energy_mean, 4),
        "energy_max": round(energy_max, 4),
        "brightness": round(brightness_normalized, 3),
        "brightness_hz": round(brightness_hz, 1),
        "tempo_stability": round(tempo_stability, 3),
        "spectral_contrast": round(spectral_contrast, 2),
        "onset_density": round(onset_density, 2),
        "dynamic_range": round(dynamic_range, 2),
        "estimated_key": estimated_key,
        "genre": genre,
        "lyrics": lyrics,
        "energy_curve": energy_curve,
        "sections": sections,
        "structure": structure,
        "hook_time": hook_time,
        "drop_time": drop_time,
        "intro_weak": intro_weak,
        "energy_variation": round(energy_variation, 3),
        "peak_energy": round(peak_energy, 4),
        "energy_std": round(energy_std, 4),
        "early_energy": round(early_energy_ratio, 3),
        "hit_score": hit_score,
    }


# ══════════════════════════════════════════════════════════════
# BPM — multi-method with validation
# ══════════════════════════════════════════════════════════════

def _detect_bpm(y, sr) -> float:
    """
    Use multiple methods to get accurate BPM.
    Cross-validate and fix half/double tempo errors.
    """
    candidates = []

    # Method 1: beat_track (default)
    tempo1, _ = librosa.beat.beat_track(y=y, sr=sr)
    t1 = float(np.atleast_1d(tempo1)[0])
    candidates.append(t1)

    # Method 2: beat_track with different hop
    tempo2, _ = librosa.beat.beat_track(y=y, sr=sr, hop_length=256)
    t2 = float(np.atleast_1d(tempo2)[0])
    candidates.append(t2)

    # Method 3: onset-based tempo estimation
    onset_env = librosa.onset.onset_strength(y=y, sr=sr)
    tempo3 = librosa.feature.tempo(onset_envelope=onset_env, sr=sr)
    t3 = float(np.atleast_1d(tempo3)[0])
    candidates.append(t3)

    # Method 4: onset with different hop
    onset_env2 = librosa.onset.onset_strength(y=y, sr=sr, hop_length=256)
    tempo4 = librosa.feature.tempo(onset_envelope=onset_env2, sr=sr)
    t4 = float(np.atleast_1d(tempo4)[0])
    candidates.append(t4)

    # Normalize all candidates to 60-200 range
    normalized = []
    for t in candidates:
        while t < 60:
            t *= 2
        while t > 200:
            t /= 2
        normalized.append(t)

    # Find consensus: group candidates that are close (within 8 BPM)
    best = normalized[0]
    best_count = 0

    for t in normalized:
        count = sum(1 for t2 in normalized if abs(t - t2) < 8)
        if count > best_count:
            best_count = count
            best = t
        elif count == best_count:
            # Prefer the tempo in the "sweet spot" 80-160
            if 80 <= t <= 160 and not (80 <= best <= 160):
                best = t

    # Average the agreeing candidates
    agreeing = [t for t in normalized if abs(t - best) < 8]
    final_bpm = float(np.mean(agreeing))

    return round(final_bpm, 1)


# ══════════════════════════════════════════════════════════════
# Key detection — Krumhansl-Schmuckler
# ══════════════════════════════════════════════════════════════

# Krumhansl-Kessler profiles
_MAJOR_PROFILE = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
_MINOR_PROFILE = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])

_KEY_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def _detect_key(y, sr) -> str:
    """
    Krumhansl-Schmuckler algorithm: correlate chroma with major/minor profiles.
    Returns e.g. 'Am', 'C', 'F#m'.
    """
    chroma = librosa.feature.chroma_cqt(y=y, sr=sr)
    chroma_avg = np.mean(chroma, axis=1)  # 12-dim vector

    best_corr = -2
    best_key = "C"

    for shift in range(12):
        # Rotate chroma to test each root
        rotated = np.roll(chroma_avg, -shift)

        # Correlate with major profile
        corr_major = float(np.corrcoef(rotated, _MAJOR_PROFILE)[0, 1])
        if corr_major > best_corr:
            best_corr = corr_major
            best_key = _KEY_NAMES[shift]

        # Correlate with minor profile
        corr_minor = float(np.corrcoef(rotated, _MINOR_PROFILE)[0, 1])
        if corr_minor > best_corr:
            best_corr = corr_minor
            best_key = _KEY_NAMES[shift] + "m"

    return best_key


# ══════════════════════════════════════════════════════════════
# Genre classification — heuristic from spectral features
# ══════════════════════════════════════════════════════════════

def _classify_genre(
    bpm: float,
    brightness_hz: float,
    onset_density: float,
    spectral_rolloff: float,
    spectral_bandwidth: float,
    spectral_contrast: float,
    zcr: float,
    energy_mean: float,
    dynamic_range: float,
    mfcc_means: list,
    duration: float,
) -> str:
    """
    Rule-based genre classifier using audio features.
    Returns primary genre + optional sub-genre.
    """
    scores = {}

    # ── Hip-Hop / Rap ──
    s = 0
    if 70 <= bpm <= 100:
        s += 3
    elif 60 <= bpm <= 110:
        s += 1
    if onset_density < 4:
        s += 1
    if brightness_hz < 3500:
        s += 1
    if energy_mean > 0.04:
        s += 1
    scores["Hip-Hop / Rap"] = s

    # ── Trap ──
    s = 0
    if 130 <= bpm <= 170:
        s += 3
    elif 120 <= bpm <= 180:
        s += 1
    # Trap often detected at half BPM
    if 65 <= bpm <= 85:
        s += 2  # likely half-time trap
    if onset_density > 3 and onset_density < 8:
        s += 1
    if brightness_hz > 3000 and brightness_hz < 5500:
        s += 1
    if spectral_rolloff > 4000:
        s += 1
    scores["Trap"] = s

    # ── Pop ──
    s = 0
    if 100 <= bpm <= 130:
        s += 2
    if brightness_hz > 2500 and brightness_hz < 5000:
        s += 1
    if dynamic_range > 8 and dynamic_range < 25:
        s += 1
    if onset_density > 2 and onset_density < 6:
        s += 1
    if energy_mean > 0.03:
        s += 1
    scores["Pop"] = s

    # ── R&B / Soul ──
    s = 0
    if 60 <= bpm <= 100:
        s += 2
    if brightness_hz < 3500:
        s += 1
    if onset_density < 3.5:
        s += 2
    if energy_mean < 0.08:
        s += 1
    if dynamic_range > 10:
        s += 1
    scores["R&B"] = s

    # ── EDM / Dance ──
    s = 0
    if 120 <= bpm <= 135:
        s += 3
    elif 115 <= bpm <= 140:
        s += 1
    if onset_density > 5:
        s += 2
    if brightness_hz > 4000:
        s += 1
    if energy_mean > 0.06:
        s += 1
    scores["EDM / Dance"] = s

    # ── House ──
    s = 0
    if 118 <= bpm <= 132:
        s += 3
    if onset_density > 4 and onset_density < 8:
        s += 1
    if brightness_hz > 3000 and brightness_hz < 6000:
        s += 1
    if energy_mean > 0.05:
        s += 1
    scores["House"] = s

    # ── Techno ──
    s = 0
    if 125 <= bpm <= 150:
        s += 3
    if onset_density > 6:
        s += 2
    if brightness_hz > 4000:
        s += 1
    if dynamic_range < 15:
        s += 1
    scores["Techno"] = s

    # ── Drum & Bass ──
    s = 0
    if 160 <= bpm <= 180:
        s += 4
    elif 155 <= bpm <= 185:
        s += 2
    if onset_density > 7:
        s += 2
    if energy_mean > 0.06:
        s += 1
    scores["Drum & Bass"] = s

    # ── Rock ──
    s = 0
    if 110 <= bpm <= 160:
        s += 1
    if brightness_hz > 3500:
        s += 1
    if dynamic_range > 15:
        s += 2
    if energy_mean > 0.07:
        s += 1
    if zcr > 0.08:
        s += 1
    scores["Rock"] = s

    # ── Metal ──
    s = 0
    if 120 <= bpm <= 200:
        s += 1
    if brightness_hz > 5000:
        s += 2
    if energy_mean > 0.1:
        s += 2
    if zcr > 0.12:
        s += 2
    if onset_density > 8:
        s += 1
    scores["Metal"] = s

    # ── Lo-Fi / Chill ──
    s = 0
    if 70 <= bpm <= 95:
        s += 2
    if brightness_hz < 3000:
        s += 2
    if onset_density < 3:
        s += 1
    if energy_mean < 0.05:
        s += 2
    if dynamic_range < 12:
        s += 1
    scores["Lo-Fi / Chill"] = s

    # ── Phonk ──
    s = 0
    if 130 <= bpm <= 145:
        s += 2
    elif 65 <= bpm <= 73:
        s += 2  # half-time phonk
    if brightness_hz > 2500 and brightness_hz < 5000:
        s += 1
    if energy_mean > 0.05:
        s += 1
    if spectral_contrast > 20:
        s += 1
    scores["Phonk"] = s

    # ── Reggaeton ──
    s = 0
    if 88 <= bpm <= 100:
        s += 3
    elif 85 <= bpm <= 105:
        s += 1
    if onset_density > 3 and onset_density < 6:
        s += 1
    scores["Reggaeton"] = s

    # ── Classical / Ambient ──
    s = 0
    if energy_mean < 0.03:
        s += 2
    if onset_density < 2:
        s += 2
    if dynamic_range > 20:
        s += 2
    if brightness_hz < 2500:
        s += 1
    if duration > 240:
        s += 1
    scores["Classical / Ambient"] = s

    # ── Jazz ──
    s = 0
    if 80 <= bpm <= 140:
        s += 1
    if dynamic_range > 15:
        s += 1
    if spectral_bandwidth > 2000:
        s += 1
    # Jazz has wider spectral spread and high mfcc variance
    if len(mfcc_means) >= 5 and abs(mfcc_means[1]) > 30:
        s += 1
    scores["Jazz"] = s

    # Pick top genre
    sorted_genres = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    top = sorted_genres[0]

    # If top score is too low, return generic
    if top[1] < 3:
        return "Other"

    return top[0]


# ══════════════════════════════════════════════════════════════
# Lyrics transcription — Whisper
# ══════════════════════════════════════════════════════════════

def _transcribe(path: str) -> Optional[str]:
    """Transcribe lyrics using faster-whisper. Returns text or None."""
    model = _get_whisper()
    if model is None:
        return None

    try:
        segments, info = model.transcribe(
            path,
            beam_size=3,
            language=None,  # auto-detect
            vad_filter=True,
            vad_parameters=dict(
                min_silence_duration_ms=500,
                speech_pad_ms=200,
            ),
        )

        lines = []
        for seg in segments:
            text = seg.text.strip()
            if text:
                lines.append(text)

        full_text = " ".join(lines).strip()

        # If too short or looks like noise, return None
        if len(full_text) < 10:
            return None

        # Detect language from info
        lang = getattr(info, 'language', None)
        logger.info(f"Transcribed {len(full_text)} chars, lang={lang}")

        return full_text

    except Exception as e:
        logger.error(f"Transcription failed: {e}")
        return None


# ══════════════════════════════════════════════════════════════
# Hook detection — improved (repetition + energy + novelty)
# ══════════════════════════════════════════════════════════════

def _find_hook_advanced(y, sr, rms, duration) -> float:
    """
    Find hook using a combination of:
    1. Energy peaks (loudest sections)
    2. Self-similarity / repetition (most repeated melodic pattern)
    3. Spectral novelty (distinct/memorable moments)
    The hook is the most repeated high-energy segment.
    """
    hop_length = 512
    fps = sr / hop_length
    window_sec = 4.0
    window_frames = int(window_sec * fps)

    if len(rms) < window_frames * 2:
        return 0.0

    # === Score 1: Energy ===
    cumsum = np.cumsum(rms)
    cumsum = np.insert(cumsum, 0, 0)
    window_sums = cumsum[window_frames:] - cumsum[:-window_frames]
    energy_scores = window_sums / (np.max(window_sums) + 1e-6)

    # === Score 2: Repetition (chroma self-similarity) ===
    chroma = librosa.feature.chroma_cqt(y=y, sr=sr, hop_length=hop_length)

    # Downsample chroma for speed: average over ~1 second blocks
    block = max(1, int(fps))
    n_blocks = chroma.shape[1] // block
    if n_blocks < 4:
        # Track too short for repetition analysis, fall back to energy only
        return _find_hook_energy(rms, fps, duration)

    chroma_blocks = np.array([
        np.mean(chroma[:, i * block:(i + 1) * block], axis=1)
        for i in range(n_blocks)
    ])

    # Count how many other blocks are similar to each block
    repetition_scores_blocks = np.zeros(n_blocks)
    for i in range(n_blocks):
        for j in range(n_blocks):
            if abs(i - j) > 2:  # skip neighbors
                sim = 1.0 - cosine_dist(chroma_blocks[i], chroma_blocks[j])
                if sim > 0.85:
                    repetition_scores_blocks[i] += 1

    # Expand block scores back to frame resolution
    rep_scores_full = np.zeros(len(rms))
    for i in range(n_blocks):
        start_f = i * block
        end_f = min((i + 1) * block, len(rms))
        rep_scores_full[start_f:end_f] = repetition_scores_blocks[i]

    # Make windowed repetition score
    if len(rep_scores_full) >= window_frames:
        rep_cumsum = np.cumsum(rep_scores_full)
        rep_cumsum = np.insert(rep_cumsum, 0, 0)
        rep_window = rep_cumsum[window_frames:] - rep_cumsum[:-window_frames]
        rep_window = rep_window / (np.max(rep_window) + 1e-6)
    else:
        rep_window = np.zeros_like(energy_scores)

    # Align lengths
    min_len = min(len(energy_scores), len(rep_window))
    energy_scores = energy_scores[:min_len]
    rep_window = rep_window[:min_len]

    # === Combined score: 40% energy + 60% repetition ===
    combined = 0.4 * energy_scores + 0.6 * rep_window

    # Skip first 3 seconds
    skip_frames = int(3.0 * fps)
    if skip_frames < len(combined):
        combined[:skip_frames] = 0

    # Skip last 10% (usually outro)
    outro_start = int(len(combined) * 0.9)
    combined[outro_start:] = 0

    best_frame = int(np.argmax(combined))
    best_time = best_frame / fps

    return round(best_time, 1)


def _find_hook_energy(rms, fps, duration) -> float:
    """Fallback: find hook by energy only."""
    window_sec = 4.0
    window_frames = int(window_sec * fps)

    if len(rms) < window_frames:
        return 0.0

    cumsum = np.cumsum(rms)
    cumsum = np.insert(cumsum, 0, 0)
    window_sums = cumsum[window_frames:] - cumsum[:-window_frames]

    best_frame = int(np.argmax(window_sums))
    best_time = best_frame / fps

    if best_time < 3.0 and duration > 30:
        start_frame = int(3.0 * fps)
        if start_frame < len(window_sums):
            best_frame = start_frame + int(np.argmax(window_sums[start_frame:]))
            best_time = best_frame / fps

    return round(best_time, 1)


# ══════════════════════════════════════════════════════════════
# Structure analysis
# ══════════════════════════════════════════════════════════════

def _analyze_structure(rms, sr, duration) -> list:
    hop_length = 512
    times = librosa.frames_to_time(np.arange(len(rms)), sr=sr, hop_length=hop_length)

    rms_max = float(np.max(rms)) if np.max(rms) > 0 else 1.0
    normalized = rms / rms_max

    max_points = 200
    if len(times) > max_points:
        step = len(times) / max_points
        indices = [int(i * step) for i in range(max_points)]
    else:
        indices = list(range(len(times)))

    return [
        {"time": round(float(times[i]), 2), "energy": round(float(normalized[i]), 3)}
        for i in indices
        if i < len(times)
    ]


# ══════════════════════════════════════════════════════════════
# Drop detection
# ══════════════════════════════════════════════════════════════

def _find_drop(rms, sr, duration) -> float:
    hop_length = 512
    fps = sr / hop_length

    window_frames = max(1, int(0.5 * fps))
    if len(rms) < window_frames * 4:
        return 0.0

    kernel = np.ones(window_frames) / window_frames
    smoothed = np.convolve(rms, kernel, mode="valid")

    diff_window = max(1, int(2.0 * fps))
    if len(smoothed) <= diff_window:
        return 0.0

    diffs = smoothed[diff_window:] - smoothed[:-diff_window]
    drop_frame = int(np.argmin(diffs))

    drop_magnitude = abs(float(diffs[drop_frame]))
    max_energy = float(np.max(rms))

    if max_energy > 0 and drop_magnitude / max_energy < 0.3:
        return 0.0

    drop_time = (drop_frame + window_frames // 2) / fps
    return round(drop_time, 1)


# ══════════════════════════════════════════════════════════════
# Intro assessment
# ══════════════════════════════════════════════════════════════

def _assess_intro(rms, sr, duration) -> bool:
    hop_length = 512
    fps = sr / hop_length

    if duration < 15:
        return False

    intro_frames = int(8.0 * fps)
    if intro_frames >= len(rms):
        return False

    intro_energy = float(np.mean(rms[:intro_frames]))

    start = int(len(rms) * 0.1)
    end = int(len(rms) * 0.9)
    if end <= start:
        return False

    track_median = float(np.median(rms[start:end]))

    if track_median <= 0:
        return False

    ratio = intro_energy / track_median
    return ratio < 0.4


# ══════════════════════════════════════════════════════════════
# Hit Score Calculator
# ══════════════════════════════════════════════════════════════

def _calculate_hit_score(
    hook_time, intro_weak, energy_variation, early_energy_ratio,
    peak_energy, energy_mean, bpm, dynamic_range, tempo_stability, duration,
) -> int:
    score = 50

    if hook_time > 0:
        if hook_time < 15:
            score += 15
        elif hook_time < 30:
            score += 10
        elif hook_time < 45:
            score += 5

    if intro_weak:
        score -= 20

    if energy_variation > 0.5:
        score += 15
    elif energy_variation > 0.3:
        score += 8

    if early_energy_ratio < 0.5:
        score -= 15
    elif early_energy_ratio < 0.7:
        score -= 8

    if peak_energy > 0.15:
        score += 10
    elif peak_energy > 0.10:
        score += 5

    if 100 <= bpm <= 140:
        score += 5

    if dynamic_range > 10:
        score += 5

    if tempo_stability > 0.8:
        score += 5

    if duration > 300:
        score -= 5

    return max(0, min(100, score))


# ══════════════════════════════════════════════════════════════
# Sections detection
# ══════════════════════════════════════════════════════════════

def _detect_sections(rms, sr, duration) -> list:
    hop_length = 512
    fps = sr / hop_length
    window = max(1, int(fps))

    if len(rms) < window * 3:
        return [{"start": 0, "end": round(duration, 1), "type": "full", "energy": round(float(np.mean(rms)), 3)}]

    n_secs = len(rms) // window
    sec_energy = [float(np.mean(rms[i * window:(i + 1) * window])) for i in range(n_secs)]

    if not sec_energy:
        return []

    median_e = np.median(sec_energy)
    high_thresh = median_e * 1.3
    low_thresh = median_e * 0.7

    sections = []
    current_type = None
    start = 0

    for i, e in enumerate(sec_energy):
        if e < low_thresh:
            stype = "quiet"
        elif e > high_thresh:
            stype = "loud"
        else:
            stype = "mid"

        if stype != current_type:
            if current_type is not None:
                sections.append({
                    "start": round(start, 1),
                    "end": round(float(i), 1),
                    "type": _section_label(current_type, start, float(i), duration),
                    "energy": round(float(np.mean(sec_energy[int(start):i])), 3) if i > int(start) else 0,
                })
            current_type = stype
            start = float(i)

    if current_type is not None:
        sections.append({
            "start": round(start, 1),
            "end": round(duration, 1),
            "type": _section_label(current_type, start, duration, duration),
            "energy": round(float(np.mean(sec_energy[int(start):])), 3) if int(start) < len(sec_energy) else 0,
        })

    return sections


def _section_label(energy_type, start, end, total):
    if start < total * 0.1 and energy_type == "quiet":
        return "intro"
    if end > total * 0.9 and energy_type == "quiet":
        return "outro"
    if energy_type == "loud":
        return "chorus"
    if energy_type == "quiet":
        return "bridge"
    return "verse"


def _guess_suffix(filename: str) -> str:
    ext = os.path.splitext(filename)[1].lower()
    return ext if ext in (".mp3", ".wav", ".flac", ".ogg", ".m4a", ".aac", ".wma") else ".mp3"


# ── Run ──────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", "8001"))
    uvicorn.run("main:app", host="0.0.0.0", port=port, log_level="info")
