function trial_list = build(instance, context)
% +builders/+oddball/build.m
% Strict oddball builder, universal timeline output, no hidden defaults.
%
% Required instance.parameters fields:
%   n_trials                  integer >= 1
%   standard_stimulus         struct with fields: generator, version, parameters
%   deviant_stimulus          struct with fields: generator, version, parameters
%   deviant_probability       scalar in [0,1]
%   order_constraint          'none' or 'no_consecutive_deviants'
%   iti_sec                   scalar (fixed ITI) or 1x2 [min max] for uniform jitter
%
% Optional:
%   playback                  struct, if provided will be attached at trial_list(1).engine.playback

% --------------------------
% 1) Read and validate input
% --------------------------
P   = must_field(instance, 'parameters', 'instance');
N   = must_num(  P, 'n_trials', 1, inf, true);
STD = must_stim( P, 'standard_stimulus');
DEV = must_stim( P, 'deviant_stimulus');
pD  = must_num(  P, 'deviant_probability', 0, 1, false);

order_constraint = must_field(P, 'order_constraint', 'parameters');
order_constraint = lower(string(order_constraint));
valid_constraints = ["none","no_consecutive_deviants"];
assert(any(order_constraint == valid_constraints), ...
    'oddball:order_constraint', 'order_constraint must be one of: %s', strjoin(valid_constraints, ', '));

[iti_min, iti_max, use_jitter] = parse_iti_spec(resolve_iti(P));

% ---------------------------------------
% 2) Decide deviant positions for N trials
% ---------------------------------------
switch char(order_constraint)
    case 'no_consecutive_deviants'
        K = round(N * pD);
        assert(K <= ceil(N/2), ...
            'oddball:constraint', 'no_consecutive_deviants impossible with N=%d, p=%g', N, pD);
        is_dev = place_nonconsecutive(N, K);
    case 'none'
        % Exact K to match requested ratio, without adjacency constraint
        K = round(N * pD);
        is_dev = exact_k_mask(N, K);
end

% ------------------------------------
% 3) Build trial_list with presentations
% ------------------------------------
trial_list = repmat(struct( ...
    'presentations', [], ...
    'iti_sec', 0, ...
    'metadata', struct() ...
    ), 1, N);

for k = 1:N
    if is_dev(k), stim_spec = DEV; meta_kind = "deviant";
    else,         stim_spec = STD; meta_kind = "standard";
    end

    pres = struct();
    pres.onset_ms      = 0;           % engine schedules at trial start
    pres.stimulus_spec = stim_spec;   % generator, version, parameters
    pres.engine        = struct();    % optional per-presentation overrides

    trial_list(k).presentations = pres;

    if use_jitter
        trial_list(k).iti_sec = iti_min + (iti_max - iti_min) * rand();
    else
        trial_list(k).iti_sec = iti_min;
    end

    trial_list(k).metadata = struct( ...
        'trial_index', k, ...
        'kind', meta_kind, ...           % 'standard' or 'deviant'
        'is_deviant', logical(is_dev(k)) ...
        );
end

% --------------------------------------------------------
% 4) Pass through builder-provided playback defaults (optional)
% --------------------------------------------------------
if isfield(P, 'playback') && ~isempty(P.playback) && isstruct(P.playback)
    trial_list(1).engine.playback = P.playback;
end

% ----------
% 5) Summary
% ----------
deviant_ratio = 100 * mean(is_dev);
fprintf('Built oddball block: %d trials (%.1f%% deviants)\n', N, deviant_ratio);

end

% ======================
% ===== Helpers ========
% ======================

function v = must_field(s, f, where)
assert(isstruct(s) && isfield(s, f) && ~isempty(s.(f)), ...
    'oddball:missingField', 'Missing field "%s" in %s', f, where);
v = s.(f);
end

function x = resolve_iti(P)
% Accept either:
%   - iti_sec (scalar or [min max]), or
%   - legacy pair iti_min_sec + iti_max_sec
if isfield(P, 'iti_sec') && ~isempty(P.iti_sec)
    x = P.iti_sec;
elseif isfield(P, 'iti_min_sec') && isfield(P, 'iti_max_sec') ...
        && ~isempty(P.iti_min_sec) && ~isempty(P.iti_max_sec)
    x = [P.iti_min_sec, P.iti_max_sec];
else
    error('oddball:missingField', 'Missing ITI: provide "iti_sec" or "iti_min_sec"+"iti_max_sec".');
end
end

function x = must_num(s, f, lo, hi, integer_required)
x = must_field(s, f, 'parameters');
validateattributes(x, {'numeric'}, {'nonempty','real'}, mfilename, f);
assert(isscalar(x) || (isvector(x) && numel(x)==2), ...
    'oddball:%s', sprintf('%s must be scalar or 1x2 numeric', f));
if isscalar(x)
    assert(x >= lo && x <= hi, 'oddball:%s', sprintf('%s out of range', f));
    if integer_required
        assert(x == floor(x), 'oddball:%s', sprintf('%s must be integer', f));
    end
else
    assert(all(x >= lo) && all(x <= hi), 'oddball:%s', sprintf('%s elements out of range', f));
end
end

function S = must_stim(P, name)
S = must_field(P, name, 'parameters');
must_field(S, 'generator', name);
must_field(S, 'version',   name);
must_field(S, 'parameters',name);
end

function [a, b, jitter] = parse_iti_spec(iti_spec)
% Accept scalar ITI or 1x2 [min max]
assert(isnumeric(iti_spec) && (isscalar(iti_spec) || numel(iti_spec)==2), ...
    'oddball:iti', 'iti_sec must be scalar or 1x2 [min max]');
if isscalar(iti_spec)
    a = double(iti_spec); b = a; jitter = false;
else
    a = double(min(iti_spec)); b = double(max(iti_spec)); jitter = true;
end
assert(a >= 0 && b >= a, 'oddball:iti', 'Invalid iti_sec');
end

function mask = exact_k_mask(N, K)
mask = false(1, N);
if K <= 0, return; end
idx = randperm(N, K);
mask(idx) = true;
end

function is_dev = place_nonconsecutive(N, K)
% Randomized placement with no adjacent deviants, exact K
if K == 0
    is_dev = false(1, N); return
end
avail = true(1, N);
is_dev = false(1, N);
for i = 1:K
    idx = find(avail);
    assert(~isempty(idx), 'oddball:placement', ...
        'Could not satisfy no_consecutive_deviants with N=%d, K=%d', N, K);
    pos = idx(randi(numel(idx)));
    is_dev(pos) = true;
    avail(pos) = false;
    if pos > 1, avail(pos-1) = false; end
    if pos < N, avail(pos+1) = false; end
end
end
