function trials = build_oddball(params)
    % build_oddball - Generates a trial list for a simple oddball paradigm.
    
    n_trials = params.n_trials;
    deviant_prob = params.deviant_probability;
    
    trials = table();
    
    for i = 1:n_trials
        is_deviant = rand() < deviant_prob;
        
        if is_deviant
            trials.stim_name{i} = params.stimulus_slots.deviant_stim;
            trials.is_deviant(i) = true;
        else
            trials.stim_name{i} = params.stimulus_slots.standard_stim;
            trials.is_deviant(i) = false;
        end
        
        % In a real scenario, you would add timing, TTLs, etc.
        trials.trial_number(i) = i;
    end
    
    fprintf('Built %d oddball trials.\n', height(trials));
end
