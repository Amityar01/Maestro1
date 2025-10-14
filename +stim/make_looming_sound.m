% +stim/make_looming_sound.m
function s = make_looming_sound(dur_ms, fs, volts_start, volts_end, freq_min, freq_max, n_tones, ramp_ms, seed)
% MAKE_LOOMING_SOUND - Generate a "cloud of tones" with increasing amplitude
%
% Creates a sound by summing multiple sine waves at random frequencies
% and applying a linear amplitude envelope. Now includes an optional seed
% for creating "frozen" (repeatable) stimuli.

% --- Seed the random number generator for reproducibility if a seed is provided ---
if nargin >= 9 && ~isempty(seed)
    rng(seed);
end

% --- Generate the "cloud of tones" ---
n_samples = round(fs * dur_ms / 1000);
t = (0:n_samples-1)' / fs;
s = zeros(n_samples, 1);

% Generate n_tones random frequencies within the specified range
rand_freqs = freq_min + (freq_max - freq_min) * rand(n_tones, 1);

% Sum the sine waves
for i = 1:n_tones
    s = s + sin(2*pi*rand_freqs(i)*t);
end

% Normalize the amplitude of the summed waves to [-1, 1]
s = s / max(abs(s));

% --- Apply the looming amplitude envelope ---
amplitude_envelope = linspace(volts_start, volts_end, n_samples)';
s = s .* amplitude_envelope;

% --- Apply standard onset/offset ramps ---
s = stim.apply_ramps(s, fs, ramp_ms);

end