% +trials/add_timing.m
function trial_list = add_timing(trial_list, timing_params)
% ADD_TIMING - Add ITI and delay information to trials
for k = 1:numel(trial_list)
    % Delay (only if specified - used in foreperiod paradigm)
    if isfield(timing_params, 'delay_ms')
        trial_list(k).delay_ms = timing_params.delay_ms;
    end
    
    % ITI (jittered)
    iti_range = timing_params.iti_max_sec - timing_params.iti_min_sec;
    trial_list(k).iti_sec = timing_params.iti_min_sec + iti_range * rand();
end
end