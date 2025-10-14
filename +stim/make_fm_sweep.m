% +stim/make_fm_sweep.m
function s = make_fm_sweep(freq_start, freq_end, dur_ms, sweep_type, fs, volts, ramp_ms)
% MAKE_FM_SWEEP - Generate frequency-modulated sweep
%
% sweep_type: 'linear' or 'log'

n = round(fs * dur_ms / 1000);
t = (0:n-1)' / fs;

if strcmp(sweep_type, 'linear')
    % Linear frequency sweep
    f_t = freq_start + (freq_end - freq_start) * t / (dur_ms/1000);
    phase = 2*pi * cumsum(f_t) / fs;
    
elseif strcmp(sweep_type, 'log')
    % Logarithmic frequency sweep (smoother perceptually)
    k = (freq_end/freq_start)^(1/(dur_ms/1000));
    f_t = freq_start * k.^t;
    phase = 2*pi * cumsum(f_t) / fs;
    
else
    error('Unknown sweep_type: %s. Use "linear" or "log"', sweep_type);
end

s = volts * sin(phase);
s = stim.apply_ramps(s, fs, ramp_ms);
end