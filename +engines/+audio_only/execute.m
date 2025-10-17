function results = execute(experiment_spec, context, session_logger)
% EXECUTE - Execute audio-only experiment using DAQ with logging
%
% INPUTS:
%   experiment_spec - struct with experiment configuration
%   context - struct with generators, builders, etc.
%   session_logger - SessionLogger instance for logging
%
% OUTPUTS:
%   results - minimal struct with session info

    fprintf('\n');
    fprintf('════════════════════════════════════════════════\n');
    fprintf('  Maestro Audio Engine v1.0.0 (DAQ)\n');
    fprintf('════════════════════════════════════════════════\n');
    fprintf('\n');
    
    % Validate experiment
    validate_experiment_spec(experiment_spec);
    
    % Extract global settings
    global_settings = experiment_spec.global_settings;
    fs = global_settings.sampling_rate_hz;
    
    % Get engine configuration
    if isfield(global_settings, 'engine_config')
        engine_config = global_settings.engine_config;
    else
        engine_config = struct();
    end
    
    % Initialize DAQ
    fprintf('Initializing DAQ...\n');
    daq_session = init_daq(fs, engine_config);
    fprintf('  ✓ DAQ initialized\n');
    fprintf('    Sampling rate: %d Hz\n', fs);
    fprintf('    Vendor: %s\n', daq_session.vendor_info);
    fprintf('    Device: %s\n', daq_session.device_info);
    fprintf('    Channels: %d\n', daq_session.n_channels);
    fprintf('\n');
    
    % Prepare results structure (minimal)
    results = struct();
    results.experiment_id = experiment_spec.experiment_id;
    results.session_dir = session_logger.session_dir;
    results.n_blocks = 0;
    results.n_trials = 0;
    
    % Execute each block in sequence
    n_blocks = length(experiment_spec.sequence);
    
    try
        for block_idx = 1:n_blocks
            fprintf('════════════════════════════════════════════════\n');
            fprintf('  Block %d / %d\n', block_idx, n_blocks);
            fprintf('════════════════════════════════════════════════\n\n');
            
            block_spec = experiment_spec.sequence(block_idx);
            
            % Start block logging
            block_logger = session_logger.start_block(block_idx, block_spec.block_instance);
            
            % Execute block
            n_trials = execute_block(block_spec, block_idx, ...
                daq_session, fs, context, block_logger);
            
            % End block logging
            session_logger.end_block(block_logger, n_trials);
            
            results.n_blocks = results.n_blocks + 1;
            results.n_trials = results.n_trials + n_trials;
            
            % Inter-block pause (if not last block)
            if block_idx < n_blocks
                fprintf('\nBlock %d complete. Press ENTER to continue (Ctrl+C to abort)...\n', block_idx);
                pause;
            end
        end
        
        results.completed = true;
        
    catch ME
        fprintf('\n✗ Experiment interrupted: %s\n', ME.message);
        results.completed = false;
        results.error = ME;
        session_logger.log_event('ERROR', ME.message);
    end
    
    % Cleanup
    cleanup_daq(daq_session);
    
    fprintf('\n');
    fprintf('════════════════════════════════════════════════\n');
    fprintf('  Experiment Complete\n');
    fprintf('════════════════════════════════════════════════\n');
    fprintf('Blocks: %d\n', results.n_blocks);
    fprintf('Trials: %d\n', results.n_trials);
    fprintf('Session: %s\n', results.session_dir);
    fprintf('\n');
end

function n_trials = execute_block(block_spec, block_idx, daq_session, fs, context, block_logger)
    % Execute a single block with logging
    
    % Get block instance
    if isfield(block_spec, 'block_instance')
        instance = block_spec.block_instance;
    else
        error('Block specification must contain block_instance');
    end
    
    % Build trial list using builder
    fprintf('Building trial list...\n');
    
    builder_type = instance.builder_type;
    if ~isKey(context.builders, builder_type)
        error('Unknown builder type: %s', builder_type);
    end
    
    builder_info = context.builders(builder_type);
    build_context = struct();
    build_context.sampling_rate_hz = fs;
    build_context.generators = context.generators;
    
    trial_list = builder_info.build_func(instance, build_context);
    
    fprintf('  ✓ Built %d trials\n\n', length(trial_list));
    fprintf('Executing trials...\n');
    
    % Execute each trial
    for trial_idx = 1:length(trial_list)
        trial = trial_list(trial_idx);
        
        % Execute trial with logging
        execute_trial(trial, trial_idx, block_idx, ...
            daq_session, fs, context, block_logger);
        
        % Progress
        if mod(trial_idx, 10) == 0
            fprintf('  Trial %d / %d\n', trial_idx, length(trial_list));
        end
        
        % Process any pending events (allows Ctrl+C to work)
        drawnow;
    end
    
    fprintf('\n✓ Block %d complete (%d trials)\n', block_idx, length(trial_list));
    n_trials = length(trial_list);
end

function execute_trial(trial, trial_idx, block_idx, ...
    daq_session, fs, context, block_logger)
    % Execute a single trial with logging
    
    % Generate all stimuli for this trial
    presentations = trial.presentations;
    n_presentations = length(presentations);
    
    generated_stimuli = cell(1, n_presentations);
    for p = 1:n_presentations
        pres = presentations(p);
        
        % Generate stimulus
        gen_context = struct();
        gen_context.sampling_rate_hz = fs;
        
        gen_type = pres.stimulus_spec.generator;
        if ~isKey(context.generators, gen_type)
            error('Unknown generator: %s', gen_type);
        end
        
        gen_info = context.generators(gen_type);
        stim_output = gen_info.generate_func(pres.stimulus_spec.parameters, gen_context);
        
        generated_stimuli{p} = stim_output;
    end
    
    % Mix presentations based on onset times
    mixed_audio = mix_presentations(generated_stimuli, presentations, fs);
    
    % Generate TTL trigger (same for all trials)
    ttl_signal = generate_ttl_pulse(length(mixed_audio), fs, daq_session.trigger_config);
    
    % Combine audio + TTL into 2-channel output
    output_matrix = [mixed_audio, ttl_signal];
    
    % Queue data to DAQ
    queueOutputData(daq_session.session, output_matrix);
    
    % Record timing
    trial_start = tic;
    
    % Play audio + send trigger
    startBackground(daq_session.session);
    trigger_time = toc(trial_start);  % TTL starts at beginning
    
    % Wait for playback to complete
    wait(daq_session.session);
    trial_duration = toc(trial_start);
    
    % Prepare log data
    log_data = struct();
    log_data.trial_index = trial_idx;
    log_data.block_index = block_idx;
    log_data.trial_type = trial.metadata.kind;
    
    % Extract stimulus parameters (from first presentation)
    stim_params = presentations(1).stimulus_spec.parameters;
    log_data.freq_hz = stim_params.freq_hz;
    log_data.dur_ms = stim_params.dur_ms;
    log_data.level_db = stim_params.level_db;
    
    log_data.onset_time_sec = trial_start;
    log_data.trigger_sent_sec = trigger_time;
    log_data.iti_sec = trial.iti_sec;
    
    % Log to CSV
    block_logger.log_trial(log_data);
    
    % Inter-trial interval
    pause(trial.iti_sec);
end

function ttl_signal = generate_ttl_pulse(n_samples, fs, trigger_config)
    % Generate simple TTL pulse (same for all trials)
    
    % Defaults
    if ~isfield(trigger_config, 'voltage')
        trigger_voltage = 5.0;
    else
        trigger_voltage = trigger_config.voltage;
    end
    
    if ~isfield(trigger_config, 'duration_ms')
        trigger_duration_ms = 10;
    else
        trigger_duration_ms = trigger_config.duration_ms;
    end
    
    % Create pulse
    pulse_samples = round(trigger_duration_ms * fs / 1000);
    
    ttl_signal = zeros(n_samples, 1);
    ttl_signal(1:pulse_samples) = trigger_voltage;
end

function mixed = mix_presentations(stimuli, presentations, fs)
    % Mix multiple presentations based on onset times
    
    % Find total duration needed
    max_end_time = 0;
    for p = 1:length(presentations)
        onset_ms = presentations(p).onset_ms;
        stim_dur_ms = stimuli{p}.duration_ms;
        end_time = onset_ms + stim_dur_ms;
        if end_time > max_end_time
            max_end_time = end_time;
        end
    end
    
    % Create output buffer
    n_samples = round(max_end_time * fs / 1000);
    mixed = zeros(n_samples, 1);
    
    % Add each presentation at its onset time
    for p = 1:length(presentations)
        onset_samples = round(presentations(p).onset_ms * fs / 1000);
        stim_data = stimuli{p}.data;
        
        % Add to buffer (with bounds checking)
        start_idx = onset_samples + 1;
        end_idx = min(start_idx + length(stim_data) - 1, n_samples);
        actual_length = end_idx - start_idx + 1;
        
        mixed(start_idx:end_idx) = mixed(start_idx:end_idx) + stim_data(1:actual_length);
    end
    
    % Clip to prevent overflow
    mixed = max(-1, min(1, mixed));
end

function daq_info = init_daq(fs, config)
    % Initialize DAQ session
    
    % Get device info from config or use default
    if isfield(config, 'vendor')
        vendor = config.vendor;
    else
        vendor = 'ni';
    end
    
    if isfield(config, 'device_id')
        device_id = config.device_id;
    else
        device_id = 'Dev1';
    end
    
    if isfield(config, 'audio_channels')
        audio_channels = config.audio_channels;
    else
        audio_channels = {'ao0'};
    end
    
    if isfield(config, 'trigger_channel')
        trigger_channel = config.trigger_channel;
    else
        trigger_channel = 'ao1';
    end
    
    % Create session
    fprintf('  Creating DAQ session...\n');
    s = daq.createSession(vendor);
    s.Rate = fs;
    
    % Add audio output channel
    for i = 1:length(audio_channels)
        addAnalogOutputChannel(s, device_id, audio_channels{i}, 'Voltage');
    end
    
    % Add trigger channel
    addAnalogOutputChannel(s, device_id, trigger_channel, 'Voltage');
    
    % Get trigger config
    if isfield(config, 'trigger_config')
        trigger_config = config.trigger_config;
    else
        trigger_config = struct('voltage', 5.0, 'duration_ms', 10);
    end
    
    % Store info
    daq_info = struct();
    daq_info.session = s;
    daq_info.vendor_info = vendor;
    daq_info.device_info = device_id;
    daq_info.n_channels = length(audio_channels) + 1;  % audio + trigger
    daq_info.trigger_config = trigger_config;
    daq_info.fs = fs;
end

function cleanup_daq(daq_info)
    % Close DAQ session
    try
        if ~isempty(daq_info.session) && isvalid(daq_info.session)
            stop(daq_info.session);
            release(daq_info.session);
        end
    catch
        % Already closed
    end
end

function validate_experiment_spec(spec)
    % Validate experiment specification
    
    required = {'experiment_id', 'global_settings', 'sequence'};
    for i = 1:length(required)
        if ~isfield(spec, required{i})
            error('Experiment spec missing field: %s', required{i});
        end
    end
    
    if ~isfield(spec.global_settings, 'sampling_rate_hz')
        error('global_settings must contain sampling_rate_hz');
    end
    
    if isempty(spec.sequence)
        error('Experiment sequence is empty');
    end
end