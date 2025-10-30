classdef TestCustomValidators < matlab.unittest.TestCase
    % TestCustomValidators - Unit tests for CustomValidators

    methods (Test)
        % Probabilities sum tests
        function testProbabilitiesSumValid(testCase)
            probs = [0.7, 0.3];
            [valid, errors] = v1.validation.CustomValidators.validate_probabilities_sum(probs, 'test');
            testCase.verifyTrue(valid);
            testCase.verifyEmpty(errors);
        end

        function testProbabilitiesSumInvalid(testCase)
            probs = [0.7, 0.2];
            [valid, errors] = v1.validation.CustomValidators.validate_probabilities_sum(probs, 'test');
            testCase.verifyFalse(valid);
            testCase.verifyNotEmpty(errors);
        end

        function testProbabilitiesSumWithinTolerance(testCase)
            probs = [0.5, 0.3, 0.2001];  % Sum = 1.0001, within default tolerance
            [valid, errors] = v1.validation.CustomValidators.validate_probabilities_sum(probs, 'test', 0.001);
            testCase.verifyTrue(valid);
        end

        function testProbabilitiesOutOfRange(testCase)
            probs = [0.8, 0.3];  % 0.3 is fine, but sum > 1
            [valid, errors] = v1.validation.CustomValidators.validate_probabilities_sum(probs, 'test');
            testCase.verifyFalse(valid);
        end

        function testProbabilitiesNegative(testCase)
            probs = [-0.1, 1.1];
            [valid, errors] = v1.validation.CustomValidators.validate_probabilities_sum(probs, 'test');
            testCase.verifyFalse(valid);
        end

        % Unique labels tests
        function testUniqueLabelsValid(testCase)
            labels = {'standard', 'deviant1', 'deviant2'};
            [valid, errors] = v1.validation.CustomValidators.validate_unique_labels(labels, 'test');
            testCase.verifyTrue(valid);
            testCase.verifyEmpty(errors);
        end

        function testDuplicateLabels(testCase)
            labels = {'standard', 'deviant', 'standard'};
            [valid, errors] = v1.validation.CustomValidators.validate_unique_labels(labels, 'test');
            testCase.verifyFalse(valid);
            testCase.verifyNotEmpty(errors);
        end

        function testSingleLabel(testCase)
            labels = {'standard'};
            [valid, errors] = v1.validation.CustomValidators.validate_unique_labels(labels, 'test');
            testCase.verifyTrue(valid);
        end

        % Oddball config tests
        function testOddballConfigValid(testCase)
            config = struct();
            config.tokens = {
                struct('label', 'standard', 'stimulus_ref', 'tone1', 'base_probability', 0.85)
                struct('label', 'deviant', 'stimulus_ref', 'tone2', 'base_probability', 0.15)
            };
            [valid, errors] = v1.validation.CustomValidators.validate_oddball_config(config);
            testCase.verifyTrue(valid);
            testCase.verifyEmpty(errors);
        end

        function testOddballConfigInvalidProbs(testCase)
            config = struct();
            config.tokens = {
                struct('label', 'standard', 'stimulus_ref', 'tone1', 'base_probability', 0.85)
                struct('label', 'deviant', 'stimulus_ref', 'tone2', 'base_probability', 0.10)
            };
            [valid, errors] = v1.validation.CustomValidators.validate_oddball_config(config);
            testCase.verifyFalse(valid);
        end

        function testOddballConfigDuplicateLabels(testCase)
            config = struct();
            config.tokens = {
                struct('label', 'standard', 'stimulus_ref', 'tone1', 'base_probability', 0.50)
                struct('label', 'standard', 'stimulus_ref', 'tone2', 'base_probability', 0.50)
            };
            [valid, errors] = v1.validation.CustomValidators.validate_oddball_config(config);
            testCase.verifyFalse(valid);
        end

        % Local-Global config tests
        function testLocalGlobalConfigValid(testCase)
            config = struct();
            config.symbols = {
                struct('symbol', 'A', 'stimulus_ref', 'tone1')
                struct('symbol', 'B', 'stimulus_ref', 'tone2')
            };
            config.patterns = {
                struct('name', 'AAAA', 'probability', 0.5, 'elements', {...
                    struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'A')})
                struct('name', 'AAAB', 'probability', 0.5, 'elements', {...
                    struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'B')})
            };
            [valid, errors] = v1.validation.CustomValidators.validate_local_global_config(config);
            testCase.verifyTrue(valid);
        end

        function testLocalGlobalInvalidSymbolRef(testCase)
            config = struct();
            config.symbols = {
                struct('symbol', 'A', 'stimulus_ref', 'tone1')
            };
            config.patterns = {
                struct('name', 'AAAB', 'probability', 1.0, 'elements', {...
                    struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'B')})
            };
            [valid, errors] = v1.validation.CustomValidators.validate_local_global_config(config);
            testCase.verifyFalse(valid);
        end

        function testLocalGlobalInvalidProbs(testCase)
            config = struct();
            config.symbols = {
                struct('symbol', 'A', 'stimulus_ref', 'tone1')
            };
            config.patterns = {
                struct('name', 'AAAA', 'probability', 0.6, 'elements', {...
                    struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'A')})
                struct('name', 'AAAB', 'probability', 0.3, 'elements', {...
                    struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'A')})
            };
            [valid, errors] = v1.validation.CustomValidators.validate_local_global_config(config);
            testCase.verifyFalse(valid);
        end
    end
end
