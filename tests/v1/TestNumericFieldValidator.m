classdef TestNumericFieldValidator < matlab.unittest.TestCase
    % TestNumericFieldValidator - Unit tests for NumericFieldValidator

    methods (Test)
        % Scalar value tests
        function testScalarImplicit(testCase)
            [valid, errors] = v1.validation.NumericFieldValidator.validate(1000, 'test');
            testCase.verifyTrue(valid);
            testCase.verifyEmpty(errors);
        end

        function testScalarExplicit(testCase)
            field = struct('value', 1000);
            [valid, errors] = v1.validation.NumericFieldValidator.validate(field, 'test');
            testCase.verifyTrue(valid);
            testCase.verifyEmpty(errors);
        end

        function testInvalidScalar(testCase)
            field = struct('value', 'invalid');
            [valid, errors] = v1.validation.NumericFieldValidator.validate(field, 'test');
            testCase.verifyFalse(valid);
            testCase.verifyNotEmpty(errors);
        end

        % Uniform distribution tests
        function testUniformValid(testCase)
            field = struct('dist', 'uniform', 'min', 900, 'max', 1100, 'scope', 'per_trial');
            [valid, errors] = v1.validation.NumericFieldValidator.validate(field, 'test');
            testCase.verifyTrue(valid);
            testCase.verifyEmpty(errors);
        end

        function testUniformInvalidRange(testCase)
            field = struct('dist', 'uniform', 'min', 1100, 'max', 900, 'scope', 'per_trial');
            [valid, errors] = v1.validation.NumericFieldValidator.validate(field, 'test');
            testCase.verifyFalse(valid);
            testCase.verifyNotEmpty(errors);
        end

        function testUniformMissingMin(testCase)
            field = struct('dist', 'uniform', 'max', 1100, 'scope', 'per_trial');
            [valid, errors] = v1.validation.NumericFieldValidator.validate(field, 'test');
            testCase.verifyFalse(valid);
        end

        function testUniformInvalidScope(testCase)
            field = struct('dist', 'uniform', 'min', 900, 'max', 1100, 'scope', 'invalid');
            [valid, errors] = v1.validation.NumericFieldValidator.validate(field, 'test');
            testCase.verifyFalse(valid);
        end

        % Normal distribution tests
        function testNormalValid(testCase)
            field = struct('dist', 'normal', 'mean', 1000, 'std', 50, 'scope', 'per_trial');
            [valid, errors] = v1.validation.NumericFieldValidator.validate(field, 'test');
            testCase.verifyTrue(valid);
            testCase.verifyEmpty(errors);
        end

        function testNormalWithClipping(testCase)
            field = struct('dist', 'normal', 'mean', 1000, 'std', 50, ...
                'clip_min', 900, 'clip_max', 1100, 'scope', 'per_trial');
            [valid, errors] = v1.validation.NumericFieldValidator.validate(field, 'test');
            testCase.verifyTrue(valid);
        end

        function testNormalNegativeStd(testCase)
            field = struct('dist', 'normal', 'mean', 1000, 'std', -50, 'scope', 'per_trial');
            [valid, errors] = v1.validation.NumericFieldValidator.validate(field, 'test');
            testCase.verifyFalse(valid);
        end

        % Log-uniform distribution tests
        function testLoguniformValid(testCase)
            field = struct('dist', 'loguniform', 'min', 100, 'max', 10000, 'scope', 'per_block');
            [valid, errors] = v1.validation.NumericFieldValidator.validate(field, 'test');
            testCase.verifyTrue(valid);
        end

        function testLoguniformNegativeMin(testCase)
            field = struct('dist', 'loguniform', 'min', -100, 'max', 10000, 'scope', 'per_block');
            [valid, errors] = v1.validation.NumericFieldValidator.validate(field, 'test');
            testCase.verifyFalse(valid);
        end

        function testLoguniformZeroMin(testCase)
            field = struct('dist', 'loguniform', 'min', 0, 'max', 10000, 'scope', 'per_block');
            [valid, errors] = v1.validation.NumericFieldValidator.validate(field, 'test');
            testCase.verifyFalse(valid);
        end

        % Categorical distribution tests
        function testCategoricalValid(testCase)
            field = struct('dist', 'categorical', ...
                'categories', [1000 1500 2000], ...
                'probabilities', [0.5 0.3 0.2], ...
                'scope', 'per_trial');
            [valid, errors] = v1.validation.NumericFieldValidator.validate(field, 'test');
            testCase.verifyTrue(valid);
        end

        function testCategoricalInvalidSum(testCase)
            field = struct('dist', 'categorical', ...
                'categories', [1000 1500], ...
                'probabilities', [0.5 0.3], ...
                'scope', 'per_trial');
            [valid, errors] = v1.validation.NumericFieldValidator.validate(field, 'test');
            testCase.verifyFalse(valid);
        end

        function testCategoricalLengthMismatch(testCase)
            field = struct('dist', 'categorical', ...
                'categories', [1000 1500 2000], ...
                'probabilities', [0.5 0.5], ...
                'scope', 'per_trial');
            [valid, errors] = v1.validation.NumericFieldValidator.validate(field, 'test');
            testCase.verifyFalse(valid);
        end

        function testCategoricalOutOfRange(testCase)
            field = struct('dist', 'categorical', ...
                'categories', [1000 1500], ...
                'probabilities', [0.8 0.3], ...
                'scope', 'per_trial');
            [valid, errors] = v1.validation.NumericFieldValidator.validate(field, 'test');
            testCase.verifyFalse(valid);
        end

        % Scope tests
        function testAllValidScopes(testCase)
            scopes = {'per_trial', 'per_block', 'per_session'};
            for i = 1:length(scopes)
                field = struct('dist', 'uniform', 'min', 0, 'max', 1, 'scope', scopes{i});
                [valid, ~] = v1.validation.NumericFieldValidator.validate(field, 'test');
                testCase.verifyTrue(valid, sprintf('Scope %s should be valid', scopes{i}));
            end
        end
    end
end
