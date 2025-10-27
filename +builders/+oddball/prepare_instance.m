function inst = prepare_instance(inst, context)
% Optional builder-side hydration/derivation for oddball.
% Fills n_trials if missing using common clues; sanity-checks probabilities.

P = inst.parameters;

% Infer n_trials if absent (keep RunnerCore generic)
if ~isfield(P,'n_trials') || isempty(P.n_trials)
    % try metadata.is_deviant
    if isfield(inst,'metadata') && isfield(inst.metadata,'is_deviant') ...
            && (islogical(inst.metadata.is_deviant) || isnumeric(inst.metadata.is_deviant))
        P.n_trials = numel(inst.metadata.is_deviant);
    elseif isfield(P,'iti_sec') && ~isempty(P.iti_sec) ...
            && (isnumeric(P.iti_sec) || islogical(P.iti_sec))
        P.n_trials = numel(P.iti_sec);
    else
        error('oddball:prepare_instance','Missing n_trials and unable to infer from metadata/iti_sec.');
    end
end

% Normalize deviant_probability 0..1
if isfield(P,'deviant_probability') && ~isempty(P.deviant_probability)
    v = double(P.deviant_probability);
    if v > 1, v = v/100; end
    assert(v >= 0 && v <= 1, 'oddball:prepare_instance','deviant_probability must be in [0,1]');
    P.deviant_probability = v;
end

inst.parameters = P;
