% demo_generator_v1 - Demonstration of v1 generator framework
%
% Shows how to use the ToneSimpleGenerator to create audio stimuli

clear; clc;

fprintf('=== V1 Generator Framework Demo ===\n\n');

%% 1. Setup

fprintf('1. Setting up context...\n');

% Create sampling infrastructure
rng_manager = v1.sampling.RNGStreamManager(12345);
scope_manager = v1.sampling.ScopeManager();
sampler = v1.sampling.NumericFieldSampler(rng_manager, scope_manager);

% Create generator context
context = v1.generators.GeneratorContext(...
    'fs_hz', 192000, ...
    'sampler', sampler);
context.set_rng_manager(rng_manager);

fprintf('   ✓ Context created (fs=%d Hz)\n', context.fs_hz);

%% 2. Generate a Simple Tone

fprintf('\n2. Generating a simple 1000 Hz tone...\n');

generator = v1.generators.ToneSimpleGenerator();

params = struct();
params.frequency_hz = 1000;
params.duration_ms = 150;
params.level = struct('value', 0.7, 'unit', 'linear_0_1');
params.envelope = struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine');
params.routing = struct('channels', [0 1]);

[audio, metadata] = generator.generate(params, context);

fprintf('   Generated audio:\n');
fprintf('     Shape: %d samples × %d channels\n', size(audio, 1), size(audio, 2));
fprintf('     Duration: %.1f ms\n', metadata.duration_ms);
fprintf('     Peak: %.3f\n', metadata.peak);
fprintf('     RMS: %.3f\n', metadata.rms);
fprintf('     Hash: %s\n', metadata.hash);

%% 3. Generate with Jittered Frequency

fprintf('\n3. Generating tones with jittered frequency...\n');

params.frequency_hz = struct('dist', 'uniform', 'min', 900, 'max', 1100, 'scope', 'per_trial');

frequencies = zeros(5, 1);
for i = 1:5
    [~, meta] = generator.generate(params, context);
    frequencies(i) = meta.realized_params.frequency_hz;
    fprintf('   Trial %d: %.1f Hz\n', i, frequencies(i));
end

fprintf('   Frequency range: [%.1f, %.1f] Hz\n', min(frequencies), max(frequencies));

%% 4. Test Determinism

fprintf('\n4. Testing determinism (same seed → same output)...\n');

% Reset RNG
rng_manager = v1.sampling.RNGStreamManager(99999);
sampler = v1.sampling.NumericFieldSampler(rng_manager, v1.sampling.ScopeManager());
context1 = v1.generators.GeneratorContext('fs_hz', 192000, 'sampler', sampler);
context1.set_rng_manager(rng_manager);

params1 = struct();
params1.frequency_hz = 1000;
params1.duration_ms = 50;
params1.level = struct('value', 0.5, 'unit', 'linear_0_1');
params1.envelope = struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine');
params1.routing = struct('channels', [0]);
params1.seed = 12345;

[audio1, ~] = generator.generate(params1, context1);

% Generate again with same seed
rng_manager2 = v1.sampling.RNGStreamManager(99999);
sampler2 = v1.sampling.NumericFieldSampler(rng_manager2, v1.sampling.ScopeManager());
context2 = v1.generators.GeneratorContext('fs_hz', 192000, 'sampler', sampler2);
context2.set_rng_manager(rng_manager2);

[audio2, ~] = generator.generate(params1, context2);

if isequal(audio1, audio2)
    fprintf('   ✓ Perfect determinism verified!\n');
    fprintf('   First 5 samples: [%s]\n', sprintf('%.6f ', audio1(1:5)));
else
    fprintf('   ✗ Determinism failed\n');
end

%% 5. Generate Different Envelope Shapes

fprintf('\n5. Generating tones with different envelope shapes...\n');

shapes = {'linear', 'cosine', 'exponential'};
params_env = struct();
params_env.frequency_hz = 1000;
params_env.duration_ms = 100;
params_env.level = struct('value', 0.7, 'unit', 'linear_0_1');
params_env.routing = struct('channels', [0]);

for i = 1:length(shapes)
    params_env.envelope = struct('attack_ms', 10, 'release_ms', 10, 'shape', shapes{i});
    [audio_env, ~] = generator.generate(params_env, context);

    fprintf('   %s: first=%.4f, mid=%.4f, last=%.4f\n', ...
        shapes{i}, audio_env(1), audio_env(round(end/2)), audio_env(end));
end

%% 6. Generate at Different Levels

fprintf('\n6. Generating tones at different levels...\n');

levels = [0.3, 0.5, 0.7, 1.0];
params_level = struct();
params_level.frequency_hz = 1000;
params_level.duration_ms = 50;
params_level.envelope = struct('attack_ms', 0, 'release_ms', 0, 'shape', 'linear');
params_level.routing = struct('channels', [0]);

for i = 1:length(levels)
    params_level.level = struct('value', levels(i), 'unit', 'linear_0_1');
    [~, meta] = generator.generate(params_level, context);

    fprintf('   Level %.1f: peak=%.3f, rms=%.3f\n', ...
        levels(i), meta.peak, meta.rms);
end

%% 7. Frequency Sweep

fprintf('\n7. Generating frequency sweep (10 tones from 500 to 2000 Hz)...\n');

freqs = linspace(500, 2000, 10);
params_sweep = struct();
params_sweep.duration_ms = 50;
params_sweep.level = struct('value', 0.5, 'unit', 'linear_0_1');
params_sweep.envelope = struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine');
params_sweep.routing = struct('channels', [0]);

fprintf('   Frequencies: ');
for i = 1:length(freqs)
    params_sweep.frequency_hz = freqs(i);
    [~, ~] = generator.generate(params_sweep, context);
    fprintf('%.0f ', freqs(i));
end
fprintf('Hz\n');
fprintf('   ✓ All tones generated successfully\n');

%% Summary

fprintf('\n');
fprintf('═══════════════════════════════════════════════════════\n');
fprintf('Generator Framework Demo Complete\n');
fprintf('═══════════════════════════════════════════════════════\n');
fprintf('\nKey Features Demonstrated:\n');
fprintf('  ✓ Simple tone generation (frequency, duration, level)\n');
fprintf('  ✓ Jittered parameters (sampling from distributions)\n');
fprintf('  ✓ Perfect determinism (same seed → same output)\n');
fprintf('  ✓ Multiple envelope shapes (linear, cosine, exponential)\n');
fprintf('  ✓ Level control (linear scaling)\n');
fprintf('  ✓ Frequency sweeps\n');
fprintf('  ✓ Full metadata (peak, RMS, hash, realized params)\n');
fprintf('\nNext: Run unit tests with run_tests_v1(''TestGenerators'')\n\n');
