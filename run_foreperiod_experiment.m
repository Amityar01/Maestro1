% run_foreperiod_experiment.m
%
% Foreperiod experiment with probabilistic outcomes:
% - Cue: 1000 Hz tone
% - Foreperiod: 500 ms (fixed)
% - Outcomes (probabilistic):
%   - 0.1: High level broadband noise
%   - 0.8: Low level broadband noise
%   - 0.1: Omission (no stimulus)

%% Configuration
clear;
clc;

% Experiment parameters
N_TRIALS = 100;  % Number of trials
SEED = 42;       % Random seed for reproducibility

% Hardware configuration
USE_HARDWARE = false;  % Set to true to use actual DAQ hardware
REAL_TIME = false;     % Set to true for real-time playback

% Audio parameters
FS_HZ = 48000;  % 48 kHz sampling rate

%% Step 1: Initialize Infrastructure
fprintf('=== Initializing Infrastructure ===\n');

% Create RNG manager and sampler for deterministic randomness
rng_manager = v1.sampling.RNGStreamManager(SEED);
sampler = v1.sampling.NumericFieldSampler(rng_manager);

% Create generator context
context = v1.generators.GeneratorContext('fs_hz', FS_HZ, 'sampler', sampler);
context.set_rng_manager(rng_manager);

fprintf('Sampling rate: %d Hz\n', FS_HZ);
fprintf('Random seed: %d\n', SEED);
fprintf('\n');

%% Step 2: Define Stimulus Library
fprintf('=== Defining Stimulus Library ===\n');

stimulus_library = containers.Map();

% Cue stimulus: 1000 Hz tone, 50 ms duration
stimulus_library('tone_1000hz') = struct(...
    'type', 'tone.simple', ...
    'frequency_hz', 1000, ...
    'duration_ms', 50, ...
    'level', struct('value', 0.5, 'unit', 'linear_0_1'), ...
    'envelope', struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine'), ...
    'routing', struct('channels', [0 1]));

fprintf('Cue: 1000 Hz tone, 50 ms, level 0.5\n');

% Outcome 1: High level broadband noise
stimulus_library('noise_high') = struct(...
    'type', 'noise.broadband', ...
    'duration_ms', 100, ...
    'level', struct('value', 0.8, 'unit', 'linear_0_1'), ...
    'cutoff_hz', 20000, ...
    'envelope', struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine'), ...
    'routing', struct('channels', [0 1]));

fprintf('Outcome 1: High level noise, level 0.8 (probability 0.1)\n');

% Outcome 2: Low level broadband noise
stimulus_library('noise_low') = struct(...
    'type', 'noise.broadband', ...
    'duration_ms', 100, ...
    'level', struct('value', 0.2, 'unit', 'linear_0_1'), ...
    'cutoff_hz', 20000, ...
    'envelope', struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine'), ...
    'routing', struct('channels', [0 1]));

fprintf('Outcome 2: Low level noise, level 0.2 (probability 0.8)\n');
fprintf('Outcome 3: Omission (probability 0.1)\n');
fprintf('\n');

%% Step 3: Configure Foreperiod Paradigm
fprintf('=== Configuring Foreperiod Paradigm ===\n');

foreperiod_config = struct();

% Cue configuration
foreperiod_config.cue = struct(...
    'stimulus_ref', 'tone_1000hz', ...
    'duration_ms', 50);

% Outcomes with probabilities
foreperiod_config.outcomes = {
    struct(...
        'stimulus_ref', 'noise_high', ...
        'duration_ms', 100, ...
        'probability', 0.1, ...
        'label', 'high_level')
    struct(...
        'stimulus_ref', 'noise_low', ...
        'duration_ms', 100, ...
        'probability', 0.8, ...
        'label', 'low_level')
    struct(...
        'stimulus_ref', 'omission', ...
        'duration_ms', 0, ...
        'probability', 0.1, ...
        'label', 'omission', ...
        'is_omission', true)
};

% Foreperiod: Fixed at 500 ms
foreperiod_config.foreperiods = [500];
foreperiod_config.foreperiod_probs = [1.0];  % 100% probability (fixed)

% Selection mode: balanced shuffle for exact proportions
foreperiod_config.selection = struct(...
    'mode', 'balanced_shuffle', ...
    'seed', SEED);

% Inter-trial interval: 2000 ms
foreperiod_config.iti = struct('value', 2000);

fprintf('Foreperiod: 500 ms (fixed)\n');
fprintf('Outcomes:\n');
fprintf('  - High level noise: p=0.1 (expect %d trials)\n', round(N_TRIALS * 0.1));
fprintf('  - Low level noise:  p=0.8 (expect %d trials)\n', round(N_TRIALS * 0.8));
fprintf('  - Omission:         p=0.1 (expect %d trials)\n', round(N_TRIALS * 0.1));
fprintf('ITI: 2000 ms\n');
fprintf('Total trials: %d\n', N_TRIALS);
fprintf('\n');

%% Step 4: Generate Trial Plan
fprintf('=== Generating Trial Plan ===\n');

adapter = v1.paradigms.ForeperiodAdapter();
trial_plan = adapter.generate_trial_plan(foreperiod_config, N_TRIALS);

fprintf('Trial plan generated: %d trials\n', trial_plan.n_trials);
fprintf('Each trial has 2 elements: cue → outcome\n');

% Count outcome types
outcome_counts = struct('high_level', 0, 'low_level', 0, 'omission', 0);
for i = 1:length(trial_plan.trials)
    trial = trial_plan.trials{i};
    outcome_element = trial.elements{2};  % Second element is outcome

    if isfield(outcome_element, 'label')
        label = outcome_element.label;
    elseif isfield(outcome_element, 'is_omission') && outcome_element.is_omission
        label = 'omission';
    else
        label = 'unknown';
    end

    if isfield(outcome_counts, label)
        outcome_counts.(label) = outcome_counts.(label) + 1;
    end
end

fprintf('Actual outcome distribution:\n');
fprintf('  - High level: %d trials (%.1f%%)\n', outcome_counts.high_level, ...
    100 * outcome_counts.high_level / N_TRIALS);
fprintf('  - Low level:  %d trials (%.1f%%)\n', outcome_counts.low_level, ...
    100 * outcome_counts.low_level / N_TRIALS);
fprintf('  - Omission:   %d trials (%.1f%%)\n', outcome_counts.omission, ...
    100 * outcome_counts.omission / N_TRIALS);
fprintf('\n');

%% Step 5: Expand to Element Table
fprintf('=== Building Element Table ===\n');

pattern_builder = v1.compilation.PatternBuilderCore();
element_table = pattern_builder.build(trial_plan);

fprintf('Element table: %d elements (%d trials × 2 elements)\n', ...
    height(element_table), N_TRIALS);
fprintf('\n');

%% Step 6: Add TTL Codes for Event Marking
fprintf('=== Adding TTL Codes ===\n');

element_table.ttl_code = zeros(height(element_table), 1);

for i = 1:height(element_table)
    if strcmp(element_table.role{i}, 'cue')
        element_table.ttl_code(i) = 1;  % Code 1 for cues
    elseif isfield(element_table, 'is_omission') && ...
           length(element_table.is_omission) >= i && ...
           element_table.is_omission(i)
        element_table.ttl_code(i) = 4;  % Code 4 for omissions
    else
        % Check stimulus_ref to determine outcome type
        stim_ref = element_table.stimulus_ref{i};
        if strcmp(stim_ref, 'noise_high')
            element_table.ttl_code(i) = 2;  % Code 2 for high level
        elseif strcmp(stim_ref, 'noise_low')
            element_table.ttl_code(i) = 3;  % Code 3 for low level
        else
            element_table.ttl_code(i) = 0;  % Unknown
        end
    end
end

fprintf('TTL codes assigned:\n');
fprintf('  Code 1: Cue onset\n');
fprintf('  Code 2: High level noise onset\n');
fprintf('  Code 3: Low level noise onset\n');
fprintf('  Code 4: Omission (no stimulus)\n');
fprintf('\n');

%% Step 7: Compile to SequenceFile
fprintf('=== Compiling SequenceFile ===\n');

compiler = v1.compilation.CompilerCore();
seq_file = compiler.compile(element_table, stimulus_library, FS_HZ, context);

fprintf('SequenceFile compiled successfully\n');
fprintf('Duration: %.2f seconds\n', seq_file.manifest.duration_ms / 1000);
fprintf('Audio buffer: %d samples × %d channels\n', ...
    size(seq_file.audio, 1), size(seq_file.audio, 2));
fprintf('Events: %d\n', height(seq_file.events));
fprintf('\n');

%% Step 8: Configure and Play on DAQ Engine
fprintf('=== Configuring DAQ Engine ===\n');

engine = v1.daq.DAQEngine();

daq_config = struct();
if USE_HARDWARE
    daq_config.mode = 'hardware';
    fprintf('Mode: Hardware DAQ\n');
else
    daq_config.mode = 'dry_run';
    fprintf('Mode: Dry run (simulation)\n');
end

daq_config.real_time = REAL_TIME;
if REAL_TIME
    fprintf('Timing: Real-time\n');
else
    fprintf('Timing: Fast (non-real-time)\n');
end

daq_config.ttl_mapping = containers.Map(...
    [1, 2, 3, 4], ...
    {'port0/line0', 'port0/line1', 'port0/line2', 'port0/line3'});

engine.configure(daq_config);
fprintf('DAQ configured\n');
fprintf('\n');

%% Step 9: Load and Play Sequence
fprintf('=== Playing Sequence ===\n');

engine.load_sequence(seq_file);
fprintf('Sequence loaded\n');

if USE_HARDWARE || REAL_TIME
    fprintf('Starting playback (this will take %.2f seconds)...\n', ...
        seq_file.manifest.duration_ms / 1000);
end

result = engine.play();

fprintf('Playback complete!\n');
fprintf('Events played: %d\n', result.events_played);
fprintf('Status: %s\n', result.status);
fprintf('\n');

%% Summary
fprintf('=== Experiment Summary ===\n');
fprintf('Total trials: %d\n', N_TRIALS);
fprintf('Foreperiod: 500 ms\n');
fprintf('Outcome distribution:\n');
fprintf('  - High level (p=0.1): %d trials\n', outcome_counts.high_level);
fprintf('  - Low level (p=0.8):  %d trials\n', outcome_counts.low_level);
fprintf('  - Omission (p=0.1):   %d trials\n', outcome_counts.omission);
fprintf('Total duration: %.2f seconds\n', seq_file.manifest.duration_ms / 1000);
fprintf('\nExperiment complete!\n');
