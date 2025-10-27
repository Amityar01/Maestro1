# Maestro Data Flow v1.0

This document describes how data moves through the Maestro system, from initial configuration to final output.

## Table of Contents
1. [Overview](#overview)
2. [Initialization Phase](#initialization-phase)
3. [Experiment Definition Phase](#experiment-definition-phase)
4. [Compilation Phase](#compilation-phase)
5. [Execution Phase](#execution-phase)
6. [Logging and Output](#logging-and-output)
7. [Data Flow Diagrams](#data-flow-diagrams)

---

## Overview

The Maestro system processes data through five distinct phases:
```
1. INITIALIZATION
   └─> Discover plugins, load schemas

2. EXPERIMENT DEFINITION
   └─> User creates/edits JSON specifications

3. COMPILATION
   └─> Build trials, generate stimuli, validate

4. EXECUTION
   └─> Run experiment, control hardware, log events

5. OUTPUT
   └─> Save data, generate reports
```

Each phase has clear inputs and outputs, with validation at every boundary.

---

## Initialization Phase

### Purpose
Discover all available plugins and prepare the runtime environment.

### Process Flow
```
System Startup
     ↓
[Scan +generators directory]
     ↓
For each subdirectory:
    - Find schema.json
    - Parse and validate schema
    - Locate generator.m
    - Create function handle
    - Register in generators map
     ↓
[Scan +builders directory]
     ↓
(Same process for builders)
     ↓
[Scan +engines directory]
     ↓
(Same process for engines)
     ↓
[Load stimulus library]
     ↓
Parse stimuli/library.json
Load individual stimulus specs
     ↓
[Scan instances directory]
     ↓
Parse all .json files
Register by instance_id
     ↓
[Scan experiments directory]
     ↓
Parse all .json files
Register by experiment_id
     ↓
[Create MaestroContext]
     ↓
Ready for use
```

### Data Structures Created
```matlab
% MaestroContext.generators
generators('tone') = struct(...
    'schema', parsed_schema, ...
    'generate_func', @generators.audio.tone.generate, ...
    'path', '/path/to/+generators/+audio/+tone', ...
    'schema_file', '/path/to/schema.json', ...
    'version', '1.0.0' ...
);

% MaestroContext.builders
builders('oddball') = struct(...
    'schema', parsed_schema, ...
    'build_func', @builders.oddball.build, ...
    'path', '/path/to/+builders/+oddball', ...
    'version', '1.0.0' ...
);

% MaestroContext.engines
engines('audio_only') = struct(...
    'schema', parsed_schema, ...
    'execute_func', @engines.audio_only.execute, ...
    'path', '/path/to/+engines/+audio_only', ...
    'version', '1.0.0' ...
);
```

### Validation at This Stage

- All schema.json files are valid JSON
- All schemas conform to Maestro schema standard
- All referenced implementation files exist
- All function handles can be created
- No duplicate generator/builder/engine types

### Error Handling

If any plugin fails to load:
- Log warning with details
- Continue loading other plugins
- Mark plugin as unavailable

Critical errors (no plugins found):
- Display error message
- Exit initialization

---

## Experiment Definition Phase

### Purpose
User creates or modifies experiment specifications.

### Process Flow (GUI)
```
User opens GUI
     ↓
[Browse Block Templates]
     ↓
Available builders displayed
User selects: "oddball"
     ↓
[Load Builder Schema]
     ↓
GUI auto-generates parameter fields
from schema.required_inputs and
schema.optional_inputs
     ↓
[User Edits Parameters]
     ↓
User sets:
  - n_trials: 200
  - deviant_probability: 0.15
  - standard_stimulus: {...}
  - deviant_stimulus: {...}
  - iti_min_sec: 1.2
  - iti_max_sec: 1.8
     ↓
[User Saves Block Instance]
     ↓
Validate parameters against schema
Create instance JSON
Save to instances/my_oddball.json
     ↓
[Add to Experiment Playlist]
     ↓
User adds multiple blocks
Arranges order
Sets inter-block delays
     ↓
[Save Experiment]
     ↓
Create experiment JSON
Save to experiments/my_session.json
```

### Data Created

**Block Instance** (instances/my_oddball.json):
```json
{
  "instance_id": "my_oddball",
  "builder_type": "oddball",
  "builder_version": "1.0.0",
  "parameters": {
    "n_trials": 200,
    "deviant_probability": 0.15,
    "standard_stimulus": {
      "generator": "tone",
      "version": "1.0.0",
      "parameters": {"freq_hz": 1000, "dur_ms": 50, "level_db": 60}
    },
    "deviant_stimulus": {
      "generator": "tone",
      "version": "1.0.0",
      "parameters": {"freq_hz": 2000, "dur_ms": 50, "level_db": 60}
    },
    "iti_min_sec": 1.2,
    "iti_max_sec": 1.8
  },
  "metadata": {...}
}
```

**Experiment** (experiments/my_session.json):
```json
{
  "experiment_id": "my_session",
  "global_settings": {
    "engine_type": "audio_only",
    "sampling_rate_hz": 192000,
    ...
  },
  "sequence": [
    {"block_instance": "instances/my_oddball.json", "order": 1}
  ],
  ...
}
```

### Validation at This Stage

- Parameters match builder schema requirements
- All required parameters present
- All values satisfy constraints
- Stimulus specifications reference valid generators
- References resolve to existing files

---

## Compilation Phase

### Purpose
Transform high-level specifications into executable data structures.

### Process Flow (Audio-Only Engine)
```
experiment = load('experiments/my_session.json')
     ↓
[Load Global Settings]
     ↓
engine_type = 'audio_only'
sampling_rate = 192000
     ↓
FOR EACH block in experiment.sequence:
     ↓
  [Load Block Instance]
       ↓
  instance = load('instances/my_oddball.json')
       ↓
  [Get Builder]
       ↓
  builder = context.builders('oddball')
       ↓
  [Validate Instance Against Schema]
       ↓
  Check all required parameters
  Check constraints
       ↓
  [Call Builder]
       ↓
  trial_list = builder.build_func(instance, context)
       ↓
  Returns: Array of trial structs
       ↓
  FOR EACH trial in trial_list:
       ↓
    FOR EACH presentation in trial.presentations:
         ↓
      [Resolve Randomization]
           ↓
      If parameters have randomization specs:
        - Apply random_uniform/gaussian/choice
        - Use rng_seed if specified
           ↓
      [Get Generator]
           ↓
      stim_spec = presentation.stimulus_spec
      generator = context.generators(stim_spec.generator)
           ↓
      [Validate Parameters Against Schema]
           ↓
      Check all required parameters
      Check constraints
           ↓
      [Call Generator]
           ↓
      output_spec = generator.generate_func(stim_spec.parameters, context)
           ↓
      Returns: Struct with .data (waveform)
           ↓
      [Store Output]
           ↓
      presentation.output = output_spec
           ↓
  [Arrange Waveforms in Time]
       ↓
  For each trial:
    - Calculate trial start time
    - For each presentation:
      - Calculate absolute onset time
      - Insert waveform at correct sample
    - Add ITI (silence)
    - Generate TTL pulse at each onset
       ↓
  [Concatenate All Trials]
       ↓
  Create single long waveforms:
    - AO_waveform (audio channel)
    - DO_waveform (TTL channel)
       ↓
  [Create Event Log]
       ↓
  For each presentation:
    - Log: sample_index, timestamp, event_name, trial_info
       ↓
END FOR (blocks)
     ↓
[Compilation Complete]
     ↓
Data structures ready for execution:
  - AO_waveform (Nx1 samples)
  - DO_waveform (Nx1 TTL)
  - trial_metadata_table
  - event_log_table
```

### Data Structures After Compilation
```matlab
% Compiled waveforms
AO_waveform = [N x 1 double];  % Audio samples
DO_waveform = [N x 1 double];  % TTL pulses (0 or 1)

% Trial metadata
trial_metadata = table(...
    'trial_id', ...
    'trial_num', ...
    'block_id', ...
    'trial_type', ...
    'is_deviant', ...
    'iti_sec', ...
    ...
);

% Event log
event_log = table(...
    'sample_index', ...   % Absolute sample position
    'time_sec', ...       % Time in seconds
    'event_type', ...     % 'presentation_onset', 'trial_start', etc.
    'trial_id', ...       % Which trial
    'presentation_id', ... % Which presentation
    'stimulus_info', ...  % Generator type, parameters
    ...
);
```

### Validation at This Stage

- All generators produce valid output specs
- All waveforms have correct sampling rate
- No timing conflicts (overlapping stimuli if not intended)
- Total duration within reasonable limits
- Memory usage acceptable

---

## Execution Phase

### Process Flow (Audio-Only Engine)
```
[Hardware Initialization]
     ↓
Initialize DAQ session:
  - Set sampling rate
  - Configure channels (AO, DO, AI)
  - Test hardware connection
     ↓
[Pre-Execution Validation]
     ↓
Check:
  - Hardware responding
  - Output directory writable
  - Sufficient disk space
  - Waveforms within hardware limits
     ↓
[Start Execution]
     ↓
timestamp_start = datetime('now')
     ↓
Write waveforms to DAQ:
  output_data = [AO_waveform, DO_waveform]
     ↓
[Hardware-Timed Playback]
     ↓
DAQ plays waveforms with precise timing
DAQ records loopback on AI channel
     ↓
This is BLOCKING - waits until complete
     ↓
[Execution Complete]
     ↓
loopback_data = returned from DAQ
timestamp_end = datetime('now')
     ↓
[Hardware Cleanup]
     ↓
Release DAQ session
Clear hardware resources
     ↓
[Execution Phase Complete]
```

### Process Flow (Audiovisual Engine)
```
[Hardware Initialization]
     ↓
Initialize Psychtoolbox:
  - Open window on specified screen
  - Set background color
  - Get screen properties
  - Calculate visual angle conversions
     ↓
Initialize DAQ:
  - Set sampling rate
  - Configure channels
     ↓
[Pre-Cache Audio]
     ↓
Find all unique audio stimuli
For each unique stimulus:
  - Generate waveform
  - Store in cache (Map: spec_hash -> waveform)
     ↓
[Real-Time Loop]
     ↓
FOR EACH trial:
     ↓
  timestamp_trial_start = GetSecs()
       ↓
  FOR EACH presentation in trial:
       ↓
    Get output_spec for this presentation
         ↓
    IF modality == 'audio':
      - Retrieve cached waveform
      - Queue to DAQ
         ↓
    IF modality == 'visual':
      - Interpret draw_commands
      - Call draw_visual_stimulus(window, output_spec.data)
         ↓
    IF modality == 'multimodal':
      - Draw visual stimulus
      - Retrieve cached audio
      - Synchronize
         ↓
    [Synchronize Onset]
         ↓
    vbl = Screen('Flip', window)
    readwrite(daq_session, audio_data)
         ↓
    Log event:
      - vbl timestamp (visual onset)
      - audio start sample
      - presentation info
         ↓
    [Wait for Duration]
         ↓
    WaitSecs(duration)
         ↓
  END FOR (presentations)
       ↓
  [Inter-Trial Interval]
       ↓
  Clear screen (or show fixation)
  WaitSecs(trial.iti_sec)
       ↓
END FOR (trials)
     ↓
[Cleanup]
     ↓
Close Psychtoolbox window
Release DAQ
     ↓
[Execution Complete]
```

### Real-Time Logging

During execution, events are logged immediately:
```matlab
% Event structure
event = struct(...
    'timestamp', datetime('now'), ...
    'vbl_timestamp', vbl, ...           % Psychtoolbox timestamp
    'sample_index', current_sample, ... % DAQ sample position
    'trial_id', trial.trial_id, ...
    'presentation_id', pres.presentation_id, ...
    'event_type', 'presentation_onset', ...
    'stimulus_info', pres.stimulus_spec ...
);

% Append to log
event_log = [event_log; event];
```

---

## Logging and Output

### Purpose
Save all data, logs, and metadata for analysis.

### Directory Structure
```
data/
  <subject_id>/
    <session_id>/
      config/
        experiment.json           ← Copy of experiment spec
        block_001_instance.json   ← Copy of block instance
        block_002_instance.json
        ...
      waveforms/
        AO_commanded.wav          ← Audio output waveform
        DO_ttl.wav                ← TTL waveform
        AI_loopback.wav           ← Recorded loopback
      logs/
        trial_log.csv             ← Trial-by-trial metadata
        event_log.csv             ← Sample-accurate events
        execution_log.txt         ← Text log of execution
      metadata/
        hardware_info.json        ← DAQ settings, screen info
        timing_analysis.json      ← Timing statistics
        checksums.json            ← Data integrity hashes
      analysis/
        (empty, for user analysis)
```

### Output Files

**trial_log.csv:**
```csv
trial_id,trial_num,block_id,trial_type,is_deviant,iti_sec,start_sample,end_sample
block1_trial_0001,1,block_001,standard,false,1.234,1,9600
block1_trial_0002,2,block_001,deviant,true,1.567,12000,20400
...
```

**event_log.csv:**
```csv
sample_index,time_sec,event_type,trial_id,presentation_id,generator,stimulus_params
1,0.000,presentation_onset,block1_trial_0001,pres_1,tone,"{""freq_hz"":1000,...}"
9601,0.050,presentation_offset,block1_trial_0001,pres_1,tone,""
12000,0.0625,presentation_onset,block1_trial_0002,pres_1,tone,"{""freq_hz"":2000,...}"
...
```

**execution_log.txt:**
```
[2025-01-15 14:30:00] Experiment started: my_session
[2025-01-15 14:30:00] Engine: audio_only v1.0.0
[2025-01-15 14:30:00] Sampling rate: 192000 Hz
[2025-01-15 14:30:01] Block 1/3: my_oddball (200 trials)
[2025-01-15 14:30:01]   Building trial list...
[2025-01-15 14:30:01]   Generating stimuli...
[2025-01-15 14:30:02]   Compiling waveforms...
[2025-01-15 14:30:03]   Waveform duration: 425.3 sec
[2025-01-15 14:30:03] Hardware initialization...
[2025-01-15 14:30:03] Starting playback...
[2025-01-15 14:37:08] Playback complete
[2025-01-15 14:37:08] Saving data...
[2025-01-15 14:37:10] Block complete
[2025-01-15 14:37:40] Block 2/3: ...
...
[2025-01-15 15:15:32] Experiment complete
[2025-01-15 15:15:32] Total duration: 45.5 minutes
[2025-01-15 15:15:32] Total trials: 600
[2025-01-15 15:15:32] Data saved: data/M042/session_003/
```

### Metadata Files

**hardware_info.json:**
```json
{
  "daq": {
    "device_id": "Dev1",
    "vendor": "National Instruments",
    "model": "USB-6212",
    "driver_version": "20.0.0",
    "sampling_rate_hz": 192000,
    "actual_rate_hz": 192000.0,
    "channels": {
      "audio_out": "ao0",
      "ttl_out": "port0/line0",
      "loopback_in": "ai0"
    }
  },
  "display": {
    "screen_number": 1,
    "resolution_px": [1920, 1080],
    "refresh_rate_hz": 60,
    "physical_size_cm": [52, 29],
    "viewing_distance_cm": 60,
    "pixels_per_degree": [38.4, 38.4]
  },
  "computer": {
    "os": "Windows 10",
    "matlab_version": "R2023b",
    "hostname": "LAB-PC-01"
  },
  "timestamp": "2025-01-15T14:30:00Z"
}
```

**timing_analysis.json:**
```json
{
  "audio_engine": {
    "compilation_time_sec": 2.34,
    "execution_time_sec": 425.3,
    "expected_duration_sec": 425.0,
    "timing_error_ms": 0.8,
    "sample_accurate": true
  },
  "audiovisual_engine": {
    "frames_total": 2556,
    "frames_dropped": 0,
    "mean_frame_duration_ms": 16.67,
    "std_frame_duration_ms": 0.12,
    "max_jitter_ms": 0.8
  },
  "trial_statistics": {
    "mean_iti_sec": 1.45,
    "std_iti_sec": 0.18,
    "min_iti_sec": 1.20,
    "max_iti_sec": 1.80
  }
}
```

---

## Data Flow Diagrams

### High-Level Flow
```
┌─────────────────────────────────────────────────┐
│                                                 │
│  USER INPUT (JSON Specifications)               │
│                                                 │
│  • Stimulus specs                               │
│  • Block instances                              │
│  • Experiments                                  │
│                                                 │
└─────────────┬───────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│                                                 │
│  MAESTRO CONTEXT (Discovery & Validation)       │
│                                                 │
│  • Load plugins                                 │
│  • Validate schemas                             │
│  • Create registry                              │
│                                                 │
└─────────────┬───────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│                                                 │
│  COMPILATION (Trial Generation)                 │
│                                                 │
│  • Build trial lists (Builders)                 │
│  • Generate stimuli (Generators)                │
│  • Arrange in time                              │
│                                                 │
└─────────────┬───────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│                                                 │
│  EXECUTION (Hardware Control)                   │
│                                                 │
│  • Engine-specific execution                    │
│  • Real-time logging                            │
│  • Hardware synchronization                     │
│                                                 │
└─────────────┬───────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│                                                 │
│  OUTPUT (Data & Logs)                           │
│                                                 │
│  • Waveforms (WAV files)                        │
│  • Logs (CSV, JSON, TXT)                        │
│  • Metadata                                     │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Detailed: Stimulus Generation Flow
```
Stimulus Specification (JSON)
         │
         ├─ generator: "tone"
         ├─ version: "1.0.0"
         └─ parameters:
              ├─ freq_hz: 1000
              ├─ dur_ms: 50
              └─ level_db: 60
         │
         ▼
┌────────────────────────────┐
│ Validate Parameters        │
│ Against Generator Schema   │
└────────┬───────────────────┘
         │
         ▼ [valid]
┌────────────────────────────┐
│ Resolve Randomization      │
│ (if applicable)            │
└────────┬───────────────────┘
         │
         ▼
┌────────────────────────────┐
│ Call Generator Function    │
│ generators.audio.tone.     │
│   generate(params, ctx)    │
└────────┬───────────────────┘
         │
         ▼
Output Specification
         │
         ├─ modality: "audio"
         ├─ render_type: "waveform"
         ├─ data: [N x 1 samples]
         ├─ duration_ms: 50
         └─ metadata: {...}
         │
         ▼
[Ready for Engine Execution]
```

### Detailed: Block Building Flow
```
Block Instance (JSON)
         │
         ├─ builder_type: "oddball"
         ├─ builder_version: "1.0.0"
         └─ parameters:
              ├─ n_trials: 200
              ├─ deviant_probability: 0.15
              ├─ standard_stimulus: {...}
              └─ deviant_stimulus: {...}
         │
         ▼
┌────────────────────────────┐
│ Validate Instance          │
│ Against Builder Schema     │
└────────┬───────────────────┘
         │
         ▼ [valid]
┌────────────────────────────┐
│ Call Builder Function      │
│ builders.oddball.          │
│   build(instance, ctx)     │
└────────┬───────────────────┘
         │
         ▼
Trial List Generation
         │
         ├─ Determine trial types
         │    (standard vs deviant)
         │
         ├─ Apply constraints
         │    (no consecutive deviants)
         │
         ├─ Generate ITI values
         │    (jittered)
         │
         └─ Create trial structs
         │
         ▼
Array of Trial Structs
         │
         ├─ trial[1]:
         │    ├─ trial_id: "..."
         │    ├─ trial_type: "standard"
         │    ├─ presentations[1]:
         │    │    ├─ stimulus_spec: {...}
         │    │    └─ onset_ms: 0
         │    └─ iti_sec: 1.234
         │
         ├─ trial[2]:
         │    └─ ...
         │
         └─ trial[200]: ...
         │
         ▼
[Ready for Stimulus Generation]
```

### Detailed: Audio-Only Engine Flow
```
Experiment + Trial Lists
         │
         ▼
┌────────────────────────────┐
│ FOR EACH trial             │
│   FOR EACH presentation    │
│     Generate stimulus      │
│     (call generator)       │
│   END                      │
│ END                        │
└────────┬───────────────────┘
         │
         ▼
Collection of Output Specs
         │
         ▼
┌────────────────────────────┐
│ Compile Waveforms          │
│                            │
│ • Arrange in time          │
│ • Insert ITI (silence)     │
│ • Generate TTL pulses      │
│ • Concatenate all          │
└────────┬───────────────────┘
         │
         ▼
Complete Waveforms
         │
         ├─ AO: [N x 1] audio
         └─ DO: [N x 1] TTL
         │
         ▼
┌────────────────────────────┐
│ Initialize DAQ             │
│ Set rate, channels         │
└────────┬───────────────────┘
         │
         ▼
┌────────────────────────────┐
│ Hardware-Timed Playback    │
│ readwrite(daq, [AO, DO])   │
│ [BLOCKING CALL]            │
└────────┬───────────────────┘
         │
         ▼
Loopback Recording
         │
         ▼
┌────────────────────────────┐
│ Save All Data              │
│ • Waveforms (WAV)          │
│ • Logs (CSV)               │
│ • Metadata (JSON)          │
└────────────────────────────┘
```

### Detailed: Audiovisual Engine Flow
```
Experiment + Trial Lists
         │
         ▼
┌────────────────────────────┐
│ Pre-Generate Unique Stimuli│
│                            │
│ Audio: Generate waveforms  │
│ Visual: Keep as specs      │
│                            │
│ Cache in Map               │
└────────┬───────────────────┘
         │
         ▼
┌────────────────────────────┐
│ Initialize Hardware        │
│ • Psychtoolbox window      │
│ • DAQ session              │
└────────┬───────────────────┘
         │
         ▼
┌────────────────────────────┐
│ Real-Time Loop             │
│                            │
│ FOR EACH trial:            │
│   FOR EACH presentation:   │
│                            │
│     IF audio:              │
│       - Get cached wave    │
│       - Queue to DAQ       │
│                            │
│     IF visual:             │
│       - Interpret spec     │
│       - Draw to buffer     │
│                            │
│     IF multimodal:         │
│       - Draw visual        │
│       - Queue audio        │
│                            │
│     Synchronize:           │
│       vbl = Flip(window)   │
│       readwrite(daq, ...)  │
│                            │
│     Log event:             │
│       timestamp, vbl, etc  │
│                            │
│   END presentation         │
│                            │
│   ITI:                     │
│     WaitSecs(...)          │
│                            │
│ END trial                  │
└────────┬───────────────────┘
         │
         ▼
┌────────────────────────────┐
│ Cleanup                    │
│ • Close PTB window         │
│ • Release DAQ              │
└────────┬───────────────────┘
         │
         ▼
┌────────────────────────────┐
│ Save Logs & Metadata       │
└────────────────────────────┘
```

---

## Summary

Data flows through Maestro in a clear pipeline:

1. **JSON Specifications** → Human-readable configs
2. **Discovery & Validation** → System prepares runtime
3. **Compilation** → High-level specs → Low-level data
4. **Execution** → Hardware control with logging
5. **Output** → Complete experimental record

Each phase:
- Has well-defined inputs and outputs
- Performs validation before proceeding
- Logs its activities
- Can be tested independently

This modular data flow enables:
- Clear debugging (find which phase failed)
- Independent testing (test each phase separately)
- Flexibility (swap engines without changing earlier phases)
- Reproducibility (same input → same output)

---

End of data_flow.md