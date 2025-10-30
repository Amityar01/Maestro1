classdef TestLocalGlobalAdapter < matlab.unittest.TestCase
    % TestLocalGlobalAdapter - Tests for Local-Global paradigm adapter
    %
    % Following TDD: These tests define the API we want.
    % The LocalGlobalAdapter should convert Local-Global configs → trial plans.
    %
    % Local-Global paradigm:
    %   - Presents sequences of tokens (e.g., AAAB, AAAA)
    %   - Each trial has MULTIPLE elements
    %   - Tests local regularity (AAA) vs global regularity (AAAB pattern)
    %
    % Test coverage:
    %   - Pattern expansion (AAAB → 4 elements)
    %   - IOI timing (inter-onset interval)
    %   - Pattern selection (IID, balanced)
    %   - Symbol tracking
    %   - Multi-element trial structure
    %   - Determinism

    properties
        adapter
        basic_config
    end

    methods (TestMethodSetup)
        function setup(testCase)
            % Create adapter instance
            testCase.adapter = v1.paradigms.LocalGlobalAdapter();

            % Basic AAAB/AAAA config
            testCase.basic_config = struct();
            testCase.basic_config.token_a = struct('stimulus_ref', 'tone_1000hz', 'duration_ms', 50);
            testCase.basic_config.token_b = struct('stimulus_ref', 'tone_1200hz', 'duration_ms', 50);
            testCase.basic_config.patterns = [
                struct('label', 'AAAB', 'sequence', 'AAAB', 'base_probability', 0.5)
                struct('label', 'AAAA', 'sequence', 'AAAA', 'base_probability', 0.5)
            ];
            testCase.basic_config.ioi = struct('value', 100);  % 100ms between elements
            testCase.basic_config.iti = struct('value', 500);
            testCase.basic_config.selection = struct('mode', 'iid');
        end
    end

    methods (Test)
        %% Basic Functionality

        function testBasicTrialPlanGeneration(testCase)
            % Test that adapter generates valid trial plan
            n_trials = 10;
            trial_plan = testCase.adapter.generate_trial_plan(testCase.basic_config, n_trials);

            % Verify trial plan structure
            testCase.verifyTrue(isstruct(trial_plan));
            testCase.verifyEqual(trial_plan.n_trials, n_trials);
            testCase.verifyEqual(length(trial_plan.trials), n_trials);
        end

        function testMultiElementTrials(testCase)
            % Test that each trial has multiple elements (4 for AAAB/AAAA)
            trial_plan = testCase.adapter.generate_trial_plan(testCase.basic_config, 5);

            for i = 1:length(trial_plan.trials)
                trial = trial_plan.trials{i};
                testCase.verifyEqual(length(trial.elements), 4, 'AAAB/AAAA patterns have 4 elements');
            end
        end

        %% Pattern Expansion

        function testAAABPatternExpansion(testCase)
            % Test that AAAB expands to A A A B elements
            config = testCase.basic_config;
            config.patterns = struct('label', 'AAAB', 'sequence', 'AAAB', 'base_probability', 1.0);
            config.selection.mode = 'balanced_shuffle';

            trial_plan = testCase.adapter.generate_trial_plan(config, 1);
            trial = trial_plan.trials{1};

            testCase.verifyEqual(length(trial.elements), 4);

            % Verify stimulus refs
            testCase.verifyEqual(trial.elements{1}.stimulus_ref, 'tone_1000hz', 'First A');
            testCase.verifyEqual(trial.elements{2}.stimulus_ref, 'tone_1000hz', 'Second A');
            testCase.verifyEqual(trial.elements{3}.stimulus_ref, 'tone_1000hz', 'Third A');
            testCase.verifyEqual(trial.elements{4}.stimulus_ref, 'tone_1200hz', 'Final B');
        end

        function testAAAAPatternExpansion(testCase)
            % Test that AAAA expands to A A A A elements
            config = testCase.basic_config;
            config.patterns = struct('label', 'AAAA', 'sequence', 'AAAA', 'base_probability', 1.0);

            trial_plan = testCase.adapter.generate_trial_plan(config, 1);
            trial = trial_plan.trials{1};

            testCase.verifyEqual(length(trial.elements), 4);

            % All should be A
            for i = 1:4
                testCase.verifyEqual(trial.elements{i}.stimulus_ref, 'tone_1000hz');
            end
        end

        function testBBBAPatternExpansion(testCase)
            % Test BBBA pattern (reverse)
            config = testCase.basic_config;
            config.patterns = struct('label', 'BBBA', 'sequence', 'BBBA', 'base_probability', 1.0);

            trial_plan = testCase.adapter.generate_trial_plan(config, 1);
            trial = trial_plan.trials{1};

            testCase.verifyEqual(trial.elements{1}.stimulus_ref, 'tone_1200hz', 'First B');
            testCase.verifyEqual(trial.elements{2}.stimulus_ref, 'tone_1200hz', 'Second B');
            testCase.verifyEqual(trial.elements{3}.stimulus_ref, 'tone_1200hz', 'Third B');
            testCase.verifyEqual(trial.elements{4}.stimulus_ref, 'tone_1000hz', 'Final A');
        end

        %% IOI Timing

        function testIOITiming(testCase)
            % Test that IOI (inter-onset interval) is applied correctly
            config = testCase.basic_config;
            config.ioi = struct('value', 100);  % 100ms between onsets

            trial_plan = testCase.adapter.generate_trial_plan(config, 1);
            trial = trial_plan.trials{1};

            % Elements should start at 0, 100, 200, 300
            testCase.verifyEqual(trial.elements{1}.scheduled_onset_ms, 0);
            testCase.verifyEqual(trial.elements{2}.scheduled_onset_ms, 100);
            testCase.verifyEqual(trial.elements{3}.scheduled_onset_ms, 200);
            testCase.verifyEqual(trial.elements{4}.scheduled_onset_ms, 300);
        end

        function testVariableIOI(testCase)
            % Test with different IOI value
            config = testCase.basic_config;
            config.ioi = struct('value', 150);  % 150ms between onsets

            trial_plan = testCase.adapter.generate_trial_plan(config, 1);
            trial = trial_plan.trials{1};

            testCase.verifyEqual(trial.elements{1}.scheduled_onset_ms, 0);
            testCase.verifyEqual(trial.elements{2}.scheduled_onset_ms, 150);
            testCase.verifyEqual(trial.elements{3}.scheduled_onset_ms, 300);
            testCase.verifyEqual(trial.elements{4}.scheduled_onset_ms, 450);
        end

        %% Symbol Tracking

        function testSymbolTracking(testCase)
            % Test that elements have symbol field (A or B)
            config = testCase.basic_config;
            config.patterns = struct('label', 'AAAB', 'sequence', 'AAAB', 'base_probability', 1.0);

            trial_plan = testCase.adapter.generate_trial_plan(config, 1);
            trial = trial_plan.trials{1};

            testCase.verifyEqual(trial.elements{1}.symbol, 'A');
            testCase.verifyEqual(trial.elements{2}.symbol, 'A');
            testCase.verifyEqual(trial.elements{3}.symbol, 'A');
            testCase.verifyEqual(trial.elements{4}.symbol, 'B');
        end

        %% Pattern Selection

        function testIIDPatternSelection(testCase)
            % Test IID pattern selection (50/50 AAAB/AAAA)
            config = testCase.basic_config;
            config.selection.mode = 'iid';
            config.selection.seed = 12345;

            trial_plan = testCase.adapter.generate_trial_plan(config, 100);

            labels = cellfun(@(t) t.label, trial_plan.trials, 'UniformOutput', false);
            aaab_count = sum(strcmp(labels, 'AAAB'));
            aaaa_count = sum(strcmp(labels, 'AAAA'));

            % Should approximate 50/50 (with variance)
            testCase.verifyGreaterThan(aaab_count, 30);
            testCase.verifyLessThan(aaab_count, 70);
            testCase.verifyGreaterThan(aaaa_count, 30);
            testCase.verifyLessThan(aaaa_count, 70);
        end

        function testBalancedShufflePatternSelection(testCase)
            % Test balanced shuffle (exact 50/50)
            config = testCase.basic_config;
            config.selection.mode = 'balanced_shuffle';
            config.selection.seed = 12345;

            trial_plan = testCase.adapter.generate_trial_plan(config, 100);

            labels = cellfun(@(t) t.label, trial_plan.trials, 'UniformOutput', false);
            aaab_count = sum(strcmp(labels, 'AAAB'));
            aaaa_count = sum(strcmp(labels, 'AAAA'));

            testCase.verifyEqual(aaab_count, 50, 'Balanced: exact 50 AAAB');
            testCase.verifyEqual(aaaa_count, 50, 'Balanced: exact 50 AAAA');
        end

        %% Determinism

        function testDeterminism(testCase)
            % Test that same seed produces same pattern sequence
            config = testCase.basic_config;
            config.selection.seed = 99999;

            trial_plan1 = testCase.adapter.generate_trial_plan(config, 50);
            trial_plan2 = testCase.adapter.generate_trial_plan(config, 50);

            labels1 = cellfun(@(t) t.label, trial_plan1.trials, 'UniformOutput', false);
            labels2 = cellfun(@(t) t.label, trial_plan2.trials, 'UniformOutput', false);

            testCase.verifyEqual(labels1, labels2, 'Same seed → same sequence');
        end

        %% Element Structure

        function testElementStructure(testCase)
            % Test that elements have all required fields
            trial_plan = testCase.adapter.generate_trial_plan(testCase.basic_config, 1);
            trial = trial_plan.trials{1};

            for i = 1:length(trial.elements)
                element = trial.elements{i};
                testCase.verifyTrue(isfield(element, 'stimulus_ref'));
                testCase.verifyTrue(isfield(element, 'scheduled_onset_ms'));
                testCase.verifyTrue(isfield(element, 'duration_ms'));
                testCase.verifyTrue(isfield(element, 'symbol'));
            end
        end

        function testElementDuration(testCase)
            % Test that elements get correct duration from tokens
            config = testCase.basic_config;
            config.token_a.duration_ms = 50;
            config.token_b.duration_ms = 75;

            trial_plan = testCase.adapter.generate_trial_plan(config, 1);
            trial = trial_plan.trials{1};

            % Pattern is AAAB or AAAA
            if strcmp(trial.label, 'AAAB')
                testCase.verifyEqual(trial.elements{1}.duration_ms, 50, 'A duration');
                testCase.verifyEqual(trial.elements{2}.duration_ms, 50, 'A duration');
                testCase.verifyEqual(trial.elements{3}.duration_ms, 50, 'A duration');
                testCase.verifyEqual(trial.elements{4}.duration_ms, 75, 'B duration');
            else  % AAAA
                for i = 1:4
                    testCase.verifyEqual(trial.elements{i}.duration_ms, 50, 'All A duration');
                end
            end
        end

        %% Longer Patterns

        function testFiveElementPattern(testCase)
            % Test with 5-element pattern (AAAAB)
            config = testCase.basic_config;
            config.patterns = struct('label', 'AAAAB', 'sequence', 'AAAAB', 'base_probability', 1.0);
            config.ioi = struct('value', 100);

            trial_plan = testCase.adapter.generate_trial_plan(config, 1);
            trial = trial_plan.trials{1};

            testCase.verifyEqual(length(trial.elements), 5);
            testCase.verifyEqual(trial.elements{5}.scheduled_onset_ms, 400);
            testCase.verifyEqual(trial.elements{5}.symbol, 'B');
        end

        %% Validation

        function testMissingTokenA(testCase)
            % Test error when token_a missing
            bad_config = testCase.basic_config;
            bad_config = rmfield(bad_config, 'token_a');

            testCase.verifyError(...
                @() testCase.adapter.generate_trial_plan(bad_config, 10), ...
                'LocalGlobalAdapter:InvalidConfig');
        end

        function testInvalidPatternProbabilities(testCase)
            % Test error when probabilities don't sum to 1
            bad_config = testCase.basic_config;
            bad_config.patterns(1).base_probability = 0.3;
            bad_config.patterns(2).base_probability = 0.3;  % Sum = 0.6

            testCase.verifyError(...
                @() testCase.adapter.generate_trial_plan(bad_config, 10), ...
                'LocalGlobalAdapter:InvalidProbabilities');
        end

        %% Metadata

        function testMetadata(testCase)
            % Test metadata in trial plan
            config = testCase.basic_config;
            config.selection.seed = 42;

            trial_plan = testCase.adapter.generate_trial_plan(config, 5);

            testCase.verifyTrue(isfield(trial_plan, 'metadata'));
            testCase.verifyEqual(trial_plan.metadata.paradigm, 'local_global');
            testCase.verifyEqual(trial_plan.metadata.selection_seed, 42);
        end

        %% Three-Pattern Design

        function testThreePatternDesign(testCase)
            % Test with three patterns (AAAB, AAAA, BBBA)
            config = testCase.basic_config;
            config.patterns = [
                struct('label', 'AAAB', 'sequence', 'AAAB', 'base_probability', 0.4)
                struct('label', 'AAAA', 'sequence', 'AAAA', 'base_probability', 0.3)
                struct('label', 'BBBA', 'sequence', 'BBBA', 'base_probability', 0.3)
            ];
            config.selection.mode = 'balanced_shuffle';

            trial_plan = testCase.adapter.generate_trial_plan(config, 100);

            labels = cellfun(@(t) t.label, trial_plan.trials, 'UniformOutput', false);
            aaab_count = sum(strcmp(labels, 'AAAB'));
            aaaa_count = sum(strcmp(labels, 'AAAA'));
            bbba_count = sum(strcmp(labels, 'BBBA'));

            testCase.verifyEqual(aaab_count, 40, '40% AAAB');
            testCase.verifyEqual(aaaa_count, 30, '30% AAAA');
            testCase.verifyEqual(bbba_count, 30, '30% BBBA');
        end
    end
end
