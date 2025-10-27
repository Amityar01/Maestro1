function waveform = make_tone(params, sample_rate)
    % make_tone - Generates a pure sinusoidal tone.
    
    % Default sample rate if not provided
    if nargin < 2
        sample_rate = 44100;
    end

    % Unpack parameters
    freq_hz = params.freq_hz;
    dur_ms = params.dur_ms;
    level_db = params.level_db;
    
    % Convert duration to samples
    duration_sec = dur_ms / 1000;
    n_samples = round(duration_sec * sample_rate);
    
    % Create time vector
    t = (0:n_samples-1) / sample_rate;
    
    % Generate sine wave
    amplitude = 10^((level_db - 100) / 20); % Simple conversion, not calibrated
    waveform = amplitude * sin(2 * pi * freq_hz * t);
    
    % In a real system, you would apply ramps here.
end
