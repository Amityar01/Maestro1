function [is_valid, error_msg] = validate_randomization_spec(spec, param_def)
% VALIDATE_RANDOMIZATION_SPEC - Validate a randomization specification
%
% INPUTS:
%   spec      - struct, randomization specification
%   param_def - struct, parameter definition from schema
%
% OUTPUTS:
%   is_valid  - boolean
%   error_msg - string, empty if valid

    error_msg = '';
    is_valid = true;
    
    % Check if randomization is allowed
    if isfield(param_def, 'randomizable') && ~param_def.randomizable
        error_msg = 'Parameter is not randomizable according to schema';
        is_valid = false;
        return;
    end
    
    % Validate based on randomization type
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
            
            % Options must be non-empty
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