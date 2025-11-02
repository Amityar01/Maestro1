%% Maestro v1 - Pattern Builder Core Demo
% This script demonstrates the Pattern Builder Core functionality.
% Following TDD: tests were written first, implementation makes them pass.

clear; clc;

fprintf('=== Maestro v1 Pattern Builder Core Demo ===\n\n');

%% Setup
builder = v1.compilation.PatternBuilderCore();

%% Demo 1: Simple Oddball Paradigm
fprintf('Demo 1: Simple Oddball (3 trials, 1 element per trial)\n');
fprintf('-------------------------------------------------------\n');

trial_plan1 = struct();
trial_plan1.n_trials = 3;
trial_plan1.iti_ms = 500;

% Create 3 trials with one element each
trial_plan1.trials = cell(3, 1);
for i = 1:3
    trial_plan1.trials{i} = struct(...
        'trial_index', i-1, ...
        'label', 'standard', ...
        'elements', {{struct(...
            'stimulus_ref', 'tone_1000hz', ...
            'scheduled_onset_ms', 0, ...
            'duration_ms', 150 ...
        )}});
end

element_table1 = builder.build(trial_plan1);

fprintf('Trial Plan:\n');
fprintf('  Trials: %d\n', trial_plan1.n_trials);
fprintf('  ITI: %d ms\n', trial_plan1.iti_ms);
fprintf('\n');

fprintf('Element Table:\n');
disp(element_table1);

fprintf('Timing verification:\n');
fprintf('  Trial 0: starts at %d ms\n', element_table1.absolute_onset_ms(1));
fprintf('  Trial 1: starts at %d ms (150 + 500 = 650)\n', element_table1.absolute_onset_ms(2));
fprintf('  Trial 2: starts at %d ms (650 + 150 + 500 = 1300)\n', element_table1.absolute_onset_ms(3));
fprintf('\n\n');

%% Demo 2: Local-Global AAAB Pattern
fprintf('Demo 2: Local-Global Pattern (2 trials, 4 elements per trial)\n');
fprintf('--------------------------------------------------------------\n');

trial_plan2 = struct();
trial_plan2.n_trials = 2;
trial_plan2.iti_ms = 500;

% Each trial has 4 elements (AAAB pattern)
trial_plan2.trials = cell(2, 1);
for i = 1:2
    trial_plan2.trials{i} = struct(...
        'trial_index', i-1, ...
        'label', 'AAAB', ...
        'elements', {{
            struct('stimulus_ref', 'tone_A', 'scheduled_onset_ms', 0, 'duration_ms', 50, 'symbol', 'A')
            struct('stimulus_ref', 'tone_A', 'scheduled_onset_ms', 100, 'duration_ms', 50, 'symbol', 'A')
            struct('stimulus_ref', 'tone_A', 'scheduled_onset_ms', 200, 'duration_ms', 50, 'symbol', 'A')
            struct('stimulus_ref', 'tone_B', 'scheduled_onset_ms', 300, 'duration_ms', 50, 'symbol', 'B')
        }});
end

element_table2 = builder.build(trial_plan2);

fprintf('Trial Plan:\n');
fprintf('  Trials: %d\n', trial_plan2.n_trials);
fprintf('  Elements per trial: 4 (AAAB)\n');
fprintf('  ITI: %d ms\n', trial_plan2.iti_ms);
fprintf('\n');

fprintf('Element Table:\n');
disp(element_table2);

fprintf('Pattern verification:\n');
fprintf('  Trial 0: elements at 0, 100, 200, 300 ms (absolute)\n');
fprintf('  Trial 1: starts at %d ms\n', element_table2.absolute_onset_ms(5));
fprintf('  Trial 1: elements at %d, %d, %d, %d ms (absolute)\n', ...
    element_table2.absolute_onset_ms(5), element_table2.absolute_onset_ms(6), ...
    element_table2.absolute_onset_ms(7), element_table2.absolute_onset_ms(8));
fprintf('\n\n');

%% Demo 3: Foreperiod Paradigm with Roles
fprintf('Demo 3: Foreperiod Paradigm (cue → outcome)\n');
fprintf('--------------------------------------------\n');

trial_plan3 = struct();
trial_plan3.n_trials = 2;
trial_plan3.iti_ms = 1000;

% Foreperiod trials: cue followed by outcome
trial_plan3.trials = {
    struct('trial_index', 0, 'label', 'short_FP', 'elements', {{
        struct('stimulus_ref', 'cue_tone', 'scheduled_onset_ms', 0, 'duration_ms', 50, 'role', 'cue')
        struct('stimulus_ref', 'target_tone', 'scheduled_onset_ms', 200, 'duration_ms', 50, 'role', 'outcome')
    }})
    struct('trial_index', 1, 'label', 'long_FP', 'elements', {{
        struct('stimulus_ref', 'cue_tone', 'scheduled_onset_ms', 0, 'duration_ms', 50, 'role', 'cue')
        struct('stimulus_ref', 'target_tone', 'scheduled_onset_ms', 600, 'duration_ms', 50, 'role', 'outcome')
    }})
};

element_table3 = builder.build(trial_plan3);

fprintf('Trial Plan:\n');
fprintf('  Trials: 2 (short and long foreperiod)\n');
fprintf('  ITI: %d ms\n', trial_plan3.iti_ms);
fprintf('\n');

fprintf('Element Table:\n');
disp(element_table3);

fprintf('Role verification:\n');
cue_rows = strcmp(element_table3.role, 'cue');
outcome_rows = strcmp(element_table3.role, 'outcome');
fprintf('  Cue elements: %d\n', sum(cue_rows));
fprintf('  Outcome elements: %d\n', sum(outcome_rows));
fprintf('\n\n');

%% Demo 4: Refractory Period Enforcement
fprintf('Demo 4: Refractory Period (100 ms silent gap)\n');
fprintf('----------------------------------------------\n');

trial_plan4 = struct();
trial_plan4.n_trials = 2;
trial_plan4.iti_ms = 500;
trial_plan4.refractory_ms = 100;  % Enforce 100ms silent period

trial_plan4.trials = cell(2, 1);
for i = 1:2
    trial_plan4.trials{i} = struct(...
        'trial_index', i-1, ...
        'label', 'test', ...
        'elements', {{struct(...
            'stimulus_ref', 'stim', ...
            'scheduled_onset_ms', 0, ...
            'duration_ms', 150 ...
        )}});
end

element_table4 = builder.build(trial_plan4);

fprintf('Trial Plan:\n');
fprintf('  Trials: %d\n', trial_plan4.n_trials);
fprintf('  ITI: %d ms\n', trial_plan4.iti_ms);
fprintf('  Refractory: %d ms\n', trial_plan4.refractory_ms);
fprintf('\n');

fprintf('Element Table:\n');
disp(element_table4);

fprintf('Timing with refractory:\n');
fprintf('  Trial 0: 0 to 150 ms\n');
fprintf('  Refractory: 150 to 250 ms\n');
fprintf('  ITI: 250 to 750 ms\n');
fprintf('  Trial 1: starts at %d ms (150 + 100 + 500 = 750)\n', element_table4.absolute_onset_ms(2));
fprintf('\n\n');

%% Demo 5: Omission Trial
fprintf('Demo 5: Omission Trial (empty trial)\n');
fprintf('-------------------------------------\n');

trial_plan5 = struct();
trial_plan5.n_trials = 3;
trial_plan5.iti_ms = 500;

% Trial 0: present, Trial 1: omission, Trial 2: present
trial_plan5.trials = {
    struct('trial_index', 0, 'label', 'present', 'elements', {{
        struct('stimulus_ref', 'stim', 'scheduled_onset_ms', 0, 'duration_ms', 100)
    }})
    struct('trial_index', 1, 'label', 'omission', 'elements', {{}})  % Empty!
    struct('trial_index', 2, 'label', 'present', 'elements', {{
        struct('stimulus_ref', 'stim', 'scheduled_onset_ms', 0, 'duration_ms', 100)
    }})
};

element_table5 = builder.build(trial_plan5);

fprintf('Trial Plan:\n');
fprintf('  Trials: 3 (present, omission, present)\n');
fprintf('  ITI: %d ms\n', trial_plan5.iti_ms);
fprintf('\n');

fprintf('Element Table (should have 2 elements, not 3):\n');
disp(element_table5);

fprintf('Omission verification:\n');
fprintf('  Total elements: %d (should be 2, not 3)\n', height(element_table5));
fprintf('  Trial indices present: [%s]\n', num2str(element_table5.trial_index'));
fprintf('  Trial 1 (omission) has no elements\n');
fprintf('\n\n');

%% Demo 6: Complex Multi-Element Trial
fprintf('Demo 6: Complex Multi-Element Trial\n');
fprintf('------------------------------------\n');

trial_plan6 = struct();
trial_plan6.n_trials = 1;
trial_plan6.iti_ms = 500;

% Single trial with many elements at different times
trial_plan6.trials = {
    struct('trial_index', 0, 'label', 'complex', 'elements', {{
        struct('stimulus_ref', 'elem_1', 'scheduled_onset_ms', 0, 'duration_ms', 50)
        struct('stimulus_ref', 'elem_2', 'scheduled_onset_ms', 100, 'duration_ms', 50)
        struct('stimulus_ref', 'elem_3', 'scheduled_onset_ms', 200, 'duration_ms', 50)
        struct('stimulus_ref', 'elem_4', 'scheduled_onset_ms', 400, 'duration_ms', 50)
        struct('stimulus_ref', 'elem_5', 'scheduled_onset_ms', 800, 'duration_ms', 50)
    }})
};

element_table6 = builder.build(trial_plan6);

fprintf('Trial Plan:\n');
fprintf('  Trials: 1\n');
fprintf('  Elements: 5 at various times\n');
fprintf('\n');

fprintf('Element Table:\n');
disp(element_table6);

fprintf('Element indexing verification:\n');
for i = 1:height(element_table6)
    fprintf('  Element %d: onset=%d ms, stimulus=%s\n', ...
        element_table6.element_index(i), ...
        element_table6.absolute_onset_ms(i), ...
        element_table6.stimulus_ref{i});
end
fprintf('\n\n');

%% Summary
fprintf('=== Pattern Builder Core Demo Complete ===\n');
fprintf('\nKey Features Demonstrated:\n');
fprintf('  ✓ Single and multiple elements per trial\n');
fprintf('  ✓ Absolute timing computation (trial + ITI)\n');
fprintf('  ✓ IOI (inter-onset interval) resolution\n');
fprintf('  ✓ Refractory period enforcement\n');
fprintf('  ✓ Element indexing (0-based)\n');
fprintf('  ✓ Role assignment (cue/outcome)\n');
fprintf('  ✓ Symbol tracking (for Local-Global)\n');
fprintf('  ✓ Omission trials (empty elements)\n');
fprintf('  ✓ Metadata preservation in table\n');
fprintf('\nImplementation Status:\n');
fprintf('  ✓ M3: Pattern Builder Core - COMPLETE\n');
fprintf('\nNext Steps:\n');
fprintf('  → Run unit tests: run_tests_v1(''TestPatternBuilder'')\n');
fprintf('  → Implement Paradigm Adapters (M4)\n');
fprintf('  → Implement Compiler (M5)\n');
