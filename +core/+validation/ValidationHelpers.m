classdef ValidationHelpers
    % VALIDATIONHELPERS - Common validation utility functions
    %
    % This class provides reusable validation functions to reduce
    % code duplication across the codebase.
    %
    % Usage:
    %   ValidationHelpers.validate_required_fields(spec, {'field1', 'field2'});
    %   ValidationHelpers.validate_numeric_range(value, 'freq_hz', 20, 20000);

    methods (Static)
        function validate_required_fields(structure, required_fields, context_name)
            % VALIDATE_REQUIRED_FIELDS - Ensure all required fields exist
            %
            % INPUTS:
            %   structure - struct to validate
            %   required_fields - cell array of required field names
            %   context_name - string, context for error message

            if nargin < 3
                context_name = 'structure';
            end

            missing = {};
            for i = 1:length(required_fields)
                field = required_fields{i};
                if ~isfield(structure, field) || isempty(structure.(field))
                    missing{end+1} = field; %#ok<AGROW>
                end
            end

            if ~isempty(missing)
                error('ValidationHelpers:MissingFields', ...
                    '%s missing required fields: %s', ...
                    context_name, strjoin(missing, ', '));
            end
        end

        function validate_numeric_range(value, field_name, min_val, max_val, must_be_integer)
            % VALIDATE_NUMERIC_RANGE - Ensure numeric value is in range
            %
            % INPUTS:
            %   value - numeric value to validate
            %   field_name - string, field name for error messages
            %   min_val - numeric, minimum allowed value
            %   max_val - numeric, maximum allowed value
            %   must_be_integer - boolean, require integer (default: false)

            if nargin < 5
                must_be_integer = false;
            end

            % Check it's numeric and scalar
            if ~isnumeric(value) || ~isscalar(value)
                error('ValidationHelpers:InvalidType', ...
                    '%s must be a numeric scalar', field_name);
            end

            % Check range
            if value < min_val || value > max_val
                error('ValidationHelpers:OutOfRange', ...
                    '%s must be between %g and %g (got %g)', ...
                    field_name, min_val, max_val, value);
            end

            % Check integer if required
            if must_be_integer && value ~= floor(value)
                error('ValidationHelpers:NotInteger', ...
                    '%s must be an integer (got %g)', field_name, value);
            end
        end

        function validate_probability(value, field_name)
            % VALIDATE_PROBABILITY - Ensure value is a valid probability
            %
            % INPUTS:
            %   value - numeric value to validate
            %   field_name - string, field name for error messages

            core.validation.ValidationHelpers.validate_numeric_range(...
                value, field_name, 0, 1, false);
        end

        function validate_enum(value, field_name, allowed_values)
            % VALIDATE_ENUM - Ensure value is in allowed set
            %
            % INPUTS:
            %   value - value to validate
            %   field_name - string, field name for error messages
            %   allowed_values - cell array of allowed values

            % Convert to string for comparison
            value_str = char(value);

            % Convert allowed values to cell array of strings
            allowed_strs = cellfun(@char, allowed_values, 'UniformOutput', false);

            if ~any(strcmp(value_str, allowed_strs))
                error('ValidationHelpers:InvalidEnum', ...
                    '%s must be one of: %s (got "%s")', ...
                    field_name, strjoin(allowed_strs, ', '), value_str);
            end
        end

        function validate_struct(value, field_name)
            % VALIDATE_STRUCT - Ensure value is a struct
            %
            % INPUTS:
            %   value - value to validate
            %   field_name - string, field name for error messages

            if ~isstruct(value)
                error('ValidationHelpers:InvalidType', ...
                    '%s must be a struct', field_name);
            end
        end

        function validate_cell_array(value, field_name, min_length, max_length)
            % VALIDATE_CELL_ARRAY - Ensure value is a cell array
            %
            % INPUTS:
            %   value - value to validate
            %   field_name - string, field name for error messages
            %   min_length - integer, minimum length (optional)
            %   max_length - integer, maximum length (optional)

            if ~iscell(value)
                error('ValidationHelpers:InvalidType', ...
                    '%s must be a cell array', field_name);
            end

            if nargin >= 3 && ~isempty(min_length)
                if length(value) < min_length
                    error('ValidationHelpers:TooShort', ...
                        '%s must have at least %d elements (got %d)', ...
                        field_name, min_length, length(value));
                end
            end

            if nargin >= 4 && ~isempty(max_length)
                if length(value) > max_length
                    error('ValidationHelpers:TooLong', ...
                        '%s must have at most %d elements (got %d)', ...
                        field_name, max_length, length(value));
                end
            end
        end

        function validate_experiment_spec(experiment_spec)
            % VALIDATE_EXPERIMENT_SPEC - Validate experiment specification
            %
            % INPUTS:
            %   experiment_spec - struct, experiment specification

            % Required top-level fields
            required_fields = {'experiment_id', 'global_settings', 'sequence'};
            core.validation.ValidationHelpers.validate_required_fields(...
                experiment_spec, required_fields, 'experiment_spec');

            % Validate global settings
            global_settings = experiment_spec.global_settings;
            if ~isfield(global_settings, 'sampling_rate_hz') || ...
                    isempty(global_settings.sampling_rate_hz)
                error('ValidationHelpers:MissingField', ...
                    'global_settings must contain sampling_rate_hz');
            end

            % Validate sampling rate is in valid range
            core.Constants.validate_sampling_rate(...
                global_settings.sampling_rate_hz);

            % Validate sequence is not empty
            if isempty(experiment_spec.sequence)
                error('ValidationHelpers:EmptySequence', ...
                    'Experiment sequence is empty');
            end
        end

        function validate_block_instance(instance)
            % VALIDATE_BLOCK_INSTANCE - Validate block instance structure
            %
            % INPUTS:
            %   instance - struct, block instance

            % Required fields
            required_fields = {'builder_type', 'instance_id', 'parameters'};
            core.validation.ValidationHelpers.validate_required_fields(...
                instance, required_fields, 'block_instance');

            % Validate parameters is a struct
            core.validation.ValidationHelpers.validate_struct(...
                instance.parameters, 'parameters');
        end

        function validate_stimulus_spec(stimulus_spec)
            % VALIDATE_STIMULUS_SPEC - Validate stimulus specification
            %
            % INPUTS:
            %   stimulus_spec - struct, stimulus specification

            % Required fields
            required_fields = {'generator', 'version', 'parameters'};
            core.validation.ValidationHelpers.validate_required_fields(...
                stimulus_spec, required_fields, 'stimulus_spec');

            % Validate parameters is a struct
            core.validation.ValidationHelpers.validate_struct(...
                stimulus_spec.parameters, 'parameters');
        end

        function [is_valid, errors] = safe_validate(validation_func, varargin)
            % SAFE_VALIDATE - Run validation and catch errors
            %
            % INPUTS:
            %   validation_func - function handle for validation
            %   varargin - arguments to pass to validation function
            %
            % OUTPUTS:
            %   is_valid - boolean, true if validation passed
            %   errors - cell array of error messages

            errors = {};
            try
                validation_func(varargin{:});
                is_valid = true;
            catch ME
                is_valid = false;
                errors = {ME.message};
            end
        end
    end
end
