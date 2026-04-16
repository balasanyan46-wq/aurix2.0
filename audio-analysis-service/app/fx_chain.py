"""
Build Pedalboard FX chain from preset parameters.

Chain order (standard vocal production):
  HighPass → Compressor → De-Esser → EQ → Reverb → Limiter
"""

from pedalboard import (
    Pedalboard,
    HighpassFilter,
    Compressor,
    LowShelfFilter,
    PeakFilter,
    HighShelfFilter,
    Reverb,
    Limiter,
)


def build_chain(preset: dict) -> Pedalboard:
    """Build a Pedalboard FX chain from preset dict."""

    plugins = []

    # 1. High-pass filter — remove rumble
    plugins.append(HighpassFilter(cutoff_frequency_hz=preset["highpass_hz"]))

    # 2. Compressor — tame dynamics
    comp = preset["compressor"]
    plugins.append(Compressor(
        threshold_db=comp["threshold_db"],
        ratio=comp["ratio"],
        attack_ms=comp["attack_ms"],
        release_ms=comp["release_ms"],
    ))

    # 3. De-esser — tame sibilance (compressor on high freq band)
    # Pedalboard doesn't have a dedicated de-esser, but we can use
    # a narrow PeakFilter with negative gain as a static de-ess
    de_ess = preset.get("de_esser")
    if de_ess:
        plugins.append(PeakFilter(
            cutoff_frequency_hz=de_ess["freq_hz"],
            gain_db=-3.0,  # gentle static de-ess
            q=3.0,
        ))

    # 4. EQ — shape the tone
    eq = preset["eq"]
    plugins.append(LowShelfFilter(
        cutoff_frequency_hz=eq["low_shelf_hz"],
        gain_db=eq["low_shelf_gain_db"],
    ))
    plugins.append(PeakFilter(
        cutoff_frequency_hz=eq["mid_hz"],
        gain_db=eq["mid_gain_db"],
        q=eq["mid_q"],
    ))
    plugins.append(HighShelfFilter(
        cutoff_frequency_hz=eq["high_shelf_hz"],
        gain_db=eq["high_shelf_gain_db"],
    ))

    # 5. Reverb — add space
    rev = preset["reverb"]
    plugins.append(Reverb(
        room_size=rev["room_size"],
        damping=rev["damping"],
        wet_level=rev["wet_level"],
        dry_level=rev["dry_level"],
    ))

    # 6. Limiter — safety ceiling
    plugins.append(Limiter(threshold_db=preset["limiter_db"]))

    return Pedalboard(plugins)
