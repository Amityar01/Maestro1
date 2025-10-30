%% Maestro v1 - DAQ Engine Demo
% This script demonstrates the complete end-to-end pipeline from
% paradigm configuration to DAQ playback.
%
% Complete Pipeline:
%   Config → Adapter → Pattern Builder → Compiler → SequenceFile → DAQ Playback

clear; clc;

fprintf('=== Maestro v1 Complete Pipeline Demo ===\n');
fprintf('Config → Trial Plan → Element Table → SequenceFile → DAQ Playback\n\n');

%% Setup

fs_hz = 48000;
fprintf('System Configuration:\n');
fprintf('  Sampling rate: %d Hz\n', fs_hz);
fprintf('  Channels: 2 (stereo)\n');
fprintf('  Mode: dry_run (no hardware required)\n\n');

% Initialize infrastructure
rng_manager = v1.sampling.RNGStreamManager(42);
sampler = v1.sampling.NumericFieldSampler(rng_manager);
context = v1.generators.GeneratorContext('fs_hz', fs_hz, 'sampler', sampler);
context.set_rng_manager(rng_manager);

% Stimulus library
stimulus_library = containers.Map();
stimulus_library('tone_1000hz') = struct(...
    'type', 'tone.simple', ...
    'frequency_hz', 1000, ...
    'duration_ms', 150, ...
    'level', struct('value', 0.7, 'unit', 'linear_0_1'), ...
    'envelope', struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine'), ...
    'routing', struct('channels', [0 1]));

stimulus_library('tone_1200hz') = struct(...
    'type', 'tone.simple', ...
    'frequency_hz', 1200, ...
    'duration_ms', 150, ...
    'level', struct('value', 0.7, 'unit', 'linear_0_1'), ...
    'envelope', struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine'), ...
    'routing', struct('channels', [0 1]));

%% Demo 1: Complete Pipeline with DAQ Playback

fprintf('=========================================\n');
fprintf('Demo 1: Complete Pipeline (20 trials)\n');
fprintf('=========================================\n\n');

% Step 1: Configure oddball paradigm
fprintf('Step 1: Configure Oddball Paradigm\n');
fprintf('-----------------------------------\n');

oddball_config = struct();
oddball_config.tokens = [
    struct('label', 'standard', 'stimulus_ref', 'tone_1000hz', ...
           'base_probability', 0.8, 'code', 1, 'duration_ms', 150)
    struct('label', 'deviant', 'stimulus_ref', 'tone_1200hz', ...
           'base_probability', 0.2, 'code', 2, 'duration_ms', 150)
];
oddball_config.selection = struct('mode', 'balanced_shuffle', 'seed', 12345);
oddball_config.iti = struct('value', 500);

fprintf('  Paradigm: Oddball\n');
fprintf('  Tokens: standard (80%%), deviant (20%%)\n');
fprintf('  Trials: 20\n\n');

% Step 2: Generate trial plan
fprintf('Step 2: Generate Trial Plan\n');
fprintf('----------------------------\n');

oddball_adapter = v1.paradigms.OddballAdapter();
trial_plan = oddball_adapter.generate_trial_plan(oddball_config, 20);

labels = cellfun(@(t) t.label, trial_plan.trials, 'UniformOutput', false);
fprintf('  Generated: %d trials\n', trial_plan.n_trials);
fprintf('  Standard: %d, Deviant: %d\n\n', ...
    sum(strcmp(labels, 'standard')), sum(strcmp(labels, 'deviant')));

% Step 3: Build element table
fprintf('Step 3: Build Element Table\n');
fprintf('----------------------------\n');

pattern_builder = v1.compilation.PatternBuilderCore();
element_table = pattern_builder.build(trial_plan);

fprintf('  Elements: %d\n', height(element_table));
fprintf('  Duration: %.2f seconds\n\n', ...
    (element_table.absolute_onset_ms(end) + element_table.duration_ms(end)) / 1000);

% Step 4: Compile to SequenceFile
fprintf('Step 4: Compile to SequenceFile\n');
fprintf('--------------------------------\n');

compiler = v1.compilation.CompilerCore();

% Add TTL codes
element_table.ttl_code = zeros(height(element_table), 1);
for i = 1:height(element_table)
    if strcmp(element_table.label{i}, 'standard')
        element_table.ttl_code(i) = 1;
    else
        element_table.ttl_code(i) = 2;
    end
end

seq_file = compiler.compile(element_table, stimulus_library, fs_hz, context);

fprintf('  SequenceFile compiled\n');
fprintf('  Audio: %d samples (%.2f s)\n', size(seq_file.audio, 1), ...
    seq_file.manifest.duration_ms / 1000);
fprintf('  Events: %d\n', height(seq_file.events));
fprintf('  Hash: %s\n\n', seq_file.manifest.audio_hash(1:16));

% Step 5: Configure DAQ Engine
fprintf('Step 5: Configure DAQ Engine\n');
fprintf('-----------------------------\n');

engine = v1.daq.DAQEngine();

daq_config = struct();
daq_config.mode = 'dry_run';  % No hardware required
daq_config.real_time = false;  % Fast simulation
daq_config.ttl_mapping = containers.Map([1 2], {'port0/line0', 'port0/line1'});

engine.configure(daq_config);

fprintf('  Mode: %s\n', daq_config.mode);
fprintf('  Real-time: %s\n\n', iif(daq_config.real_time, 'yes', 'no (fast simulation)'));

% Step 6: Load and Play
fprintf('Step 6: Load SequenceFile and Play\n');
fprintf('-----------------------------------\n');

engine.load_sequence(seq_file);

seq_info = engine.get_sequence_info();
fprintf('  Loaded sequence info:\n');
fprintf('    Duration: %.2f s\n', seq_info.duration_ms / 1000);
fprintf('    Trials: %d\n', seq_info.n_trials);
fprintf('    Events: %d\n', seq_info.n_events);
fprintf('    Sample rate: %d Hz\n', seq_info.fs_hz);
fprintf('\n');

fprintf('  Playing...\n');
playback_result = engine.play();

fprintf('\n  Playback complete!\n');
fprintf('    Success: %s\n', iif(playback_result.success, 'YES', 'NO'));
fprintf('    Start time: %s\n', playback_result.start_time);
fprintf('    Events played: %d\n', playback_result.events_played);
fprintf('    Duration: %.2f ms\n', playback_result.duration_ms);
fprintf('    Sequence hash: %s\n\n', playback_result.sequence_hash(1:16));

%% Demo 2: Event Analysis

fprintf('=====================================\n');
fprintf('Demo 2: Event Timing Analysis\n');
fprintf('=====================================\n\n');

fprintf('Recorded Events (first 10):\n');
disp(playback_result.events(1:10, :));

fprintf('\nEvent Statistics:\n');
standard_events = playback_result.events(playback_result.events.code == 1, :);
deviant_events = playback_result.events(playback_result.events.code == 2, :);

fprintf('  Standard events: %d\n', height(standard_events));
fprintf('  Deviant events: %d\n', height(deviant_events));
fprintf('  First event: %.2f ms\n', playback_result.events.time_ms(1));
fprintf('  Last event: %.2f ms\n', playback_result.events.time_ms(end));
fprintf('\n');

%% Demo 3: TTL Output Mapping

fprintf('=====================================\n');
fprintf('Demo 3: TTL Output Mapping\n');
fprintf('=====================================\n\n');

if ~isempty(playback_result.ttl_events)
    fprintf('TTL Events (first 10):\n');
    disp(playback_result.ttl_events(1:10, :));

    fprintf('\nTTL Channel Mapping:\n');
    unique_codes = unique(playback_result.ttl_events.code);
    for i = 1:length(unique_codes)
        code = unique_codes(i);
        events_with_code = playback_result.ttl_events(playback_result.ttl_events.code == code, :);
        channel = events_with_code.channel{1};
        fprintf('  Code %d → %s (%d events)\n', code, channel, height(events_with_code));
    end
    fprintf('\n');
end

%% Demo 4: Playback Control

fprintf('=====================================\n');
fprintf('Demo 4: Playback Control\n');
fprintf('=====================================\n\n');

fprintf('Testing playback state management:\n\n');

% Reset engine
fprintf('  Resetting engine...\n');
engine.reset();
fprintf('    State after reset: %s\n', engine.get_state());
fprintf('    Loaded: %s\n\n', iif(engine.is_loaded(), 'yes', 'no'));

% Load again
fprintf('  Loading sequence...\n');
engine.configure(daq_config);
engine.load_sequence(seq_file);
fprintf('    State after load: %s\n', engine.get_state());
fprintf('    Loaded: %s\n\n', iif(engine.is_loaded(), 'yes', 'no'));

% Play again
fprintf('  Playing...\n');
result2 = engine.play();
fprintf('    State after play: %s\n', engine.get_state());
fprintf('    Events played: %d\n\n', result2.events_played);

%% Demo 5: Multiple Sequences

fprintf('=====================================\n');
fprintf('Demo 5: Playing Multiple Sequences\n');
fprintf('=====================================\n\n');

fprintf('Generating and playing 3 different sequences:\n\n');

for seq_num = 1:3
    fprintf('Sequence %d:\n', seq_num);

    % Generate with different seed
    oddball_config.selection.seed = 1000 * seq_num;
    trial_plan_multi = oddball_adapter.generate_trial_plan(oddball_config, 10);

    % Build and compile
    element_table_multi = pattern_builder.build(trial_plan_multi);
    element_table_multi.ttl_code = ones(height(element_table_multi), 1);

    seq_file_multi = compiler.compile(element_table_multi, stimulus_library, fs_hz, context);

    % Reset and play
    engine.reset();
    engine.configure(daq_config);
    engine.load_sequence(seq_file_multi);
    result_multi = engine.play();

    fprintf('  Hash: %s\n', result_multi.sequence_hash(1:16));
    fprintf('  Events: %d\n', result_multi.events_played);
    fprintf('  Duration: %.2f ms\n\n', result_multi.duration_ms);
end

%% Demo 6: Real-Time Simulation

fprintf('=====================================\n');
fprintf('Demo 6: Real-Time Simulation\n');
fprintf('=====================================\n\n');

fprintf('Comparing fast vs real-time playback:\n\n');

% Generate short sequence (5 trials)
short_config = oddball_config;
short_config.selection.seed = 99999;
short_trial_plan = oddball_adapter.generate_trial_plan(short_config, 5);
short_element_table = pattern_builder.build(short_trial_plan);
short_element_table.ttl_code = ones(height(short_element_table), 1);
short_seq_file = compiler.compile(short_element_table, stimulus_library, fs_hz, context);

fprintf('Sequence duration: %.2f s\n\n', short_seq_file.manifest.duration_ms / 1000);

% Fast playback
fprintf('Fast playback (real_time=false):\n');
daq_config_fast = daq_config;
daq_config_fast.real_time = false;

engine.reset();
engine.configure(daq_config_fast);
engine.load_sequence(short_seq_file);

tic;
result_fast = engine.play();
elapsed_fast = toc;

fprintf('  Elapsed: %.3f s\n', elapsed_fast);
fprintf('  Events: %d\n\n', result_fast.events_played);

% Real-time playback
fprintf('Real-time playback (real_time=true):\n');
daq_config_rt = daq_config;
daq_config_rt.real_time = true;

engine.reset();
engine.configure(daq_config_rt);
engine.load_sequence(short_seq_file);

tic;
result_rt = engine.play();
elapsed_rt = toc;

fprintf('  Elapsed: %.3f s\n', elapsed_rt);
fprintf('  Events: %d\n\n', result_rt.events_played);

fprintf('Speedup: %.1fx faster\n\n', elapsed_rt / elapsed_fast);

%% Summary

fprintf('=== DAQ Engine Demo Complete ===\n\n');
fprintf('Complete Pipeline Demonstrated:\n');
fprintf('  1. Config → Adapter → Trial Plan\n');
fprintf('  2. Pattern Builder → Element Table\n');
fprintf('  3. Compiler → SequenceFile\n');
fprintf('  4. DAQ Engine → Playback\n\n');

fprintf('Key Features:\n');
fprintf('  ✓ Dry-run mode (no hardware required)\n');
fprintf('  ✓ Fast simulation for testing\n');
fprintf('  ✓ Real-time simulation for timing validation\n');
fprintf('  ✓ Event recording with timestamps\n');
fprintf('  ✓ TTL channel mapping\n');
fprintf('  ✓ Playback state management\n');
fprintf('  ✓ Sequence hash verification\n');
fprintf('  ✓ Multiple sequence playback\n\n');

fprintf('Implementation Status:\n');
fprintf('  ✓ M1: Validation framework\n');
fprintf('  ✓ M2: Sampling + Generators\n');
fprintf('  ✓ M3: Pattern Builder Core\n');
fprintf('  ✓ M4: Paradigm Adapters\n');
fprintf('  ✓ M5: Compiler\n');
fprintf('  ✓ M6: DAQ Engine (dry-run) - COMPLETE\n\n');

fprintf('Next Steps:\n');
fprintf('  → Run unit tests: run_tests_v1(''TestDAQEngine'')\n');
fprintf('  → Add more stimulus generators\n');
fprintf('  → Add more paradigm adapters\n');
fprintf('  → Implement hardware playback (requires NI-DAQ)\n');
fprintf('  → Build GUI for experiment configuration\n\n');

fprintf('Note: Hardware playback requires:\n');
fprintf('  - National Instruments DAQ hardware\n');
fprintf('  - MATLAB Data Acquisition Toolbox\n');
fprintf('  - Set config.mode = ''hardware''\n');

% Helper function
function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end
