# Tone Generator

Generates pure sinusoidal tones with specified frequency, duration, and level.

## Description

A pure tone is a sound with a single frequency component. This generator creates
sinusoidal waveforms with precise frequency control and optional onset/offset ramps
to prevent spectral splatter and click artifacts.

## Parameters

- **freq_hz** (Hz): Frequency of the tone (20-20000 Hz)
- **dur_ms** (ms): Duration of the tone (1-10000 ms)
- **level_db** (dB SPL): Sound pressure level (0-100 dB)
- **ramp_ms** (ms): Duration of onset/offset ramps (0-100 ms), default: 5 ms

## Usage Example
```json
{
  "generator": "tone",
  "version": "1.0.0",
  "parameters": {
    "freq_hz": 1000,
    "dur_ms": 50,
    "level_db": 60,
    "ramp_ms": 5
  }
}
```

## Technical Details

**Waveform generation:**
- Uses `sin(2*pi*f*t)` for pure sinusoidal tone
- Sample-accurate timing based on sampling rate

**Ramping:**
- Half-cosine ramps: `0.5 * (1 - cos(pi*t/T))`
- Applied symmetrically to onset and offset
- Prevents spectral splatter and acoustic clicks

**Calibration:**
- Default: 100 dB SPL = amplitude 1.0
- Can be overridden via context.calibration

## Testing
```matlab
cd +generators/+audio/+tone
test_generator
```

## Version History

- **1.0.0** (2025-01-15): Initial implementation