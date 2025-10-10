% +stim/make_pip_train.m
function s = make_pip_train(freq, n_pips, pip_dur_ms, gap_ms, fs, volts, ramp_ms)
% MAKE_PIP_TRAIN - Generate train of brief tone pips
pip = stim.make_tone(freq, pip_dur_ms, fs, volts, ramp_ms);
gap = zeros(round(fs * gap_ms / 1000), 1);
s = [];
for k = 1:n_pips
    s = [s; pip];
    if k < n_pips
        s = [s; gap];
    end
end
end