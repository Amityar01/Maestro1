classdef Validator < handle
    % Validator - Main validation class for v1 schemas
    %
    % Validates MATLAB structs against JSON schemas.
    %
    % Example:
    %   loader = v1.validation.SchemaLoader('schemas/v1');
    %   validator = v1.validation.Validator(loader);
    %   [valid, errors] = validator.validate(data, 'stimuli/tone.simple.schema.json');

    properties (Access = private)
        schema_loader  % SchemaLoader instance
    end

    methods
        function obj = Validator(schema_loader)
            % Constructor
            %
            % Args:
            %   schema_loader: SchemaLoader instance

            if nargin < 1 || ~isa(schema_loader, 'v1.validation.SchemaLoader')
                error('Validator:InvalidLoader', 'Must provide a SchemaLoader instance');
            end

            obj.schema_loader = schema_loader;
        end

        function [valid, errors] = validate(obj, data, schema_path)
            % Validate data against a schema
            %
            % Args:
            %   data: MATLAB struct to validate
            %   schema_path: Relative path to schema file
            %
            % Returns:
            %   valid: Boolean indicating if validation passed
            %   errors: Cell array of ValidationError objects

            % Load schema
            try
                schema = obj.schema_loader.load(schema_path);
            catch ME
                errors = {v1.validation.ValidationError(...
                    '', 'schema_load_error', ME.message)};
                valid = false;
                return;
            end

            % Validate
            [valid, errors] = obj.validate_value(data, schema, '');
        end

        function [valid, errors] = validate_value(obj, value, schema, field_path)
            % Validate a value against a schema node
            %
            % Args:
            %   value: Value to validate
            %   schema: Schema struct
            %   field_path: Current field path for error reporting
            %
            % Returns:
            %   valid: Boolean
            %   errors: Cell array of ValidationError objects

            errors = {};

            % Handle $ref
            if isfield(schema, 'x_ref')
                ref_path = schema.x_ref;
                % Simplified ref handling - just use numeric_field validator
                if contains(ref_path, 'numeric_field')
                    [valid, errs] = v1.validation.NumericFieldValidator.validate(value, field_path);
                    errors = [errors errs];
                    return;
                end
            end

            % Handle oneOf
            if isfield(schema, 'oneOf')
                [valid, errs] = obj.validate_one_of(value, schema.oneOf, field_path);
                errors = [errors errs];
                return;
            end

            % Handle const
            if isfield(schema, 'const')
                [valid, errs] = obj.validate_const(value, schema.const, field_path);
                errors = [errors errs];
                if ~valid
                    return;
                end
            end

            % Handle type
            if isfield(schema, 'type')
                [type_valid, type_errs] = obj.validate_type(value, schema.type, field_path);
                errors = [errors type_errs];
                if ~type_valid
                    valid = false;
                    return;  % Type mismatch, can't continue
                end
            end

            % Handle enum
            if isfield(schema, 'enum')
                [valid, errs] = obj.validate_enum(value, schema.enum, field_path);
                errors = [errors errs];
                if ~valid
                    return;
                end
            end

            % Type-specific validation
            if isstruct(value)
                [obj_valid, obj_errs] = obj.validate_object(value, schema, field_path);
                errors = [errors obj_errs];
            elseif isnumeric(value) && isscalar(value)
                [num_valid, num_errs] = obj.validate_number(value, schema, field_path);
                errors = [errors num_errs];
            elseif ischar(value) || isstring(value)
                [str_valid, str_errs] = obj.validate_string(value, schema, field_path);
                errors = [errors str_errs];
            elseif iscell(value)
                [arr_valid, arr_errs] = obj.validate_array(value, schema, field_path);
                errors = [errors arr_errs];
            end

            valid = isempty(errors);
        end

        function [valid, errors] = validate_type(obj, value, expected_type, field_path)
            % Validate type
            errors = {};

            actual_type = obj.get_json_type(value);

            if ~strcmp(actual_type, expected_type)
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'type_mismatch', ...
                    sprintf('Expected type "%s"', expected_type), ...
                    actual_type, expected_type);
            end

            valid = isempty(errors);
        end

        function json_type = get_json_type(obj, value)
            % Get JSON Schema type name for a MATLAB value
            if isstruct(value)
                json_type = 'object';
            elseif iscell(value)
                json_type = 'array';
            elseif ischar(value) || isstring(value)
                json_type = 'string';
            elseif isnumeric(value) && isscalar(value)
                if isinteger(value) || (mod(value, 1) == 0)
                    json_type = 'integer';
                else
                    json_type = 'number';
                end
            elseif islogical(value)
                json_type = 'boolean';
            else
                json_type = 'unknown';
            end
        end

        function [valid, errors] = validate_const(obj, value, const_value, field_path)
            % Validate const constraint
            errors = {};

            if ischar(value) || isstring(value)
                if ~strcmp(value, const_value)
                    errors{end+1} = v1.validation.ValidationError(...
                        field_path, 'const_mismatch', ...
                        sprintf('Value must be "%s"', const_value), ...
                        value, const_value);
                end
            elseif isnumeric(value)
                if value ~= const_value
                    errors{end+1} = v1.validation.ValidationError(...
                        field_path, 'const_mismatch', ...
                        'Value does not match const', value, const_value);
                end
            end

            valid = isempty(errors);
        end

        function [valid, errors] = validate_enum(obj, value, enum_values, field_path)
            % Validate enum constraint
            errors = {};

            found = false;
            for i = 1:length(enum_values)
                enum_val = enum_values{i};
                if (ischar(value) || isstring(value)) && strcmp(value, enum_val)
                    found = true;
                    break;
                elseif isnumeric(value) && isnumeric(enum_val) && value == enum_val
                    found = true;
                    break;
                end
            end

            if ~found
                enum_str = strjoin(cellfun(@(x) sprintf('"%s"', x), enum_values, 'UniformOutput', false), ', ');
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'enum_mismatch', ...
                    sprintf('Value must be one of: %s', enum_str), ...
                    value);
            end

            valid = isempty(errors);
        end

        function [valid, errors] = validate_one_of(obj, value, one_of_schemas, field_path)
            % Validate oneOf constraint
            errors = {};

            num_valid = 0;

            for i = 1:length(one_of_schemas)
                [branch_valid, ~] = obj.validate_value(value, one_of_schemas{i}, field_path);
                if branch_valid
                    num_valid = num_valid + 1;
                end
            end

            if num_valid == 0
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'one_of_none_valid', ...
                    'Value does not match any oneOf schemas');
            elseif num_valid > 1
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'one_of_multiple_valid', ...
                    sprintf('Value matches %d oneOf schemas (should match exactly 1)', num_valid));
            end

            valid = isempty(errors);
        end

        function [valid, errors] = validate_object(obj, value, schema, field_path)
            % Validate object (struct)
            errors = {};

            % Check required fields
            if isfield(schema, 'required')
                for i = 1:length(schema.required)
                    field_name = schema.required{i};
                    if ~isfield(value, field_name)
                        errors{end+1} = v1.validation.ValidationError(...
                            field_path, 'required_field', ...
                            sprintf('Missing required field "%s"', field_name));
                    end
                end
            end

            % Validate properties
            if isfield(schema, 'properties')
                prop_names = fieldnames(schema.properties);
                for i = 1:length(prop_names)
                    prop_name = prop_names{i};
                    if isfield(value, prop_name)
                        prop_schema = schema.properties.(prop_name);
                        prop_path = field_path;
                        if ~isempty(field_path)
                            prop_path = [field_path '.' prop_name];
                        else
                            prop_path = prop_name;
                        end
                        [~, prop_errs] = obj.validate_value(value.(prop_name), prop_schema, prop_path);
                        errors = [errors prop_errs];
                    end
                end
            end

            valid = isempty(errors);
        end

        function [valid, errors] = validate_number(obj, value, schema, field_path)
            % Validate number constraints
            errors = {};

            if isfield(schema, 'minimum')
                if value < schema.minimum
                    errors{end+1} = v1.validation.ValidationError(...
                        field_path, 'range_violation', ...
                        sprintf('Value must be >= %g', schema.minimum), ...
                        value, sprintf('>= %g', schema.minimum));
                end
            end

            if isfield(schema, 'maximum')
                if value > schema.maximum
                    errors{end+1} = v1.validation.ValidationError(...
                        field_path, 'range_violation', ...
                        sprintf('Value must be <= %g', schema.maximum), ...
                        value, sprintf('<= %g', schema.maximum));
                end
            end

            if isfield(schema, 'exclusiveMinimum')
                if value <= schema.exclusiveMinimum
                    errors{end+1} = v1.validation.ValidationError(...
                        field_path, 'range_violation', ...
                        sprintf('Value must be > %g', schema.exclusiveMinimum), ...
                        value, sprintf('> %g', schema.exclusiveMinimum));
                end
            end

            if isfield(schema, 'exclusiveMaximum')
                if value >= schema.exclusiveMaximum
                    errors{end+1} = v1.validation.ValidationError(...
                        field_path, 'range_violation', ...
                        sprintf('Value must be < %g', schema.exclusiveMaximum), ...
                        value, sprintf('< %g', schema.exclusiveMaximum));
                end
            end

            valid = isempty(errors);
        end

        function [valid, errors] = validate_string(obj, value, schema, field_path)
            % Validate string constraints
            errors = {};

            % Pattern matching (simplified)
            if isfield(schema, 'pattern')
                pattern = schema.pattern;
                if isempty(regexp(char(value), pattern, 'once'))
                    errors{end+1} = v1.validation.ValidationError(...
                        field_path, 'pattern_mismatch', ...
                        sprintf('Value must match pattern: %s', pattern), ...
                        value);
                end
            end

            valid = isempty(errors);
        end

        function [valid, errors] = validate_array(obj, value, schema, field_path)
            % Validate array (cell array)
            errors = {};

            if isfield(schema, 'minItems')
                if length(value) < schema.minItems
                    errors{end+1} = v1.validation.ValidationError(...
                        field_path, 'array_size', ...
                        sprintf('Array must have at least %d items', schema.minItems), ...
                        length(value), sprintf('>= %d', schema.minItems));
                end
            end

            if isfield(schema, 'maxItems')
                if length(value) > schema.maxItems
                    errors{end+1} = v1.validation.ValidationError(...
                        field_path, 'array_size', ...
                        sprintf('Array must have at most %d items', schema.maxItems), ...
                        length(value), sprintf('<= %d', schema.maxItems));
                end
            end

            % Validate items
            if isfield(schema, 'items')
                for i = 1:length(value)
                    item_path = sprintf('%s[%d]', field_path, i-1);  % 0-indexed for JSON compatibility
                    [~, item_errs] = obj.validate_value(value{i}, schema.items, item_path);
                    errors = [errors item_errs];
                end
            end

            valid = isempty(errors);
        end
    end
end
