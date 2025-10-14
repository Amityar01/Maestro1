% Maestro/+trials/+builders/build_audiovisual_oddball.m
function trial_list = build_audiovisual_oddball(config)
% BUILD_AUDIOVISUAL_ODDBALL - Create trial list for an AV oddball paradigm.
%
% Parses both audio and visual stimulus definitions from the config.

n_trials = config.n_trials;
p_deviant = config.deviant_probability;

% Determine which trials are deviants
is_deviant = rand(n_trials, 1) < p_deviant;

% Initialize trial list
trial_list = struct();

for k = 1:n_trials
    trial_list(k).trial_num = k;
    trial_list(k).block_type = 'audiovisual_oddball';
    
    if is_deviant(k)
        trial_list(k).trial_type = 'deviant';
        % A presentation with both audio and visual components
        trial_list(k).presentations(1).audio_stim = config.deviant.audio;
        trial_list(k).presentations(1).visual_stim = config.deviant.visual;
        trial_list(k).metadata.is_deviant = true;
    else
        trial_list(k).trial_type = 'standard';
        % A presentation with both audio and visual components
        trial_list(k).presentations(1).audio_stim = config.standard.audio;
        trial_list(k).presentations(1).visual_stim = config.standard.visual;
        trial_list(k).metadata.is_deviant = false;
    end
    
    % Onset at time 0 within the trial
    trial_list(k).presentations(1).onset_ms = 0;
end

% Apply ordering constraints if specified
if isfield(config, 'order_constraint') && strcmp(config.order_constraint, 'no_consecutive_deviants')
    trial_list = enforce_no_consecutive_deviants(trial_list);
end

fprintf('✓ Built AV oddball block: %d trials (%d deviants, %.1f%%)\n', ...
    n_trials, sum(is_deviant), 100*p_deviant*100);
end


function trial_list = enforce_no_consecutive_deviants(trial_list)
% Shuffle to avoid consecutive deviants
max_attempts = 1000;
for attempt = 1:max_attempts
    is_valid = true;
    
    % Check for consecutive deviants
    for k = 1:length(trial_list)-1
        if trial_list(k).metadata.is_deviant && trial_list(k+1).metadata.is_deviant
            is_valid = false;
            break;
        end
    end
    
    if is_valid
        return;
    end
    
    % Shuffle and try again
    idx = randperm(length(trial_list));
    trial_list = trial_list(idx);
    % Update trial numbers
    for k = 1:length(trial_list)
        trial_list(k).trial_num = k;
    end
end

warning('Could not satisfy no_consecutive_deviants constraint after %d attempts', max_attempts);
end