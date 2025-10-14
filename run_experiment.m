% maestro2/run_experiment.m
function run_experiment(block_json_file, device_id, out_dir)
% RUN_EXPERIMENT - Run a single block from JSON template
%
% block_json_file: path to JSON block template
% device_id: NI-DAQ device ID (e.g., 'Dev1')
% out_dir: output directory for data

fprintf('═══════════════════════════════════════\n');
fprintf('   Maestro 2.0 - Block Execution\n');
fprintf('═══════════════════════════════════════\n\n');

% Load block configuration from JSON
fprintf('Loading block: %s\n', block_json_file);
config = jsondecode(fileread(block_json_file));
fprintf('  Block type: %s\n', config.block_type);
fprintf('  Name: %s\n', config.name);
fprintf('  Description: %s\n\n', config.description);

% Initialize hardware
FS = 192000;
daq_session = hardware.init_daq(device_id, FS);

% Route to appropriate trial builder based on block_type
fprintf('Building trial list...\n');
builder_func = str2func(['trials.builders.build_' config.block_type]);
trial_list = builder_func(config);

% Add timing (ITI)
fprintf('Adding timing...\n');
trial_list = trials.add_timing(trial_list, config.timing);

% Build waveforms
fprintf('\n');
[ao_waveform, do_waveform, trial_log, ttl_log] = build_segment_waveforms(trial_list, FS);

% Play the block
fprintf('\n');
loopback_timetable = hardware.play_block(daq_session, ao_waveform, do_waveform);

% Extract loopback data
loopback_data = loopback_timetable.Dev1_ai0;

% Save data
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
save_segment_data(out_dir, ao_waveform, do_waveform, loopback_data, trial_log, ttl_log, config);

% Clean up
hardware.release(daq_session);

fprintf('\n✓ Block execution complete!\n');
fprintf('  Data saved to: %s\n', out_dir);
end