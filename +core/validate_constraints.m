function [is_valid, error_msg] = validate_constraints(value, constraints)
% VALIDATE_CONSTRAINTS - Validate value against constraints
%
% INPUTS:
%   value       - any type, value to validate
%   constraints - struct, constraint specifications
%
% OUTPUTS:
%   is_valid  - boolean
%   error_msg - string, empty if valid

    error_msg = '';
    is_valid = true;
    
    % Min constraint
    if isfield(constraints, 'min')
        if isnumeric(value) && value < constraints.min
            error_msg = sprintf('Value %g is below minimum %g', ...
                value, constraints.min);
            is_valid = false;
            return;
        end
    end
    
    % Max constraint
    if isfield(constraints, 'max')
        if isnumeric(value) && value > constraints.max
            error_msg = sprintf('Value %g exceeds maximum %g', ...
                value, constraints.max);
            is_valid = false;
            return;
        end
    end
    
    % Pattern constraint (for strings)
    if isfield(constraints, 'pattern')
        if ischar(value) || isstring(value)
            if isempty(regexp(char(value), constraints.pattern, 'once'))
                error_msg = sprintf('String does not match pattern: %s', ...
                    constraints.pattern);
                is_valid = false;
                return;
            end
        end
    end
    
    % Options constraint (already handled in validate_parameter_value for enum)
    % But can also apply to other types
    if isfield(constraints, 'options') && ~isfield(constraints, 'type')
        % Check if value is in options list
        found = false;
        for i = 1:length(constraints.options)
            if isequal(value, constraints.options{i})
                found = true;
                break;
            end
        end
        if ~found
            error_msg = 'Value not in allowed options';
            is_valid = false;
            return;
        end
    end
end