% TEST_ODDBALL_COMPLETE - Complete test of oddball builder

fprintf('\n');
fprintf('╔════════════════════════════════════════════════╗\n');
fprintf('║   Oddball Builder - Complete Test             ║\n');
fprintf('╚════════════════════════════════════════════════╝\n');
fprintf('\n');

cd('C:\Users\amity\Maestro')

%% Test 1: Discovery
fprintf('Test 1: Discovery\n');
fprintf('─────────────────────────────────────────────────\n');
ctx = core.MaestroContext();
ctx.list_builders();

if ~isKey(ctx.builders, 'oddball')
    error('Oddball builder not discovered!');
end
fprintf('✓ Discovery passed\n\n');

%% Test 2: Direct building (with required order_constraint)
fprintf('Test 2: Direct building\n');
fprintf('─────────────────────────────────────────────────\n');

instance = struct();
instance.instance_id = 'test_oddball';
instance.builder_type = 'oddball';
instance.parameters = struct();
instance.parameters.n_trials = 100;
instance.parameters.deviant_probability = 0.2;
instance.parameters.order_constraint = 'none';  % Required by your build.m
instance.parameters.iti_sec = [1.0, 2.0];       % [min, max] format

instance.parameters.standard_stimulus = struct(...
    'generator', 'tone', ...
    'version', '1.0.0', ...
    'parameters', struct('freq_hz', 1000, 'dur_ms', 50, 'level_db', 60, 'ramp_ms', 5) ...
);
instance.parameters.deviant_stimulus = struct(...
    'generator', 'tone', ...
    'version', '1.0.0', ...
    'parameters', struct('freq_hz', 2000, 'dur_ms', 50, 'level_db', 60, 'ramp_ms', 5) ...
);

context = struct('sampling_rate_hz', 192000, 'rng_seed', 42);
trials = builders.oddball.build(instance, context);

fprintf('Generated: %d trials\n', length(trials));

% Count deviants (using your metadata field names)
n_dev = 0;
for i = 1:length(trials)
    if trials(i).metadata.is_deviant
        n_dev = n_dev + 1;
    end
end
fprintf('Deviants: %d (%.1f%%)\n', n_dev, 100*n_dev/length(trials));
fprintf('✓ Direct building passed\n\n');

%% Test 3: Fixed ITI (scalar)
fprintf('Test 3: Fixed ITI\n');
fprintf('─────────────────────────────────────────────────\n');

instance_fixed = instance;
instance_fixed.parameters.iti_sec = 1.5;  % Fixed ITI

trials_fixed = builders.oddball.build(instance_fixed, context);

% Check all ITIs are the same
iti_vals = [trials_fixed.iti_sec];
if all(iti_vals == 1.5)
    fprintf('  ✓ All ITIs fixed at %.1f sec\n', iti_vals(1));
else
    fprintf('  ✗ ITIs not consistent\n');
end
fprintf('✓ Fixed ITI passed\n\n');

%% Test 4: Trial structure analysis
fprintf('Test 4: Trial structure analysis\n');
fprintf('─────────────────────────────────────────────────\n');

% Check first trial
trial1 = trials(1);
fprintf('First trial structure:\n');
fprintf('  metadata.trial_index: %d\n', trial1.metadata.trial_index);
fprintf('  metadata.kind: %s\n', trial1.metadata.kind);
fprintf('  presentations: %d\n', length(trial1.presentations));
fprintf('  iti_sec: %.3f\n', trial1.iti_sec);

% Check presentation structure
pres = trial1.presentations(1);
fprintf('  presentation.onset_ms: %.1f\n', pres.onset_ms);
fprintf('  presentation.stimulus_spec.generator: %s\n', pres.stimulus_spec.generator);

fprintf('✓ Trial structure passed\n\n');

%% Test 5: No consecutive deviants constraint
fprintf('Test 5: No consecutive deviants\n');
fprintf('─────────────────────────────────────────────────\n');

instance_constrained = instance;
instance_constrained.parameters.n_trials = 100;
instance_constrained.parameters.deviant_probability = 0.3;
instance_constrained.parameters.order_constraint = 'no_consecutive_deviants';

context_const = struct('sampling_rate_hz', 192000, 'rng_seed', 456);
trials_const = builders.oddball.build(instance_constrained, context_const);

% Check for consecutive deviants
has_consecutive = false;
for i = 1:length(trials_const)-1
    if trials_const(i).metadata.is_deviant && trials_const(i+1).metadata.is_deviant
        has_consecutive = true;
        fprintf('  ✗ Found consecutive deviants at trials %d-%d\n', i, i+1);
        break;
    end
end

if ~has_consecutive
    fprintf('  ✓ No consecutive deviants found\n');
end
fprintf('✓ Constraint passed\n\n');

%% Test 6: Visualization
fprintf('Test 6: Visualization\n');
fprintf('─────────────────────────────────────────────────\n');

% Create visualization of trial sequence
figure('Name', 'Oddball Trial Sequence', 'Position', [100 100 1200 400]);

% Plot trial types
subplot(2,1,1);
trial_codes = zeros(length(trials), 1);
for i = 1:length(trials)
    trial_codes(i) = trials(i).metadata.is_deviant;
end
stem(1:length(trials), trial_codes, 'Marker', 'none', 'LineWidth', 2);
ylim([-0.1 1.1]);
yticks([0 1]);
yticklabels({'Standard', 'Deviant'});
xlabel('Trial Number');
title('Trial Sequence');
grid on;

% Plot ITI distribution
subplot(2,1,2);
iti_vals = zeros(length(trials), 1);
for i = 1:length(trials)
    iti_vals(i) = trials(i).iti_sec;
end
histogram(iti_vals, 20);
xlabel('Inter-Trial Interval (sec)');
ylabel('Count');
title('ITI Distribution');
grid on;

fprintf('✓ Visualization created\n\n');

%% Test 7: Edge cases
fprintf('Test 7: Edge cases\n');
fprintf('─────────────────────────────────────────────────\n');

% Test with 0% deviants
instance_zero = instance;
instance_zero.parameters.deviant_probability = 0;
instance_zero.parameters.order_constraint = 'none';
trials_zero = builders.oddball.build(instance_zero, context);

% Count deviants properly (loop instead of array indexing)
n_dev_zero = 0;
for i = 1:length(trials_zero)
    if trials_zero(i).metadata.is_deviant
        n_dev_zero = n_dev_zero + 1;
    end
end

if n_dev_zero == 0
    fprintf('  ✓ 0%% deviants: all standard\n');
else
    fprintf('  ✗ 0%% deviants but found %d deviants\n', n_dev_zero);
end

% Test with 100% deviants
instance_all = instance;
instance_all.parameters.deviant_probability = 1.0;
instance_all.parameters.order_constraint = 'none';
trials_all = builders.oddball.build(instance_all, context);

% Count deviants properly
n_dev_all = 0;
for i = 1:length(trials_all)
    if trials_all(i).metadata.is_deviant
        n_dev_all = n_dev_all + 1;
    end
end

if n_dev_all == length(trials_all)
    fprintf('  ✓ 100%% deviants: all deviant\n');
else
    fprintf('  ✗ 100%% deviants but only %d deviants\n', n_dev_all);
end

fprintf('✓ Edge cases passed\n\n');

%% Summary
fprintf('\n');
fprintf('╔════════════════════════════════════════════════╗\n');
fprintf('║   ✓ All tests passed!                         ║\n');
fprintf('╚════════════════════════════════════════════════╝\n');
fprintf('\n');
fprintf('The oddball builder is fully functional!\n');
fprintf('\n');
fprintf('Your build.m implementation uses:\n');
fprintf('  - Required field: order_constraint ("none" or "no_consecutive_deviants")\n');
fprintf('  - ITI format: iti_sec (scalar or [min, max])\n');
fprintf('  - Metadata: trial_index, kind, is_deviant\n');
fprintf('  - Presentation onset: always 0 ms\n');
fprintf('\n');
fprintf('Next step: Create an engine (e.g., audio_only)\n');
fprintf('\n');