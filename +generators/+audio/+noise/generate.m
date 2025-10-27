function output_spec = generate(params, context)
    % GENERATE - Generate white noise stimulus

    fs = context.sampling_rate_hz;

    % 1. Get parameters
    dur_ms = params.dur_ms;
    level_db = params.level_db;
    ramp_ms = params.ramp_ms;
    % cutoff_hz = params.cutoff_hz; % You would use this to filter

    % 2. Generate time vector
    n_samples = round(fs * dur_ms / 1000);

    % 3. Generate waveform (simple white noise)
    waveform = (rand(n_samples, 1) * 2) - 1;

    % (You would add your filtering logic here using cutoff_hz)

    % 4. Apply amplitude and ramps (pseudo-code, copy from tone)
    % amplitude = db_to_amplitude(level_db, context);
    % waveform = amplitude * waveform;
    % waveform = apply_cosine_ramps(waveform, fs, ramp_ms);

    % 5. Create output
    output_spec = struct();
    output_spec.modality = 'audio';
    output_spec.render_type = 'waveform';
    output_spec.data = waveform; % Your generated data
    output_spec.duration_ms = dur_ms;
    output_spec.metadata = params;
end