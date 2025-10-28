classdef NumericFieldValidator
    % NumericFieldValidator - Validates numeric field union (scalar or distribution)
    %
    % Numeric fields can be:
    %   - Scalar: {value: 50}
    %   - Uniform: {dist: "uniform", min: 40, max: 60, scope: "per_trial"}
    %   - Normal: {dist: "normal", mean: 50, std: 5, scope: "per_trial"}
    %   - Log-uniform: {dist: "loguniform", min: 10, max: 1000, scope: "per_trial"}
    %   - Categorical: {dist: "categorical", categories: [1,2,3], probabilities: [0.5,0.3,0.2], scope: "per_trial"}

    methods (Static)
        function [valid, errors] = validate(field_value, field_path)
            % Validate a numeric field
            %
            % Args:
            %   field_value: The field to validate (struct or numeric)
            %   field_path: Dot-notation path for error reporting
            %
            % Returns:
            %   valid: Boolean indicating if validation passed
            %   errors: Array of ValidationError objects

            errors = {};

            % Check if it's a struct
            if ~isstruct(field_value)
                % If it's numeric, treat as implicit scalar {value: X}
                if isnumeric(field_value) && isscalar(field_value)
                    valid = true;
                    return;
                else
                    errors{end+1} = v1.validation.ValidationError(...
                        field_path, 'type_mismatch', ...
                        'Numeric field must be a struct or scalar number', ...
                        class(field_value), 'struct or number');
                    valid = false;
                    return;
                end
            end

            % Check if it's a scalar value form: {value: X}
            if isfield(field_value, 'value') && ~isfield(field_value, 'dist')
                [valid, errs] = v1.validation.NumericFieldValidator.validate_scalar(field_value, field_path);
                errors = [errors errs];
                return;
            end

            % Must be a distribution form
            if ~isfield(field_value, 'dist')
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'required_field', ...
                    'Numeric field must have either "value" or "dist" field');
                valid = false;
                return;
            end

            % Validate based on distribution type
            dist_type = field_value.dist;

            switch dist_type
                case 'uniform'
                    [valid, errs] = v1.validation.NumericFieldValidator.validate_uniform(field_value, field_path);
                case 'normal'
                    [valid, errs] = v1.validation.NumericFieldValidator.validate_normal(field_value, field_path);
                case 'loguniform'
                    [valid, errs] = v1.validation.NumericFieldValidator.validate_loguniform(field_value, field_path);
                case 'categorical'
                    [valid, errs] = v1.validation.NumericFieldValidator.validate_categorical(field_value, field_path);
                otherwise
                    errors{end+1} = v1.validation.ValidationError(...
                        [field_path '.dist'], 'invalid_value', ...
                        sprintf('Unknown distribution type: %s', dist_type), ...
                        dist_type, 'uniform, normal, loguniform, or categorical');
                    valid = false;
                    return;
            end

            errors = [errors errs];
        end

        function [valid, errors] = validate_scalar(field_value, field_path)
            % Validate scalar form: {value: X}
            errors = {};

            if ~isfield(field_value, 'value')
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'required_field', 'Missing "value" field');
            elseif ~isnumeric(field_value.value) || ~isscalar(field_value.value)
                errors{end+1} = v1.validation.ValidationError(...
                    [field_path '.value'], 'type_mismatch', ...
                    'Value must be a scalar number', ...
                    class(field_value.value), 'scalar number');
            end

            valid = isempty(errors);
        end

        function [valid, errors] = validate_uniform(field_value, field_path)
            % Validate uniform distribution
            errors = {};

            % Check required fields
            if ~isfield(field_value, 'min')
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'required_field', 'Uniform distribution requires "min" field');
            elseif ~isnumeric(field_value.min) || ~isscalar(field_value.min)
                errors{end+1} = v1.validation.ValidationError(...
                    [field_path '.min'], 'type_mismatch', 'min must be a scalar number');
            end

            if ~isfield(field_value, 'max')
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'required_field', 'Uniform distribution requires "max" field');
            elseif ~isnumeric(field_value.max) || ~isscalar(field_value.max)
                errors{end+1} = v1.validation.ValidationError(...
                    [field_path '.max'], 'type_mismatch', 'max must be a scalar number');
            end

            [scope_valid, scope_errs] = v1.validation.NumericFieldValidator.validate_scope(field_value, field_path);
            errors = [errors scope_errs];

            % Check min < max
            if isfield(field_value, 'min') && isfield(field_value, 'max')
                if field_value.min >= field_value.max
                    errors{end+1} = v1.validation.ValidationError(...
                        field_path, 'constraint_violation', ...
                        'min must be less than max', ...
                        sprintf('min=%g, max=%g', field_value.min, field_value.max));
                end
            end

            valid = isempty(errors);
        end

        function [valid, errors] = validate_normal(field_value, field_path)
            % Validate normal distribution
            errors = {};

            % Check required fields
            if ~isfield(field_value, 'mean')
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'required_field', 'Normal distribution requires "mean" field');
            elseif ~isnumeric(field_value.mean) || ~isscalar(field_value.mean)
                errors{end+1} = v1.validation.ValidationError(...
                    [field_path '.mean'], 'type_mismatch', 'mean must be a scalar number');
            end

            if ~isfield(field_value, 'std')
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'required_field', 'Normal distribution requires "std" field');
            elseif ~isnumeric(field_value.std) || ~isscalar(field_value.std)
                errors{end+1} = v1.validation.ValidationError(...
                    [field_path '.std'], 'type_mismatch', 'std must be a scalar number');
            elseif field_value.std < 0
                errors{end+1} = v1.validation.ValidationError(...
                    [field_path '.std'], 'range_violation', ...
                    'std must be non-negative', field_value.std, '>= 0');
            end

            [scope_valid, scope_errs] = v1.validation.NumericFieldValidator.validate_scope(field_value, field_path);
            errors = [errors scope_errs];

            % Check optional clip bounds
            if isfield(field_value, 'clip_min') && isfield(field_value, 'clip_max')
                if field_value.clip_min >= field_value.clip_max
                    errors{end+1} = v1.validation.ValidationError(...
                        field_path, 'constraint_violation', ...
                        'clip_min must be less than clip_max');
                end
            end

            valid = isempty(errors);
        end

        function [valid, errors] = validate_loguniform(field_value, field_path)
            % Validate log-uniform distribution
            errors = {};

            % Check required fields
            if ~isfield(field_value, 'min')
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'required_field', 'Log-uniform distribution requires "min" field');
            elseif ~isnumeric(field_value.min) || ~isscalar(field_value.min)
                errors{end+1} = v1.validation.ValidationError(...
                    [field_path '.min'], 'type_mismatch', 'min must be a scalar number');
            elseif field_value.min <= 0
                errors{end+1} = v1.validation.ValidationError(...
                    [field_path '.min'], 'range_violation', ...
                    'Log-uniform min must be > 0', field_value.min, '> 0');
            end

            if ~isfield(field_value, 'max')
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'required_field', 'Log-uniform distribution requires "max" field');
            elseif ~isnumeric(field_value.max) || ~isscalar(field_value.max)
                errors{end+1} = v1.validation.ValidationError(...
                    [field_path '.max'], 'type_mismatch', 'max must be a scalar number');
            elseif field_value.max <= 0
                errors{end+1} = v1.validation.ValidationError(...
                    [field_path '.max'], 'range_violation', ...
                    'Log-uniform max must be > 0', field_value.max, '> 0');
            end

            [scope_valid, scope_errs] = v1.validation.NumericFieldValidator.validate_scope(field_value, field_path);
            errors = [errors scope_errs];

            % Check min < max
            if isfield(field_value, 'min') && isfield(field_value, 'max')
                if field_value.min >= field_value.max
                    errors{end+1} = v1.validation.ValidationError(...
                        field_path, 'constraint_violation', ...
                        'min must be less than max');
                end
            end

            valid = isempty(errors);
        end

        function [valid, errors] = validate_categorical(field_value, field_path)
            % Validate categorical distribution
            errors = {};

            % Check categories
            if ~isfield(field_value, 'categories')
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'required_field', 'Categorical distribution requires "categories" field');
            elseif ~isnumeric(field_value.categories) || length(field_value.categories) < 2
                errors{end+1} = v1.validation.ValidationError(...
                    [field_path '.categories'], 'type_mismatch', ...
                    'categories must be numeric array with at least 2 elements');
            end

            % Check probabilities
            if ~isfield(field_value, 'probabilities')
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'required_field', 'Categorical distribution requires "probabilities" field');
            elseif ~isnumeric(field_value.probabilities)
                errors{end+1} = v1.validation.ValidationError(...
                    [field_path '.probabilities'], 'type_mismatch', ...
                    'probabilities must be numeric array');
            else
                % Check probabilities sum to 1
                prob_sum = sum(field_value.probabilities);
                if abs(prob_sum - 1.0) > 0.001
                    errors{end+1} = v1.validation.ValidationError(...
                        [field_path '.probabilities'], 'constraint_violation', ...
                        'Probabilities must sum to 1.0 (±0.001)', prob_sum, 1.0);
                end

                % Check all probabilities in [0,1]
                if any(field_value.probabilities < 0) || any(field_value.probabilities > 1)
                    errors{end+1} = v1.validation.ValidationError(...
                        [field_path '.probabilities'], 'range_violation', ...
                        'All probabilities must be in range [0, 1]');
                end
            end

            % Check lengths match
            if isfield(field_value, 'categories') && isfield(field_value, 'probabilities')
                if length(field_value.categories) ~= length(field_value.probabilities)
                    errors{end+1} = v1.validation.ValidationError(...
                        field_path, 'constraint_violation', ...
                        'categories and probabilities must have same length');
                end
            end

            [scope_valid, scope_errs] = v1.validation.NumericFieldValidator.validate_scope(field_value, field_path);
            errors = [errors scope_errs];

            valid = isempty(errors);
        end

        function [valid, errors] = validate_scope(field_value, field_path)
            % Validate scope field
            errors = {};

            if ~isfield(field_value, 'scope')
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'required_field', 'Distribution requires "scope" field');
            elseif ~ischar(field_value.scope) && ~isstring(field_value.scope)
                errors{end+1} = v1.validation.ValidationError(...
                    [field_path '.scope'], 'type_mismatch', 'scope must be a string');
            else
                valid_scopes = {'per_trial', 'per_block', 'per_session'};
                if ~ismember(field_value.scope, valid_scopes)
                    errors{end+1} = v1.validation.ValidationError(...
                        [field_path '.scope'], 'invalid_value', ...
                        sprintf('Invalid scope: %s', field_value.scope), ...
                        field_value.scope, 'per_trial, per_block, or per_session');
                end
            end

            valid = isempty(errors);
        end
    end
end
