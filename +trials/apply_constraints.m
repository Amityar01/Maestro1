% +trials/apply_constraints.m
function trial_list = apply_constraints(trial_list, constraints)
% APPLY_CONSTRAINTS - Apply history-dependent rules
outcomes = string({trial_list.outcome});
max_attempts = 1000;
for attempt = 1:max_attempts
    valid = true;
    if isfield(constraints, 'max_omit_run')
        if get_max_run_length(outcomes == "OMIT") > constraints.max_omit_run
            valid = false;
        end
    end
    
    if valid, break; end
    
    idx = randperm(numel(outcomes));
    outcomes = outcomes(idx);
end

if ~valid
    warning('Could not satisfy all constraints after %d attempts.', max_attempts);
end

% Re-apply the shuffled order to the final list
for k = 1:numel(trial_list)
    trial_list(k).outcome = outcomes(k);
    trial_list(k).is_omit = (outcomes(k) == "OMIT");
end
end

function max_run = get_max_run_length(vec)
runs = diff([0; vec(:); 0]);
run_starts = find(runs == 1);
run_ends = find(runs == -1);
run_lengths = run_ends - run_starts;
if isempty(run_lengths), max_run = 0; else, max_run = max(run_lengths); end
end