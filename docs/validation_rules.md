# Maestro Validation Rules v1.0

This document defines comprehensive validation rules for all components in the Maestro system.

## Table of Contents
1. [Overview](#overview)
2. [Schema Validation](#schema-validation)
3. [Generator Validation](#generator-validation)
4. [Builder Validation](#builder-validation)
5. [Block Instance Validation](#block-instance-validation)
6. [Experiment Validation](#experiment-validation)
7. [Runtime Validation](#runtime-validation)
8. [Validation Implementation](#validation-implementation)

---

## Overview

### Validation Philosophy

**Fail early, fail clearly, fail helpfully.**

Maestro validates at multiple stages:
```
1. LOAD TIME
   └─> Schema structure validation
   └─> Plugin discovery validation

2. DEFINITION TIME
   └─> Parameter type validation
   └─> Constraint validation
   └─> Reference validation

3. COMPILE TIME
   └─> Cross-component validation
   └─> Logical consistency validation
   └─> Resource availability validation

4. RUNTIME
   └─> Hardware validation
   └─> Output validation
   └─> Timing validation
```

### Validation Levels

**CRITICAL** - Must pass or system cannot proceed
- Missing required fields
- Type mismatches
- Invalid references
- Hardware unavailable

**WARNING** - Should be addressed but not blocking
- Deprecated features
- Suboptimal parameters
- Resource concerns

**INFO** - Informational only
- Performance suggestions
- Best practice recommendations

---

## Schema Validation

### Generator Schema Validation

Every generator schema must pass these checks:

#### Required Fields
```matlab
required_fields = {
    '$schema',           % Must be 'maestro-generator-v1'
    'generator_type',    % Unique string identifier
    'version',           % Valid semver
    'category',          % String
    'description',       % Non-empty string
    'modality',          % Valid enum value
    'render_type',       % Valid enum value
    'parameters',        % Struct
    'output_specification', % Struct
    'implementation'     % Struct
};
```

**Validation:**
```matlab
for i = 1:length(required_fields)
    field = required_fields{i};
    if ~isfield(schema, field)
        error('Schema:MissingField', ...
              'Generator schema missing required field: %s', field);
    end
end
```

#### Field Type Validation
```matlab
% $schema must be exact string
if ~strcmp(schema.$schema, 'maestro-generator-v1')
    error('Schema:InvalidVersion', ...
          'Schema version must be "maestro-generator-v1", got: %s', ...
          schema.$schema);
end

% generator_type must be valid identifier (alphanumeric + underscore)
if ~isvarname(['x_' schema.generator_type])
    error('Schema:InvalidIdentifier', ...
          'generator_type must be valid identifier: %s', ...
          schema.generator_type);
end

% version must be valid semver
if ~is_valid_semver(schema.version)
    error('Schema:InvalidVersion', ...
          'version must be valid semver (e.g., "1.0.0"): %s', ...
          schema.version);
end

% modality must be valid enum
valid_modalities = {'audio', 'visual', 'multimodal'};
if ~ismember(schema.modality, valid_modalities)
    error('Schema:InvalidModality', ...
          'modality must be one of: %s', strjoin(valid_modalities, ', '));
end

% render_type must be valid enum
valid_render_types = {'waveform', 'draw_commands', 'compound'};
if ~ismember(schema.render_type, valid_render_types)
    error('Schema:InvalidRenderType', ...
          'render_type must be one of: %s', strjoin(valid_render_types, ', '));
end
```

#### Parameter Definition Validation

Each parameter in `schema.parameters` must have:
```matlab
% For each parameter
param_names = fieldnames(schema.parameters);
for i = 1:length(param_names)
    param_name = param_names{i};
    param_def = schema.parameters.(param_name);
    
    % Must have 'type' field
    if ~isfield(param_def, 'type')
        error('Schema:MissingParameterType', ...
              'Parameter "%s" missing required field "type"', param_name);
    end
    
    % Type must be valid
    valid_types = {'float', 'integer', 'string', 'boolean', 'enum', ...
                   'array', 'stimulus_reference', 'file_path'};
    if ~ismember(param_def.type, valid_types)
        error('Schema:InvalidParameterType', ...
              'Parameter "%s" has invalid type: %s', ...
              param_name, param_def.type);
    end
    
    % Constraints must be appropriate for type
    if isfield(param_def, 'constraints')
        validate_constraints(param_def.type, param_def.constraints, param_name);
    end
    
    % Default value must match type
    if isfield(param_def, 'default')
        validate_value_type(param_def.default, param_def.type, param_name);
    end
end
```

#### Implementation Validation
```matlab
impl = schema.implementation;

% Must have function field
if ~isfield(impl, 'function')
    error('Schema:MissingImplementation', ...
          'implementation.function is required');
end

% Function name must be valid
if ~contains(impl.function, '.')
    error('Schema:InvalidFunction', ...
          'implementation.function must be fully qualified (e.g., "generators.audio.tone.generate")');
end

% File must exist
if isfield(impl, 'file')
    file_path = fullfile(schema_dir, impl.file);
    if ~isfile(file_path)
        error('Schema:FileNotFound', ...
              'implementation.file does not exist: %s', file_path);
    end
end
```

### Builder Schema Validation

Similar to generator validation but with builder-specific fields:
```matlab
required_fields = {
    '$schema',           % Must be 'maestro-builder-v1'
    'builder_type',      % Unique identifier
    'version',           % Semver
    'description',       % String
    'required_inputs',   % Struct
    'output_specification', % Struct
    'implementation'     % Struct
};
```

**Additional validation:**
```matlab
% required_inputs must define valid parameters
inputs = schema.required_inputs;
input_names = fieldnames(inputs);
for i = 1:length(input_names)
    input_def = inputs.(input_names{i});
    
    % Each input needs type and description
    if ~isfield(input_def, 'type')
        error('Schema:MissingInputType', ...
              'Builder input "%s" missing type', input_names{i});
    end
    
    if ~isfield(input_def, 'description')
        warning('Schema:MissingDescription', ...
                'Builder input "%s" missing description', input_names{i});
    end
end

% output_specification must describe trial structure
if ~isfield(schema.output_specification, 'trial_structure')
    error('Schema:MissingTrialStructure', ...
          'Builder must specify output trial_structure');
end
```

### Engine Schema Validation
```matlab
required_fields = {
    '$schema',                % Must be 'maestro-engine-v1'
    'engine_type',            % Unique identifier
    'version',                % Semver
    'supported_modalities',   % Array
    'supported_render_types', % Array
    'execution_mode',         % String
    'implementation'          % Struct
};

% supported_modalities must be non-empty array
if isempty(schema.supported_modalities)
    error('Schema:EmptyModalities', ...
          'Engine must support at least one modality');
end

% execution_mode must be valid
valid_modes = {'compile_then_execute', 'real_time_loop', 'closed_loop'};
if ~ismember(schema.execution_mode, valid_modes)
    error('Schema:InvalidExecutionMode', ...
          'execution_mode must be one of: %s', strjoin(valid_modes, ', '));
end
```

---

## Generator Validation

### Parameter Value Validation

When a stimulus specification provides parameters, validate against generator schema:
```matlab
function [is_valid, errors] = validate_generator_parameters(params, schema)
    errors = {};
    
    % Check all required parameters present
    required = get_required_parameters(schema);
    for i = 1:length(required)
        param_name = required{i};
        if ~isfield(params, param_name)
            errors{end+1} = sprintf('Missing required parameter: %s', param_name);
        end
    end
    
    % Check each provided parameter
    param_names = fieldnames(params);
    for i = 1:length(param_names)
        param_name = param_names{i};
        param_value = params.(param_name);
        
        % Check if parameter is defined in schema
        if ~isfield(schema.parameters, param_name)
            errors{end+1} = sprintf('Unknown parameter: %s', param_name);
            continue;
        end
        
        param_def = schema.parameters.(param_name);
        
        % Validate value or randomization spec
        if is_randomization_spec(param_value)
            % Validate randomization specification
            [valid, err] = validate_randomization_spec(param_value, param_def);
            if ~valid
                errors{end+1} = sprintf('Invalid randomization for %s: %s', ...
                                       param_name, err);
            end
        else
            % Validate fixed value
            [valid, err] = validate_parameter_value(param_value, param_def);
            if ~valid
                errors{end+1} = sprintf('Invalid value for %s: %s', ...
                                       param_name, err);
            end
        end
    end
    
    is_valid = isempty(errors);
end
```

### Type Validation
```matlab
function [is_valid, error_msg] = validate_parameter_value(value, param_def)
    error_msg = '';
    
    switch param_def.type
        case 'float'
            if ~isnumeric(value) || ~isscalar(value)
                error_msg = 'Must be numeric scalar';
                is_valid = false;
                return;
            end
            
        case 'integer'
            if ~isnumeric(value) || ~isscalar(value) || mod(value, 1) ~= 0
                error_msg = 'Must be integer scalar';
                is_valid = false;
                return;
            end
            
        case 'string'
            if ~ischar(value) && ~isstring(value)
                error_msg = 'Must be string';
                is_valid = false;
                return;
            end
            
        case 'boolean'
            if ~islogical(value) && ~isnumeric(value)
                error_msg = 'Must be boolean';
                is_valid = false;
                return;
            end
            
        case 'enum'
            if ~isfield(param_def.constraints, 'options')
                error_msg = 'Enum parameter missing options in schema';
                is_valid = false;
                return;
            end
            if ~ismember(value, param_def.constraints.options)
                error_msg = sprintf('Must be one of: %s', ...
                    strjoin(param_def.constraints.options, ', '));
                is_valid = false;
                return;
            end
            
        case 'array'
            if ~isvector(value)
                error_msg = 'Must be array/vector';
                is_valid = false;
                return;
            end
    end
    
    % Validate constraints
    if isfield(param_def, 'constraints')
        [is_valid, error_msg] = validate_constraints_on_value(value, ...
            param_def.constraints);
    else
        is_valid = true;
    end
end
```

### Constraint Validation
```matlab
function [is_valid, error_msg] = validate_constraints_on_value(value, constraints)
    error_msg = '';
    is_valid = true;
    
    % Min constraint
    if isfield(constraints, 'min')
        if value < constraints.min
            error_msg = sprintf('Value %g is below minimum %g', ...
                value, constraints.min);
            is_valid = false;
            return;
        end
    end
    
    % Max constraint
    if isfield(constraints, 'max')
        if value > constraints.max
            error_msg = sprintf('Value %g exceeds maximum %g', ...
                value, constraints.max);
            is_valid = false;
            return;
        end
    end
    
    % Pattern constraint (for strings)
    if isfield(constraints, 'pattern')
        if ~ischar(value) && ~isstring(value)
            error_msg = 'Pattern constraint only valid for strings';
            is_valid = false;
            return;
        end
        if ~regexp(char(value), constraints.pattern)
            error_msg = sprintf('String does not match pattern: %s', ...
                constraints.pattern);
            is_valid = false;
            return;
        end
    end
    
    % Options constraint
    if isfield(constraints, 'options')
        if ~ismember(value, constraints.options)
            error_msg = sprintf('Value not in allowed options: %s', ...
                strjoin(cellstr(constraints.options), ', '));
            is_valid = false;
            return;
        end
    end
end
```

### Randomization Specification Validation
```matlab
function [is_valid, error_msg] = validate_randomization_spec(spec, param_def)
    error_msg = '';
    is_valid = true;
    
    % Must be a struct
    if ~isstruct(spec)
        error_msg = 'Randomization spec must be struct';
        is_valid = false;
        return;
    end
    
    % Must have 'type' field
    if ~isfield(spec, 'type')
        error_msg = 'Randomization spec missing "type" field';
        is_valid = false;
        return;
    end
    
    % Check if randomization is allowed for this parameter
    if isfield(param_def, 'randomizable') && ~param_def.randomizable
        error_msg = sprintf('Parameter is not randomizable according to schema');
        is_valid = false;
        return;
    end
    
    switch spec.type
        case 'random_uniform'
            % Must have min and max
            if ~isfield(spec, 'min') || ~isfield(spec, 'max')
                error_msg = 'random_uniform requires min and max fields';
                is_valid = false;
                return;
            end
            % min must be less than max
            if spec.min >= spec.max
                error_msg = sprintf('min (%g) must be less than max (%g)', ...
                    spec.min, spec.max);
                is_valid = false;
                return;
            end
            % Check bounds against parameter constraints
            if isfield(param_def, 'constraints')
                if isfield(param_def.constraints, 'min')
                    if spec.min < param_def.constraints.min
                        error_msg = sprintf('Randomization min (%g) below parameter min (%g)', ...
                            spec.min, param_def.constraints.min);
                        is_valid = false;
                        return;
                    end
                end
                if isfield(param_def.constraints, 'max')
                    if spec.max > param_def.constraints.max
                        error_msg = sprintf('Randomization max (%g) exceeds parameter max (%g)', ...
                            spec.max, param_def.constraints.max);
                        is_valid = false;
                        return;
                    end
                end
            end
            
        case 'random_gaussian'
            % Must have mean and std
            if ~isfield(spec, 'mean') || ~isfield(spec, 'std')
                error_msg = 'random_gaussian requires mean and std fields';
                is_valid = false;
                return;
            end
            % std must be positive
            if spec.std <= 0
                error_msg = 'std must be positive';
                is_valid = false;
                return;
            end
            
        case 'random_choice'
            % Must have options
            if ~isfield(spec, 'options')
                error_msg = 'random_choice requires options field';
                is_valid = false;
                return;
            end
            % Options must be non-empty array
            if isempty(spec.options)
                error_msg = 'options array cannot be empty';
                is_valid = false;
                return;
            end
            % If weights provided, must match options length
            if isfield(spec, 'weights')
                if length(spec.weights) ~= length(spec.options)
                    error_msg = 'weights length must match options length';
                    is_valid = false;
                    return;
                end
                % Weights must be non-negative
                if any(spec.weights < 0)
                    error_msg = 'weights must be non-negative';
                    is_valid = false;
                    return;
                end
            end
            
        otherwise
            error_msg = sprintf('Unknown randomization type: %s', spec.type);
            is_valid = false;
    end
end
```

### Output Validation

After generator executes, validate its output:
```matlab
function [is_valid, errors] = validate_generator_output(output_spec, schema)
    errors = {};
    
    % Must be a struct
    if ~isstruct(output_spec)
        errors{end+1} = 'Generator output must be struct';
        return;
    end
    
    % Must have required fields
    required_fields = {'modality', 'render_type', 'data', 'duration_ms', 'metadata'};
    for i = 1:length(required_fields)
        if ~isfield(output_spec, required_fields{i})
            errors{end+1} = sprintf('Output missing required field: %s', ...
                required_fields{i});
        end
    end
    
    if ~isempty(errors)
        is_valid = false;
        return;
    end
    
    % Modality must match schema
    if ~strcmp(output_spec.modality, schema.modality)
        errors{end+1} = sprintf('Output modality "%s" does not match schema "%s"', ...
            output_spec.modality, schema.modality);
    end
    
    % Render type must match schema
    if ~strcmp(output_spec.render_type, schema.render_type)
        errors{end+1} = sprintf('Output render_type "%s" does not match schema "%s"', ...
            output_spec.render_type, schema.render_type);
    end
    
    % Validate data format based on render_type
    switch output_spec.render_type
        case 'waveform'
            if ~isnumeric(output_spec.data) || ~iscolumn(output_spec.data)
                errors{end+1} = 'Waveform data must be numeric column vector';
            end
            
        case 'draw_commands'
            if ~isstruct(output_spec.data)
                errors{end+1} = 'Draw commands must be struct or struct array';
            else
                % Validate draw command structure
                [valid, errs] = validate_draw_commands(output_spec.data);
                if ~valid
                    errors = [errors, errs];
                end
            end
            
        case 'compound'
            if ~isstruct(output_spec.data)
                errors{end+1} = 'Compound data must be struct';
            else
                % Must have audio and visual fields
                if ~isfield(output_spec.data, 'audio') || ...
                   ~isfield(output_spec.data, 'visual')
                    errors{end+1} = 'Compound data must have audio and visual fields';
                end
            end
    end
    
    % Duration must be positive
    if ~isnumeric(output_spec.duration_ms) || output_spec.duration_ms <= 0
        errors{end+1} = 'duration_ms must be positive number';
    end
    
    is_valid = isempty(errors);
end
```

---

## Builder Validation

### Block Instance Validation
```matlab
function [is_valid, errors] = validate_block_instance(instance, builder_schema)
    errors = {};
    
    % Must have required fields
    required_fields = {'instance_id', 'builder_type', 'builder_version', 'parameters'};
    for i = 1:length(required_fields)
        if ~isfield(instance, required_fields{i})
            errors{end+1} = sprintf('Instance missing required field: %s', ...
                required_fields{i});
        end
    end
    
    if ~isempty(errors)
        is_valid = false;
        return;
    end
    
    % Builder type must match
    if ~strcmp(instance.builder_type, builder_schema.builder_type)
        errors{end+1} = sprintf('Instance builder_type "%s" does not match schema "%s"', ...
            instance.builder_type, builder_schema.builder_type);
    end
    
    % Version must be compatible
    if ~is_version_compatible(instance.builder_version, builder_schema.version)
        warning('Instance uses builder version %s but current version is %s', ...
            instance.builder_version, builder_schema.version);
    end
    
    % Validate parameters
    [valid, param_errors] = validate_builder_parameters(instance.parameters, ...
        builder_schema);
    if ~valid
        errors = [errors, param_errors];
    end
    
    is_valid = isempty(errors);
end
```

### Builder Parameter Validation
```matlab
function [is_valid, errors] = validate_builder_parameters(params, schema)
    errors = {};
    
    % Check all required inputs present
    if isfield(schema, 'required_inputs')
        required = fieldnames(schema.required_inputs);
        for i = 1:length(required)
            param_name = required{i};
            if ~isfield(params, param_name)
                errors{end+1} = sprintf('Missing required input: %s', param_name);
            end
        end
    end
    
    % Validate each provided parameter
    param_names = fieldnames(params);
    for i = 1:length(param_names)
        param_name = param_names{i};
        param_value = params.(param_name);
        
        % Find parameter definition
        if isfield(schema.required_inputs, param_name)
            param_def = schema.required_inputs.(param_name);
        elseif isfield(schema.optional_inputs, param_name)
            param_def = schema.optional_inputs.(param_name);
        else
            errors{end+1} = sprintf('Unknown parameter: %s', param_name);
            continue;
        end
        
        % Validate based on type
        switch param_def.type
            case 'stimulus_specification'
                [valid, errs] = validate_stimulus_spec(param_value);
                if ~valid
                    errors = [errors, errs];
                end
                
            case 'integer'
                if ~isnumeric(param_value) || mod(param_value, 1) ~= 0
                    errors{end+1} = sprintf('%s must be integer', param_name);
                end
                % Check constraints
                if isfield(param_def, 'constraints')
                    [valid, err] = validate_constraints_on_value(param_value, ...
                        param_def.constraints);
                    if ~valid
                        errors{end+1} = sprintf('%s: %s', param_name, err);
                    end
                end
                
            case 'float'
                if ~isnumeric(param_value)
                    errors{end+1} = sprintf('%s must be numeric', param_name);
                end
                % Check constraints
                if isfield(param_def, 'constraints')
                    [valid, err] = validate_constraints_on_value(param_value, ...
                        param_def.constraints);
                    if ~valid
                        errors{end+1} = sprintf('%s: %s', param_name, err);
                    end
                end
                
            case 'enum'
                if ~ismember(param_value, param_def.constraints.options)
                    errors{end+1} = sprintf('%s must be one of: %s', ...
                        param_name, strjoin(param_def.constraints.options, ', '));
                end
        end
    end
    
    is_valid = isempty(errors);
end
```

### Stimulus Specification Validation
```matlab
function [is_valid, errors] = validate_stimulus_spec(stim_spec)
    errors = {};
    
    % Must be struct
    if ~isstruct(stim_spec)
        errors{end+1} = 'Stimulus specification must be struct';
        is_valid = false;
        return;
    end
    
    % Must have required fields
    required = {'generator', 'parameters'};
    for i = 1:length(required)
        if ~isfield(stim_spec, required{i})
            errors{end+1} = sprintf('Stimulus spec missing field: %s', required{i});
        end
    end
    
    if ~isempty(errors)
        is_valid = false;
        return;
    end
    
    % Generator must exist (checked against context at runtime)
    % Version should be specified
    if ~isfield(stim_spec, 'version')
        warning('Stimulus specification missing version field - will use latest');
    end
    
    % Parameters must be struct
    if ~isstruct(stim_spec.parameters)
        errors{end+1} = 'Stimulus parameters must be struct';
    end
    
    is_valid = isempty(errors);
end
```

### Trial List Validation

After builder produces trial list, validate structure:
```matlab
function [is_valid, errors] = validate_trial_list(trial_list, builder_schema)
    errors = {};
    
    % Must be struct array
    if ~isstruct(trial_list)
        errors{end+1} = 'Trial list must be struct array';
        is_valid = false;
        return;
    end
    
    % Each trial must have required fields
    required_fields = {'trial_id', 'trial_num', 'trial_type', ...
                      'presentations', 'iti_sec', 'metadata'};
    
    for t = 1:length(trial_list)
        trial = trial_list(t);
        
        % Check required fields
        for i = 1:length(required_fields)
            if ~isfield(trial, required_fields{i})
                errors{end+1} = sprintf('Trial %d missing field: %s', ...
                    t, required_fields{i});
            end
        end
        
        % trial_num must match index
        if isfield(trial, 'trial_num') && trial.trial_num ~= t
            errors{end+1} = sprintf('Trial %d has incorrect trial_num: %d', ...
                t, trial.trial_num);
        end
        
        % presentations must be non-empty struct array
        if ~isfield(trial, 'presentations') || isempty(trial.presentations)
            errors{end+1} = sprintf('Trial %d has no presentations', t);
            continue;
        end
        
        % Validate each presentation
        for p = 1:length(trial.presentations)
            pres = trial.presentations(p);
            
            % Must have required fields
            if ~isfield(pres, 'stimulus_spec')
                errors{end+1} = sprintf('Trial %d presentation %d missing stimulus_spec', t, p);
            end
            if ~isfield(pres, 'onset_ms')
                errors{end+1} = sprintf('Trial %d presentation %d missing onset_ms', t, p);
            end
            
            % onset_ms must be non-negative
            if isfield(pres, 'onset_ms') && pres.onset_ms < 0
                errors{end+1} = sprintf('Trial %d presentation %d has negative onset', t, p);
            end
            
            % Validate stimulus spec
            if isfield(pres, 'stimulus_spec')
                [valid, stim_errors] = validate_stimulus_spec(pres.stimulus_spec);
                if ~valid
                    for e = 1:length(stim_errors)
                        errors{end+1} = sprintf('Trial %d presentation %d: %s', ...
                            t, p, stim_errors{e});
                    end
                end
            end
        end
        
        % Presentations should be ordered by onset
        if length(trial.presentations) > 1
            for p = 2:length(trial.presentations)
                if trial.presentations(p).onset_ms < trial.presentations(p-1).onset_ms
                    warning('Trial %d presentations not ordered by onset time', t);
                    break;
                end
            end
        end
        
        % iti_sec must be non-negative
        if isfield(trial, 'iti_sec') && trial.iti_sec < 0
            errors{end+1} = sprintf('Trial %d has negative ITI', t);
        end
    end
    
    is_valid = isempty(errors);
end
```

---

## Block Instance Validation

### Reference Resolution
```matlab
function [is_valid, errors] = validate_references(spec, context)
    errors = {};
    
    % Find all references in spec (fields starting with @)
    refs = find_all_references(spec);
    
    for i = 1:length(refs)
        ref = refs{i};
        
        % Parse reference
        [ref_type, ref_path] = parse_reference(ref);
        
        switch ref_type
            case 'instances'
                % Check if instance exists
                [~, filename] = fileparts(ref_path);
                if ~isKey(context.instances, filename)
                    errors{end+1} = sprintf('Referenced instance not found: %s', ref);
                end
                
            case 'stimuli'
                % Check if stimulus exists in library
                if contains(ref_path, '#')
                    % Reference to specific stimulus in library
                    [file, stim_id] = strsplit(ref_path, '#');
                    if ~isKey(context.stimulus_lib, stim_id)
                        errors{end+1} = sprintf('Referenced stimulus not found: %s', stim_id);
                    end
                else
                    % Reference to file
                    if ~isfile(ref_path)
                        errors{end+1} = sprintf('Referenced stimulus file not found: %s', ref_path);
                    end
                end
                
            case 'experiments'
                % Check if experiment exists
                [~, filename] = fileparts(ref_path);
                if ~isKey(context.experiments, filename)
                    errors{end+1} = sprintf('Referenced experiment not found: %s', ref);
                end
                
            otherwise
                errors{end+1} = sprintf('Unknown reference type: %s', ref_type);
        end
    end
    
    is_valid = isempty(errors);
end
```

---

## Experiment Validation

### Experiment Structure Validation
```matlab
function [is_valid, errors] = validate_experiment(experiment, context)
    errors = {};
    
    % Required fields
    required = {'experiment_id', 'global_settings', 'sequence', 'orchestration'};
    for i = 1:length(required)
        if ~isfield(experiment, required{i})
            errors{end+1} = sprintf('Experiment missing field: %s', required{i});
        end
    end
    
    if ~isempty(errors)
        is_valid = false;
        return;
    end
    
    % Validate global settings
    [valid, gs_errors] = validate_global_settings(experiment.global_settings, context);
    if ~valid
        errors = [errors, gs_errors];
    end
    
    % Validate sequence
    [valid, seq_errors] = validate_sequence(experiment.sequence, context);
    if ~valid
        errors = [errors, seq_errors];
    end
    
    % Validate orchestration
    [valid, orch_errors] = validate_orchestration(experiment.orchestration, ...
        experiment.sequence);
    if ~valid
        errors = [errors, orch_errors];
    end
    
    % Cross-validation: engine compatibility
    engine_type = experiment.global_settings.engine_type;
    if isKey(context.engines, engine_type)
        engine_info = context.engines(engine_type);
        [valid, compat_errors] = validate_engine_compatibility(experiment, ...
            engine_info, context);
        if ~valid
            errors = [errors, compat_errors];
        end
    else
        errors{end+1} = sprintf('Unknown engine type: %s', engine_type);
    end
    
    is_valid = isempty(errors);
end
```

### Global Settings Validation
```matlab
function [is_valid, errors] = validate_global_settings(settings, context)
    errors = {};
    
    % Required fields
    required = {'engine_type', 'sampling_rate_hz'};
    for i = 1:length(required)
        if ~isfield(settings, required{i})
            errors{end+1} = sprintf('Global settings missing: %s', required{i});
        end
    end
    
    % Engine must exist
    if isfield(settings, 'engine_type')
        if ~isKey(context.engines, settings.engine_type)
            errors{end+1} = sprintf('Unknown engine: %s', settings.engine_type);
        end
    end
    
    % Sampling rate must be valid
    if isfield(settings, 'sampling_rate_hz')
        valid_rates = [44100, 48000, 96000, 192000, 384000];
        if ~ismember(settings.sampling_rate_hz, valid_rates)
            warning('Unusual sampling rate: %d Hz', settings.sampling_rate_hz);
        end
        if settings.sampling_rate_hz < 1000
            errors{end+1} = 'Sampling rate too low (< 1000 Hz)';
        end
    end
    
    is_valid = isempty(errors);
end
```

### Engine Compatibility Validation
```matlab
function [is_valid, errors] = validate_engine_compatibility(experiment, engine_info, context)
    errors = {};
    
    % Load all block instances referenced in experiment
    for i = 1:length(experiment.sequence)
        block_ref = experiment.sequence(i).block_instance;
        
        % Load block instance
        instance = load_block_instance(block_ref, context);
        
        % Build trial list (needed to check stimuli)
        builder = context.builders(instance.builder_type);
        trial_list = builder.build_func(instance, context);
        
        % Check all stimuli compatible with engine
        for t = 1:length(trial_list)
            for p = 1:length(trial_list(t).presentations)
                stim_spec = trial_list(t).presentations(p).stimulus_spec;
                generator = context.generators(stim_spec.generator);
                
                % Check modality
                if ~ismember(generator.schema.modality, engine_info.schema.supported_modalities)
                    errors{end+1} = sprintf(...
                        'Block %d trial %d: Engine "%s" does not support modality "%s"', ...
                        i, t, engine_info.schema.engine_type, generator.schema.modality);
                end
                
                % Check render type
                if ~ismember(generator.schema.render_type, engine_info.schema.supported_render_types)
                    errors{end+1} = sprintf(...
                        'Block %d trial %d: Engine "%s" does not support render_type "%s"', ...
                        i, t, engine_info.schema.engine_type, generator.schema.render_type);
                end
            end
        end
    end
    
    is_valid = isempty(errors);
end
```

---

## Runtime Validation

### Hardware Validation

Before execution, validate hardware availability:
```matlab
function [is_valid, errors] = validate_hardware(experiment, context)
    errors = {};
    
    engine = context.engines(experiment.global_settings.engine_type);
    requirements = engine.schema.requirements.hardware;
    
    % Check DAQ
    if ismember('daq', requirements)
        if ~isfield(experiment, 'hardware') || ~isfield(experiment.hardware, 'daq')
            errors{end+1} = 'Engine requires DAQ but none specified';
        else
            % Try to detect DAQ
            try
                daq_info = daqlist();
                device_id = experiment.hardware.daq.device_id;
                device_found = any(strcmp({daq_info.DeviceID}, device_id));
                if ~device_found
                    errors{end+1} = sprintf('DAQ device not found: %s', device_id);
                end
            catch ME
                errors{end+1} = sprintf('Cannot access DAQ: %s', ME.message);
            end
        end
    end
    
    % Check display
    if ismember('display', requirements)
        try
            screens = Screen('Screens');
            if isfield(experiment.hardware, 'display')
                screen_num = experiment.hardware.display.screen_number;
                if ~ismember(screen_num, screens)
                    errors{end+1} = sprintf('Display screen %d not found', screen_num);
                end
            end
        catch ME
            errors{end+1} = sprintf('Cannot access Psychtoolbox: %s', ME.message);
        end
    end
    
    is_valid = isempty(errors);
end
```

### Resource Validation

Check if system has sufficient resources:
```matlab
function [is_valid, warnings] = validate_resources(experiment, context)
    warnings = {};
    is_valid = true;
    
    % Estimate memory requirements
    % (compile all waveforms to estimate size)
    estimated_memory_gb = estimate_memory_usage(experiment, context);
    
    % Check available memory
    if ispc
        [~, sys] = memory();
        available_gb = sys.PhysicalMemory.Available / 1e9;
    else
        % Unix-based systems
        [~, mem_info] = system('free -b');
        % Parse available memory...
        available_gb = 8; % Placeholder
    end
    
    if estimated_memory_gb > 0.8 * available_gb
        warnings{end+1} = sprintf(...
            'Experiment may require %.1f GB but only %.1f GB available', ...
            estimated_memory_gb, available_gb);
    end
    
    % Estimate disk space
    output_dir = experiment.global_settings.output_directory;
    estimated_disk_gb = estimate_disk_usage(experiment, context);
    
    % Check available disk space
    if ispc
        [~, disk_info] = system(['dir "' output_dir '"']);
        % Parse available space...
        available_disk_gb = 100; % Placeholder
    else
        [~, disk_info] = system(['df -BG ' output_dir]);
        % Parse...
        available_disk_gb = 100; % Placeholder
    end
    
    if estimated_disk_gb > 0.9 * available_disk_gb
        warnings{end+1} = sprintf(...
            'Experiment may require %.1f GB disk but only %.1f GB available', ...
            estimated_disk_gb, available_disk_gb);
    end
end
```

---

## Validation Implementation

### Main Validation Function
```matlab
function validation_report = validate_all(experiment_file, context)
    % VALIDATE_ALL - Comprehensive validation of entire experiment
    
    validation_report = struct();
    validation_report.success = true;
    validation_report.errors = {};
    validation_report.warnings = {};
    validation_report.info = {};
    
    try
        % Load experiment
        experiment = jsondecode(fileread(experiment_file));
        
        % 1. Schema validation
        fprintf('Validating experiment schema...\n');
        [valid, errors] = validate_experiment_schema(experiment);
        if ~valid
            validation_report.success = false;
            validation_report.errors = [validation_report.errors, errors];
            return;
        end
        
        % 2. Reference validation
        fprintf('Validating references...\n');
        [valid, errors] = validate_references(experiment, context);
        if ~valid
            validation_report.success = false;
            validation_report.errors = [validation_report.errors, errors];
        end
        
        % 3. Block instance validation
        fprintf('Validating block instances...\n');
        for i = 1:length(experiment.sequence)
            block_ref = experiment.sequence(i).block_instance;
            instance = load_block_instance(block_ref, context);
            builder = context.builders(instance.builder_type);
            
            [valid, errors] = validate_block_instance(instance, builder.schema);
            if ~valid
                validation_report.success = false;
                for e = 1:length(errors)
                    validation_report.errors{end+1} = sprintf('Block %d: %s', i, errors{e});
                end
            end
        end
        
        % 4. Engine compatibility
        fprintf('Validating engine compatibility...\n');
        engine = context.engines(experiment.global_settings.engine_type);
        [valid, errors] = validate_engine_compatibility(experiment, engine, context);
        if ~valid
            validation_report.success = false;
            validation_report.errors = [validation_report.errors, errors];
        end
        
        % 5. Hardware validation
        fprintf('Validating hardware availability...\n');
        [valid, errors] = validate_hardware(experiment, context);
        if ~valid
            validation_report.success = false;
            validation_report.errors = [validation_report.errors, errors];
        end
        
        % 6. Resource validation (warnings only)
        fprintf('Checking system resources...\n');
        [~, warnings] = validate_resources(experiment, context);
        validation_report.warnings = [validation_report.warnings, warnings];
        
        % Summary
        fprintf('\n');
        fprintf('═══════════════════════════════════\n');
        fprintf('  VALIDATION SUMMARY\n');
        fprintf('═══════════════════════════════════\n');
        fprintf('Status: %s\n', ternary(validation_report.success, 'PASS', 'FAIL'));
        fprintf('Errors: %d\n', length(validation_report.errors));
        fprintf('Warnings: %d\n', length(validation_report.warnings));
        fprintf('\n');
        
        if ~validation_report.success
            fprintf('ERRORS:\n');
            for i = 1:length(validation_report.errors)
                fprintf('  %d. %s\n', i, validation_report.errors{i});
            end
            fprintf('\n');
        end
        
        if ~isempty(validation_report.warnings)
            fprintf('WARNINGS:\n');
            for i = 1:length(validation_report.warnings)
                fprintf('  %d. %s\n', i, validation_report.warnings{i});
            end
        end
        
    catch ME
        validation_report.success = false;
        validation_report.errors{end+1} = sprintf('Validation failed: %s', ME.message);
    end
end
```

---

## Summary

Validation in Maestro is:

1. **Comprehensive** - Checks at every stage
2. **Hierarchical** - From schemas to full experiments
3. **Clear** - Specific error messages with context
4. **Helpful** - Suggestions for fixing errors
5. **Efficient** - Fails fast with clear diagnostics

All validation functions return:
- `is_valid` (boolean)
- `errors` or `warnings` (cell array of strings)

This enables:
- Early error detection
- Clear debugging
- Confident execution
- Reproducible experiments

---

End of validation_rules.md