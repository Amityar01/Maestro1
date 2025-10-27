function demo_engine()
% DEMO_ENGINE - Demonstrate audio_only engine with logging
%
% This demo shows the complete workflow:
%   1. Create session with subject metadata
%   2. Run experiment
%   3. Verify logs created

    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════╗\n');
    fprintf('║   Audio Engine Demo (DAQ + Logging)           ║\n');
    fprintf('╚════════════════════════════════════════════════╝\n\n');
    


  %  Check for DAQ devices
    devices = daq.getDevices();
    if isempty(devices)
        error('No DAQ devices found');
    end
    fprintf('  ✓ Found %d DAQ device(s):\n', length(devices));
    for i = 1:length(devices)
        fprintf('    - %s: %s (%s)\n', devices(i).ID, devices(i).Description, devices(i).Vendor.ID);
    end
    fprintf('\n');
    
    % Create Maestro context
    fprintf('Creating Maestro context...\n');
    ctx = core.MaestroContext();
    fprintf('\n');
    
    fprintf('Available components:\n');
    fprintf('  Generators: %d\n', ctx.generators.Count);
    fprintf('  Builders: %d\n', ctx.builders.Count);
    fprintf('  Engines: %d\n', ctx.engines.Count);
    fprintf('\n');
    
    % Configure experiment
    fprintf('Configuring experiment...\n');
    experiment = struct();
    experiment.experiment_id = 'demo_oddball_001';
    
    % Global settings
    experiment.global_settings = struct();
    experiment.global_settings.sampling_rate_hz = 192000;
    experiment.global_settings.engine_type = 'audio_only';
    
    % Engine config
    experiment.global_settings.engine_config = struct();
    experiment.global_settings.engine_config.vendor = 'ni';
    experiment.global_settings.engine_config.device_id = 'Dev1';
    experiment.global_settings.engine_config.audio_channels = {'ao0'};
    experiment.global_settings.engine_config.trigger_channel = 'ao1';
    experiment.global_settings.engine_config.trigger_config = struct(...
        'voltage', 5.0, ...
        'duration_ms', 10 ...
    );
    
    % Create block
    block = struct();
    block.block_instance = struct();
    block.block_instance.instance_id = 'demo_block_001';
    block.block_instance.builder_type = 'oddball';
    
    % Block parameters
    block.block_instance.parameters = struct();
    block.block_instance.parameters.n_trials = 20;
    block.block_instance.parameters.deviant_probability = 0.25;
    block.block_instance.parameters.order_constraint = 'no_consecutive_deviants';
    block.block_instance.parameters.iti_sec = [0.8, 1.2];
    
    % Standard stimulus
    block.block_instance.parameters.standard_stimulus = struct(...
        'generator', 'tone', ...
        'version', '1.0.0', ...
        'parameters', struct(...
            'freq_hz', 1000, ...
            'dur_ms', 100, ...
            'level_db', 60, ...
            'ramp_ms', 5 ...
        ) ...
    );
    
    % Deviant stimulus
    block.block_instance.parameters.deviant_stimulus = struct(...
        'generator', 'tone', ...
        'version', '1.0.0', ...
        'parameters', struct(...
            'freq_hz', 2000, ...
            'dur_ms', 100, ...
            'level_db', 60, ...
            'ramp_ms', 5 ...
        ) ...
    );
    
    experiment.sequence = block;
    
    fprintf('\nExperiment Configuration:\n');
    fprintf('═══════════════════════════════════════════════\n');
    fprintf('ID: %s\n', experiment.experiment_id);
    fprintf('Sampling rate: %d Hz\n', experiment.global_settings.sampling_rate_hz);
    fprintf('Engine: %s\n', experiment.global_settings.engine_type);
    fprintf('DAQ vendor: %s\n', experiment.global_settings.engine_config.vendor);
    fprintf('DAQ device: %s\n', experiment.global_settings.engine_config.device_id);
    fprintf('Audio channel: %s\n', experiment.global_settings.engine_config.audio_channels{1});
    fprintf('Trigger channel: %s\n', experiment.global_settings.engine_config.trigger_channel);
    fprintf('\nBlock:\n');
    fprintf('  Trials: %d\n', block.block_instance.parameters.n_trials);
    fprintf('  Deviant probability: %.0f%%\n', block.block_instance.parameters.deviant_probability * 100);
    fprintf('  Standard: %d Hz tone\n', block.block_instance.parameters.standard_stimulus.parameters.freq_hz);
    fprintf('  Deviant: %d Hz tone\n', block.block_instance.parameters.deviant_stimulus.parameters.freq_hz);
    fprintf('  ITI: %.1f - %.1f sec\n', block.block_instance.parameters.iti_sec(1), block.block_instance.parameters.iti_sec(2));
    fprintf('\n');
    
    % Validate
    fprintf('Validating experiment...\n');
    [is_valid, errors] = core.validate_experiment(experiment, ctx);
    if ~is_valid
        fprintf('✗ Validation errors:\n');
        for i = 1:length(errors)
            fprintf('  - %s\n', errors{i});
        end
        return;
    end
    fprintf('  ✓ Experiment valid\n\n');
    
    % Pre-flight check
    fprintf('Pre-flight check:\n');
    fprintf('  - Make sure your audio amplifier is on\n');
    fprintf('  - Set volume to comfortable level\n');
    fprintf('  - OpenEphys ready (if recording)\n');
    fprintf('  - Press Ctrl+C during experiment to abort\n\n');
    
    fprintf('════════════════════════════════════════════════\n');
    fprintf('Ready to start!\n');
    fprintf('════════════════════════════════════════════════\n\n');
    
    fprintf('The demo will play:\n');
    fprintf('  - %d trials total\n', block.block_instance.parameters.n_trials);
    fprintf('  - Standards at %d Hz\n', block.block_instance.parameters.standard_stimulus.parameters.freq_hz);
    fprintf('  - Deviants at %d Hz (%.0f%% probability)\n', ...
        block.block_instance.parameters.deviant_stimulus.parameters.freq_hz, ...
        block.block_instance.parameters.deviant_probability * 100);
    fprintf('  - %d ms duration each\n', block.block_instance.parameters.standard_stimulus.parameters.dur_ms);
    fprintf('  - ~%.1f second between trials\n', mean(block.block_instance.parameters.iti_sec));
    fprintf('  - TTL trigger (5V, 10ms) sent with each trial\n\n');
    
    input('Press ENTER to start (or Ctrl+C to cancel)...', 's');
    
    fprintf('\nStarting experiment...\n\n');
    
    % Run experiment with session logging
    results = ctx.run_experiment_with_logging(experiment, ...
        'DEMO', ...          % subject_id
        1, ...               % session_number
        'Demo User');        % experimenter
    
    % Show results
    fprintf('\n');
    fprintf('════════════════════════════════════════════════\n');
    fprintf('Results Summary\n');
    fprintf('════════════════════════════════════════════════\n');
    fprintf('Completed: %s\n', mat2str(results.completed));
    fprintf('Session: %s\n', results.session_dir);
    fprintf('Blocks: %d\n', results.n_blocks);
    fprintf('Trials: %d\n', results.n_trials);
    fprintf('\n');
    
    % Check logs
    fprintf('Checking logs...\n');
    
    % Metadata
    metadata_file = fullfile(results.session_dir, 'metadata.json');
    if exist(metadata_file, 'file')
        fprintf('  ✓ metadata.json\n');
    else
        fprintf('  ✗ metadata.json missing\n');
    end
    
    % Sequence
    seq_file = fullfile(results.session_dir, 'sequence.json');
    if exist(seq_file, 'file')
        fprintf('  ✓ sequence.json\n');
    else
        fprintf('  ✗ sequence.json missing\n');
    end
    
    % Stimuli log
    stimuli_file = fullfile(results.session_dir, 'block_001', 'stimuli.csv');
    if exist(stimuli_file, 'file')
        fprintf('  ✓ block_001/stimuli.csv\n');
        
        % Read and display sample
        data = readtable(stimuli_file);
        fprintf('    Total trials logged: %d\n', height(data));
        
        % Count trial types
        n_standards = sum(strcmp(data.trial_type, 'standard'));
        n_deviants = sum(strcmp(data.trial_type, 'deviant'));
        fprintf('    Standards: %d (%.1f%%)\n', n_standards, 100*n_standards/height(data));
        fprintf('    Deviants: %d (%.1f%%)\n', n_deviants, 100*n_deviants/height(data));
        
    else
        fprintf('  ✗ block_001/stimuli.csv missing\n');
    end
    
    % Events log
    events_file = fullfile(results.session_dir, 'events.log');
    if exist(events_file, 'file')
        fprintf('  ✓ events.log\n');
    else
        fprintf('  ✗ events.log missing\n');
    end
    
    fprintf('\n');
    fprintf('════════════════════════════════════════════════\n');
    fprintf('✓ Demo complete!\n');
    fprintf('════════════════════════════════════════════════\n\n');
    
    fprintf('Next steps:\n');
    fprintf('  1. Review logs in: %s\n', results.session_dir);
    fprintf('  2. Check stimuli.csv to see trial-by-trial log\n');
    fprintf('  3. Verify TTL triggers recorded in OpenEphys\n');
    fprintf('  4. Match TTL times with stimuli.csv by order\n');
    fprintf('\n');
end