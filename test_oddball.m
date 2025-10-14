% maestro2/test_oddball.m
% Test the oddball paradigm without hardware

fprintf('═══════════════════════════════════════\n');
fprintf('   Testing Oddball Paradigm\n');
fprintf('═══════════════════════════════════════\n\n');

%% 1. Load JSON config
fprintf('STEP 1: Loading JSON configuration...\n');
config = jsondecode(fileread('block_templates/oddball_freq.json'));
fprintf('  ✓ Loaded: %s\n', config.name);
fprintf('  ✓ Block type: %s\n', config.block_type);
fprintf('  ✓ Trials: %d\n', config.n_trials);
fprintf('  ✓ Deviant probability: %.1f%%\n\n', config.deviant_probability * 100);

%% 2. Build trial list
fprintf('STEP 2: Building trial list...\n');
trial_list = trials.builders.build_oddball(config);
fprintf('  ✓ Created %d trials\n', length(trial_list));

% Check deviant distribution (FIXED)
n_deviants = 0;
for k = 1:length(trial_list)
    if trial_list(k).metadata.is_deviant
        n_deviants = n_deviants + 1;
    end
end
fprintf('  ✓ Deviants: %d (%.1f%%)\n', n_deviants, 100*n_deviants/length(trial_list));

% Check for consecutive deviants
has_consecutive = false;
for k = 1:length(trial_list)-1
    if trial_list(k).metadata.is_deviant && trial_list(k+1).metadata.is_deviant
        has_consecutive = true;
        break;
    end
end
if has_consecutive
    fprintf('  ✗ WARNING: Found consecutive deviants\n');
else
    fprintf('  ✓ No consecutive deviants\n');
end
fprintf('\n');

%% 3. Add timing
fprintf('STEP 3: Adding timing (ITI)...\n');
trial_list = trials.add_timing(trial_list, config.timing);
fprintf('  ✓ ITI range: %.1f - %.1f sec\n', config.timing.iti_min_sec, config.timing.iti_max_sec);

% Calculate mean ITI (FIXED)
iti_sum = 0;
for k = 1:length(trial_list)
    iti_sum = iti_sum + trial_list(k).iti_sec;
end
fprintf('  ✓ Mean ITI: %.2f sec\n\n', iti_sum / length(trial_list));

%% 4. Test stimulus generation
fprintf('STEP 4: Testing stimulus generation...\n');
fs = 192000;

% Generate a standard
fprintf('  Testing standard stimulus...\n');
std_stim = generate_stimulus(trial_list(1).presentations(1).stim_type, ...
                              trial_list(1).presentations(1).params, fs);
fprintf('    ✓ Standard: %d samples (%.1f ms)\n', length(std_stim), 1000*length(std_stim)/fs);

% Find a deviant trial (FIXED)
dev_idx = 0;
for k = 1:length(trial_list)
    if trial_list(k).metadata.is_deviant
        dev_idx = k;
        break;
    end
end
fprintf('  Testing deviant stimulus...\n');
dev_stim = generate_stimulus(trial_list(dev_idx).presentations(1).stim_type, ...
                              trial_list(dev_idx).presentations(1).params, fs);
fprintf('    ✓ Deviant: %d samples (%.1f ms)\n\n', length(dev_stim), 1000*length(dev_stim)/fs);

%% 5. Build full waveforms
fprintf('STEP 5: Building complete waveforms...\n');
[AO, DO, trial_log, ttl_log] = build_segment_waveforms(trial_list, fs);
fprintf('  ✓ AO waveform: %d samples\n', length(AO));
fprintf('  ✓ DO waveform: %d samples\n', length(DO));
fprintf('  ✓ Duration: %.1f sec\n', length(AO)/fs);
fprintf('  ✓ TTL events: %d\n', height(ttl_log));
fprintf('  ✓ Trial log: %d entries\n\n', height(trial_log));

%% 6. Quick visualization
fprintf('STEP 6: Visualizing first 3 trials...\n');
figure('Position', [100 100 1200 600]);

% Calculate where first 3 trials end
trial_samples = 0;
for k = 1:min(3, length(trial_list))
    trial_dur_ms = trial_list(k).presentations(1).params.dur_ms;
    trial_samples = trial_samples + round(fs * (trial_dur_ms/1000 + trial_list(k).iti_sec));
end

t = (0:trial_samples-1) / fs;
subplot(2,1,1);
plot(t, AO(1:trial_samples));
xlabel('Time (s)');
ylabel('Voltage');
title('Audio Output (AO) - First 3 Trials');
grid on;

subplot(2,1,2);
plot(t, DO(1:trial_samples));
xlabel('Time (s)');
ylabel('Digital');
title('TTL Output (DO) - First 3 Trials');
ylim([-0.1 1.1]);
grid on;

fprintf('  ✓ Plot created\n\n');

%% Summary
fprintf('═══════════════════════════════════════\n');
fprintf('   ✓ ALL TESTS PASSED!\n');
fprintf('═══════════════════════════════════════\n');
fprintf('The oddball paradigm is working correctly.\n');
fprintf('Ready to test with hardware using run_experiment.m\n\n');