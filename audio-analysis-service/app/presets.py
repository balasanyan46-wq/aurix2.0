"""
Vocal processing presets — each defines the full FX chain parameters.

Values tuned for modern vocal production:
- HIT: radio-ready vocal (Drake, The Weeknd)
- SOFT: intimate vocal (Billie Eilish, Frank Ocean)
- AGGRESSIVE: hard vocal (Travis Scott, Playboi Carti)
"""

HIT_PRESET = {
    "name": "hit",
    "highpass_hz": 80,
    "compressor": {
        "threshold_db": -18.0,
        "ratio": 3.5,
        "attack_ms": 5.0,
        "release_ms": 80.0,
    },
    "eq": {
        "low_shelf_hz": 200,
        "low_shelf_gain_db": -2.0,
        "mid_hz": 2500,
        "mid_gain_db": 2.5,
        "mid_q": 1.2,
        "high_shelf_hz": 8000,
        "high_shelf_gain_db": 4.0,
    },
    "de_esser": {
        "freq_hz": 6500,
        "threshold_db": -20.0,
        "ratio": 4.0,
    },
    "reverb": {
        "room_size": 0.25,
        "damping": 0.7,
        "wet_level": 0.12,
        "dry_level": 1.0,
    },
    "limiter_db": -1.0,
    "target_lufs": -14.0,
}

SOFT_PRESET = {
    "name": "soft",
    "highpass_hz": 60,
    "compressor": {
        "threshold_db": -22.0,
        "ratio": 2.5,
        "attack_ms": 10.0,
        "release_ms": 120.0,
    },
    "eq": {
        "low_shelf_hz": 200,
        "low_shelf_gain_db": -1.0,
        "mid_hz": 3000,
        "mid_gain_db": 1.5,
        "mid_q": 1.0,
        "high_shelf_hz": 10000,
        "high_shelf_gain_db": 2.5,
    },
    "de_esser": {
        "freq_hz": 7000,
        "threshold_db": -18.0,
        "ratio": 3.0,
    },
    "reverb": {
        "room_size": 0.45,
        "damping": 0.5,
        "wet_level": 0.22,
        "dry_level": 1.0,
    },
    "limiter_db": -1.5,
    "target_lufs": -16.0,
}

AGGRESSIVE_PRESET = {
    "name": "aggressive",
    "highpass_hz": 100,
    "compressor": {
        "threshold_db": -14.0,
        "ratio": 6.0,
        "attack_ms": 2.0,
        "release_ms": 50.0,
    },
    "eq": {
        "low_shelf_hz": 250,
        "low_shelf_gain_db": -3.0,
        "mid_hz": 2000,
        "mid_gain_db": 3.5,
        "mid_q": 1.5,
        "high_shelf_hz": 7000,
        "high_shelf_gain_db": 5.0,
    },
    "de_esser": {
        "freq_hz": 6000,
        "threshold_db": -22.0,
        "ratio": 5.0,
    },
    "reverb": {
        "room_size": 0.15,
        "damping": 0.8,
        "wet_level": 0.08,
        "dry_level": 1.0,
    },
    "limiter_db": -0.5,
    "target_lufs": -11.0,
}

PRESETS = {
    "hit": HIT_PRESET,
    "soft": SOFT_PRESET,
    "aggressive": AGGRESSIVE_PRESET,
}

def get_preset(name: str) -> dict:
    return PRESETS.get(name, HIT_PRESET)
