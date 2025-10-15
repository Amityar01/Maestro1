function [is_valid, errors] = validate_generator_output(output_spec, schema)
% VALIDATE_GENERATOR_OUTPUT - Validate generator output against schema
%
% INPUTS:
%   output_spec - struct, output from generator
%   schema      - struct, generator schema
%
% OUTPUTS:
%   is_valid - boolean
%   errors   - cell array of error messages

    errors = {};
    
    % Must be a struct
    if ~isstruct(output_spec)
        errors{end+1} = 'Generator output must be struct';
        is_valid = false;
        return;
    end
    
    % Check required fields
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
            if ~isnumeric(output_spec.data)
                errors{end+1} = 'Waveform data must be numeric';
            elseif ~iscolumn(output_spec.data)
                errors{end+1} = 'Waveform data must be column vector';
            end
            
        case 'draw_commands'
            if ~isstruct(output_spec.data)
                errors{end+1} = 'Draw commands must be struct or struct array';
            end
            
        case 'compound'
            if ~isstruct(output_spec.data)
                errors{end+1} = 'Compound data must be struct';
            elseif ~isfield(output_spec.data, 'audio') || ...
                   ~isfield(output_spec.data, 'visual')
                errors{end+1} = 'Compound data must have audio and visual fields';
            end
    end
    
    % Duration must be positive
    if ~isnumeric(output_spec.duration_ms) || output_spec.duration_ms <= 0
        errors{end+1} = 'duration_ms must be positive number';
    end
    
    % Metadata should be a struct
    if ~isstruct(output_spec.metadata)
        errors{end+1} = 'metadata must be struct';
    end
    
    is_valid = isempty(errors);
end