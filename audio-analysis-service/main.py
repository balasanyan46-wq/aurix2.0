"""
AURIX Audio Analysis Service v5.0
FastAPI + librosa + faster-whisper
— accurate BPM (multi-method validation)
— major/minor key detection (Krumhansl-Schmuckler)
— genre classification (heuristic from spectral features)
— lyrics transcription (Whisper)
— improved hook detection (repetition + energy)
— LUFS loudness measurement
— spectral flux (novelty detection)
— improved hit score algorithm
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

app = FastAPI(title="AURIX Audio Analysis", version="5.0.0")

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
    return {"status": "ok", "service": "audio-analysis", "version": "5.0"}


# ── Vocal Processing (Pedalboard FX chain) ──────────────────

from fastapi.responses import FileResponse
from app.processor import process_vocal as _process_vocal
from app.utils import safe_temp_path, cleanup

@app.post("/process-vocal")
async def process_vocal_endpoint(
    file: UploadFile = File(...),
    preset: str = "hit",
    autotune: str = "off",
    strength: float = 0.5,
    key: str = "C_major",
    style: str = "none",
):
    """
    Process vocal through professional FX chain + optional voice style.

    Query params:
      preset:   hit | soft | aggressive  (base FX when style=none)
      style:    none | trap | pop | dark | wide_star  (overrides preset FX)
      autotune: on | off
      strength: 0.0–1.0  (pitch correction; auto-set when style is used)
      key:      C_major | A_minor | D_major | etc.
    """
    tmp_in = safe_temp_path(suffix=_guess_suffix(file.filename or "vocal.wav"))
    tmp_out = safe_temp_path(suffix=".wav")
    try:
        content = await file.read()
        if len(content) > 100 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="File too large (max 100 MB)")

        with open(tmp_in, "wb") as f:
            f.write(content)

        meta = _process_vocal(
            tmp_in, tmp_out,
            preset_name=preset,
            autotune=(autotune.lower() == "on"),
            autotune_strength=min(1.0, max(0.0, strength)),
            autotune_key=key,
            style=style,
        )
        logger.info(f"Vocal processed: {meta}")

        return FileResponse(
            tmp_out,
            media_type="audio/wav",
            filename="processed_vocal.wav",
            headers={"X-Processing-Time": str(meta["processing_time"])},
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Vocal processing failed: {e}")
        cleanup(tmp_out)
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cleanup(tmp_in)

@app.get("/presets")
def list_presets():
    """List available vocal processing presets."""
    from app.presets import PRESETS
    return {k: v["name"] for k, v in PRESETS.items()}

@app.get("/styles")
def list_styles():
    """List available voice styles."""
    from app.voice_style import STYLES
    return {k: {"name": k, "autotune": v.get("autotune_override", 0.5)} for k, v in STYLES.items()}


# ── Mix beat + vocal ─────────────────────────────────────────

from app.mixer import mix_tracks as _mix_tracks

@app.post("/mix")
async def mix_endpoint(
    beat: UploadFile = File(...),
    vocal: UploadFile = File(...),
    beat_volume: float = 0.85,
    vocal_volume: float = 1.0,
):
    """Mix beat + vocal into a single stereo WAV."""
    tmp_beat = safe_temp_path(suffix=".wav")
    tmp_vocal = safe_temp_path(suffix=".wav")
    tmp_out = safe_temp_path(suffix=".wav")
    try:
        with open(tmp_beat, "wb") as f: f.write(await beat.read())
        with open(tmp_vocal, "wb") as f: f.write(await vocal.read())
        meta = _mix_tracks(tmp_beat, tmp_vocal, tmp_out, beat_volume, vocal_volume)
        return FileResponse(tmp_out, media_type="audio/wav", filename="mixed.wav",
            headers={"X-Processing-Time": str(meta["processing_time"])})
    except Exception as e:
        logger.error(f"Mix failed: {e}")
        cleanup(tmp_out)
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cleanup(tmp_beat, tmp_vocal)


# ── Auto-mastering ───────────────────────────────────────────

from app.mastering import master_track as _master_track

@app.post("/master")
async def master_endpoint(
    file: UploadFile = File(...),
    target: str = "spotify",
    stereo_width: float = 1.15,
):
    """Auto-master a track for streaming platforms."""
    tmp_in = safe_temp_path(suffix=".wav")
    tmp_out = safe_temp_path(suffix=".wav")
    try:
        with open(tmp_in, "wb") as f: f.write(await file.read())
        meta = _master_track(tmp_in, tmp_out, target=target, stereo_width=stereo_width)
        return FileResponse(tmp_out, media_type="audio/wav", filename="mastered.wav",
            headers={"X-Processing-Time": str(meta["processing_time"])})
    except Exception as e:
        logger.error(f"Mastering failed: {e}")
        cleanup(tmp_out)
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cleanup(tmp_in)


# ── Full pipeline: process vocal + mix + master ──────────────

@app.post("/full-pipeline")
async def full_pipeline_endpoint(
    beat: UploadFile = File(...),
    vocal: UploadFile = File(...),
    preset: str = "hit",
    style: str = "wide_star",
    autotune: str = "on",
    strength: float = 0.5,
    key: str = "C_major",
    target: str = "spotify",
):
    """Full pipeline: process vocal → mix with beat → master for streaming."""
    tmp_beat = safe_temp_path(suffix=_guess_suffix(beat.filename or "beat.mp3"))
    tmp_vocal = safe_temp_path(suffix=_guess_suffix(vocal.filename or "vocal.webm"))
    tmp_processed = safe_temp_path(suffix=".wav")
    tmp_mixed = safe_temp_path(suffix=".wav")
    tmp_mastered = safe_temp_path(suffix=".wav")
    try:
        with open(tmp_beat, "wb") as f: f.write(await beat.read())
        with open(tmp_vocal, "wb") as f: f.write(await vocal.read())

        # Step 1: Process vocal
        _process_vocal(tmp_vocal, tmp_processed, preset_name=preset, style=style,
            autotune=(autotune.lower() == "on"), autotune_strength=min(1.0, max(0.0, strength)),
            autotune_key=key)

        # Step 2: Mix
        _mix_tracks(tmp_beat, tmp_processed, tmp_mixed)

        # Step 3: Master
        _master_track(tmp_mixed, tmp_mastered, target=target)

        return FileResponse(tmp_mastered, media_type="audio/wav", filename="final.wav")
    except Exception as e:
        logger.error(f"Full pipeline failed: {e}")
        cleanup(tmp_mastered)
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cleanup(tmp_beat, tmp_vocal, tmp_processed, tmp_mixed)


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
        hook_t = result['main_hook_candidate']['time'] if result['main_hook_candidate'] else 'none'
        top_genre = result['primary_genre']
        logger.info(
            f"Done: BPM={result['bpm']['bpm']}, key={result['key']['key']}, "
            f"genre={top_genre}, hook={hook_t}s, "
            f"lufs={result.get('lufs', 'N/A')}, "
            f"transcript={'yes' if result['transcript']['text'] else 'no'}"
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
    """
    Core analysis — returns measured_data schema.
    All values are raw measurements or deterministic computations.
    No subjective scoring (hit_score moved to NestJS rule engine).
    """
    y, sr = librosa.load(path, sr=22050, mono=True)
    duration = librosa.get_duration(y=y, sr=sr)

    # ── BPM (multi-method with agreement) ──
    bpm_result = _detect_bpm(y, sr)

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

    # ── Dynamic range ──
    rms_db = librosa.amplitude_to_db(rms, ref=np.max)
    dynamic_range = float(np.max(rms_db) - np.percentile(rms_db, 10))

    # ── LUFS ──
    lufs = _calculate_lufs(y, sr)

    # ── Spectral features ──
    centroid = librosa.feature.spectral_centroid(y=y, sr=sr)[0]
    brightness_hz = float(np.mean(centroid))

    contrast = librosa.feature.spectral_contrast(y=y, sr=sr)
    spectral_contrast = float(np.mean(contrast))

    onsets = librosa.onset.onset_detect(y=y, sr=sr)
    onset_density = len(onsets) / max(1.0, duration)

    spectral_flux = _spectral_flux(y, sr)
    spectral_rolloff = float(np.mean(librosa.feature.spectral_rolloff(y=y, sr=sr)[0]))
    spectral_bandwidth = float(np.mean(librosa.feature.spectral_bandwidth(y=y, sr=sr)[0]))
    zcr = float(np.mean(librosa.feature.zero_crossing_rate(y=y)[0]))
    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
    mfcc_means = [float(np.mean(mfcc[i])) for i in range(13)]

    freq_bands = _frequency_band_energy(y, sr)

    # ── Harmonic ratio ──
    y_harm = librosa.effects.harmonic(y, margin=4)
    y_perc = librosa.effects.percussive(y, margin=4)
    harm_energy = float(np.sum(y_harm ** 2))
    perc_energy = float(np.sum(y_perc ** 2))
    harmonic_ratio = harm_energy / (harm_energy + perc_energy + 1e-10)

    # ── Key (with confidence) ──
    key_result = _detect_key(y, sr)

    # ── Genre candidates (rule-based with reasons) ──
    genre_candidates = _classify_genre(
        bpm=bpm_result["bpm"],
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
        harmonic_ratio=harmonic_ratio,
    )

    # ── Energy curve (50 points) ──
    n_points = 50
    hop = max(1, len(rms) // n_points)
    energy_curve = [round(float(rms[i * hop]), 4) for i in range(min(n_points, len(rms) // hop))]

    # ── Waveform peaks (100 points) ──
    waveform_peaks = _extract_waveform_peaks(y, 100)

    # ── Vocal presence detection ──
    vocal_data = _detect_vocal_presence(y, sr)
    vocal_curve = vocal_data["vocal_presence_curve"]
    first_vocal_time = vocal_data["first_vocal_time"]

    # ── Section candidates (with fingerprint groups + summary) ──
    section_result = _detect_sections(rms, sr, duration, y=y)
    section_candidates = section_result["sections"]

    # ── Structure (energy timeline) ──
    structure = _analyze_structure(rms, sr, duration)

    # ── Hook candidates (top 3 with confidence + reason) ──
    hook_candidates = _find_hook_advanced(y, sr, rms, duration, vocal_curve=vocal_curve)

    # Main hook candidate summary
    main_hook = None
    if hook_candidates:
        h = hook_candidates[0]
        main_hook = {
            "time": h["time"],
            "confidence": h["confidence"],
            "reason": h["reason"],
        }

    # ── Drop candidates ──
    drop_candidates = _find_drop(rms, sr, duration)

    # ── Intro metrics (with vocal presence + transition) ──
    intro_metrics = _assess_intro(rms, sr, duration, vocal_curve=vocal_curve)

    # ── Transcript (with reliability flags) ──
    transcript = _transcribe(path)

    # ── Genre summary ──
    primary_genre = genre_candidates[0]["genre"] if genre_candidates else "Other"
    genre_confidence = genre_candidates[0]["confidence"] if genre_candidates else 0

    return {
        "bpm": bpm_result,
        "key": key_result,
        "duration": round(duration, 2),
        "lufs": round(lufs, 1),
        "rms": round(energy_mean, 4),
        "rms_max": round(energy_max, 4),
        "dynamic_range": round(dynamic_range, 2),
        "energy_curve": energy_curve,
        "waveform_peaks": waveform_peaks,
        "spectral": {
            "brightness_hz": round(brightness_hz, 1),
            "spectral_contrast": round(spectral_contrast, 2),
            "spectral_flux": round(spectral_flux, 4),
            "spectral_rolloff": round(spectral_rolloff, 1),
            "spectral_bandwidth": round(spectral_bandwidth, 1),
            "zcr": round(zcr, 6),
            "mfcc_means": [round(m, 2) for m in mfcc_means],
            "freq_bands": freq_bands,
        },
        "tempo_stability": round(tempo_stability, 3),
        "onset_density": round(onset_density, 2),
        "harmonic_ratio": round(harmonic_ratio, 3),
        # Hook
        "hook_candidates": hook_candidates,
        "main_hook_candidate": main_hook,
        "hook_detection_method_version": "v2_energy_repetition_vocal",
        # Structure
        "section_candidates": section_candidates,
        "first_vocal_time": first_vocal_time,
        "first_chorus_candidate_time": section_result["first_chorus_candidate_time"],
        "intro_duration_estimate": section_result["intro_duration_estimate"],
        "section_repetition_score": section_result["section_repetition_score"],
        "structure_detection_method_version": section_result["structure_detection_method_version"],
        "structure": structure,
        # Drop
        "drop_candidates": drop_candidates,
        # Intro
        "intro_metrics": intro_metrics,
        # Transcript
        "transcript": transcript,
        # Genre
        "genre_candidates": genre_candidates,
        "primary_genre": primary_genre,
        "genre_confidence": genre_confidence,
    }


# ══════════════════════════════════════════════════════════════
# LUFS — integrated loudness (ITU-R BS.1770 approximation)
# ══════════════════════════════════════════════════════════════

def _calculate_lufs(y, sr) -> float:
    """Approximate integrated LUFS using RMS in dB with K-weighting approximation."""
    # Simple LUFS approximation — square mean of signal in dB
    # True LUFS needs K-weighting filter, but this is close enough for analysis
    rms_val = float(np.sqrt(np.mean(y ** 2)))
    if rms_val < 1e-10:
        return -70.0
    lufs_approx = 20 * np.log10(rms_val) - 0.691
    return max(-70.0, float(lufs_approx))


# ══════════════════════════════════════════════════════════════
# Spectral flux (novelty/change detection)
# ══════════════════════════════════════════════════════════════

def _spectral_flux(y, sr) -> float:
    """Average spectral flux — measures how much the spectrum changes frame to frame."""
    S = np.abs(librosa.stft(y, hop_length=512))
    flux = np.sqrt(np.mean(np.diff(S, axis=1) ** 2, axis=0))
    return float(np.mean(flux))


# ══════════════════════════════════════════════════════════════
# Frequency band energy breakdown
# ══════════════════════════════════════════════════════════════

def _frequency_band_energy(y, sr) -> dict:
    """Split audio into frequency bands and compute relative energy."""
    S = np.abs(librosa.stft(y, n_fft=2048, hop_length=512))
    freqs = librosa.fft_frequencies(sr=sr, n_fft=2048)

    bands = {
        "sub_bass": (20, 60),
        "bass": (60, 250),
        "low_mid": (250, 500),
        "mid": (500, 2000),
        "upper_mid": (2000, 4000),
        "high": (4000, 8000),
        "brilliance": (8000, 20000),
    }

    total_energy = float(np.sum(S ** 2)) + 1e-10
    result = {}

    for name, (lo, hi) in bands.items():
        mask = (freqs >= lo) & (freqs < hi)
        band_energy = float(np.sum(S[mask, :] ** 2))
        result[name] = round(band_energy / total_energy, 4)

    return result


# ══════════════════════════════════════════════════════════════
# Waveform peaks (for visual display)
# ══════════════════════════════════════════════════════════════

def _extract_waveform_peaks(y, n_points: int = 100) -> list:
    """Extract peak amplitudes for waveform visualization."""
    chunk_size = max(1, len(y) // n_points)
    peaks = []
    for i in range(min(n_points, len(y) // chunk_size)):
        chunk = y[i * chunk_size:(i + 1) * chunk_size]
        peaks.append(round(float(np.max(np.abs(chunk))), 4))
    return peaks


# ══════════════════════════════════════════════════════════════
# BPM — multi-method with validation
# ══════════════════════════════════════════════════════════════

def _detect_bpm(y, sr) -> dict:
    """
    Use multiple methods to get accurate BPM.
    Returns dict with bpm, candidates, and agreement score.
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
            if 80 <= t <= 160 and not (80 <= best <= 160):
                best = t

    # Average the agreeing candidates
    agreeing = [t for t in normalized if abs(t - best) < 8]
    final_bpm = float(np.mean(agreeing))
    agreement = len(agreeing) / len(normalized)  # 0-1

    return {
        "bpm": round(final_bpm, 1),
        "candidates": [round(t, 1) for t in normalized],
        "agreement": round(agreement, 2),
    }


# ══════════════════════════════════════════════════════════════
# Key detection — Krumhansl-Schmuckler
# ══════════════════════════════════════════════════════════════

# Key profiles — Temperley (2007) — more accurate than Krumhansl for pop/rock
_TEMPERLEY_MAJOR = np.array([5.0, 2.0, 3.5, 2.0, 4.5, 4.0, 2.0, 4.5, 2.0, 3.5, 1.5, 4.0])
_TEMPERLEY_MINOR = np.array([5.0, 2.0, 3.5, 4.5, 2.0, 4.0, 2.0, 4.5, 3.5, 2.0, 1.5, 4.0])

# Krumhansl-Kessler (classic)
_KK_MAJOR = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
_KK_MINOR = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])

_KEY_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def _detect_key(y, sr) -> dict:
    """
    Robust key detection with confidence score.
    Returns dict with key and confidence (0-1).
    """
    # Isolate harmonic content — critical for accurate key detection
    y_harm = librosa.effects.harmonic(y, margin=8)

    # Compute chromas on harmonic signal only
    chromas = {
        'cqt': librosa.feature.chroma_cqt(y=y_harm, sr=sr),
        'stft': librosa.feature.chroma_stft(y=y_harm, sr=sr),
        'cens': librosa.feature.chroma_cens(y=y_harm, sr=sr),
    }

    # Collect weighted votes: (key, confidence_weight)
    votes = []

    for name, chroma in chromas.items():
        chroma_avg = np.mean(chroma, axis=1)

        # Temperley profiles (better for modern music)
        key_t, corr_t = _best_key_from_profiles(chroma_avg, _TEMPERLEY_MAJOR, _TEMPERLEY_MINOR)
        votes.append((key_t, corr_t * 1.2))  # Temperley gets bonus weight

        # Krumhansl profiles (classic)
        key_k, corr_k = _best_key_from_profiles(chroma_avg, _KK_MAJOR, _KK_MINOR)
        votes.append((key_k, corr_k))

    # Weighted voting — sum weights for each key
    key_weights = {}
    for key, weight in votes:
        key_weights[key] = key_weights.get(key, 0) + weight

    # Sort by total weight
    sorted_keys = sorted(key_weights.items(), key=lambda x: x[1], reverse=True)
    best_key = sorted_keys[0][0]
    best_weight = sorted_keys[0][1]

    # Confidence: normalized weight. Max possible ≈ 6 methods * ~1.2 = ~7.2
    total_weight = sum(w for _, w in sorted_keys)
    confidence = best_weight / (total_weight + 1e-6) if total_weight > 0 else 0

    logger.info(f"Key detection votes: {sorted_keys[:3]}")

    return {
        "key": best_key,
        "confidence": round(min(1.0, confidence), 3),
    }


def _best_key_from_profiles(chroma_avg, major_profile, minor_profile):
    """Find best key using correlation with major/minor profiles. Returns (key_name, correlation)."""
    best_corr = -2
    best_key = "C"

    for shift in range(12):
        rotated = np.roll(chroma_avg, -shift)

        corr_major = float(np.corrcoef(rotated, major_profile)[0, 1])
        if corr_major > best_corr:
            best_corr = corr_major
            best_key = _KEY_NAMES[shift]

        corr_minor = float(np.corrcoef(rotated, minor_profile)[0, 1])
        if corr_minor > best_corr:
            best_corr = corr_minor
            best_key = _KEY_NAMES[shift] + "m"

    return best_key, best_corr


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
    harmonic_ratio: float = 0.5,
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
    if len(mfcc_means) >= 5 and abs(mfcc_means[1]) > 30:
        s += 1
    scores["Jazz"] = s

    # ── Acoustic / Singer-Songwriter ──
    s = 0
    if harmonic_ratio > 0.65:
        s += 3  # highly tonal = acoustic instruments
    if energy_mean < 0.06:
        s += 2
    if onset_density < 4:
        s += 1
    if dynamic_range > 12:
        s += 1
    if brightness_hz < 4000:
        s += 1
    if zcr < 0.06:
        s += 1  # low zero-crossing = clean/acoustic signal
    scores["Acoustic"] = s

    # ── Pop Acoustic ──
    s = 0
    if harmonic_ratio > 0.6:
        s += 2
    if 90 <= bpm <= 130:
        s += 2
    if energy_mean < 0.07 and energy_mean > 0.02:
        s += 1
    if brightness_hz > 2000 and brightness_hz < 4500:
        s += 1
    if onset_density > 1.5 and onset_density < 5:
        s += 1
    if dynamic_range > 10:
        s += 1
    scores["Pop Acoustic"] = s

    # ── Indie ──
    s = 0
    if 100 <= bpm <= 140:
        s += 1
    if harmonic_ratio > 0.5:
        s += 1
    if dynamic_range > 12:
        s += 1
    if energy_mean > 0.03 and energy_mean < 0.08:
        s += 1
    if brightness_hz > 2500 and brightness_hz < 5000:
        s += 1
    scores["Indie"] = s

    # Build reason descriptions for top genres
    genre_reasons = {
        "Hip-Hop / Rap": f"BPM {bpm:.0f}, brightness {brightness_hz:.0f}Hz, onset density {onset_density:.1f}",
        "Trap": f"BPM {bpm:.0f}, brightness {brightness_hz:.0f}Hz, rolloff {spectral_rolloff:.0f}",
        "Pop": f"BPM {bpm:.0f}, brightness {brightness_hz:.0f}Hz, dynamic range {dynamic_range:.1f}dB",
        "R&B": f"BPM {bpm:.0f}, low onset density {onset_density:.1f}, low brightness",
        "EDM / Dance": f"BPM {bpm:.0f}, high onset density {onset_density:.1f}, brightness {brightness_hz:.0f}Hz",
        "House": f"BPM {bpm:.0f}, onset density {onset_density:.1f}",
        "Techno": f"BPM {bpm:.0f}, high onset density {onset_density:.1f}, low dynamic range",
        "Drum & Bass": f"BPM {bpm:.0f}, high onset density {onset_density:.1f}",
        "Rock": f"BPM {bpm:.0f}, high brightness, dynamic range {dynamic_range:.1f}dB, ZCR {zcr:.3f}",
        "Metal": f"BPM {bpm:.0f}, very high brightness {brightness_hz:.0f}Hz, ZCR {zcr:.3f}",
        "Lo-Fi / Chill": f"BPM {bpm:.0f}, low brightness {brightness_hz:.0f}Hz, low energy",
        "Phonk": f"BPM {bpm:.0f}, spectral contrast {spectral_contrast:.1f}",
        "Reggaeton": f"BPM {bpm:.0f}, onset density {onset_density:.1f}",
        "Classical / Ambient": f"Low energy, low onset density {onset_density:.1f}, dynamic range {dynamic_range:.1f}dB",
        "Jazz": f"BPM {bpm:.0f}, dynamic range {dynamic_range:.1f}dB, bandwidth {spectral_bandwidth:.0f}",
        "Acoustic": f"Harmonic ratio {harmonic_ratio:.2f}, low energy, low ZCR {zcr:.3f}",
        "Pop Acoustic": f"Harmonic ratio {harmonic_ratio:.2f}, BPM {bpm:.0f}, moderate energy",
        "Indie": f"BPM {bpm:.0f}, harmonic ratio {harmonic_ratio:.2f}, dynamic range {dynamic_range:.1f}dB",
    }

    # Return top 5 genre candidates with confidence and reason
    sorted_genres = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    max_score = sorted_genres[0][1] if sorted_genres else 1
    if max_score < 1:
        max_score = 1

    candidates = []
    for genre_name, score in sorted_genres[:5]:
        if score >= 2:
            candidates.append({
                "genre": genre_name,
                "confidence": round(score / max_score, 3),
                "reason": genre_reasons.get(genre_name, "spectral features match"),
            })

    if not candidates:
        candidates = [{"genre": "Other", "confidence": 1.0, "reason": "no strong genre match"}]

    return candidates


# ══════════════════════════════════════════════════════════════
# Lyrics transcription — Whisper
# ══════════════════════════════════════════════════════════════

def _transcribe(path: str) -> dict:
    """
    Transcribe lyrics using faster-whisper.
    Returns rich transcript data with reliability indicators.
    """
    empty = {
        "text": None, "language": None, "confidence": 0, "segment_count": 0,
        "word_count": 0, "repeated_phrase_ratio": 0.0,
        "language_confidence": 0, "reliability_flags": ["no_model"],
    }

    model = _get_whisper()
    if model is None:
        return empty

    try:
        segments, info = model.transcribe(
            path,
            beam_size=3,
            language=None,
            vad_filter=True,
            vad_parameters=dict(
                min_silence_duration_ms=500,
                speech_pad_ms=200,
            ),
        )

        lines = []
        log_probs = []
        seg_count = 0
        for seg in segments:
            text = seg.text.strip()
            if text:
                lines.append(text)
                seg_count += 1
                if hasattr(seg, 'avg_logprob'):
                    log_probs.append(seg.avg_logprob)

        full_text = " ".join(lines).strip()

        if len(full_text) < 10:
            empty["reliability_flags"] = ["too_short"]
            return empty

        # Confidence from log probabilities
        if log_probs:
            avg_lp = float(np.mean(log_probs))
            confidence = max(0.0, min(1.0, 1.0 + avg_lp))
        else:
            confidence = 0.3

        lang = getattr(info, 'language', None)
        lang_prob = getattr(info, 'language_probability', None)
        language_confidence = round(float(lang_prob), 3) if lang_prob is not None else 0.5

        # Word count
        words = full_text.split()
        word_count = len(words)

        # Repeated phrase ratio: how much of text is repeated 2-grams
        repeated_phrase_ratio = _compute_repeated_phrase_ratio(words)

        # Reliability flags
        reliability_flags = []
        if confidence < 0.4:
            reliability_flags.append("low_confidence")
        if word_count < 20:
            reliability_flags.append("very_few_words")
        if repeated_phrase_ratio > 0.5:
            reliability_flags.append("high_repetition")
        if language_confidence < 0.5:
            reliability_flags.append("uncertain_language")
        # Check for Whisper hallucination: single word dominates
        if words:
            freq = {}
            for w in words:
                lw = w.lower().strip(".,!?;:")
                if len(lw) >= 2:
                    freq[lw] = freq.get(lw, 0) + 1
            max_freq = max(freq.values()) if freq else 0
            if max_freq > len(words) * 0.35:
                reliability_flags.append("possible_hallucination")

        logger.info(
            f"Transcribed {len(full_text)} chars, lang={lang}({language_confidence:.2f}), "
            f"conf={confidence:.2f}, segs={seg_count}, words={word_count}, "
            f"repeat_ratio={repeated_phrase_ratio:.2f}, flags={reliability_flags}"
        )

        return {
            "text": full_text,
            "language": lang,
            "confidence": round(confidence, 3),
            "segment_count": seg_count,
            "word_count": word_count,
            "repeated_phrase_ratio": round(repeated_phrase_ratio, 3),
            "language_confidence": language_confidence,
            "reliability_flags": reliability_flags,
        }

    except Exception as e:
        logger.error(f"Transcription failed: {e}")
        empty["reliability_flags"] = ["transcription_error"]
        return empty


def _compute_repeated_phrase_ratio(words: list) -> float:
    """Compute ratio of words that appear in repeated 2-grams."""
    if len(words) < 4:
        return 0.0

    bigrams = [f"{words[i]} {words[i+1]}" for i in range(len(words) - 1)]
    bigram_freq = {}
    for bg in bigrams:
        bg_lower = bg.lower()
        bigram_freq[bg_lower] = bigram_freq.get(bg_lower, 0) + 1

    repeated_count = sum(1 for bg in bigrams if bigram_freq[bg.lower()] >= 2)
    return repeated_count / len(bigrams) if bigrams else 0.0


# ══════════════════════════════════════════════════════════════
# Hook detection — improved (repetition + energy + novelty)
# ══════════════════════════════════════════════════════════════

def _find_hook_advanced(y, sr, rms, duration, vocal_curve=None) -> list:
    """
    Find hook candidates using energy + repetition + vocal presence.
    Returns list of top candidates with rich metadata.
    """
    hop_length = 512
    fps = sr / hop_length
    window_sec = 4.0
    window_frames = int(window_sec * fps)

    if len(rms) < window_frames * 2:
        return []

    # === Score 1: Energy ===
    cumsum = np.cumsum(rms)
    cumsum = np.insert(cumsum, 0, 0)
    window_sums = cumsum[window_frames:] - cumsum[:-window_frames]
    energy_scores = window_sums / (np.max(window_sums) + 1e-6)

    # === Score 2: Repetition (chroma self-similarity) ===
    chroma = librosa.feature.chroma_cqt(y=y, sr=sr, hop_length=hop_length)

    block = max(1, int(fps))
    n_blocks = chroma.shape[1] // block
    has_repetition = n_blocks >= 4

    if not has_repetition:
        return _find_hook_energy_candidates(rms, fps, duration, energy_scores, window_frames, vocal_curve)

    chroma_blocks = np.array([
        np.mean(chroma[:, i * block:(i + 1) * block], axis=1)
        for i in range(n_blocks)
    ])

    repetition_scores_blocks = np.zeros(n_blocks)
    for i in range(n_blocks):
        for j in range(n_blocks):
            if abs(i - j) > 2:
                sim = 1.0 - cosine_dist(chroma_blocks[i], chroma_blocks[j])
                if sim > 0.85:
                    repetition_scores_blocks[i] += 1

    rep_scores_full = np.zeros(len(rms))
    for i in range(n_blocks):
        start_f = i * block
        end_f = min((i + 1) * block, len(rms))
        rep_scores_full[start_f:end_f] = repetition_scores_blocks[i]

    if len(rep_scores_full) >= window_frames:
        rep_cumsum = np.cumsum(rep_scores_full)
        rep_cumsum = np.insert(rep_cumsum, 0, 0)
        rep_window = rep_cumsum[window_frames:] - rep_cumsum[:-window_frames]
        rep_window = rep_window / (np.max(rep_window) + 1e-6)
    else:
        rep_window = np.zeros_like(energy_scores)

    min_len = min(len(energy_scores), len(rep_window))
    energy_scores = energy_scores[:min_len]
    rep_window = rep_window[:min_len]

    combined = 0.4 * energy_scores + 0.6 * rep_window

    # Skip first 3 seconds and last 10%
    skip_frames = int(3.0 * fps)
    if skip_frames < len(combined):
        combined[:skip_frames] = 0
    outro_start = int(len(combined) * 0.9)
    combined[outro_start:] = 0

    # Find top 3 candidates
    candidates = []
    combined_copy = combined.copy()
    min_gap_frames = int(8.0 * fps)

    for _ in range(3):
        if np.max(combined_copy) <= 0:
            break
        best_frame = int(np.argmax(combined_copy))
        best_time = best_frame / fps

        e_score = float(energy_scores[best_frame]) if best_frame < len(energy_scores) else 0
        r_score = float(rep_window[best_frame]) if best_frame < len(rep_window) else 0
        c_score = float(combined_copy[best_frame])

        # Check vocal presence at this time
        has_vocal = False
        if vocal_curve and len(vocal_curve) > 0:
            vocal_idx = min(int(best_time), len(vocal_curve) - 1)
            has_vocal = vocal_curve[vocal_idx] > 0.3

        # Build reason string
        reasons = []
        if e_score > 0.6:
            reasons.append("high_energy")
        if r_score > 0.4:
            reasons.append("repeated_melody")
        if has_vocal:
            reasons.append("vocal_present")
        reason = "+".join(reasons) if reasons else "combined_score"

        # Confidence: based on combined score and gap to next
        confidence = min(1.0, c_score)

        candidates.append({
            "time": round(best_time, 1),
            "energy_score": round(e_score, 3),
            "repetition_score": round(r_score, 3),
            "combined_score": round(c_score, 3),
            "confidence": round(confidence, 3),
            "reason": reason,
            "based_on_energy": e_score > 0.4,
            "based_on_repetition": r_score > 0.2,
            "based_on_vocal_presence": has_vocal,
        })

        lo = max(0, best_frame - min_gap_frames)
        hi = min(len(combined_copy), best_frame + min_gap_frames)
        combined_copy[lo:hi] = 0

    # Adjust confidence: if top two are close, reduce confidence for both
    if len(candidates) >= 2:
        gap = candidates[0]["combined_score"] - candidates[1]["combined_score"]
        if gap < 0.1:
            candidates[0]["confidence"] = round(candidates[0]["confidence"] * 0.7, 3)
            candidates[1]["confidence"] = round(candidates[1]["confidence"] * 0.6, 3)

    return candidates


def _find_hook_energy_candidates(rms, fps, duration, energy_scores, window_frames, vocal_curve=None) -> list:
    """Fallback: find hook candidates by energy only."""
    if len(energy_scores) == 0:
        return []

    combined = energy_scores.copy()

    skip_frames = int(3.0 * fps)
    if skip_frames < len(combined):
        combined[:skip_frames] = 0
    outro_start = int(len(combined) * 0.9)
    combined[outro_start:] = 0

    candidates = []
    combined_copy = combined.copy()
    min_gap = int(8.0 * fps)

    for _ in range(3):
        if np.max(combined_copy) <= 0:
            break
        best_frame = int(np.argmax(combined_copy))
        best_time = best_frame / fps
        e_score = float(combined_copy[best_frame])

        has_vocal = False
        if vocal_curve and len(vocal_curve) > 0:
            vocal_idx = min(int(best_time), len(vocal_curve) - 1)
            has_vocal = vocal_curve[vocal_idx] > 0.3

        candidates.append({
            "time": round(best_time, 1),
            "energy_score": round(e_score, 3),
            "repetition_score": 0.0,
            "combined_score": round(e_score, 3),
            "confidence": round(min(1.0, e_score * 0.8), 3),  # lower confidence for energy-only
            "reason": "energy_peak" + ("+vocal_present" if has_vocal else ""),
            "based_on_energy": True,
            "based_on_repetition": False,
            "based_on_vocal_presence": has_vocal,
        })
        lo = max(0, best_frame - min_gap)
        hi = min(len(combined_copy), best_frame + min_gap)
        combined_copy[lo:hi] = 0

    return candidates


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

def _find_drop(rms, sr, duration) -> list:
    """Find energy drop candidates. Returns list of [{time, magnitude}]."""
    hop_length = 512
    fps = sr / hop_length

    window_frames = max(1, int(0.5 * fps))
    if len(rms) < window_frames * 4:
        return []

    kernel = np.ones(window_frames) / window_frames
    smoothed = np.convolve(rms, kernel, mode="valid")

    diff_window = max(1, int(2.0 * fps))
    if len(smoothed) <= diff_window:
        return []

    diffs = smoothed[diff_window:] - smoothed[:-diff_window]
    max_energy = float(np.max(rms))
    if max_energy <= 0:
        return []

    # Find top drops
    candidates = []
    diffs_copy = diffs.copy()
    min_gap = int(5.0 * fps)

    for _ in range(3):
        drop_frame = int(np.argmin(diffs_copy))
        drop_magnitude = abs(float(diffs_copy[drop_frame]))

        if drop_magnitude / max_energy < 0.3:
            break

        drop_time = (drop_frame + window_frames // 2) / fps
        candidates.append({
            "time": round(drop_time, 1),
            "magnitude": round(drop_magnitude / max_energy, 3),
        })

        lo = max(0, drop_frame - min_gap)
        hi = min(len(diffs_copy), drop_frame + min_gap)
        diffs_copy[lo:hi] = 0

    return candidates


# ══════════════════════════════════════════════════════════════
# Intro assessment
# ══════════════════════════════════════════════════════════════

def _assess_intro(rms, sr, duration, vocal_curve=None) -> dict:
    """
    Assess intro quality.
    Returns energy metrics + vocal presence + transition strength.
    """
    hop_length = 512
    fps = sr / hop_length

    base = {
        "intro_energy": 0, "main_energy": 0, "ratio": 1.0,
        "intro_vocal_presence": False, "intro_transition_strength": 0.0,
    }

    if duration < 15 or len(rms) < int(8.0 * fps):
        return base

    intro_frames = int(8.0 * fps)
    intro_energy = float(np.mean(rms[:intro_frames]))

    start = int(len(rms) * 0.1)
    end = int(len(rms) * 0.9)
    if end <= start:
        base["intro_energy"] = round(intro_energy, 4)
        return base

    main_energy = float(np.median(rms[start:end]))
    ratio = intro_energy / (main_energy + 1e-10)

    # Vocal presence in intro (first 8 seconds)
    intro_vocal_presence = False
    if vocal_curve and len(vocal_curve) >= 8:
        intro_vocal_avg = float(np.mean(vocal_curve[:8]))
        intro_vocal_presence = intro_vocal_avg > 0.25

    # Transition strength: energy jump from intro to post-intro
    # Measure the energy ratio between last 2s of intro and first 2s after intro
    post_intro_start = intro_frames
    post_intro_end = min(int(12.0 * fps), len(rms))
    last_intro_start = max(0, intro_frames - int(2.0 * fps))
    if post_intro_end > post_intro_start and last_intro_start < intro_frames:
        last_intro_e = float(np.mean(rms[last_intro_start:intro_frames]))
        post_intro_e = float(np.mean(rms[post_intro_start:post_intro_end]))
        if last_intro_e > 0:
            transition = (post_intro_e - last_intro_e) / (last_intro_e + 1e-10)
            transition_strength = min(1.0, max(0.0, transition))
        else:
            transition_strength = 1.0 if post_intro_e > 0 else 0.0
    else:
        transition_strength = 0.0

    return {
        "intro_energy": round(intro_energy, 4),
        "main_energy": round(main_energy, 4),
        "ratio": round(ratio, 3),
        "intro_vocal_presence": intro_vocal_presence,
        "intro_transition_strength": round(transition_strength, 3),
    }



# (Hit score calculation moved to NestJS rule engine for explainability)


# ══════════════════════════════════════════════════════════════
# Vocal presence detection — harmonic energy in vocal range
# ══════════════════════════════════════════════════════════════

def _detect_vocal_presence(y, sr, hop_length=512) -> dict:
    """
    Detect where vocals are present using harmonic energy in vocal frequency range (300-3000 Hz).
    Returns {
        first_vocal_time: float or None,
        vocal_presence_curve: list[float] (1-second resolution, 0-1 normalized),
    }
    """
    y_harm = librosa.effects.harmonic(y, margin=4)

    S = np.abs(librosa.stft(y_harm, n_fft=2048, hop_length=hop_length))
    freqs = librosa.fft_frequencies(sr=sr, n_fft=2048)

    # Vocal range mask (300-3000 Hz)
    vocal_mask = (freqs >= 300) & (freqs <= 3000)
    vocal_energy_frames = np.sum(S[vocal_mask, :] ** 2, axis=0)

    # Aggregate to ~1 second blocks
    fps = sr / hop_length
    block = max(1, int(fps))
    n_blocks = len(vocal_energy_frames) // block
    if n_blocks == 0:
        return {"first_vocal_time": None, "vocal_presence_curve": []}

    block_energies = []
    for i in range(n_blocks):
        e = float(np.mean(vocal_energy_frames[i * block:(i + 1) * block]))
        block_energies.append(e)

    max_e = max(block_energies) if block_energies else 1.0
    if max_e < 1e-10:
        return {"first_vocal_time": None, "vocal_presence_curve": [0.0] * n_blocks}

    normalized = [round(e / max_e, 3) for e in block_energies]

    # Detect first vocal: first block where energy > 30% of max vocal energy
    threshold = 0.3
    first_vocal_time = None
    for i, val in enumerate(normalized):
        if val > threshold:
            first_vocal_time = round(float(i), 1)  # seconds (1 block ≈ 1 sec)
            break

    return {
        "first_vocal_time": first_vocal_time,
        "vocal_presence_curve": normalized,
    }


# ══════════════════════════════════════════════════════════════
# Sections detection
# ══════════════════════════════════════════════════════════════

def _detect_sections(rms, sr, duration, y=None) -> list:
    """
    Detect sections using energy + spectral similarity (repetition detection).
    Similar-sounding loud parts = chorus, non-repeating = verse, quiet = bridge/intro/outro.
    """
    hop_length = 512
    fps = sr / hop_length
    window = max(1, int(fps))

    if len(rms) < window * 3:
        return [{"start": 0, "end": round(duration, 1), "type": "full", "energy": round(float(np.mean(rms)), 3)}]

    n_secs = len(rms) // window
    sec_energy = [float(np.mean(rms[i * window:(i + 1) * window])) for i in range(n_secs)]

    if not sec_energy:
        return []

    # ── Step 1: Segment by energy changes ──
    median_e = np.median(sec_energy)
    high_thresh = median_e * 1.25
    low_thresh = median_e * 0.65

    raw_segments = []
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
            if current_type is not None and i > int(start):
                raw_segments.append({
                    "start_sec": int(start),
                    "end_sec": i,
                    "energy_type": current_type,
                    "energy": float(np.mean(sec_energy[int(start):i])),
                })
            current_type = stype
            start = float(i)

    if current_type is not None and int(start) < len(sec_energy):
        raw_segments.append({
            "start_sec": int(start),
            "end_sec": n_secs,
            "energy_type": current_type,
            "energy": float(np.mean(sec_energy[int(start):])),
        })

    # Merge very short segments (< 3 sec) into neighbors
    merged = []
    for seg in raw_segments:
        seg_dur = seg["end_sec"] - seg["start_sec"]
        if seg_dur < 3 and merged:
            merged[-1]["end_sec"] = seg["end_sec"]
            merged[-1]["energy"] = (merged[-1]["energy"] + seg["energy"]) / 2
        else:
            merged.append(seg)
    raw_segments = merged if merged else raw_segments

    # ── Step 2: Compute spectral fingerprints per segment ──
    seg_fingerprints = []
    if y is not None and len(raw_segments) > 1:
        try:
            chroma = librosa.feature.chroma_cqt(y=y, sr=sr, hop_length=hop_length)
            mfcc_full = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=12, hop_length=hop_length)

            for seg in raw_segments:
                s_frame = seg["start_sec"] * window
                e_frame = min(seg["end_sec"] * window, chroma.shape[1], mfcc_full.shape[1])
                if e_frame <= s_frame:
                    seg_fingerprints.append(None)
                    continue
                c_mean = np.mean(chroma[:, s_frame:e_frame], axis=1)
                m_mean = np.mean(mfcc_full[:, s_frame:e_frame], axis=1)
                fp = np.concatenate([c_mean, m_mean])
                seg_fingerprints.append(fp / (np.linalg.norm(fp) + 1e-10))
        except Exception:
            seg_fingerprints = [None] * len(raw_segments)
    else:
        seg_fingerprints = [None] * len(raw_segments)

    # ── Step 3: Find repeating segments (chorus = loud + repeats) ──
    similarity_threshold = 0.88
    repeat_groups = {}  # group_id -> list of segment indices

    for i, fp_i in enumerate(seg_fingerprints):
        if fp_i is None:
            continue
        found_group = False
        for gid, members in repeat_groups.items():
            ref_fp = seg_fingerprints[members[0]]
            if ref_fp is not None:
                sim = float(np.dot(fp_i, ref_fp))
                if sim > similarity_threshold:
                    members.append(i)
                    found_group = True
                    break
        if not found_group:
            repeat_groups[len(repeat_groups)] = [i]

    # Mark which segments repeat (appear 2+ times in a group)
    repeating_indices = set()
    for gid, members in repeat_groups.items():
        if len(members) >= 2:
            for idx in members:
                repeating_indices.add(idx)

    # Build index→group mapping
    idx_to_group = {}
    for gid, members in repeat_groups.items():
        for idx in members:
            idx_to_group[idx] = gid

    # ── Step 4: Assign labels ──
    sections = []
    chorus_count = 0
    verse_count = 0

    for i, seg in enumerate(raw_segments):
        s = seg["start_sec"]
        e = seg["end_sec"]
        etype = seg["energy_type"]
        is_repeat = i in repeating_indices

        # Label logic
        if s < duration * 0.08 and etype in ("quiet", "mid"):
            label = "intro"
        elif e >= n_secs - 1 and etype in ("quiet", "mid") and (e - s) < duration * 0.15:
            label = "outro"
        elif etype == "loud" and is_repeat:
            chorus_count += 1
            label = "chorus"
        elif etype == "loud" and not is_repeat:
            label = "chorus" if chorus_count == 0 else "bridge"
            chorus_count += 1
        elif etype == "quiet" and s > duration * 0.2:
            label = "bridge"
        elif etype == "mid" and is_repeat:
            label = "chorus"
            chorus_count += 1
        else:
            verse_count += 1
            label = "verse"

        # Confidence per section: based on energy clarity and fingerprint match
        sec_conf = 0.5
        if etype == "loud" and is_repeat:
            sec_conf = 0.85  # loud + repeating = very confident chorus
        elif etype == "loud":
            sec_conf = 0.7
        elif s < duration * 0.08:
            sec_conf = 0.8  # intro position is reliable
        elif e >= n_secs - 1:
            sec_conf = 0.75  # outro position is fairly reliable
        elif is_repeat:
            sec_conf = 0.65
        else:
            sec_conf = 0.5

        sections.append({
            "label": label,
            "start": round(float(s), 1),
            "end": round(float(e), 1),
            "energy": round(seg["energy"], 3),
            "confidence": round(sec_conf, 2),
            "fingerprint_group": idx_to_group.get(i, -1),
        })

    # Compute summary fields
    first_chorus_time = None
    intro_duration = 0.0
    for sec in sections:
        if sec["label"] == "chorus" and first_chorus_time is None:
            first_chorus_time = sec["start"]
        if sec["label"] == "intro":
            intro_duration = sec["end"] - sec["start"]

    # Section repetition score: fraction of sections that belong to a repeating group
    repeating_count = sum(1 for idx in range(len(raw_segments)) if idx in repeating_indices)
    section_rep_score = repeating_count / max(1, len(raw_segments))

    return {
        "sections": sections,
        "first_chorus_candidate_time": first_chorus_time,
        "intro_duration_estimate": round(intro_duration, 1),
        "section_repetition_score": round(section_rep_score, 3),
        "structure_detection_method_version": "v2_energy_spectral_fingerprint",
    }


def _guess_suffix(filename: str) -> str:
    ext = os.path.splitext(filename)[1].lower()
    return ext if ext in (".mp3", ".wav", ".flac", ".ogg", ".m4a", ".aac", ".wma") else ".mp3"


# ── Run ──────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", "8001"))
    uvicorn.run("main:app", host="0.0.0.0", port=port, log_level="info")
