% test_audio_playback.m
% Quick script to test actual audio playback through DAQ hardware

%% 1. List available DAQ devices
fprintf('=== Available DAQ Devices ===\n');
try
    devices = daq.getDevices();
    if isempty(devices)
        fprintf('No DAQ devices found!\n');
        fprintf('Falling back to MATLAB audio output...\n\n');
        use_daq = false;
    else
        disp(devices);
        use_daq = true;
    end
catch
    fprintf('DAQ toolbox not available or error occurred.\n');
    fprintf('Falling back to MATLAB audio output...\n\n');
    use_daq = false;
end

%% 2. Create a simple test tone using v1 architecture
fprintf('\n=== Generating Test Tone ===\n');
fs_hz = 48000;

% Create RNG manager
rng_manager = v1.sampling.RNGStreamManager(42);

% Create stimulus library with a simple 1000 Hz tone
stimulus_library = struct();
stimulus_library.test_tone = struct(...
    'type', 'tone.simple', ...
    'frequency_hz', 1000, ...
    'duration_ms', 500, ...
    'amplitude', 0.3, ...
    'envelope', struct('type', 'cosine_ramp', 'ramp_ms', 10));

% Create a simple element table (single tone)
element_table = table();
element_table.trial_index = 1;
element_table.element_index = 1;
element_table.stimulus_ref = {'test_tone'};
element_table.absolute_onset_ms = 0;
element_table.duration_ms = 500;
element_table.label = {'test'};
element_table.ttl_code = uint8(1);

% Compile
compiler = v1.compilation.CompilerCore();
context = struct('rng_manager', rng_manager, 'iteration', 1);
seq_file = compiler.compile(element_table, stimulus_library, fs_hz, context);

fprintf('Generated %.2f seconds of audio\n', size(seq_file.audio, 1) / fs_hz);
fprintf('Audio peak level: %.3f\n', max(abs(seq_file.audio(:))));

%% 3. Play through DAQ or MATLAB audio
if use_daq
    fprintf('\n=== Attempting DAQ Playback ===\n');

    % Configure DAQ engine for hardware
    engine = v1.daq.DAQEngine();

    % Configure for hardware playback
    % You'll need to customize this based on your DAQ device
    config = struct();
    config.mode = 'hardware';
    config.vendor = 'ni';  % National Instruments
    config.device_id = devices(1).ID;  % Use first device
    config.fs_hz = fs_hz;
    config.audio_channels = [0, 1];  % Analog output channels ao0 and ao1
    config.ttl_channel = [];  % No TTL for now

    try
        engine.configure(config);
        fprintf('DAQ configured successfully!\n');

        % Load the sequence file
        engine.load_sequence(seq_file);
        fprintf('Sequence loaded!\n');

        % Play the audio
        fprintf('Playing through DAQ...\n');
        result = engine.play();
        fprintf('Playback complete!\n');
    catch ME
        fprintf('DAQ playback failed: %s\n', ME.message);
        fprintf('Error details: %s\n', ME.identifier);
        fprintf('Trying MATLAB audio instead...\n');
        use_daq = false;
    end
end

if ~use_daq
    fprintf('\n=== Playing through MATLAB Audio ===\n');
    fprintf('Playing 1000 Hz test tone...\n');

    % Use MATLAB's sound function
    sound(seq_file.audio(:, 1), fs_hz);

    fprintf('Did you hear a beep?\n');
end

fprintf('\n=== Test Complete ===\n');
fprintf('If you heard sound, your system is working!\n');
fprintf('If not, check:\n');
fprintf('  1. Volume is turned up\n');
fprintf('  2. Correct output device is selected\n');
fprintf('  3. DAQ device is properly connected (if using DAQ)\n');
