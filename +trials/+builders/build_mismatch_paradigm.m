% +trials/+builders/build_mismatch_paradigm.m
function trial_list = build_mismatch_paradigm(config)
% BUILD_MISMATCH_PARADIGM - Handles multiple mismatch types, including
% level-based and frequency-based mismatches for tone outcomes.

n_trials = config.n_trials;

% --- Determine the number of trials for each type ---
trial_types = cell(n_trials, 1);
n_matched_total = n_trials;
current_idx = 1;

fprintf('Calculating trial distribution...\n');
for i = 1:length(config.mismatches)
    mismatch = config.mismatches(i);
    n_this_mismatch = round(n_trials * mismatch.probability);
    trial_types(current_idx : current_idx + n_this_mismatch - 1) = {mismatch.type};
    current_idx = current_idx + n_this_mismatch;
    n_matched_total = n_matched_total - n_this_mismatch;
    fprintf('  - Mismatch (%s): %d trials\n', mismatch.type, n_this_mismatch);
end
trial_types(current_idx : end) = {'matched'};
fprintf('  - Matched: %d trials\n', n_matched_total);

trial_types = trial_types(randperm(n_trials));

% --- Build the trial list ---
trial_list = struct();
for k = 1:n_trials
    trial_list(k).trial_num = k;
    trial_list(k).block_type = 'mismatch_paradigm';

    trial_list(k).presentations(1).stim_type = config.cue.stim_type;
    trial_list(k).presentations(1).params = config.cue.params;
    trial_list(k).presentations(1).onset_ms = 0;

    delay_spec = config.timing.delay_ms;
    if isstruct(delay_spec), this_trial_delay_ms = delay_spec.min + (delay_spec.max - delay_spec.min) * rand();
    else, this_trial_delay_ms = delay_spec; end
    trial_list(k).metadata.delay_ms = this_trial_delay_ms;

    this_trial_type = trial_types{k};
    trial_list(k).trial_type = this_trial_type;
    trial_list(k).metadata.mismatch_type = this_trial_type;

    outcome_params = config.outcome.params;

    if strcmp(this_trial_type, 'matched')
        trial_list(k).metadata.is_mismatch = false;
    else
        trial_list(k).metadata.is_mismatch = true;
        switch this_trial_type
            case 'omission'
                continue;
            case 'decreased_level'
                outcome_params.level_db = config.mismatch_params.decreased_level_db;
            case 'increased_level'
                outcome_params.level_db = config.mismatch_params.increased_level_db;
            case 'lower_tone'
                outcome_params.freq_hz = config.mismatch_params.lower_freq_hz;
            case 'higher_tone'
                outcome_params.freq_hz = config.mismatch_params.higher_freq_hz;
            case 'lower_frequency_range'
                outcome_params.freq_hz = config.mismatch_params.lower_freq_hz;
            otherwise
                error('Unknown mismatch type: %s', this_trial_type);
        end
    end

    cue_dur_ms = config.cue.params.dur_ms;
    outcome_onset_ms = cue_dur_ms + this_trial_delay_ms;

    trial_list(k).presentations(2).stim_type = config.outcome.stim_type;
    trial_list(k).presentations(2).params = outcome_params;
    trial_list(k).presentations(2).onset_ms = outcome_onset_ms;
end
fprintf('\n✓ Built multi-mismatch block: %d total trials\n', n_trials);
end