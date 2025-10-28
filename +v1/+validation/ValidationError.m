classdef ValidationError
    % ValidationError - Represents a validation error with context
    %
    % Each error includes:
    %   - field_path: Dot-notation path to the problematic field
    %   - error_type: Category of error
    %   - message: Human-readable error message
    %   - value: The problematic value (optional)
    %   - expected: What was expected (optional)

    properties
        field_path  % Dot-notation path (e.g., 'tokens.0.base_probability')
        error_type  % Error category (e.g., 'required_field', 'type_mismatch', 'range_violation')
        message     % Human-readable message
        value       % The problematic value (optional)
        expected    % Expected value or constraint (optional)
    end

    methods
        function obj = ValidationError(field_path, error_type, message, value, expected)
            % Constructor
            %
            % Args:
            %   field_path: Dot-notation path to field
            %   error_type: Error category string
            %   message: Human-readable error message
            %   value: Problematic value (optional)
            %   expected: Expected constraint (optional)

            if nargin < 3
                error('ValidationError:MissingArguments', 'field_path, error_type, and message are required');
            end

            obj.field_path = field_path;
            obj.error_type = error_type;
            obj.message = message;

            if nargin >= 4
                obj.value = value;
            else
                obj.value = [];
            end

            if nargin >= 5
                obj.expected = expected;
            else
                obj.expected = [];
            end
        end

        function str = to_string(obj)
            % Convert error to human-readable string
            %
            % Returns:
            %   str: Formatted error message

            str = sprintf('[%s] %s: %s', obj.error_type, obj.field_path, obj.message);

            if ~isempty(obj.value)
                if isnumeric(obj.value) || islogical(obj.value)
                    str = sprintf('%s (got: %s)', str, mat2str(obj.value));
                elseif ischar(obj.value) || isstring(obj.value)
                    str = sprintf('%s (got: "%s")', str, obj.value);
                end
            end

            if ~isempty(obj.expected)
                if isnumeric(obj.expected) || islogical(obj.expected)
                    str = sprintf('%s (expected: %s)', str, mat2str(obj.expected));
                elseif ischar(obj.expected) || isstring(obj.expected)
                    str = sprintf('%s (expected: %s)', str, obj.expected);
                end
            end
        end
    end

    methods (Static)
        function report = format_errors(errors)
            % Format multiple errors into a report
            %
            % Args:
            %   errors: Array or cell array of ValidationError objects
            %
            % Returns:
            %   report: Multi-line string with all errors

            if isempty(errors)
                report = 'No validation errors';
                return;
            end

            % Convert to cell array if needed
            if ~iscell(errors)
                errors = num2cell(errors);
            end

            lines = cell(length(errors) + 1, 1);
            lines{1} = sprintf('Found %d validation error(s):', length(errors));

            for i = 1:length(errors)
                err = errors{i};
                lines{i + 1} = sprintf('  %d. %s', i, err.to_string());
            end

            report = strjoin(lines, '\n');
        end
    end
end
