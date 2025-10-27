function results = execute(experiment_spec, context, session_logger)
% EXECUTE - Execute audio-only experiment using DAQ with logging
%
% This function has been refactored to use DAQManager and TrialExecutor
% for better separation of concerns and testability.
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

    % Validate experiment specification
    core.validation.ValidationHelpers.validate_experiment_spec(experiment_spec);

    % Extract configuration
    global_settings = experiment_spec.global_settings;
    fs = global_settings.sampling_rate_hz;

    engine_config = core.config.ConfigurationManager.get_field_or_default(...
        global_settings, 'engine_config', struct());

    % Initialize DAQ using DAQManager
    daq_manager = engines.audio_only.DAQManager(fs, engine_config);
    daq_manager.initialize();

    % Display configuration
    daq_info = daq_manager.get_info();
    fprintf('  Configuration:\n');
    fprintf('    Sampling rate: %d Hz\n', daq_info.sampling_rate_hz);
    fprintf('    Vendor: %s\n', daq_info.vendor_info);
    fprintf('    Device: %s\n', daq_info.device_info);
    fprintf('    Channels: %d\n', daq_info.n_channels);
    fprintf('\n');

    % Prepare results structure
    results = struct();
    results.experiment_id = experiment_spec.experiment_id;
    results.session_dir = session_logger.session_dir;
    results.n_blocks = 0;
    results.n_trials = 0;

    % Get block sequence
    if isfield(experiment_spec, 'blocks') && ~isempty(experiment_spec.blocks)
        block_sequence = experiment_spec.blocks;
    else
        block_sequence = experiment_spec.sequence;
    end

    % Handle single block vs array
    if ~iscell(block_sequence)
        if isstruct(block_sequence)
            block_sequence = {block_sequence};
        else
            block_sequence = num2cell(block_sequence);
        end
    end

    n_blocks = length(block_sequence);

    try
        % Execute each block
        for block_idx = 1:n_blocks
            fprintf('════════════════════════════════════════════════\n');
            fprintf('  Block %d / %d\n', block_idx, n_blocks);
            fprintf('════════════════════════════════════════════════\n\n');

            block_spec = block_sequence{block_idx};

            % Start block logging
            block_logger = session_logger.start_block(block_idx, block_spec.block_instance);

            % Execute block using helper function
            n_trials = execute_block(block_spec, block_idx, ...
                daq_manager, fs, context, block_logger);

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
        session_logger.log_event(core.Constants.LOG_LEVEL_ERROR, ME.message);
    end

    % Cleanup DAQ
    daq_manager.cleanup();

    % Display summary
    fprintf('\n');
    fprintf('════════════════════════════════════════════════\n');
    fprintf('  Experiment Complete\n');
    fprintf('════════════════════════════════════════════════\n');
    fprintf('Blocks: %d\n', results.n_blocks);
    fprintf('Trials: %d\n', results.n_trials);
    fprintf('Session: %s\n', results.session_dir);
    fprintf('\n');
end

function n_trials = execute_block(block_spec, block_idx, daq_manager, fs, context, block_logger)
    % EXECUTE_BLOCK - Execute a single block
    %
    % INPUTS:
    %   block_spec - struct, block specification
    %   block_idx - integer, block index
    %   daq_manager - DAQManager instance
    %   fs - numeric, sampling rate
    %   context - MaestroContext
    %   block_logger - BlockLogger instance
    %
    % OUTPUTS:
    %   n_trials - integer, number of trials executed

    % Get block instance
    core.validation.ValidationHelpers.validate_required_fields(...
        block_spec, {'block_instance'}, 'block_spec');
    instance = block_spec.block_instance;

    % Build trial list using builder
    fprintf('Building trial list...\n');

    builder_type = instance.builder_type;
    if ~isKey(context.builders, builder_type)
        error('engines:audio_only:UnknownBuilder', ...
            'Unknown builder type: %s', builder_type);
    end

    builder_info = context.builders(builder_type);

    build_context = struct();
    build_context.sampling_rate_hz = fs;
    build_context.generators = context.generators;

    trial_list = builder_info.build_func(instance, build_context);

    fprintf('  ✓ Built %d trials\n\n', length(trial_list));
    fprintf('Executing trials...\n');

    % Create trial executor
    trial_executor = engines.audio_only.TrialExecutor(daq_manager, context, fs);

    % Execute each trial
    for trial_idx = 1:length(trial_list)
        trial = trial_list(trial_idx);

        % Execute trial with logging
        trial_executor.execute_trial(trial, trial_idx, block_idx, block_logger);

        % Progress update
        if mod(trial_idx, 10) == 0
            fprintf('  Trial %d / %d\n', trial_idx, length(trial_list));
        end

        % Process pending events (allows Ctrl+C to work)
        drawnow;
    end

    fprintf('\n✓ Block %d complete (%d trials)\n', block_idx, length(trial_list));
    n_trials = length(trial_list);
end
