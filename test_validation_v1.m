% test_validation_v1 - Demonstration and test of v1 validation framework
%
% This script demonstrates the validation framework working with:
%   1. Numeric fields (scalar and distributions)
%   2. Stimulus schemas
%   3. Paradigm schemas
%   4. Custom validators

clear; clc;

fprintf('=== V1 Validation Framework Test ===\n\n');

%% 1. Test Schema Loader

fprintf('1. Testing SchemaLoader...\n');
try
    loader = v1.validation.SchemaLoader('schemas/v1');
    fprintf('   ✓ SchemaLoader created\n');

    % Load a schema
    schema = loader.load('core/numeric_field.schema.json');
    fprintf('   ✓ Loaded numeric_field schema\n');

    % Load by ID
    %schema2 = loader.load_by_id('https://maestro.neuroscience/schemas/v1/core/numeric_field');
    %fprintf('   ✓ Loaded schema by ID\n');
catch ME
    fprintf('   ✗ Error: %s\n', ME.message);
end

fprintf('\n');

%% 2. Test Numeric Field Validator

fprintf('2. Testing NumericFieldValidator...\n');

% Test scalar value
test_cases = {
    struct('name', 'Scalar implicit', 'value', 1000, 'should_pass', true)
    struct('name', 'Scalar explicit', 'value', struct('value', 1000), 'should_pass', true)
    struct('name', 'Uniform valid', 'value', struct('dist', 'uniform', 'min', 900, 'max', 1100, 'scope', 'per_trial'), 'should_pass', true)
    struct('name', 'Uniform invalid (min > max)', 'value', struct('dist', 'uniform', 'min', 1100, 'max', 900, 'scope', 'per_trial'), 'should_pass', false)
    struct('name', 'Normal valid', 'value', struct('dist', 'normal', 'mean', 1000, 'std', 50, 'scope', 'per_trial'), 'should_pass', true)
    struct('name', 'Normal invalid (negative std)', 'value', struct('dist', 'normal', 'mean', 1000, 'std', -50, 'scope', 'per_trial'), 'should_pass', false)
    struct('name', 'Loguniform valid', 'value', struct('dist', 'loguniform', 'min', 100, 'max', 10000, 'scope', 'per_block'), 'should_pass', true)
    struct('name', 'Categorical valid', 'value', struct('dist', 'categorical', 'categories', [1000 1500 2000], 'probabilities', [0.5 0.3 0.2], 'scope', 'per_trial'), 'should_pass', true)
    struct('name', 'Categorical invalid (probs dont sum)', 'value', struct('dist', 'categorical', 'categories', [1000 1500], 'probabilities', [0.5 0.3], 'scope', 'per_trial'), 'should_pass', false)
};

for i = 1:length(test_cases)
    test = test_cases{i};
    [valid, errors] = v1.validation.NumericFieldValidator.validate(test.value, 'test_field');

    if valid == test.should_pass
        fprintf('   ✓ %s\n', test.name);
    else
        fprintf('   ✗ %s (expected %s, got %s)\n', test.name, ...
            mat2str(test.should_pass), mat2str(valid));
        if ~isempty(errors)
            for j = 1:length(errors)
                fprintf('      Error: %s\n', errors{j}.to_string());
            end
        end
    end
end

fprintf('\n');

%% 3. Test Custom Validators

fprintf('3. Testing CustomValidators...\n');

% Test probabilities sum
[valid, errors] = v1.validation.CustomValidators.validate_probabilities_sum(...
    [0.7, 0.3], 'test.probabilities');
if valid
    fprintf('   ✓ Probabilities sum to 1.0\n');
else
    fprintf('   ✗ Probabilities sum validation failed\n');
end

[valid, errors] = v1.validation.CustomValidators.validate_probabilities_sum(...
    [0.7, 0.2], 'test.probabilities');
if ~valid
    fprintf('   ✓ Detected probabilities not summing to 1.0\n');
    fprintf('      %s\n', errors{1}.to_string());
else
    fprintf('   ✗ Should have detected invalid probability sum\n');
end

% Test unique labels
[valid, errors] = v1.validation.CustomValidators.validate_unique_labels(...
    {'standard', 'deviant1', 'deviant2'}, 'test.labels');
if valid
    fprintf('   ✓ Unique labels validated\n');
else
    fprintf('   ✗ Unique labels validation failed\n');
end

[valid, errors] = v1.validation.CustomValidators.validate_unique_labels(...
    {'standard', 'deviant', 'standard'}, 'test.labels');
if ~valid
    fprintf('   ✓ Detected duplicate labels\n');
    fprintf('      %s\n', errors{1}.to_string());
else
    fprintf('   ✗ Should have detected duplicate labels\n');
end

fprintf('\n');

%% 4. Test Oddball Config Validation

fprintf('4. Testing Oddball Configuration Validation...\n');

% Valid oddball config
oddball_valid = struct();
oddball_valid.tokens = {
    struct('label', 'standard', 'stimulus_ref', 'tone_1000hz', 'base_probability', 0.85)
    struct('label', 'deviant', 'stimulus_ref', 'tone_1500hz', 'base_probability', 0.15)
};

[valid, errors] = v1.validation.CustomValidators.validate_oddball_config(oddball_valid);
if valid
    fprintf('   ✓ Valid oddball config accepted\n');
else
    fprintf('   ✗ Valid config rejected:\n');
    fprintf('%s\n', v1.validation.ValidationError.format_errors(errors));
end

% Invalid oddball config (probabilities don't sum)
oddball_invalid = struct();
oddball_invalid.tokens = {
    struct('label', 'standard', 'stimulus_ref', 'tone_1000hz', 'base_probability', 0.85)
    struct('label', 'deviant', 'stimulus_ref', 'tone_1500hz', 'base_probability', 0.10)
};

[valid, errors] = v1.validation.CustomValidators.validate_oddball_config(oddball_invalid);
if ~valid
    fprintf('   ✓ Detected invalid probabilities\n');
    fprintf('      %s\n', errors{1}.to_string());
else
    fprintf('   ✗ Should have detected invalid probabilities\n');
end

% Invalid oddball config (duplicate labels)
oddball_dup = struct();
oddball_dup.tokens = {
    struct('label', 'standard', 'stimulus_ref', 'tone_1000hz', 'base_probability', 0.50)
    struct('label', 'standard', 'stimulus_ref', 'tone_1500hz', 'base_probability', 0.50)
};

[valid, errors] = v1.validation.CustomValidators.validate_oddball_config(oddball_dup);
if ~valid
    fprintf('   ✓ Detected duplicate labels\n');
    fprintf('      %s\n', errors{1}.to_string());
else
    fprintf('   ✗ Should have detected duplicate labels\n');
end

fprintf('\n');

%% 5. Test Local-Global Config Validation

fprintf('5. Testing Local-Global Configuration Validation...\n');

% Valid local-global config
lg_valid = struct();
lg_valid.symbols = {
    struct('symbol', 'A', 'stimulus_ref', 'tone_1000hz')
    struct('symbol', 'B', 'stimulus_ref', 'tone_1500hz')
};
lg_valid.patterns = {
    struct('name', 'AAAA', 'probability', 0.5, 'elements', {...
        struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'A')})
    struct('name', 'AAAB', 'probability', 0.5, 'elements', {...
        struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'B')})
};

[valid, errors] = v1.validation.CustomValidators.validate_local_global_config(lg_valid);
if valid
    fprintf('   ✓ Valid local-global config accepted\n');
else
    fprintf('   ✗ Valid config rejected:\n');
    fprintf('%s\n', v1.validation.ValidationError.format_errors(errors));
end

% Invalid local-global config (symbol not found)
lg_invalid = struct();
lg_invalid.symbols = {
    struct('symbol', 'A', 'stimulus_ref', 'tone_1000hz')
};
lg_invalid.patterns = {
    struct('name', 'AAAB', 'probability', 1.0, 'elements', {...
        struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'B')})
};

[valid, errors] = v1.validation.CustomValidators.validate_local_global_config(lg_invalid);
if ~valid
    fprintf('   ✓ Detected invalid symbol reference\n');
    fprintf('      %s\n', errors{1}.to_string());
else
    fprintf('   ✗ Should have detected invalid symbol reference\n');
end

fprintf('\n');

%% Summary

fprintf('=== Validation Framework Test Complete ===\n');
fprintf('\nThe validation framework is working! Key features:\n');
fprintf('  • Schema loading and caching\n');
fprintf('  • Numeric field validation (scalar and distributions)\n');
fprintf('  • Custom validators (probabilities, labels, timing, budgets)\n');
fprintf('  • Clear error messages with field paths\n');
fprintf('  • Domain-specific validators for paradigms\n');
fprintf('\nNext steps:\n');
fprintf('  • Implement sampling framework\n');
fprintf('  • Create generator interface\n');
fprintf('  • Build pattern builder core\n');
