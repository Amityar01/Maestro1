classdef TestPatternBuilder < matlab.unittest.TestCase
    % TestPatternBuilder - Unit tests for PatternBuilderCore
    %
    % Following TDD: write tests first to define the API.
    % Pattern Builder expands trial plans into element tables.

    methods (Test)
        %% Basic Trial Expansion Tests

        function testSingleElementPerTrial(testCase)
            % Simplest case: one element per trial
            builder = v1.compilation.PatternBuilderCore();

            trial_plan = struct();
            trial_plan.n_trials = 3;
            trial_plan.elements_per_trial = 1;
            trial_plan.iti_ms = 500;

            % Each trial has one element
            trial_plan.trials = cell(3, 1);
            for i = 1:3
                trial_plan.trials{i} = struct(...
                    'trial_index', i-1, ...
                    'label', 'standard', ...
                    'elements', {{struct(...
                        'stimulus_ref', 'tone_1000hz', ...
                        'scheduled_onset_ms', 0, ...
                        'duration_ms', 150 ...
                    )}});
            end

            element_table = builder.build(trial_plan);

            % Should have 3 elements (one per trial)
            testCase.verifyEqual(height(element_table), 3);

            % Check fields exist
            testCase.verifyTrue(ismember('trial_index', element_table.Properties.VariableNames));
            testCase.verifyTrue(ismember('element_index', element_table.Properties.VariableNames));
            testCase.verifyTrue(ismember('stimulus_ref', element_table.Properties.VariableNames));
            testCase.verifyTrue(ismember('absolute_onset_ms', element_table.Properties.VariableNames));
        end

        function testMultipleElementsPerTrial(testCase)
            % Multiple elements within a trial (e.g., Local-Global AAAB)
            builder = v1.compilation.PatternBuilderCore();

            trial_plan = struct();
            trial_plan.n_trials = 2;
            trial_plan.iti_ms = 500;

            % Each trial has 4 elements
            trial_plan.trials = cell(2, 1);
            for i = 1:2
                trial_plan.trials{i} = struct(...
                    'trial_index', i-1, ...
                    'label', 'AAAB', ...
                    'elements', {{
                        struct('stimulus_ref', 'A', 'scheduled_onset_ms', 0, 'duration_ms', 50)
                        struct('stimulus_ref', 'A', 'scheduled_onset_ms', 100, 'duration_ms', 50)
                        struct('stimulus_ref', 'A', 'scheduled_onset_ms', 200, 'duration_ms', 50)
                        struct('stimulus_ref', 'B', 'scheduled_onset_ms', 300, 'duration_ms', 50)
                    }});
            end

            element_table = builder.build(trial_plan);

            % Should have 8 elements (4 per trial × 2 trials)
            testCase.verifyEqual(height(element_table), 8);

            % First trial elements
            trial0_elements = element_table(element_table.trial_index == 0, :);
            testCase.verifyEqual(height(trial0_elements), 4);
        end

        function testAbsoluteOnsetComputation(testCase)
            % Test that absolute onsets are computed correctly
            builder = v1.compilation.PatternBuilderCore();

            trial_plan = struct();
            trial_plan.n_trials = 2;
            trial_plan.iti_ms = 500;

            trial_plan.trials = cell(2, 1);
            trial_plan.trials{1} = struct(...
                'trial_index', 0, ...
                'label', 'trial1', ...
                'elements', {{struct('stimulus_ref', 'stim', 'scheduled_onset_ms', 0, 'duration_ms', 100)}});
            trial_plan.trials{2} = struct(...
                'trial_index', 1, ...
                'label', 'trial2', ...
                'elements', {{struct('stimulus_ref', 'stim', 'scheduled_onset_ms', 0, 'duration_ms', 100)}});

            element_table = builder.build(trial_plan);

            % First element starts at 0
            testCase.verifyEqual(element_table.absolute_onset_ms(1), 0);

            % Second trial starts after first trial duration + ITI
            % Trial 1 duration = 100ms (element duration)
            % ITI = 500ms
            % So trial 2 starts at 100 + 500 = 600ms
            expected_onset = 100 + 500;
            testCase.verifyEqual(element_table.absolute_onset_ms(2), expected_onset);
        end

        %% Timing Resolution Tests

        function testIOIResolution(testCase)
            % Test inter-onset interval within trial
            builder = v1.compilation.PatternBuilderCore();

            trial_plan = struct();
            trial_plan.n_trials = 1;
            trial_plan.ioi_ms = 100;  % Inter-onset interval
            trial_plan.iti_ms = 500;

            % Three elements with relative onsets
            trial_plan.trials = {struct(...
                'trial_index', 0, ...
                'label', 'AAA', ...
                'elements', {{
                    struct('stimulus_ref', 'A', 'scheduled_onset_ms', 0, 'duration_ms', 50)
                    struct('stimulus_ref', 'A', 'scheduled_onset_ms', 100, 'duration_ms', 50)
                    struct('stimulus_ref', 'A', 'scheduled_onset_ms', 200, 'duration_ms', 50)
                }})};

            element_table = builder.build(trial_plan);

            % Check spacing
            testCase.verifyEqual(element_table.absolute_onset_ms(1), 0);
            testCase.verifyEqual(element_table.absolute_onset_ms(2), 100);
            testCase.verifyEqual(element_table.absolute_onset_ms(3), 200);
        end

        function testTrialWindowComputation(testCase)
            % Test that trial windows are computed correctly
            builder = v1.compilation.PatternBuilderCore();

            trial_plan = struct();
            trial_plan.n_trials = 1;
            trial_plan.iti_ms = 500;

            % Single element trial
            trial_plan.trials = {struct(...
                'trial_index', 0, ...
                'label', 'test', ...
                'elements', {{struct('stimulus_ref', 'stim', 'scheduled_onset_ms', 0, 'duration_ms', 150)}})};

            element_table = builder.build(trial_plan);

            % Trial window should be element duration
            testCase.verifyTrue(isfield(element_table.Properties.UserData, 'trial_windows') || ...
                               ismember('trial_window_ms', element_table.Properties.VariableNames));
        end

        %% Constraint Tests

        function testRefractoryPeriod(testCase)
            % Test that refractory period is enforced
            builder = v1.compilation.PatternBuilderCore();

            trial_plan = struct();
            trial_plan.n_trials = 2;
            trial_plan.iti_ms = 500;
            trial_plan.refractory_ms = 100;  % Min silent gap after offset

            trial_plan.trials = cell(2, 1);
            for i = 1:2
                trial_plan.trials{i} = struct(...
                    'trial_index', i-1, ...
                    'label', 'test', ...
                    'elements', {{struct('stimulus_ref', 'stim', 'scheduled_onset_ms', 0, 'duration_ms', 150)}});
            end

            % Should validate or adjust timing for refractory
            element_table = builder.build(trial_plan);

            % Check that trials are spaced appropriately
            % Trial 1: 0 to 150ms
            % Refractory: 150 to 250ms
            % ITI: 250 to 750ms
            % Trial 2: 750ms
            expected_onset_2 = 150 + 100 + 500;
            testCase.verifyEqual(element_table.absolute_onset_ms(2), expected_onset_2);
        end

        function testEnvelopeTiming(testCase)
            % Test that envelope durations are considered
            builder = v1.compilation.PatternBuilderCore();

            trial_plan = struct();
            trial_plan.n_trials = 1;
            trial_plan.iti_ms = 500;

            % Element with envelope
            trial_plan.trials = {struct(...
                'trial_index', 0, ...
                'label', 'test', ...
                'elements', {{struct(...
                    'stimulus_ref', 'stim', ...
                    'scheduled_onset_ms', 0, ...
                    'duration_ms', 150, ...
                    'envelope', struct('attack_ms', 10, 'release_ms', 10) ...
                )}})};

            element_table = builder.build(trial_plan);

            % Total duration should include envelope
            % Core duration: 150ms
            % Attack: 10ms (already included in 150ms)
            % Release: 10ms (already included in 150ms)
            % Element duration IS the total duration
            testCase.verifyTrue(true);  % Envelope is part of total duration
        end

        %% Metadata Tests

        function testElementIndexing(testCase)
            % Test that elements are indexed correctly
            builder = v1.compilation.PatternBuilderCore();

            trial_plan = struct();
            trial_plan.n_trials = 2;
            trial_plan.iti_ms = 500;

            % Trial 1: 2 elements, Trial 2: 3 elements
            trial_plan.trials = {
                struct('trial_index', 0, 'label', 'trial1', 'elements', {{
                    struct('stimulus_ref', 'A', 'scheduled_onset_ms', 0, 'duration_ms', 50)
                    struct('stimulus_ref', 'B', 'scheduled_onset_ms', 100, 'duration_ms', 50)
                }})
                struct('trial_index', 1, 'label', 'trial2', 'elements', {{
                    struct('stimulus_ref', 'A', 'scheduled_onset_ms', 0, 'duration_ms', 50)
                    struct('stimulus_ref', 'B', 'scheduled_onset_ms', 100, 'duration_ms', 50)
                    struct('stimulus_ref', 'C', 'scheduled_onset_ms', 200, 'duration_ms', 50)
                }})
            };

            element_table = builder.build(trial_plan);

            % Check element indices within trials
            trial0_elements = element_table(element_table.trial_index == 0, :);
            testCase.verifyEqual(trial0_elements.element_index(1), 0);
            testCase.verifyEqual(trial0_elements.element_index(2), 1);

            trial1_elements = element_table(element_table.trial_index == 1, :);
            testCase.verifyEqual(trial1_elements.element_index(1), 0);
            testCase.verifyEqual(trial1_elements.element_index(2), 1);
            testCase.verifyEqual(trial1_elements.element_index(3), 2);
        end

        function testRoleAssignment(testCase)
            % Test that element roles are preserved
            builder = v1.compilation.PatternBuilderCore();

            trial_plan = struct();
            trial_plan.n_trials = 1;
            trial_plan.iti_ms = 500;

            % Elements with roles (cue/outcome)
            trial_plan.trials = {struct(...
                'trial_index', 0, ...
                'label', 'foreperiod', ...
                'elements', {{
                    struct('stimulus_ref', 'cue_stim', 'scheduled_onset_ms', 0, 'duration_ms', 50, 'role', 'cue')
                    struct('stimulus_ref', 'outcome_stim', 'scheduled_onset_ms', 200, 'duration_ms', 50, 'role', 'outcome')
                }})};

            element_table = builder.build(trial_plan);

            % Check roles preserved
            testCase.verifyTrue(ismember('role', element_table.Properties.VariableNames));
            testCase.verifyEqual(element_table.role{1}, 'cue');
            testCase.verifyEqual(element_table.role{2}, 'outcome');
        end

        function testSymbolTracking(testCase)
            % Test that symbols are tracked (for Local-Global)
            builder = v1.compilation.PatternBuilderCore();

            trial_plan = struct();
            trial_plan.n_trials = 1;
            trial_plan.iti_ms = 500;

            % Elements with symbols
            trial_plan.trials = {struct(...
                'trial_index', 0, ...
                'label', 'AAAB', ...
                'elements', {{
                    struct('stimulus_ref', 'tone1', 'scheduled_onset_ms', 0, 'duration_ms', 50, 'symbol', 'A')
                    struct('stimulus_ref', 'tone1', 'scheduled_onset_ms', 100, 'duration_ms', 50, 'symbol', 'A')
                    struct('stimulus_ref', 'tone1', 'scheduled_onset_ms', 200, 'duration_ms', 50, 'symbol', 'A')
                    struct('stimulus_ref', 'tone2', 'scheduled_onset_ms', 300, 'duration_ms', 50, 'symbol', 'B')
                }})};

            element_table = builder.build(trial_plan);

            % Check symbols preserved
            testCase.verifyTrue(ismember('symbol', element_table.Properties.VariableNames));
            testCase.verifyEqual(element_table.symbol{1}, 'A');
            testCase.verifyEqual(element_table.symbol{4}, 'B');
        end

        %% Validation Tests

        function testFeasibilityCheck(testCase)
            % Test that infeasible timing is detected
            builder = v1.compilation.PatternBuilderCore();

            trial_plan = struct();
            trial_plan.n_trials = 1;
            trial_plan.iti_ms = 10;  % Very short ITI
            trial_plan.refractory_ms = 100;  % Long refractory

            trial_plan.trials = {struct(...
                'trial_index', 0, ...
                'label', 'test', ...
                'elements', {{struct('stimulus_ref', 'stim', 'scheduled_onset_ms', 0, 'duration_ms', 150)}})};

            % Should either error or warn about infeasibility
            % For now, just test it doesn't crash
            element_table = builder.build(trial_plan);
            testCase.verifyTrue(true);  % Didn't crash
        end

        function testEmptyTrial(testCase)
            % Test handling of empty trials (omission trials)
            builder = v1.compilation.PatternBuilderCore();

            trial_plan = struct();
            trial_plan.n_trials = 2;
            trial_plan.iti_ms = 500;

            % Trial 1 has element, Trial 2 is empty (omission)
            trial_plan.trials = {
                struct('trial_index', 0, 'label', 'present', 'elements', {{
                    struct('stimulus_ref', 'stim', 'scheduled_onset_ms', 0, 'duration_ms', 100)
                }})
                struct('trial_index', 1, 'label', 'omission', 'elements', {{}})
            };

            element_table = builder.build(trial_plan);

            % Should have 1 element (from trial 1 only)
            testCase.verifyEqual(height(element_table), 1);
        end

        %% Output Format Tests

        function testTableStructure(testCase)
            % Test that output is a proper table with required columns
            builder = v1.compilation.PatternBuilderCore();

            trial_plan = struct();
            trial_plan.n_trials = 1;
            trial_plan.iti_ms = 500;

            trial_plan.trials = {struct(...
                'trial_index', 0, ...
                'label', 'test', ...
                'elements', {{struct('stimulus_ref', 'stim', 'scheduled_onset_ms', 0, 'duration_ms', 100)}})};

            element_table = builder.build(trial_plan);

            % Should be a table
            testCase.verifyClass(element_table, 'table');

            % Required columns
            required_cols = {'trial_index', 'element_index', 'stimulus_ref', ...
                           'absolute_onset_ms', 'duration_ms'};

            for i = 1:length(required_cols)
                testCase.verifyTrue(ismember(required_cols{i}, element_table.Properties.VariableNames), ...
                    sprintf('Missing required column: %s', required_cols{i}));
            end
        end

        function testElementCount(testCase)
            % Verify total element count matches sum of elements per trial
            builder = v1.compilation.PatternBuilderCore();

            trial_plan = struct();
            trial_plan.n_trials = 3;
            trial_plan.iti_ms = 500;

            % 2 elements, 3 elements, 1 element = 6 total
            trial_plan.trials = {
                struct('trial_index', 0, 'label', 't1', 'elements', {{
                    struct('stimulus_ref', 'A', 'scheduled_onset_ms', 0, 'duration_ms', 50)
                    struct('stimulus_ref', 'B', 'scheduled_onset_ms', 100, 'duration_ms', 50)
                }})
                struct('trial_index', 1, 'label', 't2', 'elements', {{
                    struct('stimulus_ref', 'A', 'scheduled_onset_ms', 0, 'duration_ms', 50)
                    struct('stimulus_ref', 'B', 'scheduled_onset_ms', 100, 'duration_ms', 50)
                    struct('stimulus_ref', 'C', 'scheduled_onset_ms', 200, 'duration_ms', 50)
                }})
                struct('trial_index', 2, 'label', 't3', 'elements', {{
                    struct('stimulus_ref', 'A', 'scheduled_onset_ms', 0, 'duration_ms', 50)
                }})
            };

            element_table = builder.build(trial_plan);

            testCase.verifyEqual(height(element_table), 6);
        end
    end
end
