%% Maestro v1 - Compiler Demo (End-to-End Pipeline)
% This script demonstrates the complete compilation pipeline from
% paradigm configuration to executable SequenceFile.
%
% Pipeline: Config → Adapter → Pattern Builder → Compiler → SequenceFile
%
% Following TDD: tests were written first, implementation makes them pass.

clear; clc;

fprintf('=== Maestro v1 Compiler Demo ===\n');
fprintf('Complete Pipeline: Config → Trial Plan → Element Table → SequenceFile\n\n');

%% Setup

% Audio parameters
fs_hz = 48000;  % 48 kHz sampling rate
fprintf('Audio Parameters:\n');
fprintf('  Sampling rate: %d Hz\n', fs_hz);
fprintf('  Channels: 2 (stereo)\n\n');

% Initialize sampling infrastructure
rng_manager = v1.sampling.RNGStreamManager(42);  % Master seed
sampler = v1.sampling.NumericFieldSampler(rng_manager);
context = v1.generators.GeneratorContext('fs_hz', fs_hz, 'sampler', sampler);
context.set_rng_manager(rng_manager);

% Create stimulus library
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

fprintf('Stimulus Library: 2 stimuli loaded\n');
fprintf('  - tone_1000hz: 1000 Hz, 150 ms\n');
fprintf('  - tone_1200hz: 1200 Hz, 150 ms\n\n');

%% Demo 1: Oddball Pipeline (Config → SequenceFile)

fprintf('=====================================\n');
fprintf('Demo 1: Oddball Pipeline (10 trials)\n');
fprintf('=====================================\n\n');

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
fprintf('  Selection: balanced_shuffle\n');
fprintf('  ITI: 500 ms\n');
fprintf('  Trials: 10\n\n');

% Step 2: Generate trial plan
fprintf('Step 2: Generate Trial Plan (Adapter)\n');
fprintf('--------------------------------------\n');

oddball_adapter = v1.paradigms.OddballAdapter();
trial_plan = oddball_adapter.generate_trial_plan(oddball_config, 10);

fprintf('  Trial plan generated: %d trials\n', trial_plan.n_trials);
labels = cellfun(@(t) t.label, trial_plan.trials, 'UniformOutput', false);
fprintf('  Sequence: %s\n', strjoin(labels, ' '));
fprintf('  Standard count: %d\n', sum(strcmp(labels, 'standard')));
fprintf('  Deviant count: %d\n\n', sum(strcmp(labels, 'deviant')));

% Step 3: Expand to element table
fprintf('Step 3: Expand to Element Table (Pattern Builder)\n');
fprintf('--------------------------------------------------\n');

pattern_builder = v1.compilation.PatternBuilderCore();
element_table = pattern_builder.build(trial_plan);

fprintf('  Element table generated: %d elements\n', height(element_table));
fprintf('  First 5 elements:\n');
disp(element_table(1:5, :));
fprintf('\n');

% Step 4: Compile to SequenceFile
fprintf('Step 4: Compile to SequenceFile (Compiler)\n');
fprintf('-------------------------------------------\n');

compiler = v1.compilation.CompilerCore();

% Add TTL codes to element table
element_table.ttl_code = zeros(height(element_table), 1);
for i = 1:height(element_table)
    if strcmp(element_table.label{i}, 'standard')
        element_table.ttl_code(i) = 1;
    else
        element_table.ttl_code(i) = 2;
    end
end

seq_file = compiler.compile(element_table, stimulus_library, fs_hz, context);

fprintf('\nSequenceFile compiled!\n');
fprintf('  Audio buffer: %d samples × %d channels\n', size(seq_file.audio, 1), size(seq_file.audio, 2));
fprintf('  Duration: %.2f seconds\n', seq_file.manifest.duration_ms / 1000);
fprintf('  Events: %d\n', height(seq_file.events));
fprintf('  Audio hash: %s\n\n', seq_file.manifest.audio_hash(1:16));

% Inspect SequenceFile
fprintf('SequenceFile Structure:\n');
fprintf('  .audio: [%d × %d] single\n', size(seq_file.audio));
fprintf('  .ttl: [%d × 1] uint8\n', size(seq_file.ttl, 1));
fprintf('  .events: table with %d rows\n', height(seq_file.events));
fprintf('  .trial_table: table with %d rows\n', height(seq_file.trial_table));
fprintf('  .element_table: table with %d rows\n', height(seq_file.element_table));
fprintf('  .manifest: struct with provenance\n\n');

fprintf('Events Table (first 5):\n');
disp(seq_file.events(1:5, :));
fprintf('\n');

fprintf('Manifest:\n');
disp(seq_file.manifest);
fprintf('\n');

%% Demo 2: Local-Global Pipeline (AAAB Patterns)

fprintf('===========================================\n');
fprintf('Demo 2: Local-Global Pipeline (5 trials)\n');
fprintf('===========================================\n\n');

% Step 1: Configure Local-Global paradigm
fprintf('Step 1: Configure Local-Global Paradigm\n');
fprintf('----------------------------------------\n');

lg_config = struct();
lg_config.token_a = struct('stimulus_ref', 'tone_1000hz', 'duration_ms', 50);
lg_config.token_b = struct('stimulus_ref', 'tone_1200hz', 'duration_ms', 50);
lg_config.patterns = [
    struct('label', 'AAAB', 'sequence', 'AAAB', 'base_probability', 0.5)
    struct('label', 'AAAA', 'sequence', 'AAAA', 'base_probability', 0.5)
];
lg_config.ioi = struct('value', 100);  % 100ms between elements
lg_config.iti = struct('value', 800);
lg_config.selection = struct('mode', 'balanced_shuffle', 'seed', 99999);

fprintf('  Paradigm: Local-Global\n');
fprintf('  Patterns: AAAB (50%%), AAAA (50%%)\n');
fprintf('  IOI: 100 ms\n');
fprintf('  ITI: 800 ms\n');
fprintf('  Trials: 5\n\n');

% Step 2: Generate trial plan
fprintf('Step 2: Generate Trial Plan (Adapter)\n');
fprintf('--------------------------------------\n');

lg_adapter = v1.paradigms.LocalGlobalAdapter();
lg_trial_plan = lg_adapter.generate_trial_plan(lg_config, 5);

fprintf('  Trial plan generated: %d trials\n', lg_trial_plan.n_trials);
lg_labels = cellfun(@(t) t.label, lg_trial_plan.trials, 'UniformOutput', false);
fprintf('  Sequence: %s\n', strjoin(lg_labels, ' '));
fprintf('  AAAB count: %d\n', sum(strcmp(lg_labels, 'AAAB')));
fprintf('  AAAA count: %d\n\n', sum(strcmp(lg_labels, 'AAAA')));

% Step 3: Expand to element table
fprintf('Step 3: Expand to Element Table (Pattern Builder)\n');
fprintf('--------------------------------------------------\n');

lg_element_table = pattern_builder.build(lg_trial_plan);

fprintf('  Element table generated: %d elements (5 trials × 4 elements)\n', height(lg_element_table));
fprintf('  First trial (4 elements):\n');
disp(lg_element_table(1:4, :));
fprintf('\n');

% Step 4: Compile to SequenceFile
fprintf('Step 4: Compile to SequenceFile (Compiler)\n');
fprintf('-------------------------------------------\n');

% Add TTL codes
lg_element_table.ttl_code = lg_element_table.trial_index + 1;  % Simple coding

lg_seq_file = compiler.compile(lg_element_table, stimulus_library, fs_hz, context);

fprintf('\nSequenceFile compiled!\n');
fprintf('  Audio buffer: %d samples × %d channels\n', size(lg_seq_file.audio, 1), size(lg_seq_file.audio, 2));
fprintf('  Duration: %.2f seconds\n', lg_seq_file.manifest.duration_ms / 1000);
fprintf('  Events: %d (5 trials × 4 elements)\n', height(lg_seq_file.events));
fprintf('  Audio hash: %s\n\n', lg_seq_file.manifest.audio_hash(1:16));

fprintf('Events Table (first 8 = 2 trials):\n');
disp(lg_seq_file.events(1:8, :));
fprintf('\n');

%% Demo 3: Audio Analysis

fprintf('==============================\n');
fprintf('Demo 3: Audio Analysis\n');
fprintf('==============================\n\n');

fprintf('Oddball SequenceFile Audio:\n');
fprintf('  Shape: [%d samples × %d channels]\n', size(seq_file.audio));
fprintf('  Duration: %.2f seconds\n', size(seq_file.audio, 1) / fs_hz);
fprintf('  Peak amplitude: %.4f\n', max(abs(seq_file.audio(:))));
fprintf('  RMS: %.4f\n', sqrt(mean(seq_file.audio(:).^2)));
fprintf('  Non-zero samples: %d (%.1f%%)\n', ...
    sum(abs(seq_file.audio(:, 1)) > 0), ...
    100 * sum(abs(seq_file.audio(:, 1)) > 0) / size(seq_file.audio, 1));
fprintf('\n');

% Plot audio waveform (first 2 seconds)
figure('Name', 'Oddball Audio Waveform');
plot_samples = min(2 * fs_hz, size(seq_file.audio, 1));
time_axis = (0:plot_samples-1) / fs_hz;

subplot(3, 1, 1);
plot(time_axis, seq_file.audio(1:plot_samples, 1));
xlabel('Time (s)');
ylabel('Amplitude');
title('Oddball Audio - Channel 0');
grid on;

subplot(3, 1, 2);
plot(time_axis, double(seq_file.ttl(1:plot_samples)));
xlabel('Time (s)');
ylabel('TTL Code');
title('TTL Codes');
ylim([-0.5 3]);
grid on;

% Mark events
subplot(3, 1, 3);
event_times = seq_file.events.time_ms / 1000;
event_codes = seq_file.events.code;
standard_events = event_times(event_codes == 1);
deviant_events = event_times(event_codes == 2);

hold on;
plot(standard_events, ones(size(standard_events)), 'bo', 'MarkerSize', 10, 'DisplayName', 'Standard');
plot(deviant_events, 2*ones(size(deviant_events)), 'ro', 'MarkerSize', 10, 'DisplayName', 'Deviant');
xlabel('Time (s)');
ylabel('Event Type');
title('Event Timeline');
legend('Location', 'best');
ylim([0 3]);
xlim([0 2]);
grid on;

fprintf('Figure created: Oddball audio waveform and events\n\n');

%% Demo 4: HDF5 Export and Read-Back

fprintf('==============================\n');
fprintf('Demo 4: HDF5 Export/Import\n');
fprintf('==============================\n\n');

% Write to HDF5
output_path = 'test_oddball_sequence.h5';
fprintf('Writing SequenceFile to HDF5...\n');
compiler.write_hdf5(seq_file, output_path);
fprintf('  Written to: %s\n', output_path);

% Check file size
file_info = dir(output_path);
fprintf('  File size: %.2f KB\n\n', file_info.bytes / 1024);

% Read back
fprintf('Reading SequenceFile from HDF5...\n');
seq_file_loaded = compiler.read_hdf5(output_path);
fprintf('  Loaded successfully\n\n');

% Verify integrity
fprintf('Integrity Check:\n');
fprintf('  Audio shape match: %s\n', iif(isequal(size(seq_file.audio), size(seq_file_loaded.audio)), 'PASS', 'FAIL'));
fprintf('  Audio data match: %s\n', iif(isequal(seq_file.audio, seq_file_loaded.audio), 'PASS', 'FAIL'));
fprintf('  TTL data match: %s\n', iif(isequal(seq_file.ttl, seq_file_loaded.ttl), 'PASS', 'FAIL'));
fprintf('  Events match: %s\n', iif(height(seq_file.events) == height(seq_file_loaded.events), 'PASS', 'FAIL'));
fprintf('  Hash match: %s\n', iif(strcmp(seq_file.manifest.audio_hash, seq_file_loaded.manifest.audio_hash), 'PASS', 'FAIL'));
fprintf('\n');

%% Demo 5: Determinism Verification

fprintf('==============================\n');
fprintf('Demo 5: Determinism\n');
fprintf('==============================\n\n');

fprintf('Test: Compile same element table twice\n\n');

% Reset context with same seed
rng_manager2 = v1.sampling.RNGStreamManager(42);  % Same seed
sampler2 = v1.sampling.NumericFieldSampler(rng_manager2);
context2 = v1.generators.GeneratorContext('fs_hz', fs_hz, 'sampler', sampler2);
context2.set_rng_manager(rng_manager2);

% Compile again
seq_file_2 = compiler.compile(element_table, stimulus_library, fs_hz, context2);

fprintf('Results:\n');
fprintf('  Audio buffer 1 hash: %s\n', seq_file.manifest.audio_hash(1:32));
fprintf('  Audio buffer 2 hash: %s\n', seq_file_2.manifest.audio_hash(1:32));
fprintf('  Match: %s\n', iif(strcmp(seq_file.manifest.audio_hash, seq_file_2.manifest.audio_hash), 'YES ✓ (deterministic)', 'NO ✗'));
fprintf('  Audio arrays equal: %s\n', iif(isequal(seq_file.audio, seq_file_2.audio), 'YES ✓', 'NO ✗'));
fprintf('\n');

%% Summary

fprintf('=== Compiler Demo Complete ===\n\n');
fprintf('Key Features Demonstrated:\n');
fprintf('  ✓ End-to-end pipeline: Config → SequenceFile\n');
fprintf('  ✓ Oddball: 10 trials, 80/20 split\n');
fprintf('  ✓ Local-Global: 5 trials, AAAB/AAAA patterns\n');
fprintf('  ✓ Audio generation and stitching\n');
fprintf('  ✓ TTL code injection at element onsets\n');
fprintf('  ✓ Events table with sample-accurate timing\n');
fprintf('  ✓ Metadata packaging (trials, elements, manifest)\n');
fprintf('  ✓ SHA-256 hash for provenance\n');
fprintf('  ✓ HDF5 export and import\n');
fprintf('  ✓ Determinism verification\n');
fprintf('\nImplementation Status:\n');
fprintf('  ✓ M1: Validation framework\n');
fprintf('  ✓ M2: Sampling + Generators\n');
fprintf('  ✓ M3: Pattern Builder Core\n');
fprintf('  ✓ M4: Paradigm Adapters\n');
fprintf('  ✓ M5: Compiler - COMPLETE\n');
fprintf('\nNext Steps:\n');
fprintf('  → Run unit tests: run_tests_v1(''TestCompiler'')\n');
fprintf('  → Implement DAQ Engine (M6) for playback\n');
fprintf('  → Build GUI (M8) for configuration\n');
fprintf('\nGenerated Files:\n');
fprintf('  - %s (%.2f KB)\n', output_path, file_info.bytes / 1024);

% Helper function
function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end
