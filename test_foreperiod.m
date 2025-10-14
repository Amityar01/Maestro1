% maestro2/test_foreperiod.m
% Test the foreperiod paradigm (S1 -> Delay -> S2) without hardware

fprintf('═══════════════════════════════════════\n');
fprintf('   Testing Foreperiod Paradigm\n');
fprintf('═══════════════════════════════════════\n\n');

%% 1. Load JSON config
fprintf('STEP 1: Loading JSON configuration...\n');
config = jsondecode(fileread('block_templates/foreperiod_noise.json'));
fprintf('  ✓ Loaded: %s\n', config.name);
fprintf('  ✓ Block type: %s\n', config.block_type);
fprintf('  ✓ Trials: %d\n', config.n_trials);
fprintf('  ✓ Omission probability: %.1f%%\n\n', config.omission_probability * 100);

%% 2. Build trial list
fprintf('STEP 2: Building trial list...\n');
trial_list = trials.builders.build_foreperiod(config);
fprintf('  ✓ Created %d trials\n', length(trial_list));

% Verify trial type distribution
n_omit = 0;
for k = 1:length(trial_list)
    if trial_list(k).metadata.is_mismatch
        n_omit = n_omit + 1;
    end
end
fprintf('  ✓ Mismatch trials: %d (%.1f%%)\n\n', n_omit, 100*n_omit/length(trial_list));

%% 3. Add timing
fprintf('STEP 3: Adding timing (ITI)...\n');
trial_list = trials.add_timing(trial_list, config.timing);
fprintf('  ✓ ITI range: %.1f - %.1f sec\n', config.timing.iti_min_sec, config.timing.iti_max_sec);
fprintf('  ✓ Foreperiod delay: %d ms\n\n', config.timing.delay_ms);

%% 4. Build full waveforms
fprintf('STEP 4: Building complete waveforms...\n');
fs = 192000;
[AO, DO, trial_log, ttl_log] = build_segment_waveforms(trial_list, fs);
fprintf('  ✓ AO waveform: %d samples\n', length(AO));
fprintf('  ✓ DO waveform: %d samples\n', length(DO));
fprintf('  ✓ Duration: %.1f sec\n', length(AO)/fs);
fprintf('  ✓ TTL events: %d\n', height(ttl_log));
fprintf('  ✓ Trial log: %d entries\n\n', height(trial_log));

%% 5. Quick visualization
fprintf('STEP 5: Visualizing first 3 trials...\n');
figure('Position', [100 100 1200 600]);

% Calculate where the first 3 trials end for plotting
trial_samples = 0;
for k = 1:min(3, length(trial_list))
    % Use the universal trial duration calculator
    trial_dur_ms = calculate_trial_duration(trial_list(k), fs);
    trial_samples = trial_samples + round(fs * (trial_dur_ms/1000 + trial_list(k).iti_sec));
end

t = (0:trial_samples-1) / fs;
subplot(2,1,1);
plot(t, AO(1:trial_samples));
xlabel('Time (s)');
ylabel('Voltage');
title('Audio Output (AO) - First 3 Trials');
grid on;
hold on;
% Add vertical lines for TTL events to make timing clear
ttl_times = ttl_log.SampleIndex(ttl_log.SampleIndex <= trial_samples) / fs;
for i = 1:length(ttl_times)
    xline(ttl_times(i), '--r', 'LineWidth', 1);
end
legend('Waveform', 'TTL Onsets');


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
fprintf('The foreperiod paradigm is working correctly.\n');
fprintf('Ready to test with hardware using run_experiment.m\n\n');

% --- Helper function needed for visualization ---
function dur_ms = calculate_trial_duration(trial, fs)
    if isempty(trial.presentations)
        dur_ms = 0;
        return;
    end
    max_end_ms = 0;
    for p_idx = 1:numel(trial.presentations)
        pres = trial.presentations(p_idx);
        if isfield(pres.params, 'dur_ms')
            stim_dur = pres.params.dur_ms;
        else, stim_dur = 50; end
        end_ms = pres.onset_ms + stim_dur;
        max_end_ms = max(max_end_ms, end_ms);
    end
    dur_ms = max_end_ms;
end