% +stim/apply_ramps.m
function y = apply_ramps(y, fs, ramp_ms)
% APPLY_RAMPS - Apply half-cosine onset/offset ramps
n = max(1, round(fs * ramp_ms / 1000));
if n <= numel(y)
    r = (1 - cos(linspace(0, pi, n)))' / 2;
    y(1:n) = y(1:n) .* r;
    y(end-n+1:end) = y(end-n+1:end) .* flipud(r);
end
y = y - mean(y);
end