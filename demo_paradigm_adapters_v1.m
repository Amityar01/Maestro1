%% Maestro v1 - Paradigm Adapters Demo
% This script demonstrates the paradigm adapters that convert
% paradigm configs → trial plans.
%
% Following TDD: tests were written first, implementation makes them pass.

clear; clc;

fprintf('=== Maestro v1 Paradigm Adapters Demo ===\n\n');

%% Demo 1: Simple Oddball (80/20)
fprintf('Demo 1: Simple Oddball (80%% standard, 20%% deviant)\n');
fprintf('-------------------------------------------------------\n');

oddball_adapter = v1.paradigms.OddballAdapter();

% Configure 2-tone oddball
oddball_config = struct();
oddball_config.tokens = [
    struct('label', 'standard', 'stimulus_ref', 'tone_1000hz', ...
           'base_probability', 0.8, 'code', 1, 'duration_ms', 150)
    struct('label', 'deviant', 'stimulus_ref', 'tone_1200hz', ...
           'base_probability', 0.2, 'code', 2, 'duration_ms', 150)
];
oddball_config.selection = struct('mode', 'balanced_shuffle', 'seed', 12345);
oddball_config.iti = struct('value', 500);

trial_plan1 = oddball_adapter.generate_trial_plan(oddball_config, 100);

fprintf('Configuration:\n');
fprintf('  Tokens: standard (80%%), deviant (20%%)\n');
fprintf('  Selection: balanced_shuffle (exact proportions)\n');
fprintf('  Trials: %d\n', trial_plan1.n_trials);
fprintf('  ITI: %d ms\n\n', trial_plan1.iti_ms);

labels = cellfun(@(t) t.label, trial_plan1.trials, 'UniformOutput', false);
standard_count = sum(strcmp(labels, 'standard'));
deviant_count = sum(strcmp(labels, 'deviant'));

fprintf('Results:\n');
fprintf('  Standard trials: %d (expected 80)\n', standard_count);
fprintf('  Deviant trials: %d (expected 20)\n', deviant_count);
fprintf('  First 10 trials: %s\n', strjoin(labels(1:10), ' '));
fprintf('\n');

fprintf('Example trial (deviant):\n');
deviant_idx = find(strcmp(labels, 'deviant'), 1);
example_trial = trial_plan1.trials{deviant_idx};
fprintf('  Trial index: %d\n', example_trial.trial_index);
fprintf('  Label: %s\n', example_trial.label);
fprintf('  Code: %d\n', example_trial.code);
fprintf('  Stimulus: %s\n', example_trial.elements{1}.stimulus_ref);
fprintf('  Onset: %d ms\n', example_trial.elements{1}.scheduled_onset_ms);
fprintf('  Duration: %d ms\n', example_trial.elements{1}.duration_ms);
fprintf('\n\n');

%% Demo 2: Oddball with Constraints
fprintf('Demo 2: Oddball with Max Consecutive Constraints\n');
fprintf('--------------------------------------------------\n');

constrained_config = oddball_config;
constrained_config.selection.mode = 'iid';  % Random, then constrained
constrained_config.selection.seed = 99999;
constrained_config.constraints.max_consecutive_deviants = 2;
constrained_config.constraints.max_consecutive_standards = 6;

trial_plan2 = oddball_adapter.generate_trial_plan(constrained_config, 100);

labels2 = cellfun(@(t) t.label, trial_plan2.trials, 'UniformOutput', false);

fprintf('Configuration:\n');
fprintf('  Selection: iid (random with constraints)\n');
fprintf('  Max consecutive deviants: 2\n');
fprintf('  Max consecutive standards: 6\n\n');

% Check constraints
consecutive_deviants = 0;
max_consec_dev = 0;
consecutive_standards = 0;
max_consec_std = 0;

for i = 1:length(labels2)
    if strcmp(labels2{i}, 'deviant')
        consecutive_deviants = consecutive_deviants + 1;
        max_consec_dev = max(max_consec_dev, consecutive_deviants);
        consecutive_standards = 0;
    else
        consecutive_standards = consecutive_standards + 1;
        max_consec_std = max(max_consec_std, consecutive_standards);
        consecutive_deviants = 0;
    end
end

fprintf('Results:\n');
fprintf('  Max consecutive deviants: %d (limit: 2)\n', max_consec_dev);
fprintf('  Max consecutive standards: %d (limit: 6)\n', max_consec_std);
fprintf('  Constraints satisfied: %s\n', ...
    iif(max_consec_dev <= 2 && max_consec_std <= 6, 'YES ✓', 'NO ✗'));
fprintf('\n\n');

%% Demo 3: Three-Tone Oddball
fprintf('Demo 3: Three-Tone Oddball\n');
fprintf('---------------------------\n');

three_tone_config = struct();
three_tone_config.tokens = [
    struct('label', 'standard', 'stimulus_ref', 'tone_1000hz', ...
           'base_probability', 0.7, 'code', 1, 'duration_ms', 150)
    struct('label', 'deviant1', 'stimulus_ref', 'tone_1200hz', ...
           'base_probability', 0.15, 'code', 2, 'duration_ms', 150)
    struct('label', 'deviant2', 'stimulus_ref', 'tone_800hz', ...
           'base_probability', 0.15, 'code', 3, 'duration_ms', 150)
];
three_tone_config.selection = struct('mode', 'balanced_shuffle', 'seed', 42);
three_tone_config.iti = struct('value', 500);

trial_plan3 = oddball_adapter.generate_trial_plan(three_tone_config, 100);

labels3 = cellfun(@(t) t.label, trial_plan3.trials, 'UniformOutput', false);
codes3 = cellfun(@(t) t.code, trial_plan3.trials);

fprintf('Configuration:\n');
fprintf('  Tokens: standard (70%%), deviant1 (15%%), deviant2 (15%%)\n');
fprintf('  Trials: 100\n\n');

fprintf('Results:\n');
fprintf('  Standard: %d (expected 70)\n', sum(strcmp(labels3, 'standard')));
fprintf('  Deviant1: %d (expected 15)\n', sum(strcmp(labels3, 'deviant1')));
fprintf('  Deviant2: %d (expected 15)\n', sum(strcmp(labels3, 'deviant2')));
fprintf('  Unique codes: [%s]\n', num2str(unique(codes3)'));
fprintf('\n\n');

%% Demo 4: Local-Global AAAB vs AAAA
fprintf('Demo 4: Local-Global (AAAB vs AAAA)\n');
fprintf('------------------------------------\n');

lg_adapter = v1.paradigms.LocalGlobalAdapter();

lg_config = struct();
lg_config.token_a = struct('stimulus_ref', 'tone_1000hz', 'duration_ms', 50);
lg_config.token_b = struct('stimulus_ref', 'tone_1200hz', 'duration_ms', 50);
lg_config.patterns = [
    struct('label', 'AAAB', 'sequence', 'AAAB', 'base_probability', 0.5)
    struct('label', 'AAAA', 'sequence', 'AAAA', 'base_probability', 0.5)
];
lg_config.ioi = struct('value', 100);  % 100ms between elements
lg_config.iti = struct('value', 800);
lg_config.selection = struct('mode', 'balanced_shuffle', 'seed', 12345);

trial_plan4 = lg_adapter.generate_trial_plan(lg_config, 100);

fprintf('Configuration:\n');
fprintf('  Patterns: AAAB (50%%), AAAA (50%%)\n');
fprintf('  IOI: %d ms (between elements in pattern)\n', 100);
fprintf('  Trials: %d\n\n', trial_plan4.n_trials);

lg_labels = cellfun(@(t) t.label, trial_plan4.trials, 'UniformOutput', false);

fprintf('Results:\n');
fprintf('  AAAB trials: %d (expected 50)\n', sum(strcmp(lg_labels, 'AAAB')));
fprintf('  AAAA trials: %d (expected 50)\n', sum(strcmp(lg_labels, 'AAAA')));
fprintf('  Elements per trial: %d\n', length(trial_plan4.trials{1}.elements));
fprintf('\n');

fprintf('Example AAAB trial:\n');
aaab_idx = find(strcmp(lg_labels, 'AAAB'), 1);
aaab_trial = trial_plan4.trials{aaab_idx};
fprintf('  Trial index: %d\n', aaab_trial.trial_index);
fprintf('  Pattern: %s\n', aaab_trial.label);
fprintf('  Elements:\n');
for i = 1:length(aaab_trial.elements)
    elem = aaab_trial.elements{i};
    fprintf('    %d. Symbol=%s, Stimulus=%s, Onset=%d ms, Duration=%d ms\n', ...
        i, elem.symbol, elem.stimulus_ref, elem.scheduled_onset_ms, elem.duration_ms);
end
fprintf('\n\n');

%% Demo 5: Local-Global Three Patterns
fprintf('Demo 5: Local-Global with Three Patterns\n');
fprintf('-----------------------------------------\n');

three_pattern_config = lg_config;
three_pattern_config.patterns = [
    struct('label', 'AAAB', 'sequence', 'AAAB', 'base_probability', 0.4)
    struct('label', 'AAAA', 'sequence', 'AAAA', 'base_probability', 0.3)
    struct('label', 'BBBA', 'sequence', 'BBBA', 'base_probability', 0.3)
];

trial_plan5 = lg_adapter.generate_trial_plan(three_pattern_config, 100);

lg_labels5 = cellfun(@(t) t.label, trial_plan5.trials, 'UniformOutput', false);

fprintf('Configuration:\n');
fprintf('  Patterns: AAAB (40%%), AAAA (30%%), BBBA (30%%)\n');
fprintf('  Trials: 100\n\n');

fprintf('Results:\n');
fprintf('  AAAB: %d (expected 40)\n', sum(strcmp(lg_labels5, 'AAAB')));
fprintf('  AAAA: %d (expected 30)\n', sum(strcmp(lg_labels5, 'AAAA')));
fprintf('  BBBA: %d (expected 30)\n', sum(strcmp(lg_labels5, 'BBBA')));
fprintf('\n');

fprintf('Example BBBA trial:\n');
bbba_idx = find(strcmp(lg_labels5, 'BBBA'), 1);
bbba_trial = trial_plan5.trials{bbba_idx};
fprintf('  Elements: ');
for i = 1:length(bbba_trial.elements)
    fprintf('%s ', bbba_trial.elements{i}.symbol);
end
fprintf('(BBBA)\n');
fprintf('\n\n');

%% Demo 6: Determinism Check
fprintf('Demo 6: Determinism Verification\n');
fprintf('--------------------------------\n');

% Generate twice with same seed
det_config = oddball_config;
det_config.selection.seed = 77777;

trial_plan_a = oddball_adapter.generate_trial_plan(det_config, 50);
trial_plan_b = oddball_adapter.generate_trial_plan(det_config, 50);

labels_a = cellfun(@(t) t.label, trial_plan_a.trials, 'UniformOutput', false);
labels_b = cellfun(@(t) t.label, trial_plan_b.trials, 'UniformOutput', false);

is_identical = isequal(labels_a, labels_b);

fprintf('Test: Generate same oddball sequence twice with seed=77777\n\n');
fprintf('Results:\n');
fprintf('  Sequence A (first 10): %s\n', strjoin(labels_a(1:10), ' '));
fprintf('  Sequence B (first 10): %s\n', strjoin(labels_b(1:10), ' '));
fprintf('  Identical: %s\n', iif(is_identical, 'YES ✓ (deterministic)', 'NO ✗'));
fprintf('\n\n');

%% Demo 7: Integration with Pattern Builder
fprintf('Demo 7: Pipeline - Adapter → Pattern Builder\n');
fprintf('---------------------------------------------\n');

% Generate oddball trial plan
pipeline_config = oddball_config;
pipeline_config.selection.seed = 11111;
oddball_trial_plan = oddball_adapter.generate_trial_plan(pipeline_config, 20);

% Feed to pattern builder
pattern_builder = v1.compilation.PatternBuilderCore();
element_table = pattern_builder.build(oddball_trial_plan);

fprintf('Pipeline: OddballAdapter → PatternBuilderCore\n\n');
fprintf('Oddball Config:\n');
fprintf('  Trials: %d\n', oddball_trial_plan.n_trials);
fprintf('  ITI: %d ms\n\n', oddball_trial_plan.iti_ms);

fprintf('Element Table (first 10 rows):\n');
disp(element_table(1:10, :));

fprintf('Timing verification:\n');
fprintf('  First element: %d ms (trial 0 starts)\n', element_table.absolute_onset_ms(1));
fprintf('  Element 5: %d ms\n', element_table.absolute_onset_ms(5));
fprintf('  Element 10: %d ms\n', element_table.absolute_onset_ms(10));
fprintf('  Last element: %d ms\n', element_table.absolute_onset_ms(end));
fprintf('\n\n');

%% Demo 8: Local-Global → Pattern Builder
fprintf('Demo 8: Local-Global → Pattern Builder\n');
fprintf('---------------------------------------\n');

lg_trial_plan = lg_adapter.generate_trial_plan(lg_config, 10);
lg_element_table = pattern_builder.build(lg_trial_plan);

fprintf('Pipeline: LocalGlobalAdapter → PatternBuilderCore\n\n');
fprintf('Local-Global Config:\n');
fprintf('  Trials: %d\n', lg_trial_plan.n_trials);
fprintf('  Elements per trial: 4 (AAAB or AAAA)\n');
fprintf('  IOI: 100 ms\n');
fprintf('  ITI: %d ms\n\n', lg_trial_plan.iti_ms);

fprintf('Element Table (first 12 rows = 3 trials):\n');
disp(lg_element_table(1:12, :));

fprintf('Pattern structure verification:\n');
fprintf('  Trial 0: elements at offsets 0, 100, 200, 300 ms\n');
fprintf('  Trial 1 starts: %d ms\n', lg_element_table.absolute_onset_ms(5));
fprintf('  Total elements: %d (10 trials × 4 elements)\n', height(lg_element_table));
fprintf('\n\n');

%% Summary
fprintf('=== Paradigm Adapters Demo Complete ===\n');
fprintf('\nKey Features Demonstrated:\n');
fprintf('  ✓ Oddball: IID and balanced shuffle selection\n');
fprintf('  ✓ Oddball: Constraint enforcement (max consecutive)\n');
fprintf('  ✓ Oddball: Multi-token (2-tone and 3-tone)\n');
fprintf('  ✓ Local-Global: Multi-element trials (AAAB patterns)\n');
fprintf('  ✓ Local-Global: IOI timing within trials\n');
fprintf('  ✓ Local-Global: Symbol tracking (A/B)\n');
fprintf('  ✓ Determinism: Same seed → same sequence\n');
fprintf('  ✓ Integration: Adapter → Pattern Builder → Element Table\n');
fprintf('\nImplementation Status:\n');
fprintf('  ✓ M1: Validation framework\n');
fprintf('  ✓ M2: Sampling + Generators\n');
fprintf('  ✓ M3: Pattern Builder Core\n');
fprintf('  ✓ M4: Paradigm Adapters (oddball, local-global) - COMPLETE\n');
fprintf('\nNext Steps:\n');
fprintf('  → Run unit tests: run_tests_v1(''TestOddballAdapter'')\n');
fprintf('  → Run unit tests: run_tests_v1(''TestLocalGlobalAdapter'')\n');
fprintf('  → Implement Compiler (M5)\n');
fprintf('  → Implement DAQ Engine (M6)\n');

% Helper function for inline conditionals
function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end
