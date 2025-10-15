function trial_list = build(instance, context)
% BUILD - Build oddball trial list
%
% This builder creates a standard/deviant oddball paradigm where frequent
% "standard" stimuli are interspersed with rare "deviant" stimuli.
%
% INPUTS:
%   instance - struct, block instance with:
%              .parameters.n_trials - number of trials
%              .parameters.standard_stimulus - standard stim spec
%              .parameters.deviant_stimulus - deviant stim spec
%              .parameters.deviant_probability - proportion of deviants
%              .parameters.order_constraint - (optional) ordering rules
%              .parameters.iti_min_sec - (optional) min ITI
%              .parameters.iti_max_sec - (optional) max ITI
%
%   context  - struct, runtime context with:
%              .generators - available generators
%              .rng_seed - (optional) random seed
%
% OUTPUTS:
%   trial_list - array of trial structs with standardized format

    % Extract parameters
    params = instance.parameters;
    n_trials = params.n_trials;
    p_deviant = params.deviant_probability;
    standard_stim = params.standard_stimulus;
    deviant_stim = params.deviant_stimulus;
    
    % Handle optional parameters
    if isfield(params, 'order_constraint')
        order_constraint = params.order_constraint;
    else
        order_constraint = 'random';
    end
    
    if isfield(params, 'iti_min_sec')
        iti_min = params.iti_min_sec;
    else
        iti_min = 1.0;
    end
    
    if isfield(params, 'iti_max_sec')
        iti_max = params.iti_max_sec;
    else
        iti_max = 2.0;
    end
    
    % Set random seed if provided
    if isfield(context, 'rng_seed') && ~isempty(context.rng_seed)
        rng(context.rng_seed);
    end
    
    % Determine which trials are deviants
    is_deviant = rand(n_trials, 1) < p_deviant;
    
    % Apply ordering constraints
    switch order_constraint
        case 'no_consecutive_deviants'
            is_deviant = enforce_no_consecutive_deviants(is_deviant);
        case 'random'
            % No constraint, keep as is
        otherwise
            warning('builders:oddball:UnknownConstraint', ...
                'Unknown order constraint: %s', order_constraint);
    end
    
    % Generate ITI values (jittered)
    iti_values = iti_min + (iti_max - iti_min) * rand(n_trials, 1);
    
    % Build trial list
    trial_list = struct();
    
    for k = 1:n_trials
        % Basic trial info
        if isfield(instance, 'instance_id')
            trial_list(k).trial_id = sprintf('%s_trial_%04d', ...
                instance.instance_id, k);
        else
            trial_list(k).trial_id = sprintf('trial_%04d', k);
        end
        
        trial_list(k).trial_num = k;
        trial_list(k).iti_sec = iti_values(k);
        
        % Determine trial type and stimulus
        if is_deviant(k)
            trial_list(k).trial_type = 'deviant';
            stim_spec = deviant_stim;
        else
            trial_list(k).trial_type = 'standard';
            stim_spec = standard_stim;
        end
        
        % Create single presentation at time 0
        trial_list(k).presentations(1).presentation_id = ...
            sprintf('%s_pres_1', trial_list(k).trial_id);
        trial_list(k).presentations(1).stimulus_spec = stim_spec;
        trial_list(k).presentations(1).onset_ms = 0;
        trial_list(k).presentations(1).metadata = struct();
        
        % Trial metadata
        trial_list(k).metadata = struct();
        trial_list(k).metadata.is_deviant = is_deviant(k);
        trial_list(k).metadata.trial_type = trial_list(k).trial_type;
    end
    
    % Summary
    n_deviants = sum(is_deviant);
    actual_p = n_deviants / n_trials;
    fprintf('Built oddball block: %d trials (%.1f%% deviants)\n', ...
        n_trials, 100 * actual_p);
end

function is_deviant = enforce_no_consecutive_deviants(is_deviant)
    % Shuffle trials to avoid consecutive deviants
    
    max_attempts = 1000;
    
    for attempt = 1:max_attempts
        % Check if there are any consecutive deviants
        has_consecutive = false;
        for k = 1:length(is_deviant)-1
            if is_deviant(k) && is_deviant(k+1)
                has_consecutive = true;
                break;
            end
        end
        
        % If no consecutive deviants, we're done
        if ~has_consecutive
            return;
        end
        
        % Otherwise, shuffle and try again
        is_deviant = is_deviant(randperm(length(is_deviant)));
    end
    
    % If we couldn't satisfy constraint after many attempts, warn
    warning('builders:oddball:ConstraintNotSatisfied', ...
        'Could not satisfy no_consecutive_deviants after %d attempts. ' + ...
        'Try reducing deviant_probability.', max_attempts);
end