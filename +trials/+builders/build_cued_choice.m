% +trials/+builders/build_cued_choice.m
function trial_list = build_cued_choice(config)
% BUILD_CUED_CHOICE - A simple paradigm where a cue is followed by one of
% several possible outcomes, chosen based on specified probabilities.

n_trials = config.n_trials;

% --- Create a weighted list of all possible outcomes ---
outcome_names = {};
fprintf('Calculating trial distribution...\n');
for i = 1:length(config.outcomes)
    outcome = config.outcomes{i}; % <-- CORRECTED: Use curly braces {}
    n_this_outcome = round(n_trials * outcome.probability);
    
    fprintf('  - Outcome (%s): %d trials\n', outcome.name, n_this_outcome);
    
    outcome_names = [outcome_names; repmat({outcome.name}, n_this_outcome, 1)];
end

if length(outcome_names) < n_trials
    n_fill = n_trials - length(outcome_names);
    outcome_names = [outcome_names; repmat({config.outcomes{1}.name}, n_fill, 1)]; % <-- CORRECTED
end
outcome_names = outcome_names(1:n_trials);

shuffled_names = outcome_names(randperm(n_trials));


% --- Build the trial list ---
trial_list = struct();
for k = 1:n_trials
    trial_list(k).trial_num = k;
    trial_list(k).block_type = 'cued_choice';
    
    % --- Presentation 1: The Cue ---
    trial_list(k).presentations(1).stim_type = config.cue.stim_type;
    trial_list(k).presentations(1).params = config.cue.params;
    trial_list(k).presentations(1).onset_ms = 0;
    
    % --- Find the definition for the selected outcome ---
    this_outcome_name = shuffled_names{k};
    trial_list(k).trial_type = this_outcome_name;
    
    outcome_def = struct();
    for i = 1:length(config.outcomes)
        if strcmp(config.outcomes{i}.name, this_outcome_name) % <-- CORRECTED
            outcome_def = config.outcomes{i}; % <-- CORRECTED
            break;
        end
    end
    
    % --- Presentation 2: The Outcome ---
    if isfield(outcome_def, 'is_omission') && outcome_def.is_omission
        continue;
    end
    
    cue_dur_ms = config.cue.params.dur_ms;
    outcome_onset_ms = cue_dur_ms + config.timing.delay_ms;
    
    trial_list(k).presentations(2).stim_type = outcome_def.stim_type;
    trial_list(k).presentations(2).params = outcome_def.params;
    trial_list(k).presentations(2).onset_ms = outcome_onset_ms;
end

fprintf('\n✓ Built cued-choice block: %d total trials\n', n_trials);
end