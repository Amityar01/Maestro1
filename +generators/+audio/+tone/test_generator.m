function test_generator()
% TEST_GENERATOR - Test tone generator
%
% Run this to verify the tone generator works correctly

    fprintf('Testing tone generator...\n');
    fprintf('════════════════════════════════════════════════\n\n');
    
    test_basic_generation();
    test_correct_frequency();
    test_correct_duration();
    test_ramp_application();
    test_output_format();
    test_parameter_validation();
    
    fprintf('\n✓ All tone generator tests passed!\n\n');
end

function test_basic_generation()
    fprintf('1. Testing basic generation...\n');
    
    params = struct(...
        'freq_hz', 1000, ...
        'dur_ms', 50, ...
        'level_db', 60, ...
        'ramp_ms', 5 ...
    );
    
    context = struct('sampling_rate_hz', 192000);
    
    % Call generator
    spec = generators.audio.tone.generate(params, context);
    
    % Verify output structure
    assert(isfield(spec, 'modality'), 'Missing modality field');
    assert(strcmp(spec.modality, 'audio'), 'Wrong modality');
    assert(isfield(spec, 'render_type'), 'Missing render_type');
    assert(strcmp(spec.render_type, 'waveform'), 'Wrong render_type');
    assert(isfield(spec, 'data'), 'Missing data');
    assert(isfield(spec, 'duration_ms'), 'Missing duration_ms');
    assert(isfield(spec, 'metadata'), 'Missing metadata');
    
    fprintf('   ✓ Basic generation works\n');
end

function test_correct_frequency()
    fprintf('2. Testing frequency accuracy...\n');
    
    freq_hz = 1000;
    params = struct(...
        'freq_hz', freq_hz, ...
        'dur_ms', 100, ...
        'level_db', 60, ...
        'ramp_ms', 0 ...  % No ramps for cleaner FFT
    );
    
    context = struct('sampling_rate_hz', 192000);
    spec = generators.audio.tone.generate(params, context);
    
    % Check frequency using FFT
    Y = fft(spec.data);
    fs = context.sampling_rate_hz;
    N = length(spec.data);
    f = (0:N-1) * (fs/N);
    
    % Find peak frequency (only positive frequencies)
    [~, idx] = max(abs(Y(1:floor(N/2))));
    measured_freq = f(idx);
    
    % Should be within 1 Hz
    assert(abs(measured_freq - freq_hz) < 1, ...
        sprintf('Frequency error too large: %.1f Hz', abs(measured_freq - freq_hz)));
    
    fprintf('   ✓ Frequency accurate (%.1f Hz)\n', measured_freq);
end

function test_correct_duration()
    fprintf('3. Testing duration accuracy...\n');
    
    dur_ms = 50;
    params = struct(...
        'freq_hz', 1000, ...
        'dur_ms', dur_ms, ...
        'level_db', 60, ...
        'ramp_ms', 5 ...
    );
    
    context = struct('sampling_rate_hz', 192000);
    spec = generators.audio.tone.generate(params, context);
    
    % Check number of samples
    expected_samples = round(192000 * dur_ms / 1000);
    actual_samples = length(spec.data);
    
    assert(actual_samples == expected_samples, ...
        sprintf('Duration mismatch: expected %d samples, got %d', ...
        expected_samples, actual_samples));
    
    fprintf('   ✓ Duration accurate (%d samples)\n', actual_samples);
end

function test_ramp_application()
    fprintf('4. Testing ramp application...\n');
    
    params = struct(...
        'freq_hz', 1000, ...
        'dur_ms', 100, ...
        'level_db', 60, ...
        'ramp_ms', 10 ...
    );
    
    context = struct('sampling_rate_hz', 192000);
    spec = generators.audio.tone.generate(params, context);
    
    % First and last samples should be near zero due to ramps
    assert(abs(spec.data(1)) < 0.01, 'Ramp not applied at onset');
    assert(abs(spec.data(end)) < 0.01, 'Ramp not applied at offset');
    
    % Middle should have full amplitude
    mid_idx = round(length(spec.data) / 2);
    assert(abs(spec.data(mid_idx)) > 0.1, 'Signal too weak in middle');
    
    fprintf('   ✓ Ramps applied correctly\n');
end

function test_output_format()
    fprintf('5. Testing output format compliance...\n');
    
    params = struct(...
        'freq_hz', 1000, ...
        'dur_ms', 50, ...
        'level_db', 60, ...
        'ramp_ms', 5 ...
    );
    
    context = struct('sampling_rate_hz', 192000);
    spec = generators.audio.tone.generate(params, context);
    
    % Check all required fields
    required = {'modality', 'render_type', 'data', 'duration_ms', 'metadata'};
    for i = 1:length(required)
        assert(isfield(spec, required{i}), ...
            sprintf('Missing required field: %s', required{i}));
    end
    
    % Data must be column vector
    assert(iscolumn(spec.data), 'Data must be column vector');
    
    % Metadata must be struct
    assert(isstruct(spec.metadata), 'Metadata must be struct');
    
    fprintf('   ✓ Output format compliant\n');
end

function test_parameter_validation()
    fprintf('6. Testing parameter validation...\n');
    
    % This is handled by the core system, but we can test
    % that our generator handles edge cases
    
    % Very short duration
    params = struct('freq_hz', 1000, 'dur_ms', 1, 'level_db', 60, 'ramp_ms', 0);
    context = struct('sampling_rate_hz', 192000);
    try
        spec = generators.audio.tone.generate(params, context);
        assert(~isempty(spec.data), 'Failed to generate very short tone');
    catch ME
        error('Generator should handle very short durations: %s', ME.message);
    end
    
    % Very high frequency (but valid)
    params = struct('freq_hz', 15000, 'dur_ms', 50, 'level_db', 60, 'ramp_ms', 5);
    try
        spec = generators.audio.tone.generate(params, context);
        assert(~isempty(spec.data), 'Failed to generate high frequency tone');
    catch ME
        error('Generator should handle high frequencies: %s', ME.message);
    end
    
    fprintf('   ✓ Edge cases handled\n');
end