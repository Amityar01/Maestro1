% maestro2/build_segment_waveforms.m
function [AO, DO, trial_log, ttl_log] = build_segment_waveforms(trial_list, fs)
% BUILD_SEGMENT_WAVEFORMS - Universal waveform compiler for any paradigm
%
% Works with the new trial structure:
%   trial.presentations(n).stim_type
%   trial.presentations(n).params
%   trial.presentations(n).onset_ms

fprintf('Building waveforms for %d trials...\n', numel(trial_list));

AO = [];
DO = [];
ttl_log = table();
current_sample = 1;

ttl_pulse = ones(round(fs * 0.002), 1); % 2ms TTL pulse

for k = 1:numel(trial_list)
    trial = trial_list(k);
    
    % Calculate trial duration (max onset + stimulus duration + ITI)
    trial_dur_ms = calculate_trial_duration(trial, fs);
    iti_samples = round(fs * trial.iti_sec);
    trial_total_samples = round(fs * trial_dur_ms / 1000) + iti_samples;
    
    % Initialize this trial's waveforms
    trial_ao = zeros(trial_total_samples, 1);
    trial_do = zeros(trial_total_samples, 1);
    
    % Loop through all presentations in this trial
    for p_idx = 1:numel(trial.presentations)
        pres = trial.presentations(p_idx);
        
        % Generate stimulus
        stim = generate_stimulus(pres.stim_type, pres.params, fs);
        
        % Calculate insertion point
        onset_sample = round(fs * pres.onset_ms / 1000) + 1;
        
        % Insert stimulus
        insert_end = min(onset_sample + length(stim) - 1, length(trial_ao));
        trial_ao(onset_sample:insert_end) = trial_ao(onset_sample:insert_end) + ...
                                            stim(1:(insert_end-onset_sample+1));
        
        % Add TTL at onset
        ttl_end = min(onset_sample + length(ttl_pulse) - 1, length(trial_do));
        trial_do(onset_sample:ttl_end) = ttl_pulse(1:(ttl_end-onset_sample+1));
        
        % Log TTL event
        event_name = sprintf('T%d_P%d_%s', k, p_idx, pres.stim_type);
        ttl_log = [ttl_log; {current_sample + onset_sample - 1, event_name}];
    end
    
    % Append to main waveforms
    AO = [AO; trial_ao];
    DO = [DO; trial_do];
    current_sample = current_sample + trial_total_samples;
end

% Convert trial list to table for logging
trial_log = struct2table(trial_list);
ttl_log.Properties.VariableNames = {'SampleIndex', 'Event'};

fprintf('✓ Waveforms built. Total duration: %.1f sec (%.2f min)\n', ...
    length(AO)/fs, length(AO)/fs/60);
end

function dur_ms = calculate_trial_duration(trial, fs)
% Calculate the duration of the trial based on presentations

if isempty(trial.presentations)
    dur_ms = 0;
    return;
end

max_end_ms = 0;
for p_idx = 1:numel(trial.presentations)
    pres = trial.presentations(p_idx);
    
    % Get stimulus duration
    if isfield(pres.params, 'dur_ms')
        stim_dur = pres.params.dur_ms;
    else
        % Default duration if not specified
        stim_dur = 50;
    end
    
    end_ms = pres.onset_ms + stim_dur;
    max_end_ms = max(max_end_ms, end_ms);
end

dur_ms = max_end_ms;
end