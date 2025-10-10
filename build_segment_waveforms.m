% Maestro/build_segment_waveforms.m
function [AO, DO, trial_log, ttl_log] = build_segment_waveforms(trial_list, cfg, fs)
% BUILD_SEGMENT_WAVEFORMS - Creates AO and DO data for a whole segment

fprintf('Building waveforms for %d trials...\n');

% --- Get stimulus parameters from the config struct ---
p = cfg.stim_params;
t = cfg.timing;

% --- Generate the unique stimuli for this experiment ---
% NOTE: For now, we are using a fixed voltage. Later, this will come from
% the calibration file and GUI.
VOLTS_S1 = 0.2;
VOLTS_S2_O1 = 0.9; % Corresponds to "L-Noise"
VOLTS_S2_O2 = 0.3; % Corresponds to "Q-Noise"

% Generate S1 (Cue)
if strcmpi(p.s1_type, 'single_tone')
    S1 = stim.make_tone(p.s1_freq, 50, fs, VOLTS_S1, 10);
elseif strcmpi(p.s1_type, 'pip_train')
    S1 = stim.make_pip_train(p.s1_freq, 3, 30, 40, fs, VOLTS_S1, 10);
else
    error('Unknown S1 type: %s', p.s1_type);
end

% Generate S2 (Outcomes)
if strcmpi(p.s2_type, 'tone')
    O1 = stim.make_tone(p.s2_freq, 50, fs, VOLTS_S2_O1, 10);
    O2 = stim.make_tone(p.s2_freq/2, 50, fs, VOLTS_S2_O2, 10); % Example for 2nd tone
elseif strcmpi(p.s2_type, 'noise')
    O1 = stim.make_noise(50, fs, VOLTS_S2_O1, 10, 123); % Seeded for O1
    O2 = stim.make_noise(50, fs, VOLTS_S2_O2, 10, 456); % Seeded for O2
else
    error('Unknown S2 type: %s', p.s2_type);
end

% --- Build the full waveforms trial by trial ---
ttl_pulse = ones(round(fs * 0.002), 1); % 2ms pulse
AO = [];
DO = [];
ttl_log = table();
current_sample = 1;

for k = 1:numel(trial_list)
    trial = trial_list(k);
    
    % Select the correct outcome sound for this trial
    switch trial.outcome
        case "O1"
            outcome_sound = O1;
        case "O2"
            outcome_sound = O2;
        case "OMIT"
            outcome_sound = zeros(size(O1)); % Silence of the same duration
    end
    
    delay_samples = round(fs * t.delay_ms / 1000);
    iti_samples = round(fs * trial.iti_sec);
    
    % Create trial audio
    trial_ao = [S1; zeros(delay_samples, 1); outcome_sound; zeros(iti_samples, 1)];
    
    % Create trial TTLs
    trial_do = zeros(size(trial_ao));
    s1_onset = 1;
    expected_s2_onset = numel(S1) + delay_samples + 1;
    
    trial_do(s1_onset : s1_onset+numel(ttl_pulse)-1) = ttl_pulse;
    ttl_log = [ttl_log; {current_sample + s1_onset, 'S1_onset'}];
    
    trial_do(expected_s2_onset : expected_s2_onset+numel(ttl_pulse)-1) = ttl_pulse;
    ttl_log = [ttl_log; {current_sample + expected_s2_onset, 'Expected_S2_onset'}];
    
    if ~trial.is_omit
        ttl_log = [ttl_log; {current_sample + expected_s2_onset, 'Actual_S2_onset'}];
    end
    
    % Append to the main waveform
    AO = [AO; trial_ao];
    DO = [DO; trial_do];
    
    current_sample = current_sample + numel(trial_ao);
end

trial_log = struct2table(trial_list);
ttl_log.Properties.VariableNames = {'SampleIndex', 'Event'};
fprintf('✓ Waveforms built. Total duration: %.1f min.\n', numel(AO)/fs/60);
end