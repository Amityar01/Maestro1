function [is_valid, errors] = validate_block_instance(instance, builder_schema)
% VALIDATE_BLOCK_INSTANCE - Validate a block instance against builder schema
%
% INPUTS:
%   instance       - struct, block instance specification
%   builder_schema - struct, builder template schema
%
% OUTPUTS:
%   is_valid - boolean
%   errors   - cell array of error messages

    errors = {};
    
    % Check required fields
    required_fields = {'instance_id', 'builder_type', 'parameters'};
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
    
    % Validate parameters against required_inputs and optional_inputs
    params = instance.parameters;
    
    % Check required inputs
    if isfield(builder_schema, 'required_inputs')
        required = fieldnames(builder_schema.required_inputs);
        for i = 1:length(required)
            param_name = required{i};
            if ~isfield(params, param_name)
                errors{end+1} = sprintf('Missing required parameter: %s', param_name);
            end
        end
    end
    
    % Validate each parameter
    param_names = fieldnames(params);
    for i = 1:length(param_names)
        param_name = param_names{i};
        param_value = params.(param_name);
        
        % Find parameter definition
        param_def = [];
        if isfield(builder_schema, 'required_inputs') && ...
           isfield(builder_schema.required_inputs, param_name)
            param_def = builder_schema.required_inputs.(param_name);
        elseif isfield(builder_schema, 'optional_inputs') && ...
               isfield(builder_schema.optional_inputs, param_name)
            param_def = builder_schema.optional_inputs.(param_name);
        end
        
        if isempty(param_def)
            errors{end+1} = sprintf('Unknown parameter: %s', param_name);
            continue;
        end
        
        % Validate value
        [valid, err] = core.validate_parameter_value(param_value, param_def);
        if ~valid
            errors{end+1} = sprintf('Parameter %s: %s', param_name, err);
        end
    end
    
    is_valid = isempty(errors);
end