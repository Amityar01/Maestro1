% +stim/make_tone.m
function s = make_tone(freq, dur_ms, fs, volts, ramp_ms)
% MAKE_TONE - Generate pure tone with half-cosine ramps
n = round(fs * dur_ms / 1000);
t = (0:n-1)' / fs;
s = volts * sin(2*pi*freq*t);
s = stim.apply_ramps(s, fs, ramp_ms);
end