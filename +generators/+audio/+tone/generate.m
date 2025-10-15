function output_spec = generate(params, context)
% GENERATE - Generate pure tone stimulus
%
% This function generates a pure sinusoidal tone with specified frequency,
% duration, and level, with optional onset/offset ramps.
%
% INPUTS:
%   params - struct with fields:
%            .freq_hz  - frequency in Hz
%            .dur_ms   - duration in milliseconds
%            .level_db - sound level in dB SPL
%            .ramp_ms  - ramp duration in milliseconds (optional)
%
%   context - struct with fields:
%             .sampling_rate_hz - DAQ sampling rate
%             .calibration      - calibration info (optional)
%
% OUTPUTS:
%   output_spec - struct with standardized format:
%                 .modality      - 'audio'
%                 .render_type   - 'waveform'
%                 .data          - [N x 1] audio samples
%                 .duration_ms   - actual duration
%                 .metadata      - copy of parameters

    % Extract parameters
    freq_hz = params.freq_hz;
    dur_ms = params.dur_ms;
    level_db = params.level_db;
    
    % Handle optional ramp parameter
    if isfield(params, 'ramp_ms')
        ramp_ms = params.ramp_ms;
    else
        ramp_ms = 5;  % Default
    end
    
    % Get sampling rate from context
    if ~isfield(context, 'sampling_rate_hz')
        error('generators:audio:tone:MissingContext', ...
            'Context must contain sampling_rate_hz field');
    end
    fs = context.sampling_rate_hz;
    
    % Generate time vector
    n_samples = round(fs * dur_ms / 1000);
    t = (0:n_samples-1)' / fs;  % Column vector
    
    % Generate sinusoid
    waveform = sin(2 * pi * freq_hz * t);
    
    % Apply amplitude scaling (convert dB to linear)
    amplitude = db_to_amplitude(level_db, context);
    waveform = amplitude * waveform;
    
    % Apply onset/offset ramps
    if ramp_ms > 0
        waveform = apply_cosine_ramps(waveform, fs, ramp_ms);
    end
    
    % Create output specification
    output_spec = struct();
    output_spec.modality = 'audio';
    output_spec.render_type = 'waveform';
    output_spec.data = waveform;
    output_spec.duration_ms = dur_ms;
    output_spec.metadata = params;
end

function amplitude = db_to_amplitude(db_spl, context)
    % Convert dB SPL to linear amplitude
    % Uses calibration from context if available
    
    if isfield(context, 'calibration') && ...
       isfield(context.calibration, 'reference_db') && ...
       isfield(context.calibration, 'reference_amplitude')
        ref_db = context.calibration.reference_db;
        ref_amp = context.calibration.reference_amplitude;
    else
        % Default: 100 dB SPL = amplitude 1.0
        ref_db = 100;
        ref_amp = 1.0;
    end
    
    amplitude = ref_amp * 10^((db_spl - ref_db) / 20);
end

function y = apply_cosine_ramps(y, fs, ramp_ms)
    % Apply half-cosine onset and offset ramps
    
    if ramp_ms <= 0
        return;
    end
    
    n_ramp = round(fs * ramp_ms / 1000);
    
    % Check if ramp is too long
    if n_ramp >= length(y) / 2
        warning('generators:audio:tone:RampTooLong', ...
            'Ramp duration (%.1f ms) too long for signal duration, skipping ramps', ...
            ramp_ms);
        return;
    end
    
    % Create ramp window (half cosine)
    ramp = (1 - cos(linspace(0, pi, n_ramp)))' / 2;
    
    % Apply to onset
    y(1:n_ramp) = y(1:n_ramp) .* ramp;
    
    % Apply to offset
    y(end-n_ramp+1:end) = y(end-n_ramp+1:end) .* flipud(ramp);
end