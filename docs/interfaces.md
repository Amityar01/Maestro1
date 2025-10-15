# Maestro Interface Specifications v1.0

This document defines all MATLAB function signatures and contracts for the Maestro system.

## Table of Contents
1. [Generator Interface](#generator-interface)
2. [Builder Interface](#builder-interface)
3. [Engine Interface](#engine-interface)
4. [Core System Interfaces](#core-system-interfaces)
5. [Data Structures](#data-structures)

---

## Generator Interface

All stimulus generators must implement this interface.

### Function Signature
```matlab
function output_spec = generate(params, context)
% GENERATE - Generate a stimulus specification
%
% This is the universal interface that all generators must implement.
%
% INPUTS:
%   params  - struct, validated parameters matching generator schema
%             All required parameters guaranteed to be present
%             All values guaranteed to satisfy constraints
%
%   context - struct with runtime information:
%             .sampling_rate_hz  - integer, DAQ sampling rate
%             .calibration       - struct, hardware calibration data
%             .rng_seed          - integer, random seed (if specified)
%             .generators        - containers.Map, available generators
%             .custom            - struct, any custom context data
%
% OUTPUTS:
%   output_spec - struct with standardized format:
%                 .modality      - string: 'audio' | 'visual' | 'multimodal'
%                 .render_type   - string: 'waveform' | 'draw_commands' | 'compound'
%                 .data          - format depends on render_type (see below)
%                 .duration_ms   - numeric, expected duration in milliseconds
%                 .metadata      - struct, generator-specific metadata
%
% RENDER TYPE FORMATS:
%
%   'waveform' (for audio):
%       .data = column vector of audio samples (Nx1 double)
%
%   'draw_commands' (for visual):
%       .data = struct or array of structs with:
%               .type          - string: 'rect' | 'oval' | 'gabor' | 'texture' | ...
%               .position_deg  - [x, y] position in visual degrees
%               .size_deg      - [width, height] in visual degrees
%               .rotation_deg  - scalar, rotation angle
%               .color         - [R, G, B] or [R, G, B, A] in range [0, 255]
%               ... additional type-specific fields
%
%   'compound' (for multimodal):
%       .data = struct with:
%               .audio  - output_spec from audio generator
%               .visual - output_spec from visual generator
%               .sync   - struct with synchronization info:
%                         .type   - 'simultaneous' | 'audio_first' | 'visual_first'
%                         .delay_ms - delay between modalities (if applicable)
%
% REQUIREMENTS:
%   - Function must be deterministic for same params + rng_seed
%   - Must not modify global state
%   - Must not access hardware directly
%   - Must complete in reasonable time (< 1 second for typical stimulus)
%   - Must handle all edge cases gracefully (error with clear message)
%
% EXAMPLE:
%   params = struct('freq_hz', 1000, 'dur_ms', 50, 'level_db', 60);
%   context = struct('sampling_rate_hz', 192000);
%   spec = generate(params, context);
```

### Example Implementation: Tone Generator
```matlab
function output_spec = generate(params, context)
    % Extract parameters
    freq_hz = params.freq_hz;
    dur_ms = params.dur_ms;
    level_db = params.level_db;
    ramp_ms = params.ramp_ms; % Guaranteed to exist (required or has default)
    
    % Get sampling rate from context
    fs = context.sampling_rate_hz;
    
    % Generate time vector
    n_samples = round(fs * dur_ms / 1000);
    t = (0:n_samples-1)' / fs;
    
    % Generate sinusoid
    waveform = sin(2 * pi * freq_hz * t);
    
    % Apply amplitude (convert dB to linear)
    amplitude = db_to_amplitude(level_db, context.calibration);
    waveform = amplitude * waveform;
    
    % Apply onset/offset ramps
    waveform = apply_cosine_ramps(waveform, fs, ramp_ms);
    
    % Create output specification
    output_spec = struct();
    output_spec.modality = 'audio';
    output_spec.render_type = 'waveform';
    output_spec.data = waveform;
    output_spec.duration_ms = dur_ms;
    output_spec.metadata = params; % Store original parameters
end
```

---

## Builder Interface

All block builders must implement this interface.

### Function Signature
```matlab
function trial_list = build(instance, context)
% BUILD - Build a list of trials from a block instance
%
% This is the universal interface that all builders must implement.
%
% INPUTS:
%   instance - struct, validated block instance with:
%              .instance_id      - string, unique identifier
%              .builder_type     - string, type of builder
%              .builder_version  - string, semver version
%              .parameters       - struct, builder-specific parameters
%              .metadata         - struct, instance metadata
%
%   context  - struct with runtime information:
%              .generators       - containers.Map, available generators
%              .sampling_rate_hz - integer, for stimulus generation
%              .rng_seed         - integer, random seed (if specified)
%              .custom           - struct, any custom context
%
% OUTPUTS:
%   trial_list - array of trial structs with standardized format:
%                Each trial must have:
%                .trial_id        - string, unique identifier
%                .trial_num       - integer, 1-indexed sequential number
%                .trial_type      - string, builder-specific type
%                .presentations   - array of presentation structs (see below)
%                .iti_sec         - numeric, inter-trial interval in seconds
%                .metadata        - struct, trial-specific metadata
%
% PRESENTATION FORMAT:
%   Each element of trial.presentations is a struct with:
%       .presentation_id  - string, unique identifier
%       .stimulus_spec    - struct, complete stimulus specification with:
%                           .generator  - string, generator type
%                           .version    - string, generator version
%                           .parameters - struct, generator parameters
%       .onset_ms         - numeric, onset time relative to trial start
%       .metadata         - struct, presentation-specific metadata
%
% REQUIREMENTS:
%   - Trial numbers must be sequential starting from 1
%   - Presentations within a trial must be ordered by onset_ms
%   - Must respect all constraints specified in builder template
%   - Must be deterministic given same instance + rng_seed
%   - Must not access hardware
%   - Must not generate actual stimuli (only specifications)
%   - Should validate all parameters before building
%
% EXAMPLE:
%   instance = load_instance('instances/my_oddball.json');
%   context = struct('generators', gen_map, 'sampling_rate_hz', 192000);
%   trials = build(instance, context);
```

### Example Implementation: Oddball Builder
```matlab
function trial_list = build(instance, context)
    % Extract parameters
    params = instance.parameters;
    n_trials = params.n_trials;
    p_deviant = params.deviant_probability;
    standard_stim = params.standard_stimulus;
    deviant_stim = params.deviant_stimulus;
    
    % Set random seed if provided
    if isfield(context, 'rng_seed') && ~isempty(context.rng_seed)
        rng(context.rng_seed);
    end
    
    % Determine which trials are deviants
    is_deviant = rand(n_trials, 1) < p_deviant;
    
    % Apply ordering constraints if specified
    if isfield(params, 'order_constraint')
        switch params.order_constraint
            case 'no_consecutive_deviants'
                is_deviant = enforce_no_consecutive(is_deviant);
        end
    end
    
    % Generate ITI values
    iti_min = params.iti_min_sec;
    iti_max = params.iti_max_sec;
    iti_values = iti_min + (iti_max - iti_min) * rand(n_trials, 1);
    
    % Build trial list
    trial_list = struct();
    for k = 1:n_trials
        trial_list(k).trial_id = sprintf('%s_trial_%04d', instance.instance_id, k);
        trial_list(k).trial_num = k;
        trial_list(k).iti_sec = iti_values(k);
        
        if is_deviant(k)
            trial_list(k).trial_type = 'deviant';
            stim_spec = deviant_stim;
        else
            trial_list(k).trial_type = 'standard';
            stim_spec = standard_stim;
        end
        
        % Create single presentation at time 0
        trial_list(k).presentations(1).presentation_id = ...
            sprintf('%s_pres_1', trial_list(k).trial_id);
        trial_list(k).presentations(1).stimulus_spec = stim_spec;
        trial_list(k).presentations(1).onset_ms = 0;
        trial_list(k).presentations(1).metadata = struct();
        
        % Trial metadata
        trial_list(k).metadata.is_deviant = is_deviant(k);
    end
end

function is_deviant = enforce_no_consecutive(is_deviant)
    % Shuffle until no consecutive deviants
    max_attempts = 1000;
    for attempt = 1:max_attempts
        is_valid = true;
        for k = 1:length(is_deviant)-1
            if is_deviant(k) && is_deviant(k+1)
                is_valid = false;
                break;
            end
        end
        if is_valid
            return;
        end
        % Shuffle and try again
        is_deviant = is_deviant(randperm(length(is_deviant)));
    end
    warning('Could not satisfy no_consecutive_deviants after %d attempts', max_attempts);
end
```

---

## Engine Interface

All execution engines must implement this interface.

### Function Signature
```matlab
function results = execute(experiment, context)
% EXECUTE - Execute a complete experiment
%
% This is the universal interface that all engines must implement.
%
% INPUTS:
%   experiment - struct, validated experiment specification with:
%                .experiment_id    - string
%                .metadata         - struct
%                .global_settings  - struct
%                .sequence         - array of block references
%                .orchestration    - struct
%                .hardware         - struct
%
%   context    - struct with runtime information:
%                .generators       - containers.Map, available generators
%                .builders         - containers.Map, available builders
%                .block_instances  - containers.Map, loaded instances
%                .hardware_handles - struct, initialized hardware
%                .output_directory - string, where to save data
%
% OUTPUTS:
%   results - struct with execution summary:
%             .success              - boolean, overall success
%             .blocks_completed     - integer, number of blocks finished
%             .total_trials         - integer, total trials executed
%             .start_time           - datetime, experiment start
%             .end_time             - datetime, experiment end
%             .duration_sec         - numeric, total duration
%             .output_files         - struct, paths to saved files
%             .logs                 - struct, execution logs
%             .errors               - cell array of error messages (if any)
%
% RESPONSIBILITIES:
%   1. Load and validate all block instances
%   2. Build trial lists for all blocks
%   3. Generate stimuli from trial specifications
%   4. Execute trials in specified order
%   5. Handle timing and synchronization
%   6. Log all events with timestamps
%   7. Save data in standardized format
%   8. Handle errors gracefully
%   9. Clean up hardware resources
%
% ENGINE-SPECIFIC BEHAVIOR:
%   Different engines implement different execution strategies:
%   - 'audio_only': Pre-compile all waveforms, play as single stream
%   - 'audiovisual': Real-time loop with frame-by-frame rendering
%   - 'closed_loop': Real-time with feedback processing
%
% EXAMPLE:
%   experiment = load_experiment('experiments/my_session.json');
%   context = initialize_context();
%   results = execute(experiment, context);
```

### Example Implementation Skeleton: Audio-Only Engine
```matlab
function results = execute(experiment, context)
    % Initialize results
    results = struct();
    results.success = false;
    results.blocks_completed = 0;
    results.total_trials = 0;
    results.errors = {};
    results.start_time = datetime('now');
    
    try
        % Load all block instances
        blocks = load_all_blocks(experiment.sequence, context);
        
        % Build all trial lists
        all_trials = cell(length(blocks), 1);
        for i = 1:length(blocks)
            all_trials{i} = build_block(blocks{i}, context);
        end
        
        % Compile all stimuli into waveforms
        [ao_waveform, do_waveform, event_log] = compile_waveforms(all_trials, context);
        
        % Initialize hardware
        daq_session = initialize_daq(experiment.hardware.daq, context);
        
        % Execute (play waveforms)
        loopback_data = play_and_record(daq_session, ao_waveform, do_waveform);
        
        % Save data
        output_files = save_data(experiment, all_trials, ao_waveform, ...
                                 do_waveform, loopback_data, event_log, context);
        
        % Cleanup
        release_hardware(daq_session);
        
        % Update results
        results.success = true;
        results.blocks_completed = length(blocks);
        results.total_trials = sum(cellfun(@length, all_trials));
        results.output_files = output_files;
        
    catch ME
        results.success = false;
        results.errors{end+1} = ME.message;
        % Try to cleanup
        try
            release_hardware(daq_session);
        catch
        end
    end
    
    results.end_time = datetime('now');
    results.duration_sec = seconds(results.end_time - results.start_time);
end
```

---

## Core System Interfaces

### MaestroContext Class
```matlab
classdef MaestroContext < handle
    % MAESTROCONTEXT - Central registry and runtime context
    
    properties (SetAccess = private)
        generators      % containers.Map: generator_type -> generator_info
        builders        % containers.Map: builder_type -> builder_info
        engines         % containers.Map: engine_type -> engine_info
        stimulus_lib    % containers.Map: stimulus_id -> stimulus_spec
        instances       % containers.Map: instance_id -> block_instance
        experiments     % containers.Map: experiment_id -> experiment_spec
    end
    
    methods
        function obj = MaestroContext(base_path)
            % MAESTROCONTEXT - Initialize and discover all plugins
            %
            % INPUTS:
            %   base_path - string, root directory (default: pwd)
            
            if nargin < 1
                base_path = pwd;
            end
            
            obj.discover_all(base_path);
        end
        
        function discover_all(obj, base_path)
            % DISCOVER_ALL - Discover all available plugins and content
            
            obj.generators = discover_generators(fullfile(base_path, '+generators'));
            obj.builders = discover_builders(fullfile(base_path, '+builders'));
            obj.engines = discover_engines(fullfile(base_path, '+engines'));
            obj.stimulus_lib = load_stimulus_library(fullfile(base_path, 'stimuli'));
            obj.instances = discover_instances(fullfile(base_path, 'instances'));
            obj.experiments = discover_experiments(fullfile(base_path, 'experiments'));
            
            fprintf('Maestro Context Initialized:\n');
            fprintf('  Generators: %d\n', length(obj.generators));
            fprintf('  Builders: %d\n', length(obj.builders));
            fprintf('  Engines: %d\n', length(obj.engines));
            fprintf('  Stimulus Library: %d\n', length(obj.stimulus_lib));
            fprintf('  Block Instances: %d\n', length(obj.instances));
            fprintf('  Experiments: %d\n', length(obj.experiments));
        end
        
        function [is_valid, errors] = validate_spec(obj, spec, schema)
            % VALIDATE_SPEC - Validate a specification against a schema
            %
            % INPUTS:
            %   spec   - struct, specification to validate
            %   schema - struct, schema definition
            %
            % OUTPUTS:
            %   is_valid - boolean, true if valid
            %   errors   - cell array of error messages
        end
        
        function output_spec = generate_stimulus(obj, stim_spec, context)
            % GENERATE_STIMULUS - Generate a stimulus from specification
            %
            % INPUTS:
            %   stim_spec - struct, stimulus specification
            %   context   - struct, runtime context
            %
            % OUTPUTS:
            %   output_spec - struct, generated stimulus output
            
            % Get generator
            gen_info = obj.generators(stim_spec.generator);
            
            % Validate parameters
            [is_valid, errors] = obj.validate_spec(stim_spec.parameters, ...
                                                    gen_info.schema.parameters);
            if ~is_valid
                error('Invalid stimulus parameters: %s', strjoin(errors, ', '));
            end
            
            % Call generator
            output_spec = gen_info.generate_func(stim_spec.parameters, context);
        end
        
        function trial_list = build_block(obj, instance, context)
            % BUILD_BLOCK - Build trial list from block instance
            %
            % INPUTS:
            %   instance - struct, block instance specification
            %   context  - struct, runtime context
            %
            % OUTPUTS:
            %   trial_list - array of trial structs
            
            % Get builder
            builder_info = obj.builders(instance.builder_type);
            
            % Validate instance
            [is_valid, errors] = obj.validate_spec(instance, builder_info.schema);
            if ~is_valid
                error('Invalid block instance: %s', strjoin(errors, ', '));
            end
            
            % Call builder
            trial_list = builder_info.build_func(instance, context);
        end
        
        function results = run_experiment(obj, experiment_spec, context)
            % RUN_EXPERIMENT - Execute a complete experiment
            %
            % INPUTS:
            %   experiment_spec - struct, experiment specification
            %   context         - struct, runtime context (optional)
            %
            % OUTPUTS:
            %   results - struct, execution results
            
            % Get engine
            engine_info = obj.engines(experiment_spec.global_settings.engine_type);
            
            % Validate experiment
            [is_valid, errors] = obj.validate_spec(experiment_spec, engine_info.schema);
            if ~is_valid
                error('Invalid experiment: %s', strjoin(errors, ', '));
            end
            
            % Prepare context
            if nargin < 3
                context = struct();
            end
            context.generators = obj.generators;
            context.builders = obj.builders;
            context.block_instances = obj.instances;
            
            % Call engine
            results = engine_info.execute_func(experiment_spec, context);
        end
    end
end
```

### Discovery Functions
```matlab
function generators = discover_generators(base_path)
% DISCOVER_GENERATORS - Find all generator plugins
%
% INPUTS:
%   base_path - string, path to +generators directory
%
% OUTPUTS:
%   generators - containers.Map with:
%                key: generator_type (string)
%                value: struct with:
%                       .schema        - struct, parsed schema
%                       .generate_func - function_handle
%                       .path          - string, directory path
%                       .schema_file   - string, path to schema.json
%                       .impl_file     - string, path to generator.m
```
```matlab
function builders = discover_builders(base_path)
% DISCOVER_BUILDERS - Find all builder plugins
%
% INPUTS:
%   base_path - string, path to +builders directory
%
% OUTPUTS:
%   builders - containers.Map with:
%              key: builder_type (string)
%              value: struct with:
%                     .schema      - struct, parsed schema
%                     .build_func  - function_handle
%                     .path        - string, directory path
```
```matlab
function engines = discover_engines(base_path)
% DISCOVER_ENGINES - Find all execution engines
%
% INPUTS:
%   base_path - string, path to +engines directory
%
% OUTPUTS:
%   engines - containers.Map with:
%             key: engine_type (string)
%             value: struct with:
%                    .schema        - struct, parsed schema
%                    .execute_func  - function_handle
%                    .path          - string, directory path
```

### Validation Functions
```matlab
function [is_valid, errors] = validate_parameters(params, schema)
% VALIDATE_PARAMETERS - Validate parameters against schema
%
% INPUTS:
%   params - struct, parameters to validate
%   schema - struct, parameter definitions from schema
%
% OUTPUTS:
%   is_valid - boolean, true if all validations pass
%   errors   - cell array of error messages
%
% VALIDATION CHECKS:
%   1. All required parameters present
%   2. No unexpected parameters (unless schema allows)
%   3. Types match schema
%   4. Values satisfy constraints (min, max, options, etc.)
%   5. Cross-parameter validation (if specified in schema)
```
```matlab
function resolved_params = resolve_randomization(param_spec, rng_seed)
% RESOLVE_RANDOMIZATION - Convert randomization specs to concrete values
%
% INPUTS:
%   param_spec - value or randomization specification
%   rng_seed   - integer, random seed (optional)
%
% OUTPUTS:
%   resolved_params - concrete value
%
% HANDLES:
%   - Fixed values: return as-is
%   - random_uniform: sample from uniform distribution
%   - random_gaussian: sample from Gaussian distribution
%   - random_choice: sample from discrete options
```

---

## Data Structures

### Trial Structure (Standardized)
```matlab
trial = struct(...
    'trial_id', 'unique_string', ...           % Unique identifier
    'trial_num', 1, ...                        % Sequential number (1-indexed)
    'trial_type', 'string', ...                % Builder-specific type
    'presentations', [...], ...                % Array of presentation structs
    'iti_sec', 1.5, ...                        % Inter-trial interval
    'metadata', struct(...                     % Trial-specific metadata
        'is_deviant', false, ...
        'difficulty', 1, ...
        ...
    ) ...
);
```

### Presentation Structure (Standardized)
```matlab
presentation = struct(...
    'presentation_id', 'unique_string', ...    % Unique identifier
    'stimulus_spec', struct(...                % Complete stimulus spec
        'generator', 'tone', ...
        'version', '1.0.0', ...
        'parameters', struct(...) ...
    ), ...
    'onset_ms', 0, ...                         % Relative to trial start
    'metadata', struct(...) ...                % Presentation-specific
);
```

### Output Specification (from Generator)
```matlab
% For audio stimuli
output_spec = struct(...
    'modality', 'audio', ...
    'render_type', 'waveform', ...
    'data', waveform_column_vector, ...        % Nx1 double
    'duration_ms', 50, ...
    'metadata', struct(...) ...
);

% For visual stimuli
output_spec = struct(...
    'modality', 'visual', ...
    'render_type', 'draw_commands', ...
    'data', struct(...                         % Draw command(s)
        'type', 'rect', ...
        'position_deg', [0, 0], ...
        'size_deg', [1, 2], ...
        'color', [255, 255, 255], ...
        ...
    ), ...
    'duration_ms', 100, ...
    'metadata', struct(...) ...
);

% For multimodal stimuli
output_spec = struct(...
    'modality', 'multimodal', ...
    'render_type', 'compound', ...
    'data', struct(...
        'audio', audio_output_spec, ...
        'visual', visual_output_spec, ...
        'sync', struct('type', 'simultaneous', 'delay_ms', 0) ...
    ), ...
    'duration_ms', 100, ...
    'metadata', struct(...) ...
);
```

### Context Structure
```matlab
context = struct(...
    'sampling_rate_hz', 192000, ...            % DAQ sampling rate
    'generators', containers.Map(), ...         % Available generators
    'builders', containers.Map(), ...           % Available builders
    'calibration', struct(...                  % Hardware calibration
        'reference_db', 100, ...
        'reference_volts', 10, ...
        ...
    ), ...
    'rng_seed', 42, ...                        % Random seed (optional)
    'output_directory', 'data/', ...           % Where to save
    'custom', struct(...) ...                  % Custom fields
);
```

---

## Function Naming Conventions

All functions follow these conventions:

- **Verbs for actions**: `generate`, `build`, `execute`, `validate`, `discover`
- **Nouns for queries**: `get_schema`, `load_instance`, `find_builder`
- **Adjectives for checks**: `is_valid`, `has_field`, `can_execute`
- **Descriptive names**: `resolve_randomization`, `enforce_constraints`

---

## Error Handling

All interface functions must:

1. **Validate inputs** before processing
2. **Throw errors** with clear, actionable messages
3. **Include context** in error messages (what failed, why, how to fix)
4. **Clean up resources** on error (hardware, files, etc.)

Example:
```matlab
if ~isfield(params, 'freq_hz')
    error('Generator:MissingParameter', ...
          'Required parameter ''freq_hz'' not found in stimulus specification. ' + ...
          'Check that your stimulus includes all required parameters from the schema.');
end
```

---

## Testing Requirements

All plugins must include tests:
```matlab
% test_tone_generator.m
function test_tone_generator()
    % Test basic functionality
    test_generates_correct_duration();
    test_generates_correct_frequency();
    test_applies_ramps();
    test_handles_edge_cases();
end

function test_generates_correct_duration()
    params = struct('freq_hz', 1000, 'dur_ms', 50, 'level_db', 60, 'ramp_ms', 5);
    context = struct('sampling_rate_hz', 192000);
    
    spec = generators.audio.tone.generate(params, context);
    
    expected_samples = round(192000 * 0.05);
    assert(length(spec.data) == expected_samples, ...
           'Duration does not match specification');
end
```

---

## Performance Requirements

- **Generators**: Must complete in < 1 second for typical stimuli
- **Builders**: Must complete in < 5 seconds for 1000 trials
- **Validation**: Must complete in < 100ms per schema
- **Discovery**: Must complete in < 2 seconds on startup

---

## Backward Compatibility

When updating interfaces:

1. **Increment version** in schema
2. **Maintain old versions** in separate directories
3. **Document breaking changes** in changelog
4. **Provide migration guide** for updating old experiments
```
+generators/
  +audio/
    +tone/
      +v1.0.0/
        generator.m
        schema.json
      +v2.0.0/          ← New version with breaking changes
        generator.m
        schema.json
      generator.m       ← Symlink to latest version (v2.0.0)
```

---

This completes the interface specifications. All plugins and core components must adhere to these contracts.