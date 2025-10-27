classdef TestValidationHelpers < matlab.unittest.TestCase
    % TESTVALIDATIONHELPERS - Unit tests for ValidationHelpers
    %
    % Tests all validation functions to ensure proper error handling
    % and validation logic.

    methods (Test)
        % ============================================================
        % Required Fields Tests
        % ============================================================

        function testValidateRequiredFields_AllPresent(testCase)
            % Test validation passes when all fields present

            s = struct('field1', 'value1', 'field2', 'value2', 'field3', 'value3');
            required = {'field1', 'field2', 'field3'};

            % Should not throw
            core.validation.ValidationHelpers.validate_required_fields(...
                s, required, 'test_struct');
        end

        function testValidateRequiredFields_OneMissing(testCase)
            % Test validation fails when one field missing

            s = struct('field1', 'value1', 'field2', 'value2');
            required = {'field1', 'field2', 'field3'};

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_required_fields(...
                    s, required, 'test_struct'), ...
                'ValidationHelpers:MissingFields');
        end

        function testValidateRequiredFields_EmptyField(testCase)
            % Test validation fails when field is empty

            s = struct('field1', 'value1', 'field2', []);
            required = {'field1', 'field2'};

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_required_fields(...
                    s, required, 'test_struct'), ...
                'ValidationHelpers:MissingFields');
        end

        % ============================================================
        % Numeric Range Tests
        % ============================================================

        function testValidateNumericRange_ValidValue(testCase)
            % Test validation passes for valid value

            % Should not throw
            core.validation.ValidationHelpers.validate_numeric_range(...
                50, 'test_field', 0, 100, false);
        end

        function testValidateNumericRange_BoundaryValues(testCase)
            % Test validation passes at boundaries

            % Min boundary
            core.validation.ValidationHelpers.validate_numeric_range(...
                0, 'test_field', 0, 100, false);

            % Max boundary
            core.validation.ValidationHelpers.validate_numeric_range(...
                100, 'test_field', 0, 100, false);
        end

        function testValidateNumericRange_BelowMin(testCase)
            % Test validation fails below minimum

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_numeric_range(...
                    -1, 'test_field', 0, 100, false), ...
                'ValidationHelpers:OutOfRange');
        end

        function testValidateNumericRange_AboveMax(testCase)
            % Test validation fails above maximum

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_numeric_range(...
                    101, 'test_field', 0, 100, false), ...
                'ValidationHelpers:OutOfRange');
        end

        function testValidateNumericRange_NotNumeric(testCase)
            % Test validation fails for non-numeric

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_numeric_range(...
                    'string', 'test_field', 0, 100, false), ...
                'ValidationHelpers:InvalidType');
        end

        function testValidateNumericRange_NotScalar(testCase)
            % Test validation fails for non-scalar

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_numeric_range(...
                    [1 2 3], 'test_field', 0, 100, false), ...
                'ValidationHelpers:InvalidType');
        end

        function testValidateNumericRange_IntegerRequired_Valid(testCase)
            % Test integer validation passes for integer

            % Should not throw
            core.validation.ValidationHelpers.validate_numeric_range(...
                42, 'test_field', 0, 100, true);
        end

        function testValidateNumericRange_IntegerRequired_Float(testCase)
            % Test integer validation fails for float

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_numeric_range(...
                    42.5, 'test_field', 0, 100, true), ...
                'ValidationHelpers:NotInteger');
        end

        % ============================================================
        % Probability Tests
        % ============================================================

        function testValidateProbability_ValidValues(testCase)
            % Test probability validation for valid values

            % Should not throw
            core.validation.ValidationHelpers.validate_probability(0, 'p');
            core.validation.ValidationHelpers.validate_probability(0.5, 'p');
            core.validation.ValidationHelpers.validate_probability(1, 'p');
        end

        function testValidateProbability_BelowZero(testCase)
            % Test probability validation fails below 0

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_probability(-0.1, 'p'), ...
                'ValidationHelpers:OutOfRange');
        end

        function testValidateProbability_AboveOne(testCase)
            % Test probability validation fails above 1

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_probability(1.1, 'p'), ...
                'ValidationHelpers:OutOfRange');
        end

        % ============================================================
        % Enum Tests
        % ============================================================

        function testValidateEnum_ValidValue(testCase)
            % Test enum validation passes for valid value

            allowed = {'option1', 'option2', 'option3'};

            % Should not throw
            core.validation.ValidationHelpers.validate_enum(...
                'option1', 'test_field', allowed);
        end

        function testValidateEnum_InvalidValue(testCase)
            % Test enum validation fails for invalid value

            allowed = {'option1', 'option2', 'option3'};

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_enum(...
                    'invalid', 'test_field', allowed), ...
                'ValidationHelpers:InvalidEnum');
        end

        function testValidateEnum_CaseSensitive(testCase)
            % Test enum validation is case-sensitive

            allowed = {'Option1', 'Option2'};

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_enum(...
                    'option1', 'test_field', allowed), ...
                'ValidationHelpers:InvalidEnum');
        end

        % ============================================================
        % Type Validation Tests
        % ============================================================

        function testValidateStruct_Valid(testCase)
            % Test struct validation passes for struct

            s = struct('field', 'value');

            % Should not throw
            core.validation.ValidationHelpers.validate_struct(s, 'test_field');
        end

        function testValidateStruct_NotStruct(testCase)
            % Test struct validation fails for non-struct

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_struct(...
                    'not a struct', 'test_field'), ...
                'ValidationHelpers:InvalidType');
        end

        function testValidateCellArray_Valid(testCase)
            % Test cell array validation passes

            c = {1, 2, 3};

            % Should not throw
            core.validation.ValidationHelpers.validate_cell_array(c, 'test_field');
        end

        function testValidateCellArray_NotCell(testCase)
            % Test cell array validation fails for non-cell

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_cell_array(...
                    [1 2 3], 'test_field'), ...
                'ValidationHelpers:InvalidType');
        end

        function testValidateCellArray_WithLengthConstraints(testCase)
            % Test cell array length validation

            c = {1, 2, 3};

            % Valid length
            core.validation.ValidationHelpers.validate_cell_array(...
                c, 'test_field', 2, 5);

            % Too short
            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_cell_array(...
                    c, 'test_field', 5, 10), ...
                'ValidationHelpers:TooShort');

            % Too long
            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_cell_array(...
                    c, 'test_field', 1, 2), ...
                'ValidationHelpers:TooLong');
        end

        % ============================================================
        % Complex Validation Tests
        % ============================================================

        function testValidateExperimentSpec_Valid(testCase)
            % Test experiment spec validation passes

            spec = struct(...
                'experiment_id', 'test_exp', ...
                'global_settings', struct('sampling_rate_hz', 192000), ...
                'sequence', {{'block1'}});

            % Should not throw
            core.validation.ValidationHelpers.validate_experiment_spec(spec);
        end

        function testValidateExperimentSpec_MissingField(testCase)
            % Test experiment spec validation fails for missing field

            spec = struct(...
                'experiment_id', 'test_exp', ...
                'global_settings', struct('sampling_rate_hz', 192000));
            % Missing sequence

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_experiment_spec(spec), ...
                'ValidationHelpers:MissingFields');
        end

        function testValidateExperimentSpec_MissingSamplingRate(testCase)
            % Test experiment spec validation fails without sampling rate

            spec = struct(...
                'experiment_id', 'test_exp', ...
                'global_settings', struct('other_field', 'value'), ...
                'sequence', {{'block1'}});

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_experiment_spec(spec), ...
                'ValidationHelpers:MissingField');
        end

        function testValidateExperimentSpec_EmptySequence(testCase)
            % Test experiment spec validation fails for empty sequence

            % Create struct properly - assigning {} directly in struct()
            % creates issues in some MATLAB versions
            spec = struct(...
                'experiment_id', 'test_exp', ...
                'global_settings', struct('sampling_rate_hz', 192000));
            spec.sequence = {};  % Assign empty cell array separately

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_experiment_spec(spec), ...
                'ValidationHelpers:EmptySequence');
        end

        function testValidateBlockInstance_Valid(testCase)
            % Test block instance validation passes

            instance = struct(...
                'builder_type', 'oddball', ...
                'instance_id', 'test_id', ...
                'parameters', struct('n_trials', 100));

            % Should not throw
            core.validation.ValidationHelpers.validate_block_instance(instance);
        end

        function testValidateBlockInstance_MissingBuilderType(testCase)
            % Test block instance validation fails without builder_type

            instance = struct(...
                'instance_id', 'test_id', ...
                'parameters', struct('n_trials', 100));

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_block_instance(instance), ...
                'ValidationHelpers:MissingFields');
        end

        function testValidateStimulusSpec_Valid(testCase)
            % Test stimulus spec validation passes

            spec = struct(...
                'generator', 'audio.tone', ...
                'version', '1.0', ...
                'parameters', struct('freq_hz', 1000));

            % Should not throw
            core.validation.ValidationHelpers.validate_stimulus_spec(spec);
        end

        function testValidateStimulusSpec_MissingGenerator(testCase)
            % Test stimulus spec validation fails without generator

            spec = struct(...
                'version', '1.0', ...
                'parameters', struct('freq_hz', 1000));

            testCase.verifyError(...
                @() core.validation.ValidationHelpers.validate_stimulus_spec(spec), ...
                'ValidationHelpers:MissingFields');
        end

        % ============================================================
        % Safe Validation Tests
        % ============================================================

        function testSafeValidate_PassingValidation(testCase)
            % Test safe_validate with passing validation

            validation_func = @(x) core.validation.ValidationHelpers.validate_numeric_range(...
                x, 'test', 0, 100, false);

            [is_valid, errors] = core.validation.ValidationHelpers.safe_validate(...
                validation_func, 50);

            testCase.verifyTrue(is_valid);
            testCase.verifyEmpty(errors);
        end

        function testSafeValidate_FailingValidation(testCase)
            % Test safe_validate with failing validation

            validation_func = @(x) core.validation.ValidationHelpers.validate_numeric_range(...
                x, 'test', 0, 100, false);

            [is_valid, errors] = core.validation.ValidationHelpers.safe_validate(...
                validation_func, 150);

            testCase.verifyFalse(is_valid);
            testCase.verifyNotEmpty(errors);
        end
    end
end
