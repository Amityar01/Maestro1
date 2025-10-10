% Maestro/run_experiment.m
function run_experiment(preset_name, device_id, out_dir, calibration_file)
% RUN_EXPERIMENT - Main entry point for running experiments

% Load preset
fprintf('Loading preset: %s...\n', preset_name);
preset_func = str2func(['presets.' preset_name]);
cfg = preset_func();

% Load calibration (placeholder for now)
fprintf('Loading calibration from %s...\n', calibration_file);
% cal = jsondecode(fileread(calibration_file)); % We will enable this later

% Initialize hardware
FS = 192000; % Sample rate from design
daq_session = hardware.init_daq(device_id, FS);

% Run each segment
for seg_idx = 1:numel(cfg.segments)
    seg = cfg.segments(seg_idx);
    
    fprintf('\n==========================================\n');
    fprintf('   Starting Segment %d/%d: %s\n', seg_idx, numel(cfg.segments), seg.name);
    fprintf('==========================================\n');
    
    % Build trial list
    trial_list = trials.build_ratio_locked(seg.ratios, seg.n_trials);
    trial_list = trials.add_timing(trial_list, cfg.timing);
    if isfield(cfg, 'constraints')
        trial_list = trials.apply_constraints(trial_list, cfg.constraints);
    end
    
    % Build waveforms for the entire segment
    [ao_waveform, do_waveform, trial_log, ttl_log] = build_segment_waveforms(trial_list, cfg, FS);
    
    % Play the block
    loopback_timetable = hardware.play_block(daq_session, ao_waveform, do_waveform);
    
    % --- NEW LINE HERE ---
    % Extract the raw data from the timetable object before saving
    loopback_data = loopback_timetable.Dev1_ai0;
    % ---------------------

    % Save the data
    seg_out_dir = fullfile(out_dir, sprintf('segment_%02d_%s', seg_idx, seg.name));
    if ~exist(seg_out_dir, 'dir'), mkdir(seg_out_dir); end
    save_segment_data(seg_out_dir, ao_waveform, do_waveform, loopback_data, trial_log, ttl_log, cfg);
end

hardware.release(daq_session);
fprintf('\n✓ Experiment complete.\n');
end