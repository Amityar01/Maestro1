# Audio-Only Engine

Executes audio experiments using DAQ hardware with precise timing and hardware triggering.

## Features

- **Hardware timing**: Sample-accurate playback via DAQ
- **Multiple channels**: Configurable analog outputs
- **Hardware triggers**: Digital output for sync with recording equipment
- **Multiple presentations per trial**: Handles overlapping/sequential audio
- **Response collection**: Keyboard responses during playback

## Requirements

- MATLAB Data Acquisition Toolbox
- Compatible DAQ hardware (National Instruments, etc.)

## Configuration
```json
{
  "sampling_rate_hz": 192000,
  "vendor": "ni",
  "device_id": "Dev1",
  "audio_channels": ["ao0", "ao1"],
  "trigger_channel": "port0/line0"
}
```

## Hardware Setup

1. Connect audio outputs to amplifier/speakers
2. (Optional) Connect trigger line to recording system
3. Test DAQ configuration: `daq.getDevices()`

## Testing Without Hardware

For testing without DAQ hardware, create a simulation mode...