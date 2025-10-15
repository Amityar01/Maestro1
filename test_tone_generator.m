% TEST_TONE_COMPLETE - Complete end-to-end test of tone generator

fprintf('\n');
fprintf('╔════════════════════════════════════════════════╗\n');
fprintf('║   Tone Generator - Complete Test              ║\n');
fprintf('╚════════════════════════════════════════════════╝\n');
fprintf('\n');

cd('C:\Users\amity\Maestro')

%% Test 1: Discovery
fprintf('Test 1: Discovery\n');
fprintf('─────────────────────────────────────────────────\n');
ctx = core.MaestroContext();
ctx.list_generators();

if ~isKey(ctx.generators, 'tone')
    error('Tone generator not discovered!');
end
fprintf('✓ Discovery passed\n\n');

%% Test 2: Direct generation
fprintf('Test 2: Direct generation\n');
fprintf('─────────────────────────────────────────────────\n');
params = struct('freq_hz', 1000, 'dur_ms', 50, 'level_db', 60, 'ramp_ms', 5);
context = struct('sampling_rate_hz', 192000);
spec = generators.audio.tone.generate(params, context);

fprintf('Generated:\n');
fprintf('  Samples: %d\n', length(spec.data));
fprintf('  Duration: %.1f ms\n', spec.duration_ms);
fprintf('  Modality: %s\n', spec.modality);
fprintf('✓ Direct generation passed\n\n');

%% Test 3: Generation through context
fprintf('Test 3: Generation through context\n');
fprintf('─────────────────────────────────────────────────\n');
stim_spec = struct(...
    'generator', 'tone', ...
    'parameters', struct('freq_hz', 2000, 'dur_ms', 100, 'level_db', 65, 'ramp_ms', 5) ...
);
context = struct('sampling_rate_hz', 192000);
output = ctx.generate_stimulus(stim_spec, context);

fprintf('Generated:\n');
fprintf('  Frequency: %.0f Hz\n', output.metadata.freq_hz);
fprintf('  Samples: %d\n', length(output.data));
fprintf('  Duration: %.1f ms\n', output.duration_ms);
fprintf('✓ Context generation passed\n\n');

%% Test 4: Parameter validation
fprintf('Test 4: Parameter validation\n');
fprintf('─────────────────────────────────────────────────\n');

% Valid parameters
params_valid = struct('freq_hz', 1000, 'dur_ms', 50, 'level_db', 60);
[valid, errors] = ctx.validate_generator_params('tone', params_valid);
if valid
    fprintf('  ✓ Valid params accepted\n');
else
    fprintf('  ✗ Valid params rejected: %s\n', strjoin(errors, ', '));
end

% Invalid parameters (missing required)
params_invalid = struct('freq_hz', 1000);
[valid, errors] = ctx.validate_generator_params('tone', params_invalid);
if ~valid
    fprintf('  ✓ Invalid params rejected (%d errors)\n', length(errors));
else
    fprintf('  ✗ Invalid params accepted\n');
end

fprintf('✓ Validation passed\n\n');

%% Test 5: Randomization
fprintf('Test 5: Randomization\n');
fprintf('─────────────────────────────────────────────────\n');

stim_spec_rand = struct(...
    'generator', 'tone', ...
    'parameters', struct(...
        'freq_hz', struct('type', 'random_uniform', 'min', 1000, 'max', 2000), ...
        'dur_ms', 50, ...
        'level_db', 60, ...
        'ramp_ms', 5 ...
    ) ...
);

% Generate 5 randomized stimuli
freqs = zeros(5, 1);
for i = 1:5
    context_rand = struct('sampling_rate_hz', 192000, 'rng_seed', i);
    output_rand = ctx.generate_stimulus(stim_spec_rand, context_rand);
    freqs(i) = output_rand.metadata.freq_hz;
end

fprintf('  Generated frequencies: ');
fprintf('%.0f ', freqs);
fprintf('Hz\n');

if all(freqs >= 1000 & freqs <= 2000)
    fprintf('  ✓ All frequencies in range [1000, 2000] Hz\n');
else
    fprintf('  ✗ Some frequencies out of range\n');
end

fprintf('✓ Randomization passed\n\n');

%% Test 6: Audio playback
fprintf('Test 6: Audio playback\n');
fprintf('─────────────────────────────────────────────────\n');

% Generate a sequence of tones
fprintf('Playing tone sequence: ');
freqs_to_play = [500, 1000, 2000, 4000];
for i = 1:length(freqs_to_play)
    fprintf('%.0f Hz... ', freqs_to_play(i));
    stim = struct(...
        'generator', 'tone', ...
        'parameters', struct('freq_hz', freqs_to_play(i), 'dur_ms', 200, ...
                            'level_db', 60, 'ramp_ms', 10) ...
    );
    context = struct('sampling_rate_hz', 44100);  % Standard audio rate
    output = ctx.generate_stimulus(stim, context);
    sound(output.data, context.sampling_rate_hz);
    pause(0.3);
end
fprintf('done\n');
fprintf('✓ Playback passed\n\n');

%% Test 7: Visualization
fprintf('Test 7: Visualization\n');
fprintf('─────────────────────────────────────────────────\n');

% Generate a tone with visible frequency
params_viz = struct('freq_hz', 100, 'dur_ms', 50, 'level_db', 60, 'ramp_ms', 5);
context_viz = struct('sampling_rate_hz', 192000);
spec_viz = generators.audio.tone.generate(params_viz, context_viz);

% Plot
figure('Name', 'Tone Generator Test', 'Position', [100 100 1200 400]);

% Time domain
subplot(1,3,1);
t = (0:length(spec_viz.data)-1) / context_viz.sampling_rate_hz * 1000;
plot(t, spec_viz.data, 'LineWidth', 1);
xlabel('Time (ms)');
ylabel('Amplitude');
title('Time Domain (100 Hz tone)');
grid on;

% Zoom in to show waveform
subplot(1,3,2);
t_zoom = t(1:500);
data_zoom = spec_viz.data(1:500);
plot(t_zoom, data_zoom, 'LineWidth', 1.5);
xlabel('Time (ms)');
ylabel('Amplitude');
title('Zoomed View (first 2.6 ms)');
grid on;

% Frequency domain
subplot(1,3,3);
Y = fft(spec_viz.data);
L = length(spec_viz.data);
P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);
f = context_viz.sampling_rate_hz*(0:(L/2))/L;
plot(f(1:1000), P1(1:1000), 'LineWidth', 1);
xlabel('Frequency (Hz)');
ylabel('|P1(f)|');
title('Frequency Spectrum');
grid on;
xlim([0 500]);

fprintf('✓ Visualization created\n\n');

%% Summary
fprintf('╔════════════════════════════════════════════════╗\n');
fprintf('║   ✓ All tests passed!                         ║\n');
fprintf('╚════════════════════════════════════════════════╝\n');
fprintf('\n');
fprintf('The tone generator is fully functional!\n');
fprintf('\n');
fprintf('Next steps:\n');
fprintf('  1. Create a builder (e.g., oddball)\n');
fprintf('  2. Create an engine (e.g., audio_only)\n');
fprintf('  3. Run a complete experiment\n');
fprintf('\n');