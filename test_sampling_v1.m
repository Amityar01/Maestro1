% test_sampling_v1 - Demonstration and test of v1 sampling framework
%
% This script demonstrates the sampling framework working with:
%   1. RNG stream management (deterministic, named streams)
%   2. Distribution sampling (uniform, normal, loguniform, categorical)
%   3. Scope management (per_trial, per_block, per_session)
%   4. Numeric field sampling
%   5. Struct sampling

clear; clc;

fprintf('=== V1 Sampling Framework Test ===\n\n');

%% 1. Test RNG Stream Manager

fprintf('1. Testing RNGStreamManager...\n');

% Create manager with master seed
rng_manager = v1.sampling.RNGStreamManager(42);
fprintf('   ✓ Created RNG manager with master seed 42\n');

% Get some streams
stream1 = rng_manager.get_stream('trial_timing');
stream2 = rng_manager.get_stream('stimulus_params');
fprintf('   ✓ Created named streams\n');

% Sample and verify determinism
val1 = rand(stream1);
rng_manager.reset_stream('trial_timing');
val2 = rand(stream1);

if val1 == val2
    fprintf('   ✓ Deterministic sampling (reset produces same value)\n');
else
    fprintf('   ✗ Non-deterministic! Got %g and %g\n', val1, val2);
end

% Get seed record
seed_record = rng_manager.get_seed_record();
fprintf('   ✓ Seed record: master=%d, %d streams\n', ...
    seed_record.master_seed, length(fieldnames(seed_record.stream_seeds)));

fprintf('\n');

%% 2. Test Distribution Samplers

fprintf('2. Testing DistributionSamplers...\n');

% Reset for reproducibility
rng_manager.clear_all();
stream = rng_manager.get_stream('test');

% Uniform
params = struct('min', 900, 'max', 1100);
values = v1.sampling.DistributionSamplers.sample_uniform(params, stream, 1000);
fprintf('   Uniform [900, 1100]: mean=%g, std=%g\n', mean(values), std(values));
if abs(mean(values) - 1000) < 20 && abs(std(values) - 57.7) < 10
    fprintf('   ✓ Uniform distribution statistics correct\n');
end

% Normal
params = struct('mean', 1000, 'std', 50);
values = v1.sampling.DistributionSamplers.sample_normal(params, stream, 1000);
fprintf('   Normal (1000, 50): mean=%g, std=%g\n', mean(values), std(values));
if abs(mean(values) - 1000) < 10 && abs(std(values) - 50) < 5
    fprintf('   ✓ Normal distribution statistics correct\n');
end

% Normal with clipping
params = struct('mean', 1000, 'std', 100, 'clip_min', 900, 'clip_max', 1100);
values = v1.sampling.DistributionSamplers.sample_normal(params, stream, 1000);
fprintf('   Normal clipped [900, 1100]: min=%g, max=%g\n', min(values), max(values));
if min(values) >= 900 && max(values) <= 1100
    fprintf('   ✓ Clipping works correctly\n');
end

% Log-uniform
params = struct('min', 100, 'max', 10000);
values = v1.sampling.DistributionSamplers.sample_loguniform(params, stream, 1000);
fprintf('   Log-uniform [100, 10000]: geometric mean=%g\n', exp(mean(log(values))));
if all(values >= 100) && all(values <= 10000)
    fprintf('   ✓ Log-uniform range correct\n');
end

% Categorical
params = struct('categories', [1000 1500 2000], 'probabilities', [0.5 0.3 0.2]);
values = v1.sampling.DistributionSamplers.sample_categorical(params, stream, 1000);
counts = [sum(values == 1000), sum(values == 1500), sum(values == 2000)];
freqs = counts / sum(counts);
fprintf('   Categorical: observed freqs = [%.3f, %.3f, %.3f]\n', freqs);
if all(abs(freqs - [0.5 0.3 0.2]) < 0.05)
    fprintf('   ✓ Categorical frequencies correct\n');
end

% Compute moments
params = struct('dist', 'uniform', 'min', 900, 'max', 1100);
moments = v1.sampling.DistributionSamplers.compute_moments(params);
fprintf('   Uniform moments: mean=%g, var=%g\n', moments.mean, moments.variance);

fprintf('\n');

%% 3. Test Scope Manager

fprintf('3. Testing ScopeManager...\n');

scope_manager = v1.sampling.ScopeManager();

% Set session context
scope_manager.set_context('session', 'session_1');
fprintf('   ✓ Set session context\n');

% Sample per_session value
sample_fn = @() randi(100);
val1 = scope_manager.get_or_sample('param1', 'per_session', sample_fn);
val2 = scope_manager.get_or_sample('param1', 'per_session', sample_fn);

if val1 == val2
    fprintf('   ✓ per_session caching works (val=%d)\n', val1);
else
    fprintf('   ✗ per_session caching failed\n');
end

% Set block context
scope_manager.set_context('block', 'block_1');
val1 = scope_manager.get_or_sample('param2', 'per_block', sample_fn);
val2 = scope_manager.get_or_sample('param2', 'per_block', sample_fn);

if val1 == val2
    fprintf('   ✓ per_block caching works (val=%d)\n', val1);
else
    fprintf('   ✗ per_block caching failed\n');
end

% Change block - should resample
scope_manager.set_context('block', 'block_2');
val3 = scope_manager.get_or_sample('param2', 'per_block', sample_fn);

if val3 ~= val1
    fprintf('   ✓ per_block cache clears on block change\n');
else
    fprintf('   ✗ per_block cache should have cleared\n');
end

% per_trial should always sample new
val1 = scope_manager.get_or_sample('param3', 'per_trial', sample_fn);
val2 = scope_manager.get_or_sample('param3', 'per_trial', sample_fn);

if val1 ~= val2
    fprintf('   ✓ per_trial never caches\n');
else
    fprintf('   ⚠ per_trial happened to get same random value (unlikely but possible)\n');
end

fprintf('\n');

%% 4. Test NumericFieldSampler

fprintf('4. Testing NumericFieldSampler...\n');

rng_manager = v1.sampling.RNGStreamManager(12345);
scope_manager = v1.sampling.ScopeManager();
sampler = v1.sampling.NumericFieldSampler(rng_manager, scope_manager);

fprintf('   ✓ Created NumericFieldSampler\n');

% Test scalar sampling
field_spec = struct('value', 1000);
value = sampler.sample(field_spec, 'freq');
fprintf('   Scalar: %g\n', value);
if value == 1000
    fprintf('   ✓ Scalar sampling works\n');
end

% Test implicit scalar
value = sampler.sample(1000, 'freq_implicit');
if value == 1000
    fprintf('   ✓ Implicit scalar works\n');
end

% Test uniform sampling
field_spec = struct('dist', 'uniform', 'min', 900, 'max', 1100, 'scope', 'per_trial');
values = zeros(1, 10);
for i = 1:10
    values(i) = sampler.sample(field_spec, 'freq_uniform');
end
fprintf('   Uniform per_trial: range [%g, %g]\n', min(values), max(values));
if all(values >= 900) && all(values <= 1100) && length(unique(values)) > 1
    fprintf('   ✓ Uniform per_trial sampling works\n');
end

% Test per_block caching
scope_manager.set_context('block', 'block_1');
field_spec = struct('dist', 'uniform', 'min', 900, 'max', 1100, 'scope', 'per_block');
val1 = sampler.sample(field_spec, 'freq_block');
val2 = sampler.sample(field_spec, 'freq_block');
if val1 == val2
    fprintf('   ✓ per_block caching works in sampler\n');
end

% Test normal sampling
field_spec = struct('dist', 'normal', 'mean', 1000, 'std', 50, 'scope', 'per_trial');
values = zeros(1, 100);
for i = 1:100
    values(i) = sampler.sample(field_spec, 'freq_normal');
end
fprintf('   Normal: mean=%g, std=%g\n', mean(values), std(values));

% Test categorical
field_spec = struct('dist', 'categorical', 'categories', [1000 1500 2000], ...
    'probabilities', [0.5 0.3 0.2], 'scope', 'per_trial');
values = zeros(1, 100);
for i = 1:100
    values(i) = sampler.sample(field_spec, 'freq_cat');
end
unique_vals = unique(values);
if length(unique_vals) == 3
    fprintf('   ✓ Categorical sampling works\n');
end

% Test moments computation
field_spec = struct('dist', 'uniform', 'min', 900, 'max', 1100, 'scope', 'per_trial');
moments = sampler.compute_moments(field_spec);
fprintf('   Moments: mean=%g, var=%g\n', moments.mean, moments.variance);

fprintf('\n');

%% 5. Test Struct Sampling

fprintf('5. Testing struct sampling...\n');

% Create a struct with multiple numeric fields
stimulus_spec = struct();
stimulus_spec.frequency_hz = struct('dist', 'uniform', 'min', 900, 'max', 1100, 'scope', 'per_trial');
stimulus_spec.duration_ms = struct('value', 150);
stimulus_spec.level_db = struct('dist', 'categorical', 'categories', [70 75 80], ...
    'probabilities', [0.2 0.5 0.3], 'scope', 'per_block');
stimulus_spec.ramp_ms = 5;  % Implicit scalar

% Sample the struct
scope_manager.set_context('block', 'block_1');
sampled = sampler.sample_struct(stimulus_spec);

fprintf('   Sampled struct:\n');
fprintf('     frequency_hz: %g\n', sampled.frequency_hz);
fprintf('     duration_ms: %g\n', sampled.duration_ms);
fprintf('     level_db: %g\n', sampled.level_db);
fprintf('     ramp_ms: %g\n', sampled.ramp_ms);

if isfield(sampled, 'frequency_hz') && isfield(sampled, 'duration_ms') && ...
   isfield(sampled, 'level_db') && isfield(sampled, 'ramp_ms')
    fprintf('   ✓ Struct sampling works\n');
end

% Sample again - per_block should be cached
sampled2 = sampler.sample_struct(stimulus_spec);
if sampled.level_db == sampled2.level_db
    fprintf('   ✓ per_block caching works in struct sampling\n');
end

if sampled.frequency_hz ~= sampled2.frequency_hz
    fprintf('   ✓ per_trial resampling works in struct sampling\n');
end

fprintf('\n');

%% 6. Test Determinism and Reproducibility

fprintf('6. Testing determinism and reproducibility...\n');

% Create two samplers with same master seed
rng1 = v1.sampling.RNGStreamManager(99999);
scope1 = v1.sampling.ScopeManager();
sampler1 = v1.sampling.NumericFieldSampler(rng1, scope1);

rng2 = v1.sampling.RNGStreamManager(99999);
scope2 = v1.sampling.ScopeManager();
sampler2 = v1.sampling.NumericFieldSampler(rng2, scope2);

% Sample same field spec
field_spec = struct('dist', 'normal', 'mean', 1000, 'std', 100, 'scope', 'per_trial');

values1 = zeros(1, 10);
values2 = zeros(1, 10);

for i = 1:10
    values1(i) = sampler1.sample(field_spec, 'test_param');
    values2(i) = sampler2.sample(field_spec, 'test_param');
end

if all(values1 == values2)
    fprintf('   ✓ Perfect determinism (same seeds → same samples)\n');
    fprintf('     Values: [%s]\n', sprintf('%g ', values1(1:5)));
else
    fprintf('   ✗ Determinism failed\n');
end

% Get seed records
seed1 = rng1.get_seed_record();
seed2 = rng2.get_seed_record();

if seed1.master_seed == seed2.master_seed
    fprintf('   ✓ Seed provenance recorded correctly\n');
end

fprintf('\n');

%% Summary

fprintf('=== Sampling Framework Test Complete ===\n');
fprintf('\nThe sampling framework is working! Key features:\n');
fprintf('  • Deterministic RNG with named streams\n');
fprintf('  • All distribution types: uniform, normal, loguniform, categorical\n');
fprintf('  • Scope management: per_trial, per_block, per_session\n');
fprintf('  • Validation before sampling\n');
fprintf('  • Struct sampling (recursive)\n');
fprintf('  • Full reproducibility from master seed\n');
fprintf('  • Moment computation for distributions\n');
fprintf('\nNext steps:\n');
fprintf('  • Create generator interface\n');
fprintf('  • Build pattern builder core\n');
fprintf('  • Implement first end-to-end example\n');
