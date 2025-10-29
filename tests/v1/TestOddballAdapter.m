classdef TestOddballAdapter < matlab.unittest.TestCase
    % TestOddballAdapter - Tests for oddball paradigm adapter
    %
    % Following TDD: These tests define the API we want.
    % The OddballAdapter should convert oddball configs → trial plans.
    %
    % Test coverage:
    %   - IID selection mode (independent trials)
    %   - Balanced shuffle mode (equal proportions)
    %   - CSV preset mode (predefined sequence)
    %   - Probability distributions
    %   - Constraints (max consecutive)
    %   - TTL code assignment
    %   - Determinism (seed-based)
    %   - Trial plan output structure

    properties
        adapter
        basic_config
    end

    methods (TestMethodSetup)
        function setup(testCase)
            % Create adapter instance
            testCase.adapter = v1.paradigms.OddballAdapter();

            % Basic 2-tone oddball config
            testCase.basic_config = struct();
            testCase.basic_config.tokens = [
                struct('label', 'standard', 'stimulus_ref', 'tone_1000hz', ...
                       'base_probability', 0.8, 'code', 1)
                struct('label', 'deviant', 'stimulus_ref', 'tone_1200hz', ...
                       'base_probability', 0.2, 'code', 2)
            ];
            testCase.basic_config.selection = struct('mode', 'iid');
            testCase.basic_config.iti = struct('value', 500);
        end
    end

    methods (Test)
        %% Basic Functionality

        function testBasicTrialPlanGeneration(testCase)
            % Test that adapter generates valid trial plan structure
            n_trials = 10;
            trial_plan = testCase.adapter.generate_trial_plan(testCase.basic_config, n_trials);

            % Verify trial plan structure
            testCase.verifyTrue(isstruct(trial_plan), 'Output should be struct');
            testCase.verifyTrue(isfield(trial_plan, 'n_trials'), 'Should have n_trials');
            testCase.verifyTrue(isfield(trial_plan, 'iti_ms'), 'Should have iti_ms');
            testCase.verifyTrue(isfield(trial_plan, 'trials'), 'Should have trials');

            % Verify trial count
            testCase.verifyEqual(trial_plan.n_trials, n_trials);
            testCase.verifyEqual(length(trial_plan.trials), n_trials);
        end

        function testITIConversion(testCase)
            % Test that ITI is converted to milliseconds correctly
            testCase.basic_config.iti = struct('value', 500);
            trial_plan = testCase.adapter.generate_trial_plan(testCase.basic_config, 5);
            testCase.verifyEqual(trial_plan.iti_ms, 500);

            % Test with distribution
            testCase.basic_config.iti = struct('dist', 'uniform', 'min', 400, ...
                                              'max', 600, 'scope', 'per_trial');
            trial_plan = testCase.adapter.generate_trial_plan(testCase.basic_config, 5);
            testCase.verifyTrue(isfield(trial_plan, 'iti_ms'), 'Should have iti_ms even with distribution');
        end

        function testTrialStructure(testCase)
            % Test that each trial has required fields
            trial_plan = testCase.adapter.generate_trial_plan(testCase.basic_config, 3);

            for i = 1:length(trial_plan.trials)
                trial = trial_plan.trials{i};
                testCase.verifyTrue(isfield(trial, 'trial_index'), 'Trial should have trial_index');
                testCase.verifyTrue(isfield(trial, 'label'), 'Trial should have label');
                testCase.verifyTrue(isfield(trial, 'elements'), 'Trial should have elements');
                testCase.verifyTrue(isfield(trial, 'code'), 'Trial should have code');

                % Verify trial_index is 0-based
                testCase.verifyEqual(trial.trial_index, i-1);

                % Verify elements structure
                testCase.verifyTrue(iscell(trial.elements), 'Elements should be cell array');
                if ~isempty(trial.elements)
                    element = trial.elements{1};
                    testCase.verifyTrue(isfield(element, 'stimulus_ref'));
                    testCase.verifyTrue(isfield(element, 'scheduled_onset_ms'));
                    testCase.verifyTrue(isfield(element, 'duration_ms'));
                end
            end
        end

        %% IID Selection Mode

        function testIIDSelection(testCase)
            % Test IID (independent and identically distributed) selection
            config = testCase.basic_config;
            config.selection.mode = 'iid';
            config.selection.seed = 12345;

            trial_plan = testCase.adapter.generate_trial_plan(config, 100);

            % Count occurrences
            labels = cellfun(@(t) t.label, trial_plan.trials, 'UniformOutput', false);
            standard_count = sum(strcmp(labels, 'standard'));
            deviant_count = sum(strcmp(labels, 'deviant'));

            % Should approximate 80/20 split (with some variance)
            testCase.verifyGreaterThan(standard_count, 60, 'Should have ~80 standards');
            testCase.verifyLessThan(standard_count, 95, 'Should have ~80 standards');
            testCase.verifyGreaterThan(deviant_count, 5, 'Should have ~20 deviants');
            testCase.verifyLessThan(deviant_count, 40, 'Should have ~20 deviants');
        end

        function testIIDDeterminism(testCase)
            % Test that same seed produces same sequence
            config = testCase.basic_config;
            config.selection.mode = 'iid';
            config.selection.seed = 99999;

            trial_plan1 = testCase.adapter.generate_trial_plan(config, 50);
            trial_plan2 = testCase.adapter.generate_trial_plan(config, 50);

            labels1 = cellfun(@(t) t.label, trial_plan1.trials, 'UniformOutput', false);
            labels2 = cellfun(@(t) t.label, trial_plan2.trials, 'UniformOutput', false);

            testCase.verifyEqual(labels1, labels2, 'Same seed → same sequence');
        end

        %% Balanced Shuffle Mode

        function testBalancedShuffle(testCase)
            % Test balanced shuffle mode (exact proportions)
            config = testCase.basic_config;
            config.selection.mode = 'balanced_shuffle';
            config.selection.seed = 12345;

            % 100 trials: should get exactly 80 standards, 20 deviants
            trial_plan = testCase.adapter.generate_trial_plan(config, 100);

            labels = cellfun(@(t) t.label, trial_plan.trials, 'UniformOutput', false);
            standard_count = sum(strcmp(labels, 'standard'));
            deviant_count = sum(strcmp(labels, 'deviant'));

            testCase.verifyEqual(standard_count, 80, 'Balanced shuffle: exact proportions');
            testCase.verifyEqual(deviant_count, 20, 'Balanced shuffle: exact proportions');
        end

        function testBalancedShuffleRounding(testCase)
            % Test balanced shuffle with n_trials not divisible by proportions
            config = testCase.basic_config;
            config.selection.mode = 'balanced_shuffle';
            config.selection.seed = 12345;

            % 97 trials: 0.8*97 = 77.6 → should round to 78 standards
            trial_plan = testCase.adapter.generate_trial_plan(config, 97);

            labels = cellfun(@(t) t.label, trial_plan.trials, 'UniformOutput', false);
            standard_count = sum(strcmp(labels, 'standard'));
            deviant_count = sum(strcmp(labels, 'deviant'));

            testCase.verifyEqual(standard_count + deviant_count, 97, 'Total should be 97');
            testCase.verifyGreaterThanOrEqual(standard_count, 77, 'Should round appropriately');
            testCase.verifyLessThanOrEqual(standard_count, 78, 'Should round appropriately');
        end

        %% CSV Preset Mode

        function testCSVPresetMode(testCase)
            % Test CSV preset mode (predefined sequence)
            config = testCase.basic_config;
            config.selection.mode = 'csv_preset';
            config.selection.sequence = [1 1 1 1 2 1 1 1 1 2];  % Indices into tokens

            trial_plan = testCase.adapter.generate_trial_plan(config, 10);

            % Verify sequence matches
            expected_labels = {'standard', 'standard', 'standard', 'standard', 'deviant', ...
                              'standard', 'standard', 'standard', 'standard', 'deviant'};
            actual_labels = cellfun(@(t) t.label, trial_plan.trials, 'UniformOutput', false);

            testCase.verifyEqual(actual_labels, expected_labels, 'Should follow CSV sequence');
        end

        function testCSVPresetWithFewerTrials(testCase)
            % Test CSV preset when n_trials < sequence length
            config = testCase.basic_config;
            config.selection.mode = 'csv_preset';
            config.selection.sequence = [1 1 1 1 2 1 1 1 1 2];

            trial_plan = testCase.adapter.generate_trial_plan(config, 5);

            expected_labels = {'standard', 'standard', 'standard', 'standard', 'deviant'};
            actual_labels = cellfun(@(t) t.label, trial_plan.trials, 'UniformOutput', false);

            testCase.verifyEqual(actual_labels, expected_labels, 'Should use first N trials');
        end

        %% Constraints

        function testMaxConsecutiveDeviants(testCase)
            % Test max_consecutive_deviants constraint
            config = testCase.basic_config;
            config.selection.mode = 'iid';
            config.selection.seed = 12345;
            config.constraints.max_consecutive_deviants = 2;

            trial_plan = testCase.adapter.generate_trial_plan(config, 100);

            % Check constraint is enforced
            labels = cellfun(@(t) t.label, trial_plan.trials, 'UniformOutput', false);
            consecutive_deviants = 0;
            max_consecutive = 0;

            for i = 1:length(labels)
                if strcmp(labels{i}, 'deviant')
                    consecutive_deviants = consecutive_deviants + 1;
                    max_consecutive = max(max_consecutive, consecutive_deviants);
                else
                    consecutive_deviants = 0;
                end
            end

            testCase.verifyLessThanOrEqual(max_consecutive, 2, 'Should respect max_consecutive_deviants');
        end

        function testMaxConsecutiveStandards(testCase)
            % Test max_consecutive_standards constraint
            config = testCase.basic_config;
            config.selection.mode = 'iid';
            config.selection.seed = 12345;
            config.constraints.max_consecutive_standards = 5;

            trial_plan = testCase.adapter.generate_trial_plan(config, 100);

            % Check constraint is enforced
            labels = cellfun(@(t) t.label, trial_plan.trials, 'UniformOutput', false);
            consecutive_standards = 0;
            max_consecutive = 0;

            for i = 1:length(labels)
                if strcmp(labels{i}, 'standard')
                    consecutive_standards = consecutive_standards + 1;
                    max_consecutive = max(max_consecutive, consecutive_standards);
                else
                    consecutive_standards = 0;
                end
            end

            testCase.verifyLessThanOrEqual(max_consecutive, 5, 'Should respect max_consecutive_standards');
        end

        %% TTL Codes

        function testTTLCodeAssignment(testCase)
            % Test that TTL codes are assigned correctly
            trial_plan = testCase.adapter.generate_trial_plan(testCase.basic_config, 10);

            for i = 1:length(trial_plan.trials)
                trial = trial_plan.trials{i};
                if strcmp(trial.label, 'standard')
                    testCase.verifyEqual(trial.code, 1, 'Standard should have code 1');
                elseif strcmp(trial.label, 'deviant')
                    testCase.verifyEqual(trial.code, 2, 'Deviant should have code 2');
                end
            end
        end

        %% Multi-Token Oddball

        function testThreeTokenOddball(testCase)
            % Test 3-stimulus oddball (standard, deviant1, deviant2)
            config = struct();
            config.tokens = [
                struct('label', 'standard', 'stimulus_ref', 'tone_1000hz', ...
                       'base_probability', 0.7, 'code', 1)
                struct('label', 'deviant1', 'stimulus_ref', 'tone_1200hz', ...
                       'base_probability', 0.15, 'code', 2)
                struct('label', 'deviant2', 'stimulus_ref', 'tone_800hz', ...
                       'base_probability', 0.15, 'code', 3)
            ];
            config.selection = struct('mode', 'balanced_shuffle', 'seed', 12345);
            config.iti = struct('value', 500);

            trial_plan = testCase.adapter.generate_trial_plan(config, 100);

            labels = cellfun(@(t) t.label, trial_plan.trials, 'UniformOutput', false);
            standard_count = sum(strcmp(labels, 'standard'));
            deviant1_count = sum(strcmp(labels, 'deviant1'));
            deviant2_count = sum(strcmp(labels, 'deviant2'));

            testCase.verifyEqual(standard_count, 70, '3-tone oddball: 70 standards');
            testCase.verifyEqual(deviant1_count, 15, '3-tone oddball: 15 deviant1');
            testCase.verifyEqual(deviant2_count, 15, '3-tone oddball: 15 deviant2');
        end

        %% Element Timing

        function testElementTiming(testCase)
            % Test that elements have correct timing (onset at 0, duration from stimulus)
            config = testCase.basic_config;
            config.tokens(1).duration_ms = 150;
            config.tokens(2).duration_ms = 150;

            trial_plan = testCase.adapter.generate_trial_plan(config, 5);

            for i = 1:length(trial_plan.trials)
                trial = trial_plan.trials{i};
                testCase.verifyNotEmpty(trial.elements, 'Oddball trials should have elements');

                element = trial.elements{1};
                testCase.verifyEqual(element.scheduled_onset_ms, 0, 'Element starts at trial onset');
                testCase.verifyEqual(element.duration_ms, 150, 'Duration from token config');
            end
        end

        %% Validation

        function testMissingRequiredFields(testCase)
            % Test that missing required fields cause errors
            bad_config = struct();
            bad_config.tokens = [];  % Missing tokens

            testCase.verifyError(...
                @() testCase.adapter.generate_trial_plan(bad_config, 10), ...
                'OddballAdapter:InvalidConfig', ...
                'Should error on missing tokens');
        end

        function testInvalidProbabilities(testCase)
            % Test that probabilities not summing to 1 cause error
            bad_config = testCase.basic_config;
            bad_config.tokens(1).base_probability = 0.5;
            bad_config.tokens(2).base_probability = 0.3;  % Sum = 0.8, not 1.0

            testCase.verifyError(...
                @() testCase.adapter.generate_trial_plan(bad_config, 10), ...
                'OddballAdapter:InvalidProbabilities', ...
                'Should error when probabilities do not sum to 1');
        end

        %% Metadata

        function testMetadataInTrials(testCase)
            % Test that trials include metadata for provenance
            config = testCase.basic_config;
            config.selection.seed = 42;

            trial_plan = testCase.adapter.generate_trial_plan(config, 5);

            % Check for metadata in trial plan
            testCase.verifyTrue(isfield(trial_plan, 'metadata'), 'Should include metadata');
            testCase.verifyEqual(trial_plan.metadata.paradigm, 'oddball');
            testCase.verifyEqual(trial_plan.metadata.selection_seed, 42);
        end
    end
end
