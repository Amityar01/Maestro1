# Maestro v1 Architecture

**Version**: 1.0.0
**Status**: Foundation schemas complete, implementation in progress

---

## Design Philosophy

Maestro v1 is a **schema-first, contract-driven** neuroscience experiment platform designed around:

1. **Composability**: Stimulus, paradigm, schedule, and engine are completely separable
2. **Determinism**: Pure functions, explicit seeds, reproducible compilation
3. **Reflection**: UI built automatically from schemas, no hardcoded paradigms
4. **Safety**: Validation at every boundary, fail fast with clear messages
5. **Provenance**: Every artifact traceable to source schemas and seeds
6. **Hardware Agnostic**: Capabilities negotiation, no assumptions about channels or rates

---

## Core Principles

### No Hardcoded Assumptions
- No hardcoded device channels, sample rates, or TTL mappings
- No hardware calls in generators or builders
- TTL identity never encodes stimulus type
- All configuration through schemas

### Validation Everywhere
- Probabilities sum to 1.0 (within tolerance)
- Timing feasibility (ramps + refractory fit within realized intervals)
- Resource budgets (memory, CPU for complex stimuli)
- Clipping and crest factor guards

### Deterministic by Design
- All RNG uses named streams with recorded seeds
- Compilation is a pure function (same input → same output)
- Reproduction from manifest yields byte-identical files

---

## Module Contracts

### 1. Generators (Stimulus Synthesis)

**Purpose**: Create audio buffers from parameters

**Signature**:
```matlab
[audio, metadata] = generate(params, context)
```

**Inputs**:
- `params`: Stimulus-specific parameters (frequency_hz, duration_ms, etc.)
- `context`: Common core (level, envelope, routing, seed, fs_hz)

**Outputs**:
- `audio`: Float32 audio buffer [samples × channels]
- `metadata`: Peak, RMS, duration, provenance hash

**Constraints**:
- Must be pure and deterministic (same inputs → same output)
- No file system writes or device calls
- Envelope applied last, after all synthesis
- Must respect resource budgets

**Schema Reference**: `schemas/v1/stimuli/*.schema.json`

---

### 2. Pattern Builder Core

**Purpose**: Expand trial plans into element tables

**Input IR**: List of elements per trial, each with:
- `stimulus_ref`: Reference to stimulus definition
- `scheduled_onset_ms`: When it should play
- `per_position_overrides`: Optional parameter overrides
- `role`: Optional (cue, outcome, etc.)

**Task**:
1. Realize distributions (sample jittered values)
2. Enforce envelope and refractory constraints
3. Compute trial windows
4. Emit element table with all timing resolved

**Output**: Element table (one row per scheduled stimulus)

**Schema Reference**: See paradigm schemas for input structure

---

### 3. Paradigm Adapters

Each paradigm type has an adapter that converts paradigm-specific config into the Pattern Builder IR.

#### Oddball Adapter
- Inputs: Tokens with probabilities, selection mode, constraints, ITI
- Outputs: Element list (one element per trial)
- Handles: iid/balanced/csv selection, min gap, max run length

#### Local-Global Adapter
- Inputs: Symbols, patterns (e.g., AAAA, AAAB), timing (IOI, ITI)
- Outputs: Element list (multiple elements per trial for patterns)
- Handles: Grid/absolute timing, symbol resolution, pattern selection

#### Foreperiod Adapter
- Inputs: Cue, outcomes, foreperiod distribution, ITI
- Outputs: Element list (cue + outcome per trial)
- Handles: Foreperiod sampling, omission trials

#### Freq-Level Sweep Adapter
- Inputs: Frequency set, level set, repetitions, randomization
- Outputs: Element list (one element per combination × repetitions)
- Handles: Linear/log spacing, shuffle policy, startle guard

**Schema Reference**: `schemas/v1/paradigms/*.schema.json`

---

### 4. Compiler

**Purpose**: Convert element table to SequenceFile v1

**Inputs**:
- Element table (from Pattern Builder)
- Capability descriptor (from engine)

**Tasks**:
1. Allocate continuous audio and TTL tracks
2. Generate each stimulus via generators
3. Mix into tracks at scheduled onsets
4. Schedule TTL pulse for every element onset
5. Write manifest with provenance

**Output**: SequenceFile v1 (HDF5 or NPZ)

**Constraints**:
- Sample-accurate TTL placement: `sample_index = round(onset_ms * fs / 1000)`
- TTL pulse width >= engine minimum
- Audio never clips (warn if approaching full scale)

**Schema Reference**: `schemas/v1/sequence/sequence_file_v1.schema.json`

---

### 5. Engines

**Purpose**: Play sequence files to hardware/software

#### DAQ Engine v1
- Plays audio to DAQ analog outputs
- Plays TTL to digital line
- Logs actual onset times (for latency measurement)
- No underruns for sessions up to 1 hour

#### PTB Engine (stub)
- Plays audio via PsychPortAudio
- Software TTL surrogate (logged events instead of hardware pulses)
- For development/testing without DAQ hardware

**Capability Descriptor**: Each engine advertises:
- Supported sample rates
- Max channels, TTL availability
- Buffer sizes, latency estimates
- Voltage ranges (for hardware engines)

**Schema Reference**: `schemas/v1/capabilities/engine_capabilities.schema.json`

---

### 6. GUI (Reflection-Driven)

**Principle**: GUI reads schemas, never hardcodes stimulus types or paradigms

**Views**:
1. **Block Manager**: Add/edit/reorder blocks, validity lamps
2. **Block Editor**: Schema-driven forms, fixed/sampled toggle, feasibility checks
3. **Stimulus Editor**: Opens from any stimulus_ref, allows Save As
4. **Session Composer**: Inter-block delays, RUN BLOCK, RUN SEQUENCE
5. **Metadata Form**: Experimenter, subject, rig, calibration

**UI Hints in Schemas**:
```json
"ui_hints": {
  "label": "Pure Tone",
  "icon": "waveform-sine",
  "parameter_groups": [...],
  "field_widgets": {
    "frequency_hz": {
      "widget": "spinner",
      "min": 20,
      "max": 22000,
      "step": 10,
      "units": "Hz"
    }
  },
  "preview_template": "{frequency_hz} Hz tone, {duration_ms} ms"
}
```

**Validation Feedback**:
- Probability sum ticker (shows current sum, highlights if not 1.0)
- Feasibility lamps (red/yellow/green)
- Expected trial counts for balanced mode
- CSV import with row-level error reporting

---

## Data Shapes

### Numeric Field Union

All numeric parameters can be scalar or sampled:

```json
// Scalar
{"value": 1000}

// Uniform distribution
{"dist": "uniform", "min": 900, "max": 1100, "scope": "per_trial", "seed": 42}

// Normal (clipped)
{"dist": "normal", "mean": 1000, "std": 50, "clip_min": 900, "clip_max": 1100, "scope": "per_trial"}

// Log-uniform
{"dist": "loguniform", "min": 100, "max": 10000, "scope": "per_block"}

// Categorical
{"dist": "categorical", "categories": [1000, 1500, 2000], "probabilities": [0.5, 0.3, 0.2], "scope": "per_trial"}
```

**Scopes**:
- `per_trial`: Sample once per trial
- `per_block`: Sample once per block (all trials use same value)
- `per_session`: Sample once per session

---

### Token Common Core

All stimuli inherit these fields:

```json
{
  "id": "stim_001",
  "type": "tone.simple",
  "duration_ms": {"value": 150},
  "level": {
    "value": {"value": 75},
    "unit": "dB_SPL",
    "calibration_ref": "calibration_2024_01_15.json"
  },
  "envelope": {
    "attack_ms": 5,
    "release_ms": 5,
    "shape": "cosine"
  },
  "routing": {
    "channels": [0, 1],
    "pan": 0.0
  },
  "seed": 12345,
  "am": {
    "rate_hz": {"value": 10},
    "depth_0_1": 0.5,
    "waveform": "sine",
    "phase_deg": 0
  }
}
```

---

## SequenceFile v1

**Container**: HDF5 or NPZ (decision pending)

**Datasets**:
- `audio`: float32, shape [samples, channels]
- `ttl`: uint8, shape [samples], 1 = TTL high
- `events`: table with columns [event_type, sample_index, trial_id, element_id, timestamp_ms]
- `trial_table`: one row per trial
- `element_table`: one row per element
- `manifest`: JSON blob with full provenance

**Event Types**:
- `playback_start`, `playback_end`
- `stim_onset_ttl`
- `block_start`, `block_end`
- `manual_gate`

**Manifest Contents**:
- Exact schema JSON (stimulus and paradigm)
- All RNG seeds
- Capability descriptor used for compilation
- Content hashes (SHA-256)
- Experimenter metadata

**Acceptance Criteria**:
- Every TTL edge has matching element row
- Reproduction from manifest yields byte-identical sequence files
- Trial and element tables map 1:1 with events

---

## Plugin Discovery

**Mechanism**: Scan `plugins/v1/{generators,builders,engines}/` for descriptor files

**Descriptor Format** (example for tone.simple):
```json
{
  "plugin_type": "generator",
  "stimulus_type": "tone.simple",
  "version": "1.0.0",
  "schema_ref": "schemas/v1/stimuli/tone.simple.schema.json",
  "function_handle": "v1.generators.tone_simple.generate",
  "capabilities": {
    "max_duration_s": 60,
    "memory_per_second_mb": 0.768
  },
  "ui_hints_summary": {
    "label": "Pure Tone",
    "category": "tones"
  }
}
```

**Discovery Process**:
1. Scan plugin directories
2. Read descriptor.json files
3. Validate against schema
4. Register function handle
5. GUI uses descriptors to populate stimulus palette

**GUI Never Imports Plugin Code**: All UI rendering from schemas and hints

---

## Validation Rules

### At Block Configuration Time
- Probabilities sum to 1.0 (tolerance 0.001)
- Unique labels (no duplicate token/pattern labels)
- CSV presets reference known labels

### At Compilation Time
- Feasibility: ramps + refractory fit within IOI/ITI
- Budget checks: cloud stimuli don't exceed memory/CPU limits
- TTL pulse width >= engine minimum
- Sample rate in engine's supported list

### At Runtime (Engine)
- Buffer underrun detection
- TTL timing verification (log actual edges)
- Clipping detection (warn if audio > 95% full scale)

---

## Testing Strategy

### Milestone Gates

**M1: Schemas and Validators**
- All schemas pass JSON Schema validation
- Numeric field samplers produce correct moments
- Clipping and crest guards work

**M2: Generators**
- Deterministic (same seed → same output)
- Spectra within tolerance for tones
- Stable previews

**M3: Pattern Builder Core**
- Enforces envelope and refractory constraints
- Strict determinism (same inputs → same element table)

**M4: Paradigm Adapters**
- Correct counts and timing for Oddball, Local-Global, Foreperiod, Freq-Level Sweep
- Constraint satisfaction (min gap, max run)

**M5: Compiler**
- Produces byte-stable SequenceFile v1
- TTL edges sample-accurate
- Manifest complete

**M6: DAQ Engine**
- Runs 1 hour without underrun
- TTL-to-audio alignment within target (< 1 ms)

**M7: Provenance**
- Logs map 1:1 with TTL edges
- Reproduction from manifest yields identical files

**M8: GUI**
- Enforces required fields
- Renders hints correctly
- CSV import with row-level validation

### End-to-End Acceptance Tests
1. Oddball v1 block (250 trials, 15% deviant)
2. Local-Global AAAB vs AAAA (50 trials each)
3. Foreperiod with omission (cue-outcome, 10% catch)
4. Freq-Level sweep (10 freqs × 5 levels, shuffled)

All must pass: counts, timing, alignment, provenance

---

## Implementation Roadmap

### Phase 1: Foundation (Current)
- ✅ All schemas defined
- ⏳ Validation framework
- ⏳ Sampling framework
- ⏳ Generator base class

### Phase 2: Core Modules
- ⏳ Pattern Builder Core
- ⏳ Oddball adapter
- ⏳ Tone.simple generator
- ⏳ Compiler skeleton

### Phase 3: First End-to-End
- ⏳ DAQ engine v1
- ⏳ SequenceFile writer
- ⏳ Oddball block compilation and playback

### Phase 4: Extended Paradigms
- ⏳ Local-Global adapter
- ⏳ Foreperiod adapter
- ⏳ Freq-Level Sweep adapter

### Phase 5: GUI
- ⏳ Schema reader and renderer
- ⏳ Block Manager
- ⏳ Session Composer

### Phase 6: Advanced Stimuli
- ⏳ Noise generators
- ⏳ Pip cloud generator
- ⏳ Click train generator

---

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Hardware coupling creeping into plugins | High | Enforce contracts in CI, code review |
| Timing infeasibility slipping to runtime | High | Hard validators, feasibility lamps |
| GUI special-casing | Medium | All UI through schemas, no hardcoding |
| Long session memory pressure | Medium | Chunked sequence files, streaming |
| Schema versioning conflicts | Medium | Semver, migration tools |

---

## Open Questions

1. **File container**: HDF5 or NPZ? → Decide before M5
2. **PTB audiovisual**: Extend capability descriptor when ready
3. **Hazard functions for foreperiod**: Add new distribution type if needed
4. **Streaming playback**: Implement if memory becomes limiting factor

---

## Glossary

- **Element**: Single scheduled stimulus token within a trial
- **Trial**: Local pattern window (e.g., 6 pips or cue+outcome)
- **Block**: Set of trials with one paradigm instance
- **Session**: Ordered list of blocks with delays/gates
- **TTL**: Digital pulse at each element onset, identity in logs
- **Capability Descriptor**: Engine advertisement of what it can do
- **Manifest**: Complete provenance record in SequenceFile
- **Schema**: JSON Schema defining structure and validation rules
- **UI Hints**: Schema annotations for automatic GUI rendering

---

## Contributing

### Code Style
- Deterministic RNG with named streams
- No hidden defaults, record all derived values
- Error messages include field paths and numeric values
- Semver for schemas (breaking change → major bump)

### Schema Changes
- Test with validator before committing
- Update ARCHITECTURE_V1.md if contracts change
- Add migration guide for breaking changes

### Testing
- Unit tests for each module
- Integration tests for end-to-end workflows
- Acceptance gates must pass before merge

---

## License

[To be determined]

---

**Status**: Foundation complete, implementation in progress
**Next Milestone**: M2 - Generators
**Target**: Oddball end-to-end demo by M3
