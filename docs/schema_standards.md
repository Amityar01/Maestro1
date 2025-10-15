# Maestro Schema Standards v1.0

This document defines the complete JSON schema specifications for all components in the Maestro system.

## Table of Contents
1. [Generator Schema](#generator-schema)
2. [Stimulus Specification](#stimulus-specification)
3. [Builder Template Schema](#builder-template-schema)
4. [Block Instance Schema](#block-instance-schema)
5. [Experiment Schema](#experiment-schema)
6. [Common Types](#common-types)

---

## Generator Schema

Defines a stimulus generator plugin. Located at `+generators/<category>/<name>/schema.json`
```json
{
  "$schema": "maestro-generator-v1",
  "generator_type": "string (unique identifier, e.g., 'tone', 'gabor')",
  "version": "string (semver, e.g., '1.0.0')",
  "category": "string (e.g., 'audio', 'visual', 'compound')",
  "description": "string (human-readable description)",
  
  "modality": "enum: 'audio' | 'visual' | 'multimodal'",
  "render_type": "enum: 'waveform' | 'draw_commands' | 'compound'",
  
  "compatible_engines": ["array of engine types that can execute this"],
  
  "parameters": {
    "param_name": {
      "type": "string (see Parameter Types below)",
      "required": "boolean (default: false)",
      "default": "any (default value if not provided)",
      "description": "string (parameter description)",
      "constraints": {
        "min": "number (for numeric types)",
        "max": "number (for numeric types)",
        "options": ["array (for enum types)"],
        "pattern": "string (regex for string types)"
      },
      "randomizable": "boolean (can this parameter be randomized?)",
      "unit": "string (e.g., 'Hz', 'dB', 'ms', 'degrees')",
      "ui_hints": {
        "widget": "string ('slider', 'spinner', 'dropdown', 'text')",
        "display_name": "string (override parameter name in GUI)",
        "group": "string (logical grouping for UI)"
      }
    }
  },
  
  "output_specification": {
    "description": "string (what this generator produces)",
    "structure": {
      "modality": "string",
      "render_type": "string",
      "data": "object (format depends on render_type)",
      "duration_ms": "number",
      "metadata": "object"
    }
  },
  
  "implementation": {
    "language": "string ('matlab')",
    "function": "string (fully qualified function name, e.g., 'generators.audio.tone.generate')",
    "file": "string (relative path to implementation file)",
    "dependencies": ["array of required toolboxes/packages"]
  },
  
  "examples": [
    {
      "name": "string (example name)",
      "description": "string",
      "parameters": { "...": "example parameter values" }
    }
  ],
  
  "metadata": {
    "author": "string",
    "created": "string (ISO 8601 date)",
    "modified": "string (ISO 8601 date)",
    "tags": ["array of search tags"]
  }
}
```

### Parameter Types

- `float`: Floating-point number
- `integer`: Integer number
- `string`: Text string
- `boolean`: True/false
- `enum`: One of a fixed set of values
- `array`: Array of values (specify element type in constraints)
- `stimulus_reference`: Reference to another stimulus
- `file_path`: Path to an external file

### Example: Tone Generator Schema
```json
{
  "$schema": "maestro-generator-v1",
  "generator_type": "tone",
  "version": "1.0.0",
  "category": "audio",
  "description": "Pure sinusoidal tone with half-cosine ramps",
  
  "modality": "audio",
  "render_type": "waveform",
  
  "compatible_engines": ["audio_only", "audiovisual"],
  
  "parameters": {
    "freq_hz": {
      "type": "float",
      "required": true,
      "description": "Frequency of the tone",
      "constraints": {
        "min": 20,
        "max": 20000
      },
      "randomizable": true,
      "unit": "Hz",
      "ui_hints": {
        "widget": "slider",
        "display_name": "Frequency"
      }
    },
    "dur_ms": {
      "type": "float",
      "required": true,
      "description": "Duration of the tone",
      "constraints": {
        "min": 1,
        "max": 10000
      },
      "unit": "ms",
      "ui_hints": {
        "widget": "spinner"
      }
    },
    "level_db": {
      "type": "float",
      "required": true,
      "description": "Sound pressure level",
      "constraints": {
        "min": 0,
        "max": 100
      },
      "randomizable": true,
      "unit": "dB SPL",
      "ui_hints": {
        "widget": "slider",
        "display_name": "Level"
      }
    },
    "ramp_ms": {
      "type": "float",
      "required": false,
      "default": 5,
      "description": "Duration of onset/offset ramps",
      "constraints": {
        "min": 0,
        "max": 100
      },
      "unit": "ms"
    }
  },
  
  "output_specification": {
    "description": "Audio waveform with specified frequency and level",
    "structure": {
      "modality": "audio",
      "render_type": "waveform",
      "data": "column vector of audio samples",
      "duration_ms": "matches dur_ms parameter",
      "metadata": "copy of input parameters"
    }
  },
  
  "implementation": {
    "language": "matlab",
    "function": "generators.audio.tone.generate",
    "file": "generator.m",
    "dependencies": []
  },
  
  "examples": [
    {
      "name": "1 kHz tone",
      "description": "Standard 1 kHz calibration tone",
      "parameters": {
        "freq_hz": 1000,
        "dur_ms": 50,
        "level_db": 60
      }
    }
  ],
  
  "metadata": {
    "author": "Maestro Development Team",
    "created": "2025-01-15",
    "modified": "2025-01-15",
    "tags": ["audio", "tone", "pure_tone", "calibration"]
  }
}
```

---

## Stimulus Specification

A stimulus specification is the concrete instance of a generator with specific parameters.
```json
{
  "stimulus_id": "string (optional, for referencing)",
  "generator": "string (generator_type from generator schema)",
  "version": "string (semver, which version of generator to use)",
  "parameters": {
    "param_name": "value | randomization_spec"
  },
  "metadata": {
    "label": "string (optional, human-readable label)",
    "notes": "string (optional, notes about this stimulus)"
  }
}
```

### Parameter Values

Parameters can be either:

**Fixed value:**
```json
"freq_hz": 1000
```

**Randomization specification:**
```json
"freq_hz": {
  "type": "random_uniform",
  "min": 1000,
  "max": 2000
}
```
```json
"level_db": {
  "type": "random_gaussian",
  "mean": 60,
  "std": 5
}
```
```json
"freq_hz": {
  "type": "random_choice",
  "options": [1000, 2000, 4000]
}
```

### Example: Stimulus Specification
```json
{
  "stimulus_id": "tone_1khz_50ms_60db",
  "generator": "tone",
  "version": "1.0.0",
  "parameters": {
    "freq_hz": 1000,
    "dur_ms": 50,
    "level_db": 60,
    "ramp_ms": 5
  },
  "metadata": {
    "label": "Standard tone",
    "notes": "Used as standard in oddball paradigm"
  }
}
```

---

## Builder Template Schema

Defines a block builder plugin. Located at `+builders/<name>/template.schema.json`
```json
{
  "$schema": "maestro-builder-v1",
  "builder_type": "string (unique identifier, e.g., 'oddball')",
  "version": "string (semver)",
  "description": "string (human-readable description)",
  
  "paradigm_category": "string (e.g., 'oddball', 'foreperiod', 'adaptive')",
  
  "required_inputs": {
    "input_name": {
      "type": "string (parameter type)",
      "description": "string",
      "constraints": { "...": "..." }
    }
  },
  
  "optional_inputs": {
    "input_name": {
      "type": "string",
      "default": "any (default value)",
      "description": "string",
      "constraints": { "...": "..." }
    }
  },
  
  "output_specification": {
    "description": "string (what this builder produces)",
    "trial_structure": {
      "trial_types": ["array of possible trial types"],
      "metadata_fields": ["array of metadata fields produced"],
      "presentation_count": "string ('fixed' or 'variable')",
      "timing_model": "string ('fixed_iti' or 'jittered_iti' or 'custom')"
    }
  },
  
  "implementation": {
    "language": "string ('matlab')",
    "function": "string (fully qualified function name)",
    "file": "string (relative path to implementation)",
    "dependencies": []
  },
  
  "examples": [
    {
      "name": "string",
      "description": "string",
      "instance": { "...": "example instance specification" }
    }
  ],
  
  "metadata": {
    "author": "string",
    "created": "string (ISO 8601 date)",
    "modified": "string (ISO 8601 date)",
    "tags": ["array"],
    "references": ["array of papers/citations"]
  }
}
```

### Example: Oddball Builder Template
```json
{
  "$schema": "maestro-builder-v1",
  "builder_type": "oddball",
  "version": "1.0.0",
  "description": "Standard/deviant oddball paradigm with configurable probability",
  
  "paradigm_category": "oddball",
  
  "required_inputs": {
    "n_trials": {
      "type": "integer",
      "description": "Total number of trials to generate",
      "constraints": {
        "min": 1,
        "max": 100000
      }
    },
    "standard_stimulus": {
      "type": "stimulus_specification",
      "description": "Stimulus specification for standard trials"
    },
    "deviant_stimulus": {
      "type": "stimulus_specification",
      "description": "Stimulus specification for deviant trials"
    },
    "deviant_probability": {
      "type": "float",
      "description": "Probability of deviant trials (0-1)",
      "constraints": {
        "min": 0,
        "max": 1
      }
    }
  },
  
  "optional_inputs": {
    "order_constraint": {
      "type": "enum",
      "default": "random",
      "description": "Ordering constraint for trials",
      "constraints": {
        "options": ["random", "no_consecutive_deviants"]
      }
    },
    "iti_min_sec": {
      "type": "float",
      "default": 1.0,
      "description": "Minimum inter-trial interval",
      "constraints": {
        "min": 0
      }
    },
    "iti_max_sec": {
      "type": "float",
      "default": 2.0,
      "description": "Maximum inter-trial interval",
      "constraints": {
        "min": 0
      }
    }
  },
  
  "output_specification": {
    "description": "List of trials with standard or deviant stimuli",
    "trial_structure": {
      "trial_types": ["standard", "deviant"],
      "metadata_fields": ["is_deviant", "trial_type"],
      "presentation_count": "fixed (1 per trial)",
      "timing_model": "jittered_iti"
    }
  },
  
  "implementation": {
    "language": "matlab",
    "function": "builders.oddball.build",
    "file": "builder.m",
    "dependencies": []
  },
  
  "examples": [
    {
      "name": "Frequency oddball",
      "description": "1 kHz standard, 2 kHz deviant at 10%",
      "instance": {
        "builder_type": "oddball",
        "parameters": {
          "n_trials": 100,
          "standard_stimulus": {
            "generator": "tone",
            "parameters": {"freq_hz": 1000, "dur_ms": 50, "level_db": 60}
          },
          "deviant_stimulus": {
            "generator": "tone",
            "parameters": {"freq_hz": 2000, "dur_ms": 50, "level_db": 60}
          },
          "deviant_probability": 0.1,
          "order_constraint": "no_consecutive_deviants"
        }
      }
    }
  ],
  
  "metadata": {
    "author": "Maestro Development Team",
    "created": "2025-01-15",
    "tags": ["oddball", "mismatch_negativity", "standard", "deviant"],
    "references": [
      "Näätänen et al. (2007). Mismatch negativity - A unique measure of sensory processing"
    ]
  }
}
```

---

## Block Instance Schema

A concrete instance of a builder with specific parameters. Saved in `instances/<name>.json`
```json
{
  "$schema": "maestro-instance-v1",
  "instance_id": "string (unique identifier)",
  "builder_type": "string (references builder template)",
  "builder_version": "string (semver, which builder version)",
  
  "parameters": {
    "param_name": "value (must satisfy builder template requirements)"
  },
  
  "metadata": {
    "name": "string (human-readable name)",
    "description": "string (optional)",
    "created": "string (ISO 8601 timestamp)",
    "created_by": "string (experimenter name)",
    "modified": "string (ISO 8601 timestamp)",
    "project": "string (project name)",
    "notes": "string (free-form notes)",
    "tags": ["array of tags for searching"]
  }
}
```

### Example: Block Instance
```json
{
  "$schema": "maestro-instance-v1",
  "instance_id": "exp01_oddball_freq_session1",
  "builder_type": "oddball",
  "builder_version": "1.0.0",
  
  "parameters": {
    "n_trials": 200,
    "standard_stimulus": {
      "generator": "tone",
      "version": "1.0.0",
      "parameters": {
        "freq_hz": 1000,
        "dur_ms": 50,
        "level_db": 60
      }
    },
    "deviant_stimulus": {
      "generator": "tone",
      "version": "1.0.0",
      "parameters": {
        "freq_hz": 2000,
        "dur_ms": 50,
        "level_db": 60
      }
    },
    "deviant_probability": 0.15,
    "order_constraint": "no_consecutive_deviants",
    "iti_min_sec": 1.2,
    "iti_max_sec": 1.8
  },
  
  "metadata": {
    "name": "Frequency Oddball - Session 1",
    "description": "Standard frequency oddball with 15% deviants",
    "created": "2025-01-15T10:30:00Z",
    "created_by": "Jane Doe",
    "modified": "2025-01-15T10:30:00Z",
    "project": "auditory_prediction",
    "notes": "Increased deviant probability from 10% based on pilot data",
    "tags": ["oddball", "frequency", "session_1"]
  }
}
```

---

## Experiment Schema

Defines a complete experimental session. Saved in `experiments/<name>.json`
```json
{
  "$schema": "maestro-experiment-v1",
  "experiment_id": "string (unique identifier)",
  "version": "string (experiment definition version)",
  
  "metadata": {
    "name": "string (experiment name)",
    "description": "string",
    "subject_id": "string",
    "session_number": "integer",
    "date": "string (ISO 8601 date)",
    "experimenter": "string",
    "project": "string",
    "protocol_id": "string (IRB/IACUC protocol number)",
    "notes": "string",
    "tags": ["array"]
  },
  
  "global_settings": {
    "sampling_rate_hz": "integer (DAQ sampling rate)",
    "daq_device": "string (device identifier, e.g., 'Dev1')",
    "output_directory": "string (where to save data)",
    "randomization_seed": "integer (optional, for reproducibility)",
    "engine_type": "string (which execution engine to use)"
  },
  
  "sequence": [
    {
      "block_id": "string (unique within experiment)",
      "block_instance": "string (path or reference to instance)",
      "order": "integer (execution order)",
      "pre_block_delay_sec": "number (delay before block starts)",
      "post_block_delay_sec": "number (delay after block ends)",
      "metadata": {
        "notes": "string",
        "skip": "boolean (if true, skip this block)"
      }
    }
  ],
  
  "orchestration": {
    "type": "enum: 'sequential' | 'randomized' | 'conditional'",
    "randomize_blocks": "boolean | array (which blocks to randomize)",
    "counterbalance_groups": ["array of arrays (blocks to counterbalance)"],
    "stop_on_error": "boolean (stop experiment if block fails)",
    "pause_between_blocks": "boolean (wait for user to continue)"
  },
  
  "hardware": {
    "daq": {
      "device_id": "string",
      "channels": {
        "audio_out": "string (e.g., 'ao0')",
        "ttl_out": "string (e.g., 'port0/line0')",
        "loopback_in": "string (e.g., 'ai0')"
      }
    },
    "display": {
      "screen_number": "integer",
      "background_color": [128, 128, 128],
      "calibration": {
        "viewing_distance_cm": 60,
        "screen_width_cm": 50,
        "screen_height_cm": 30
      }
    }
  }
}
```

### Example: Complete Experiment
```json
{
  "$schema": "maestro-experiment-v1",
  "experiment_id": "M042_session_003",
  "version": "1.0.0",
  
  "metadata": {
    "name": "Prediction Error Session 3",
    "description": "Habituation followed by oddball and foreperiod blocks",
    "subject_id": "M042",
    "session_number": 3,
    "date": "2025-01-15",
    "experimenter": "Jane Doe",
    "project": "auditory_prediction",
    "protocol_id": "IACUC-2024-001",
    "notes": "Subject showing good performance",
    "tags": ["mouse", "auditory", "prediction", "habituation"]
  },
  
  "global_settings": {
    "sampling_rate_hz": 192000,
    "daq_device": "Dev1",
    "output_directory": "data/M042/session_003",
    "randomization_seed": 42,
    "engine_type": "audio_only"
  },
  
  "sequence": [
    {
      "block_id": "block_001_habituation",
      "block_instance": "instances/habituation_tones.json",
      "order": 1,
      "pre_block_delay_sec": 0,
      "post_block_delay_sec": 30,
      "metadata": {
        "notes": "Habituation block"
      }
    },
    {
      "block_id": "block_002_oddball",
      "block_instance": "instances/exp01_oddball_freq_session1.json",
      "order": 2,
      "pre_block_delay_sec": 10,
      "post_block_delay_sec": 30,
      "metadata": {
        "notes": "Main oddball block"
      }
    },
    {
      "block_id": "block_003_foreperiod",
      "block_instance": "instances/foreperiod_threat.json",
      "order": 3,
      "pre_block_delay_sec": 10,
      "post_block_delay_sec": 0,
      "metadata": {
        "notes": "Foreperiod task"
      }
    }
  ],
  
  "orchestration": {
    "type": "sequential",
    "randomize_blocks": false,
    "stop_on_error": true,
    "pause_between_blocks": false
  },
  
  "hardware": {
    "daq": {
      "device_id": "Dev1",
      "channels": {
        "audio_out": "ao0",
        "ttl_out": "port0/line0",
        "loopback_in": "ai0"
      }
    }
  }
}
```

---

## Common Types

### Randomization Specifications

Used in stimulus parameters that support randomization:
```json
{
  "type": "random_uniform",
  "min": "number",
  "max": "number"
}
```
```json
{
  "type": "random_gaussian",
  "mean": "number",
  "std": "number",
  "clip_min": "number (optional)",
  "clip_max": "number (optional)"
}
```
```json
{
  "type": "random_choice",
  "options": ["array of values"],
  "weights": ["array of probabilities (optional, default uniform)"]
}
```

### References

Referenced items use `@` prefix:
```json
{
  "block_instance": "@instances/my_block.json"
}
```
```json
{
  "stimulus": "@stimuli/library.json#tone_1khz"
}
```

---

## Validation Rules

All schemas must be validated before use:

1. **Required fields**: All required fields must be present
2. **Type checking**: All values must match specified types
3. **Constraint checking**: All constraints must be satisfied
4. **Version compatibility**: Versions must be valid semver
5. **Reference resolution**: All references must resolve to valid objects
6. **Logical consistency**: Parameters must make logical sense (e.g., min < max)

---

## Versioning Strategy

All components use semantic versioning (semver):

- **Major version** (X.0.0): Breaking changes to interface
- **Minor version** (0.X.0): New features, backward compatible
- **Patch version** (0.0.X): Bug fixes, backward compatible

Experiments reference specific versions:
```json
{
  "generator": "tone",
  "version": "1.2.0"
}
```

System maintains multiple versions and routes to correct implementation.

---

## Extensions

Custom fields can be added using namespace prefixes:
```json
{
  "generator": "tone",
  "parameters": {...},
  "x_custom_field": "custom value",
  "x_lab_specific_setting": 42
}
```

Fields starting with `x_` are preserved but ignored by core system.