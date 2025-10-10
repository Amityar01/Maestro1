% +stim/make_noise.m
function s = make_noise(dur_ms, fs, volts, ramp_ms, seed)
% MAKE_NOISE - Generate frozen white noise token
if nargin < 5, seed = []; end
if ~isempty(seed), rng(seed); end
n = round(fs * dur_ms / 1000);
x = randn(n, 1);
x = x / std(x); % Normalize
s = volts * x;
s = stim.apply_ramps(s, fs, ramp_ms);
end