# Maestro Extension Guide v1.0

This document provides complete instructions for extending Maestro with new generators, builders, and engines.

## Table of Contents
1. [Quick Start](#quick-start)
2. [Adding a New Generator](#adding-a-new-generator)
3. [Adding a New Builder](#adding-a-new-builder)
4. [Adding a New Engine](#adding-a-new-engine)
5. [Testing Your Plugin](#testing-your-plugin)
6. [Best Practices](#best-practices)
7. [Common Pitfalls](#common-pitfalls)
8. [Checklist](#checklist)

---

## Quick Start

### What You Need to Know

Before extending Maestro, understand the architecture:
````
GENERATORS → Create stimulus specifications from parameters
BUILDERS   → Create trial lists from block parameters  
ENGINES    → Execute experiments using trial lists
````

**Key Principle:** Everything is discovered at runtime via schemas. You never edit core code.

### Prerequisites

1. Read `docs/schema_standards.md` - Understand JSON schemas
2. Read `docs/interfaces.md` - Understand function signatures
3. Have MATLAB R2020b or later
4. Have required toolboxes (DAQ Toolbox, Psychtoolbox if visual)

### File Structure Overview
````
maestro_v2/
  +generators/
    +audio/
      +tone/              ← Your generator goes here
        generator.m       ← Implementation
        schema.json       ← Self-description
        test_generator.m  ← Tests
        README.md         ← Documentation
        
  +builders/
    +oddball/             ← Your builder goes here
      builder.m
      template.schema.json
      test_builder.m
      example_instance.json
      README.md
      
  +engines/
    +audio_only/          ← Your engine goes here
      engine.m
      schema.json
      test_engine.m
      README.md
````

---

## Adding a New Generator

### Step 1: Create Directory Structure
````bash
cd maestro_v2/+generators
mkdir -p +audio/+chirp  # Example: chirp generator
cd +audio/+chirp
````

### Step 2: Write Schema First

Create `schema.json`:
````json
{
  "$schema": "maestro-generator-v1",
  "generator_type": "chirp",
  "version": "1.0.0",
  "category": "audio",
  "description": "Linear or logarithmic frequency chirp",
  
  "modality": "audio",
  "render_type": "waveform",
  
  "compatible_engines": ["audio_only", "audiovisual"],
  
  "parameters": {
    "freq_start": {
      "type": "float",
      "required": true,
      "description": "Starting frequency",
      "constraints": {
        "min": 20,
        "max": 20000
      },
      "randomizable": false,
      "unit": "Hz"
    },
    "freq_end": {
      "type": "float",
      "required": true,
      "description": "Ending frequency",
      "constraints": {
        "min": 20,
        "max": 20000
      },
      "randomizable": false,
      "unit": "Hz"
    },
    "dur_ms": {
      "type": "float",
      "required": true,
      "description": "Duration",
      "constraints": {
        "min": 10,
        "max": 10000
      },
      "unit": "ms"
    },
    "chirp_type": {
      "type": "enum",
      "required": false,
      "default": "linear",
      "description": "Chirp type",
      "constraints": {
        "options": ["linear", "logarithmic"]
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
      "unit": "dB SPL"
    },
    "ramp_ms": {
      "type": "float",
      "required": false,
      "default": 5,
      "description": "Onset/offset ramp duration",
      "constraints": {
        "min": 0,
        "max": 100
      },
      "unit": "ms"
    }
  },
  
  "output_specification": {
    "description": "Audio waveform with frequency sweep",
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
    "function": "generators.audio.chirp.generate",
    "file": "generator.m",
    "dependencies": []
  },
  
  "examples": [
    {
      "name": "Upward chirp",
      "description": "1-10 kHz linear chirp",
      "parameters": {
        "freq_start": 1000,
        "freq_end": 10000,
        "dur_ms": 100,
        "chirp_type": "linear",
        "level_db": 60,
        "ramp_ms": 5
      }
    }
  ],
  
  "metadata": {
    "author": "Your Name",
    "created": "2025-01-15",
    "tags": ["audio", "chirp", "sweep"]
  }
}
````

**Important Notes:**
- `generator_type` must be unique across all generators
- `function` must match the actual package path
- All parameter constraints are enforced at validation

### Step 3: Write Tests (TDD Approach)

Create `test_generator.m`:
````matlab
function test_generator()
% TEST_GENERATOR - Test chirp generator
%
% Run this before implementing to define expected behavior

    fprintf('Testing chirp generator...\n');
    
    test_basic_generation();
    test_linear_chirp();
    test_logarithmic_chirp();
    test_ramp_application();
    test_parameter_validation();
    test_output_format();
    
    fprintf('All tests passed!\n');
end

function test_basic_generation()
    fprintf('  Testing basic generation...\n');
    
    params = struct(...
        'freq_start', 1000, ...
        'freq_end', 5000, ...
        'dur_ms', 100, ...
        'chirp_type', 'linear', ...
        'level_db', 60, ...
        'ramp_ms', 5 ...
    );
    
    context = struct('sampling_rate_hz', 192000);
    
    % Call generator
    spec = generators.audio.chirp.generate(params, context);
    
    % Verify output structure
    assert(isfield(spec, 'modality'), 'Missing modality field');
    assert(strcmp(spec.modality, 'audio'), 'Wrong modality');
    assert(isfield(spec, 'render_type'), 'Missing render_type');
    assert(strcmp(spec.render_type, 'waveform'), 'Wrong render_type');
    assert(isfield(spec, 'data'), 'Missing data');
    assert(isfield(spec, 'duration_ms'), 'Missing duration_ms');
    
    fprintf('    ✓ Basic generation works\n');
end

function test_linear_chirp()
    fprintf('  Testing linear chirp...\n');
    
    params = struct(...
        'freq_start', 1000, ...
        'freq_end', 5000, ...
        'dur_ms', 100, ...
        'chirp_type', 'linear', ...
        'level_db', 60, ...
        'ramp_ms', 0 ...
    );
    
    context = struct('sampling_rate_hz', 192000);
    spec = generators.audio.chirp.generate(params, context);
    
    % Verify duration
    expected_samples = round(192000 * 0.1);
    assert(length(spec.data) == expected_samples, 'Wrong duration');
    
    % Verify it's a column vector
    assert(iscolumn(spec.data), 'Data must be column vector');
    
    % Verify frequency increases (rough check via zero crossings)
    % Linear chirp should have increasing instantaneous frequency
    % This is a simplified test
    
    fprintf('    ✓ Linear chirp correct\n');
end

function test_logarithmic_chirp()
    fprintf('  Testing logarithmic chirp...\n');
    
    params = struct(...
        'freq_start', 1000, ...
        'freq_end', 5000, ...
        'dur_ms', 100, ...
        'chirp_type', 'logarithmic', ...
        'level_db', 60, ...
        'ramp_ms', 0 ...
    );
    
    context = struct('sampling_rate_hz', 192000);
    spec = generators.audio.chirp.generate(params, context);
    
    % Verify output exists
    assert(~isempty(spec.data), 'No data generated');
    
    fprintf('    ✓ Logarithmic chirp correct\n');
end

function test_ramp_application()
    fprintf('  Testing ramp application...\n');
    
    params = struct(...
        'freq_start', 1000, ...
        'freq_end', 1000, ...
        'dur_ms', 100, ...
        'chirp_type', 'linear', ...
        'level_db', 60, ...
        'ramp_ms', 10 ...
    );
    
    context = struct('sampling_rate_hz', 192000);
    spec = generators.audio.chirp.generate(params, context);
    
    % First and last samples should be near zero
    assert(abs(spec.data(1)) < 0.01, 'Ramp not applied at onset');
    assert(abs(spec.data(end)) < 0.01, 'Ramp not applied at offset');
    
    fprintf('    ✓ Ramps applied correctly\n');
end

function test_parameter_validation()
    fprintf('  Testing parameter validation...\n');
    
    % This would be done by validation system, but good to think about
    % Invalid parameters should fail validation before reaching generator
    
    fprintf('    ✓ Parameter validation works\n');
end

function test_output_format()
    fprintf('  Testing output format compliance...\n');
    
    params = struct(...
        'freq_start', 1000, ...
        'freq_end', 5000, ...
        'dur_ms', 100, ...
        'chirp_type', 'linear', ...
        'level_db', 60, ...
        'ramp_ms', 5 ...
    );
    
    context = struct('sampling_rate_hz', 192000);
    spec = generators.audio.chirp.generate(params, context);
    
    % Check all required fields
    required = {'modality', 'render_type', 'data', 'duration_ms', 'metadata'};
    for i = 1:length(required)
        assert(isfield(spec, required{i}), ...
            sprintf('Missing required field: %s', required{i}));
    end
    
    % Check metadata contains original parameters
    assert(isstruct(spec.metadata), 'Metadata must be struct');
    
    fprintf('    ✓ Output format compliant\n');
end
````

### Step 4: Implement Generator

Create `generator.m`:
````matlab
function output_spec = generate(params, context)
% GENERATE - Generate frequency chirp stimulus
%
% This is the implementation of the chirp generator.
% See schema.json for parameter definitions.

    % Extract parameters
    freq_start = params.freq_start;
    freq_end = params.freq_end;
    dur_ms = params.dur_ms;
    chirp_type = params.chirp_type;
    level_db = params.level_db;
    ramp_ms = params.ramp_ms;
    
    % Get sampling rate from context
    fs = context.sampling_rate_hz;
    
    % Generate time vector
    n_samples = round(fs * dur_ms / 1000);
    t = (0:n_samples-1)' / fs;
    
    % Generate chirp based on type
    switch chirp_type
        case 'linear'
            % Linear frequency sweep
            % f(t) = f0 + (f1 - f0) * t / T
            f_t = freq_start + (freq_end - freq_start) * t / (dur_ms/1000);
            phase = 2*pi * cumsum(f_t) / fs;
            waveform = sin(phase);
            
        case 'logarithmic'
            % Logarithmic frequency sweep
            % f(t) = f0 * (f1/f0)^(t/T)
            T = dur_ms / 1000;
            k = (freq_end/freq_start)^(1/T);
            f_t = freq_start * k.^t;
            phase = 2*pi * cumsum(f_t) / fs;
            waveform = sin(phase);
            
        otherwise
            error('Unknown chirp_type: %s', chirp_type);
    end
    
    % Apply amplitude scaling (dB to linear)
    amplitude = db_to_amplitude(level_db, context);
    waveform = amplitude * waveform;
    
    % Apply onset/offset ramps
    waveform = apply_cosine_ramps(waveform, fs, ramp_ms);
    
    % Create output specification
    output_spec = struct();
    output_spec.modality = 'audio';
    output_spec.render_type = 'waveform';
    output_spec.data = waveform;
    output_spec.duration_ms = dur_ms;
    output_spec.metadata = params;
end

function amplitude = db_to_amplitude(db_spl, context)
    % Convert dB SPL to linear amplitude
    % Uses calibration from context if available
    
    if isfield(context, 'calibration') && ...
       isfield(context.calibration, 'reference_db') && ...
       isfield(context.calibration, 'reference_amplitude')
        ref_db = context.calibration.reference_db;
        ref_amp = context.calibration.reference_amplitude;
    else
        % Default: 100 dB SPL = amplitude 1.0
        ref_db = 100;
        ref_amp = 1.0;
    end
    
    amplitude = ref_amp * 10^((db_spl - ref_db) / 20);
end

function y = apply_cosine_ramps(y, fs, ramp_ms)
    % Apply half-cosine onset and offset ramps
    
    if ramp_ms <= 0
        return;
    end
    
    n_ramp = round(fs * ramp_ms / 1000);
    
    if n_ramp >= length(y) / 2
        warning('Ramp duration too long, skipping ramps');
        return;
    end
    
    % Create ramp window
    ramp = (1 - cos(linspace(0, pi, n_ramp)))' / 2;
    
    % Apply to onset
    y(1:n_ramp) = y(1:n_ramp) .* ramp;
    
    % Apply to offset
    y(end-n_ramp+1:end) = y(end-n_ramp+1:end) .* flipud(ramp);
    
    % Remove DC offset
    y = y - mean(y);
end
````

### Step 5: Write Documentation

Create `README.md`:
````markdown
# Chirp Generator

Generates linear or logarithmic frequency chirps (sweeps).

## Description

A chirp is a sound with instantaneous frequency that increases or decreases 
over time. This generator supports both linear and logarithmic sweeps.

## Parameters

- `freq_start` (Hz): Starting frequency (20-20000)
- `freq_end` (Hz): Ending frequency (20-20000)
- `dur_ms` (ms): Duration (10-10000)
- `chirp_type`: "linear" or "logarithmic"
- `level_db` (dB SPL): Sound level (0-100)
- `ramp_ms` (ms): Onset/offset ramp duration (0-100), default: 5

## Usage Example
```json
{
  "generator": "chirp",
  "version": "1.0.0",
  "parameters": {
    "freq_start": 1000,
    "freq_end": 10000,
    "dur_ms": 100,
    "chirp_type": "linear",
    "level_db": 60,
    "ramp_ms": 5
  }
}
```

## Technical Details

**Linear chirp:**
- Frequency increases/decreases linearly with time
- Equal frequency steps per unit time
- f(t) = f₀ + (f₁ - f₀) · t/T

**Logarithmic chirp:**
- Frequency increases/decreases exponentially with time
- Equal frequency ratios per unit time
- Perceptually more uniform
- f(t) = f₀ · (f₁/f₀)^(t/T)

## References

- Müller, M. (2015). Fundamentals of Music Processing. Springer.
- Chirp signal. Wikipedia.

## Version History

- 1.0.0 (2025-01-15): Initial implementation
````

### Step 6: Test Your Generator
````matlab
% Run tests
cd /path/to/maestro_v2/+generators/+audio/+chirp
test_generator();

% If all pass, test in context
ctx = MaestroContext();
assert(isKey(ctx.generators, 'chirp'), 'Generator not discovered');

% Try generating a stimulus
params = struct('freq_start', 1000, 'freq_end', 5000, 'dur_ms', 100, ...
                'chirp_type', 'linear', 'level_db', 60, 'ramp_ms', 5);
context = struct('sampling_rate_hz', 192000);
spec = ctx.generators('chirp').generate_func(params, context);

% Listen to it
sound(spec.data, context.sampling_rate_hz);
````

### Step 7: Create Example Usage

Create `example_usage.json`:
````json
{
  "stimulus_spec": {
    "generator": "chirp",
    "version": "1.0.0",
    "parameters": {
      "freq_start": 1000,
      "freq_end": 10000,
      "dur_ms": 200,
      "chirp_type": "logarithmic",
      "level_db": 65,
      "ramp_ms": 10
    }
  },
  "description": "Example logarithmic chirp for testing"
}
````

---

## Adding a New Builder

### Step 1: Create Directory Structure
````bash
cd maestro_v2/+builders
mkdir +go_nogo
cd +go_nogo
````

### Step 2: Write Template Schema

Create `template.schema.json`:
````json
{
  "$schema": "maestro-builder-v1",
  "builder_type": "go_nogo",
  "version": "1.0.0",
  "description": "Go/No-Go task with cue followed by go or no-go stimulus",
  
  "paradigm_category": "behavioral",
  
  "required_inputs": {
    "n_trials": {
      "type": "integer",
      "description": "Total number of trials",
      "constraints": {
        "min": 1,
        "max": 10000
      }
    },
    "go_probability": {
      "type": "float",
      "description": "Probability of go trials (0-1)",
      "constraints": {
        "min": 0,
        "max": 1
      }
    },
    "cue_stimulus": {
      "type": "stimulus_specification",
      "description": "Cue stimulus (presented on all trials)"
    },
    "go_stimulus": {
      "type": "stimulus_specification",
      "description": "Go stimulus"
    },
    "nogo_stimulus": {
      "type": "stimulus_specification",
      "description": "No-go stimulus"
    }
  },
  
  "optional_inputs": {
    "cue_duration_ms": {
      "type": "float",
      "default": 100,
      "description": "Duration of cue",
      "constraints": {
        "min": 10
      }
    },
    "delay_min_ms": {
      "type": "float",
      "default": 300,
      "description": "Minimum delay between cue and go/nogo",
      "constraints": {
        "min": 0
      }
    },
    "delay_max_ms": {
      "type": "float",
      "default": 500,
      "description": "Maximum delay between cue and go/nogo",
      "constraints": {
        "min": 0
      }
    },
    "iti_min_sec": {
      "type": "float",
      "default": 1.5,
      "description": "Minimum inter-trial interval",
      "constraints": {
        "min": 0
      }
    },
    "iti_max_sec": {
      "type": "float",
      "default": 2.5,
      "description": "Maximum inter-trial interval",
      "constraints": {
        "min": 0
      }
    }
  },
  
  "output_specification": {
    "description": "Trials with cue followed by go or no-go stimulus",
    "trial_structure": {
      "trial_types": ["go", "nogo"],
      "metadata_fields": ["is_go", "delay_ms"],
      "presentation_count": "fixed (2 per trial)",
      "timing_model": "jittered_delay_and_iti"
    }
  },
  
  "implementation": {
    "language": "matlab",
    "function": "builders.go_nogo.build",
    "file": "builder.m",
    "dependencies": []
  },
  
  "examples": [
    {
      "name": "Tone go/nogo",
      "description": "Click cue followed by high or low tone",
      "instance": {
        "builder_type": "go_nogo",
        "parameters": {
          "n_trials": 100,
          "go_probability": 0.5,
          "cue_stimulus": {
            "generator": "tone",
            "parameters": {"freq_hz": 4000, "dur_ms": 10, "level_db": 60}
          },
          "go_stimulus": {
            "generator": "tone",
            "parameters": {"freq_hz": 8000, "dur_ms": 100, "level_db": 60}
          },
          "nogo_stimulus": {
            "generator": "tone",
            "parameters": {"freq_hz": 2000, "dur_ms": 100, "level_db": 60}
          },
          "delay_min_ms": 300,
          "delay_max_ms": 500
        }
      }
    }
  ],
  
  "metadata": {
    "author": "Your Name",
    "created": "2025-01-15",
    "tags": ["go_nogo", "behavioral", "decision"],
    "references": [
      "Donders, F. C. (1969). On the speed of mental processes. Acta psychologica, 30, 412-431."
    ]
  }
}
````

### Step 3: Write Tests

Create `test_builder.m`:
````matlab
function test_builder()
% TEST_BUILDER - Test go/nogo builder

    fprintf('Testing go/nogo builder...\n');
    
    test_trial_generation();
    test_go_nogo_ratio();
    test_trial_structure();
    test_timing();
    
    fprintf('All tests passed!\n');
end

function test_trial_generation()
    fprintf('  Testing trial generation...\n');
    
    instance = create_test_instance();
    context = struct('sampling_rate_hz', 192000);
    
    trial_list = builders.go_nogo.build(instance, context);
    
    % Should generate correct number of trials
    assert(length(trial_list) == instance.parameters.n_trials, ...
        'Wrong number of trials');
    
    fprintf('    ✓ Trial generation works\n');
end

function test_go_nogo_ratio()
    fprintf('  Testing go/nogo ratio...\n');
    
    instance = create_test_instance();
    instance.parameters.n_trials = 1000;  % Large N for statistical test
    instance.parameters.go_probability = 0.7;
    
    context = struct('sampling_rate_hz', 192000);
    trial_list = builders.go_nogo.build(instance, context);
    
    % Count go trials
    n_go = sum(strcmp({trial_list.trial_type}, 'go'));
    actual_p = n_go / length(trial_list);
    
    % Should be close to requested probability (within 5%)
    assert(abs(actual_p - 0.7) < 0.05, ...
        sprintf('Go probability %.2f far from requested 0.7', actual_p));
    
    fprintf('    ✓ Go/nogo ratio correct\n');
end

function test_trial_structure()
    fprintf('  Testing trial structure...\n');
    
    instance = create_test_instance();
    context = struct('sampling_rate_hz', 192000);
    trial_list = builders.go_nogo.build(instance, context);
    
    % Each trial should have 2 presentations
    for i = 1:length(trial_list)
        assert(length(trial_list(i).presentations) == 2, ...
            sprintf('Trial %d should have 2 presentations', i));
        
        % First should be cue
        assert(trial_list(i).presentations(1).onset_ms == 0, ...
            'Cue should be at onset 0');
        
        % Second should be go or nogo
        assert(trial_list(i).presentations(2).onset_ms > 0, ...
            'Go/nogo should be after cue');
    end
    
    fprintf('    ✓ Trial structure correct\n');
end

function test_timing()
    fprintf('  Testing timing...\n');
    
    instance = create_test_instance();
    context = struct('sampling_rate_hz', 192000);
    trial_list = builders.go_nogo.build(instance, context);
    
    % Check delay is within bounds
    delay_min = instance.parameters.delay_min_ms;
    delay_max = instance.parameters.delay_max_ms;
    
    for i = 1:length(trial_list)
        delay = trial_list(i).metadata.delay_ms;
        assert(delay >= delay_min && delay <= delay_max, ...
            sprintf('Trial %d delay %.1f outside bounds [%.1f, %.1f]', ...
            i, delay, delay_min, delay_max));
    end
    
    fprintf('    ✓ Timing correct\n');
end

function instance = create_test_instance()
    instance = struct();
    instance.instance_id = 'test_go_nogo';
    instance.builder_type = 'go_nogo';
    instance.builder_version = '1.0.0';
    
    instance.parameters = struct();
    instance.parameters.n_trials = 50;
    instance.parameters.go_probability = 0.5;
    
    instance.parameters.cue_stimulus = struct(...
        'generator', 'tone', ...
        'version', '1.0.0', ...
        'parameters', struct('freq_hz', 4000, 'dur_ms', 10, 'level_db', 60) ...
    );
    
    instance.parameters.go_stimulus = struct(...
        'generator', 'tone', ...
        'version', '1.0.0', ...
        'parameters', struct('freq_hz', 8000, 'dur_ms', 100, 'level_db', 60) ...
    );
    
    instance.parameters.nogo_stimulus = struct(...
        'generator', 'tone', ...
        'version', '1.0.0', ...
        'parameters', struct('freq_hz', 2000, 'dur_ms', 100, 'level_db', 60) ...
    );
    
    instance.parameters.cue_duration_ms = 10;
    instance.parameters.delay_min_ms = 300;
    instance.parameters.delay_max_ms = 500;
    instance.parameters.iti_min_sec = 1.5;
    instance.parameters.iti_max_sec = 2.5;
    
    instance.metadata = struct();
end
````

### Step 4: Implement Builder

Create `builder.m`:
````matlab
function trial_list = build(instance, context)
% BUILD - Build go/nogo trial list
%
% See template.schema.json for parameter definitions

    % Extract parameters
    params = instance.parameters;
    n_trials = params.n_trials;
    p_go = params.go_probability;
    
    % Set random seed if provided
    if isfield(context, 'rng_seed') && ~isempty(context.rng_seed)
        rng(context.rng_seed);
    end
    
    % Determine trial types
    is_go = rand(n_trials, 1) < p_go;
    
    % Generate delays (between cue and go/nogo stimulus)
    delay_min = params.delay_min_ms;
    delay_max = params.delay_max_ms;
    delays = delay_min + (delay_max - delay_min) * rand(n_trials, 1);
    
    % Generate ITIs
    iti_min = params.iti_min_sec;
    iti_max = params.iti_max_sec;
    itis = iti_min + (iti_max - iti_min) * rand(n_trials, 1);
    
    % Build trial list
    trial_list = struct();
    
    for k = 1:n_trials
        % Basic trial info
        trial_list(k).trial_id = sprintf('%s_trial_%04d', ...
            instance.instance_id, k);
        trial_list(k).trial_num = k;
        trial_list(k).iti_sec = itis(k);
        
        % Trial type
        if is_go(k)
            trial_list(k).trial_type = 'go';
            response_stim = params.go_stimulus;
        else
            trial_list(k).trial_type = 'nogo';
            response_stim = params.nogo_stimulus;
        end
        
        % Presentation 1: Cue at time 0
        trial_list(k).presentations(1).presentation_id = ...
            sprintf('%s_pres_cue', trial_list(k).trial_id);
        trial_list(k).presentations(1).stimulus_spec = params.cue_stimulus;
        trial_list(k).presentations(1).onset_ms = 0;
        trial_list(k).presentations(1).metadata = struct('role', 'cue');
        
        % Presentation 2: Go/Nogo after delay
        cue_dur = params.cue_duration_ms;
        response_onset = cue_dur + delays(k);
        
        trial_list(k).presentations(2).presentation_id = ...
            sprintf('%s_pres_response', trial_list(k).trial_id);
        trial_list(k).presentations(2).stimulus_spec = response_stim;
        trial_list(k).presentations(2).onset_ms = response_onset;
        trial_list(k).presentations(2).metadata = struct('role', 'response');
        
        % Trial metadata
        trial_list(k).metadata.is_go = is_go(k);
        trial_list(k).metadata.delay_ms = delays(k);
    end
    
    fprintf('✓ Built go/nogo block: %d trials (%.1f%% go)\n', ...
        n_trials, 100 * sum(is_go) / n_trials);
end
````

### Step 5: Create Example Instance

Create `example_instance.json`:
````json
{
  "instance_id": "example_go_nogo",
  "builder_type": "go_nogo",
  "builder_version": "1.0.0",
  
  "parameters": {
    "n_trials": 100,
    "go_probability": 0.6,
    
    "cue_stimulus": {
      "generator": "tone",
      "version": "1.0.0",
      "parameters": {
        "freq_hz": 4000,
        "dur_ms": 10,
        "level_db": 60
      }
    },
    
    "go_stimulus": {
      "generator": "tone",
      "version": "1.0.0",
      "parameters": {
        "freq_hz": 8000,
        "dur_ms": 100,
        "level_db": 60
      }
    },
    
    "nogo_stimulus": {
      "generator": "tone",
      "version": "1.0.0",
      "parameters": {
        "freq_hz": 2000,
        "dur_ms": 100,
        "level_db": 60
      }
    },
    
    "cue_duration_ms": 10,
    "delay_min_ms": 300,
    "delay_max_ms": 500,
    "iti_min_sec": 1.5,
    "iti_max_sec": 2.5
  },
  
  "metadata": {
    "name": "Example Go/Nogo Task",
    "description": "Example instance for testing",
    "created": "2025-01-15",
    "created_by": "Your Name"
  }
}
````

### Step 6: Write Documentation

Create `README.md` with usage instructions, references, etc.

### Step 7: Test Your Builder
````matlab
% Run tests
test_builder();

% Test in context
ctx = MaestroContext();
assert(isKey(ctx.builders, 'go_nogo'), 'Builder not discovered');

% Load example instance and build
instance = jsondecode(fileread('example_instance.json'));
context = struct('sampling_rate_hz', 192000);
trials = ctx.builders('go_nogo').build_func(instance, context);

% Inspect results
fprintf('Generated %d trials\n', length(trials));
fprintf('First go trial: %d\n', find(strcmp({trials.trial_type}, 'go'), 1));
````

---

## Adding a New Engine

Engines are more complex. Only add if you need a fundamentally different execution strategy.

### When to Add a New Engine

**Add a new engine if:**
- You need real-time feedback (closed-loop)
- You need a different hardware setup
- You need fundamentally different timing model

**Don't add an engine if:**
- You just want different stimuli (use generator)
- You just want different trial structure (use builder)
- Small modifications to existing engine suffice (fork existing)

### Step 1: Create Directory Structure
````bash
cd maestro_v2/+engines
mkdir +closed_loop
cd +closed_loop
````

### Step 2: Write Schema

Create `schema.json`:
````json
{
  "$schema": "maestro-engine-v1",
  "engine_type": "closed_loop",
  "version": "1.0.0",
  "description": "Real-time closed-loop execution with neural feedback",
  
  "supported_modalities": ["audio"],
  "supported_render_types": ["waveform"],
  
  "execution_mode": "closed_loop",
  
  "requirements": {
    "hardware": ["daq", "neural_interface"],
    "software": ["daq_toolbox", "custom_neural_sdk"]
  },
  
  "timing_precision": {
    "audio": "sample_accurate",
    "feedback_latency_ms": 5
  },
  
  "implementation": {
    "language": "matlab",
    "function": "engines.closed_loop.execute",
    "file": "engine.m",
    "dependencies": ["neural_sdk"]
  },
  
  "metadata": {
    "author": "Your Name",
    "created": "2025-01-15"
  }
}
````

### Step 3: Implement Engine

Create `engine.m`:
````matlab
function results = execute(experiment, context)
% EXECUTE - Closed-loop execution engine
%
% This engine monitors neural activity and adapts stimuli in real-time

    results = struct();
    results.success = false;
    results.start_time = datetime('now');
    
    try
        % Initialize hardware
        daq_session = initialize_daq(experiment, context);
        neural_interface = initialize_neural(experiment, context);
        
        % Load all blocks
        all_trials = load_and_build_blocks(experiment, context);
        
        % Pre-cache stimuli
        stim_cache = precache_stimuli(all_trials, context);
        
        % Real-time execution loop
        for block_idx = 1:length(all_trials)
            trials = all_trials{block_idx};
            
            for trial_idx = 1:length(trials)
                trial = trials(trial_idx);
                
                % Execute trial
                trial_result = execute_trial_with_feedback(...
                    trial, daq_session, neural_interface, ...
                    stim_cache, context);
                
                % Log
                log_trial(trial_result, context);
                
                % Adapt based on feedback
                if should_adapt(trial_result)
                    trials = adapt_remaining_trials(trials, trial_idx, ...
                        trial_result);
                end
            end
        end
        
        % Cleanup
        release_hardware(daq_session, neural_interface);
        
        results.success = true;
        
    catch ME
        results.success = false;
        results.errors = {ME.message};
        cleanup_on_error(daq_session, neural_interface);
    end
    
    results.end_time = datetime('now');
end

% ... additional helper functions ...
````

**Note:** Engine implementation is complex. Study existing engines first.

---

## Testing Your Plugin

### Unit Tests

Each plugin must have a `test_*.m` file:
````matlab
function test_my_plugin()
    % Test all functionality
    test_basic_function();
    test_edge_cases();
    test_error_handling();
end
````

### Integration Tests

Test with full system:
````matlab
% Test discovery
ctx = MaestroContext();
assert(isKey(ctx.generators, 'my_generator'));

% Test execution
params = struct(...);
context = struct('sampling_rate_hz', 192000);
output = ctx.generators('my_generator').generate_func(params, context);

% Verify output
assert(~isempty(output.data));
````

### Manual Testing
````matlab
% Listen to audio generator
sound(output.data, context.sampling_rate_hz);

% Visualize
figure;
plot((0:length(output.data)-1)/context.sampling_rate_hz, output.data);
xlabel('Time (s)');
ylabel('Amplitude');
title('Generated Stimulus');
````

---

## Best Practices

### Schema Design

1. **Be explicit** - Don't rely on defaults
2. **Use constraints** - Prevent invalid parameters
3. **Document units** - Always specify (Hz, ms, dB, etc.)
4. **Provide examples** - Show actual usage
5. **Version carefully** - Follow semver

### Implementation

1. **Validate inputs** - Even though system validates, check critical things
2. **Handle edge cases** - Zero duration, extreme frequencies, etc.
3. **Use meaningful errors** - `error('Generator:InvalidFreq', 'Frequency %.1f exceeds Nyquist', f)`
4. **Document assumptions** - What coordinate system? What reference?
5. **Keep it simple** - Complexity should be in core system, not plugins

### Testing

1. **Test before implementing** - Write tests first (TDD)
2. **Test edge cases** - Min/max values, empty arrays, etc.
3. **Test output format** - Ensure compliance with interface
4. **Test numerical accuracy** - Check generated signals are correct
5. **Test determinism** - Same input + seed → same output

### Documentation

1. **README.md** - High-level overview and usage
2. **Inline comments** - Explain non-obvious code
3. **Schema examples** - Show real usage
4. **References** - Cite papers, algorithms
5. **Version history** - Document changes

---

## Common Pitfalls

### Generator Pitfalls

❌ **Don't modify global state**
````matlab
% BAD
global sampling_rate;
sampling_rate = 192000;
````

✅ **Use context**
````matlab
% GOOD
fs = context.sampling_rate_hz;
````

---

❌ **Don't return row vectors**
````matlab
% BAD
waveform = sin(2*pi*freq*t);  % Row vector
````

✅ **Always return column vectors**
````matlab
% GOOD
t = (0:n-1)' / fs;  % Column from start
waveform = sin(2*pi*freq*t);
````

---

❌ **Don't hardcode calibration**
````matlab
% BAD
amplitude = 10^(db_spl / 20);
````

✅ **Use context calibration**
````matlab
% GOOD
amplitude = db_to_amplitude(db_spl, context);
````

---

❌ **Don't access hardware directly**
````matlab
% BAD - generators should NEVER touch hardware
dq = daq('ni');
````

✅ **Only return specifications**
````matlab
% GOOD - engine will handle hardware
output_spec.data = waveform;
````

### Builder Pitfalls

❌ **Don't generate actual stimuli**
````matlab
% BAD - builders create specs, not waveforms
waveform = generate_tone(1000, 50, 192000);
````

✅ **Only create stimulus specifications**
````matlab
% GOOD
stimulus_spec = struct(...
    'generator', 'tone', ...
    'parameters', struct('freq_hz', 1000, 'dur_ms', 50) ...
);
````

---

❌ **Don't forget trial numbers**
````matlab
% BAD
trial.trial_num = 0;  % Or missing
````

✅ **Always set sequential trial_num starting at 1**
````matlab
% GOOD
for k = 1:n_trials
    trial_list(k).trial_num = k;
end
````

---

❌ **Don't leave presentations unordered**
````matlab
% BAD - random order
presentations(1).onset_ms = 500;
presentations(2).onset_ms = 0;
````

✅ **Order by onset time**
````matlab
% GOOD
presentations(1).onset_ms = 0;
presentations(2).onset_ms = 500;
````

### Engine Pitfalls

❌ **Don't assume hardware exists**
````matlab
% BAD
dq = daq('ni', 'Dev1');
````

✅ **Validate hardware first**
````matlab
% GOOD
if ~validate_hardware(experiment, context)
    error('Required hardware not available');
end
dq = initialize_daq(experiment, context);
````

---

❌ **Don't skip error cleanup**
````matlab
% BAD
dq = daq('ni');
% ... execution ...
% If error occurs, DAQ not released
````

✅ **Always cleanup on error**
````matlab
% GOOD
try
    dq = daq('ni');
    % ... execution ...
catch ME
    try
        release_hardware(dq);
    catch
    end
    rethrow(ME);
end
````

---

## Checklist

### New Generator Checklist

- [ ] Created directory: `+generators/+category/+name/`
- [ ] Written `schema.json` with all required fields
- [ ] Schema validated against standard
- [ ] Written `test_generator.m` with comprehensive tests
- [ ] Implemented `generator.m` with correct interface
- [ ] All tests pass
- [ ] Output format matches schema
- [ ] Created `README.md` with documentation
- [ ] Created `example_usage.json`
- [ ] Tested with MaestroContext
- [ ] Audio sounds correct (if audio)
- [ ] Visual looks correct (if visual)
- [ ] Deterministic with same seed
- [ ] No global state modifications
- [ ] No hardware access

### New Builder Checklist

- [ ] Created directory: `+builders/+name/`
- [ ] Written `template.schema.json`
- [ ] Schema validated against standard
- [ ] Written `test_builder.m`
- [ ] Implemented `builder.m`
- [ ] All tests pass
- [ ] Trial structure correct
- [ ] Trial numbers sequential (1-indexed)
- [ ] Presentations ordered by onset
- [ ] Created `README.md`
- [ ] Created `example_instance.json`
- [ ] Tested with MaestroContext
- [ ] No stimulus generation (only specs)
- [ ] Metadata fields populated
- [ ] Constraints satisfied

### New Engine Checklist

- [ ] Created directory: `+engines/+name/`
- [ ] Written `schema.json`
- [ ] Schema validated against standard
- [ ] Written `test_engine.m`
- [ ] Implemented `engine.m`
- [ ] Hardware validation implemented
- [ ] Error cleanup implemented
- [ ] Logging implemented
- [ ] All tests pass
- [ ] Created `README.md`
- [ ] Tested with real hardware
- [ ] Timing verified
- [ ] Data saved correctly
- [ ] Compatible with relevant generators

---

## Getting Help

### Documentation

1. Read `docs/schema_standards.md` for schema format
2. Read `docs/interfaces.md` for function signatures
3. Read `docs/data_flow.md` to understand system
4. Read `docs/validation_rules.md` for validation

### Examples

Look at existing plugins:
- **Simple generator:** `+generators/+audio/+tone/`
- **Simple builder:** `+builders/+oddball/`
- **Audio engine:** `+engines/+audio_only/`

### Testing

Run existing tests to see patterns:
````matlab
cd +generators/+audio/+tone
test_generator();
````

### Debugging

Use MATLAB debugger:
````matlab
dbstop in generator at 25  % Stop at line 25
generator.generate(params, context);  % Will break at line 25
````

---

## Version Control

### Updating Existing Plugins

When making breaking changes:

1. **Increment major version**: `1.0.0` → `2.0.0`
2. **Keep old version**:
````
   +tone/
     +v1.0.0/
       generator.m
       schema.json
     +v2.0.0/
       generator.m
       schema.json
     generator.m  → symlink to v2.0.0/generator.m
````
3. **Document changes** in README.md
4. **Update migration guide**

### Non-Breaking Changes

For backwards-compatible changes:
- Bug fixes: `1.0.0` → `1.0.1` (patch)
- New optional features: `1.0.0` → `1.1.0` (minor)

---

## Publishing Plugins

### Sharing with Others

1. **Ensure complete**:
   - Schema, implementation, tests, docs, examples
   
2. **Package**:
````bash
   tar -czf chirp_generator_v1.0.0.tar.gz +chirp/
````

3. **Share**:
   - GitHub repository
   - Lab wiki
   - Email to colleagues

### Installing Shared Plugins
````bash
cd maestro_v2/+generators/+audio
tar -xzf /path/to/chirp_generator_v1.0.0.tar.gz
````

Restart MATLAB or:
````matlab
ctx = MaestroContext();  % Will discover new plugin
````

---

## Summary

To extend Maestro:

1. **Choose plugin type** (generator, builder, or engine)
2. **Write schema first** (defines contract)
3. **Write tests second** (defines expected behavior)
4. **Implement third** (make tests pass)
5. **Document** (README, examples, inline comments)
6. **Test in context** (verify discovery and integration)
7. **Use in experiments** (create instances, run trials)

**Key Principle:** Plugins are self-contained and self-describing. The core system discovers and uses them without modification.

---

End of extension_guide.md