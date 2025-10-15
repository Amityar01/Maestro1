function [is_valid, errors] = validate_parameters(params, param_schema)
% VALIDATE_PARAMETERS - Validate parameters against schema
%
% INPUTS:
%   params       - struct, parameters to validate
%   param_schema - struct, parameter definitions from schema
%
% OUTPUTS:
%   is_valid - boolean, true if all validations pass
%   errors   - cell array of error messages

    errors = {};
    
    % Get all required parameters
    param_names = fieldnames(param_schema);
    required_params = {};
    for i = 1:length(param_names)
        param_name = param_names{i};
        param_def = param_schema.(param_name);
        
        if isfield(param_def, 'required') && param_def.required
            required_params{end+1} = param_name; %#ok<AGROW>
        end
    end
    
    % Check all required parameters are present
    for i = 1:length(required_params)
        param_name = required_params{i};
        if ~isfield(params, param_name)
            errors{end+1} = sprintf('Missing required parameter: %s', param_name); %#ok<AGROW>
        end
    end
    
    % Check each provided parameter
    provided_params = fieldnames(params);
    for i = 1:length(provided_params)
        param_name = provided_params{i};
        param_value = params.(param_name);
        
        % Check if parameter is defined in schema
        if ~isfield(param_schema, param_name)
            errors{end+1} = sprintf('Unknown parameter: %s', param_name); %#ok<AGROW>
            continue;
        end
        
        param_def = param_schema.(param_name);
        
        % Check if it's a randomization spec
        if core.is_randomization_spec(param_value)
            % Validate randomization specification
            [valid, err] = core.validate_randomization_spec(param_value, param_def);
            if ~valid
                errors{end+1} = sprintf('Invalid randomization for %s: %s', ...
                    param_name, err); %#ok<AGROW>
            end
        else
            % Validate fixed value
            [valid, err] = core.validate_parameter_value(param_value, param_def);
            if ~valid
                errors{end+1} = sprintf('Invalid value for %s: %s', ...
                    param_name, err); %#ok<AGROW>
            end
        end
    end
    
    is_valid = isempty(errors);
end