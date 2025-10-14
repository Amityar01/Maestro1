% +trials/+builders/build_foreperiod.m
function trial_list = build_foreperiod(config)
% BUILD_FOREPERIOD - Create a trial list for a foreperiod paradigm (S1->Delay->S2)
%
% config should contain:
%   .n_trials - total number of trials
%   .omission_probability - proportion of trials where S2 is omitted
%   .cue - struct with stim_type and params for the cue (S1)
%   .outcome - struct with stim_type and params for the outcome (S2)
%   .timing.delay_ms - foreperiod delay between cue offset and outcome onset

n_trials = config.n_trials;

% Determine which trials are omissions (mismatch)
is_omission = rand(n_trials, 1) < config.omission_probability;

% Initialize trial list
trial_list = struct();

for k = 1:n_trials
    trial_list(k).trial_num = k;
    trial_list(k).block_type = 'foreperiod'; % <-- Updated
    
    % --- Presentation 1: The Cue (S1) ---
    trial_list(k).presentations(1).stim_type = config.cue.stim_type;
    trial_list(k).presentations(1).params = config.cue.params;
    trial_list(k).presentations(1).onset_ms = 0;
    
    % --- Presentation 2: The Outcome (S2) ---
    if is_omission(k)
        trial_list(k).trial_type = 'mismatch_omission';
        trial_list(k).metadata.is_mismatch = true;
    else
        trial_list(k).trial_type = 'paired';
        trial_list(k).metadata.is_mismatch = false;
        
        % Calculate onset time for the outcome
        cue_dur_ms = config.cue.params.dur_ms;
        outcome_onset_ms = cue_dur_ms + config.timing.delay_ms;
        
        trial_list(k).presentations(2).stim_type = config.outcome.stim_type;
        trial_list(k).presentations(2).params = config.outcome.params;
        trial_list(k).presentations(2).onset_ms = outcome_onset_ms;
    end
end

fprintf('✓ Built foreperiod block: %d trials\n', n_trials); % <-- Updated
n_standard = n_trials - sum(is_omission);
n_omit = sum(is_omission);
fprintf('  - Paired (S1->S2): %d trials (%.1f%%)\n', n_standard, 100*n_standard/n_trials);
fprintf('  - Mismatch (S1 only): %d trials (%.1f%%)\n', n_omit, 100*n_omit/n_trials);
end