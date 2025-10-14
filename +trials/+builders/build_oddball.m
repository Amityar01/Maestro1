% maestro2/+trials/+builders/build_oddball.m
function trial_list = build_oddball(config)
% BUILD_ODDBALL - Create trial list for standard/deviant oddball paradigm
%
% config should contain:
%   .n_trials - total number of trials
%   .deviant_probability - proportion of deviant trials (0-1)
%   .standard - struct with stim_type and params
%   .deviant - struct with stim_type and params
%   .order_constraint (optional) - 'random', 'no_consecutive_deviants'

n_trials = config.n_trials;
p_deviant = config.deviant_probability;

% Determine which trials are deviants
is_deviant = rand(n_trials, 1) < p_deviant;

% Initialize trial list
trial_list = struct();

for k = 1:n_trials
    trial_list(k).trial_num = k;
    trial_list(k).block_type = 'oddball';
    
    if is_deviant(k)
        trial_list(k).trial_type = 'deviant';
        trial_list(k).presentations(1).stim_type = config.deviant.stim_type;
        trial_list(k).presentations(1).params = config.deviant.params;
        trial_list(k).metadata.is_deviant = true;
    else
        trial_list(k).trial_type = 'standard';
        trial_list(k).presentations(1).stim_type = config.standard.stim_type;
        trial_list(k).presentations(1).params = config.standard.params;
        trial_list(k).metadata.is_deviant = false;
    end
    
    % Single presentation at time 0
    trial_list(k).presentations(1).onset_ms = 0;
end

% Apply ordering constraints
if isfield(config, 'order_constraint')
    switch config.order_constraint
        case 'no_consecutive_deviants'
            trial_list = enforce_no_consecutive_deviants(trial_list);
        case 'random'
            % Already random, do nothing
    end
end

fprintf('✓ Built oddball block: %d trials (%d deviants, %.1f%%)\n', ...
    n_trials, sum(is_deviant), 100*p_deviant);
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