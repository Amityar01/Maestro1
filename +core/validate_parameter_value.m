function [is_valid, error_msg] = validate_parameter_value(value, param_def)
% VALIDATE_PARAMETER_VALUE - Validate a parameter value against its definition
%
% INPUTS:
%   value     - any type, the value to validate
%   param_def - struct, parameter definition from schema
%
% OUTPUTS:
%   is_valid  - boolean
%   error_msg - string, empty if valid

    error_msg = '';
    
    % Check type
    param_type = param_def.type;
    
    switch param_type
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
            if ~islogical(value) && (~isnumeric(value) || (value ~= 0 && value ~= 1))
                error_msg = 'Must be boolean';
                is_valid = false;
                return;
            end
            
        case 'enum'
            if ~isfield(param_def, 'constraints') || ...
               ~isfield(param_def.constraints, 'options')
                error_msg = 'Enum parameter missing options in schema';
                is_valid = false;
                return;
            end
            
            % Convert value to string for comparison if needed
            value_str = value;
            if isnumeric(value)
                value_str = num2str(value);
            elseif isstring(value)
                value_str = char(value);
            end
            
            % Check if value is in options
            options = param_def.constraints.options;
            found = false;
            for i = 1:length(options)
                opt = options{i};
                if ischar(opt)
                    opt_str = opt;
                elseif isnumeric(opt)
                    opt_str = num2str(opt);
                else
                    opt_str = char(opt);
                end
                
                if strcmp(value_str, opt_str)
                    found = true;
                    break;
                end
            end
            
            if ~found
                error_msg = sprintf('Must be one of: %s', strjoin(options, ', '));
                is_valid = false;
                return;
            end
            
        case 'array'
            if ~isvector(value)
                error_msg = 'Must be array/vector';
                is_valid = false;
                return;
            end
            
        case 'stimulus_specification'
            % Should be a struct with generator and parameters
            if ~isstruct(value) || ~isfield(value, 'generator') || ...
               ~isfield(value, 'parameters')
                error_msg = 'Must be struct with "generator" and "parameters" fields';
                is_valid = false;
                return;
            end
            
        case 'file_path'
            if ~ischar(value) && ~isstring(value)
                error_msg = 'Must be string (file path)';
                is_valid = false;
                return;
            end
    end
    
    % Check constraints if present
    if isfield(param_def, 'constraints')
        [is_valid, error_msg] = core.validate_constraints(value, param_def.constraints);
    else
        is_valid = true;
    end
end