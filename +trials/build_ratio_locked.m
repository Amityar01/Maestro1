% +trials/build_ratio_locked.m
function trial_list = build_ratio_locked(ratios, n_total, rng_seed)
% BUILD_RATIO_LOCKED - Generate trial list with fixed ratios
if nargin < 3, rng_seed = randi(99999); end
rng(rng_seed);

n_O1 = round(ratios.p_O1 * n_total);
n_O2 = round(ratios.p_O2 * n_total);
n_omit = n_total - n_O1 - n_O2;

outcomes = [repmat("O1", n_O1, 1); ...
            repmat("O2", n_O2, 1); ...
            repmat("OMIT", n_omit, 1)];

idx = randperm(numel(outcomes));
outcomes = outcomes(idx);

trial_list = struct();
for k = 1:n_total
    trial_list(k).trial_num = k;
    trial_list(k).outcome = outcomes(k);
    trial_list(k).is_omit = (outcomes(k) == "OMIT");
end
end