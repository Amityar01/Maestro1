classdef DAQEngine < handle
    % DAQEngine - Playback engine for SequenceFiles on NI-DAQ hardware
    %
    % The DAQ Engine loads compiled SequenceFiles and plays them on
    % National Instruments DAQ hardware with sample-accurate timing.
    %
    % Modes:
    %   - hardware: Real NI-DAQ playback (requires hardware)
    %   - dry_run: Simulated playback for testing
    %
    % Contract:
    %   - Input: SequenceFile, hardware configuration
    %   - Output: Playback result with event timing
    %   - Sample-accurate: TTL codes synchronized with audio
    %   - Event recording: Timestamps for all events
    %
    % Example:
    %   engine = v1.daq.DAQEngine();
    %   engine.configure(struct('mode', 'dry_run'));
    %   engine.load_sequence(seq_file);
    %   result = engine.play();

    properties (Access = private)
        seq_file            % Loaded SequenceFile
        config              % Hardware configuration
        state               % Engine state: idle, ready, playing, completed
        daq_session         % DAQ session (hardware mode only)
    end

    methods
        function obj = DAQEngine()
            % Create DAQ engine
            obj.state = 'idle';
            obj.seq_file = [];
            obj.config = [];
            obj.daq_session = [];
        end

        function configure(obj, config)
            % Configure hardware settings
            %
            % Args:
            %   config: Configuration struct with fields:
            %     - mode: 'hardware' or 'dry_run'
            %     - device_id (optional): DAQ device ID (e.g., 'Dev1')
            %     - audio_channels (optional): Audio output channels
            %     - ttl_channel (optional): TTL digital output channel
            %     - ttl_mapping (optional): Map of code → channel
            %     - fs_hz (optional): Expected sample rate
            %     - real_time (optional): true for real-time, false for fast simulation

            % Validate mode
            if ~isfield(config, 'mode')
                config.mode = 'dry_run';  % Default to safe mode
            end

            if ~ismember(config.mode, {'hardware', 'dry_run'})
                error('DAQEngine:InvalidMode', 'Mode must be "hardware" or "dry_run"');
            end

            % Set defaults
            if ~isfield(config, 'real_time')
                if strcmp(config.mode, 'hardware')
                    config.real_time = true;  % Hardware is always real-time
                else
                    config.real_time = false;  % Dry-run defaults to fast
                end
            end

            obj.config = config;

            % Initialize hardware session if in hardware mode
            if strcmp(config.mode, 'hardware')
                obj.init_hardware_session();
            end

            fprintf('DAQEngine configured: mode=%s\n', config.mode);
        end

        function load_sequence(obj, seq_file)
            % Load a SequenceFile for playback
            %
            % Args:
            %   seq_file: SequenceFile struct from CompilerCore

            % Validate SequenceFile structure
            obj.validate_sequence_file(seq_file);

            obj.seq_file = seq_file;
            obj.state = 'ready';

            fprintf('SequenceFile loaded: %.2f s, %d events\n', ...
                seq_file.manifest.duration_ms / 1000, ...
                height(seq_file.events));
        end

        function result = play(obj)
            % Play the loaded SequenceFile
            %
            % Returns:
            %   result: Playback result struct with fields:
            %     - success: true if playback completed
            %     - start_time: Playback start timestamp
            %     - end_time: Playback end timestamp
            %     - duration_ms: Actual playback duration
            %     - events_played: Number of events played
            %     - events: Events table with actual timestamps
            %     - sequence_hash: Hash of played sequence

            % Validate state
            if ~obj.is_configured()
                error('DAQEngine:NotConfigured', 'Engine not configured. Call configure() first.');
            end

            if ~obj.is_loaded()
                error('DAQEngine:NoSequence', 'No sequence loaded. Call load_sequence() first.');
            end

            % Check sample rate match if configured
            if isfield(obj.config, 'fs_hz')
                if obj.config.fs_hz ~= obj.seq_file.manifest.fs_hz
                    error('DAQEngine:SampleRateMismatch', ...
                        'Sample rate mismatch: config=%d Hz, sequence=%d Hz', ...
                        obj.config.fs_hz, obj.seq_file.manifest.fs_hz);
                end
            end

            % Dispatch to appropriate playback method
            if strcmp(obj.config.mode, 'hardware')
                result = obj.play_hardware();
            else
                result = obj.play_dry_run();
            end

            obj.state = 'completed';
        end

        function stop(obj)
            % Stop playback (if playing)

            if strcmp(obj.state, 'playing')
                if ~isempty(obj.daq_session)
                    stop(obj.daq_session);
                end
                obj.state = 'ready';
                fprintf('Playback stopped.\n');
            end
        end

        function reset(obj)
            % Reset engine to idle state

            obj.stop();
            obj.seq_file = [];
            obj.state = 'idle';

            if ~isempty(obj.daq_session)
                delete(obj.daq_session);
                obj.daq_session = [];
            end

            fprintf('DAQEngine reset.\n');
        end

        function tf = is_configured(obj)
            % Check if engine is configured
            tf = ~isempty(obj.config);
        end

        function tf = is_loaded(obj)
            % Check if SequenceFile is loaded
            tf = ~isempty(obj.seq_file);
        end

        function state = get_state(obj)
            % Get current engine state
            state = obj.state;
        end

        function config = get_config(obj)
            % Get current configuration
            config = obj.config;
        end

        function info = get_sequence_info(obj)
            % Get information about loaded SequenceFile
            %
            % Returns:
            %   info: Struct with sequence information

            if ~obj.is_loaded()
                error('DAQEngine:NoSequence', 'No sequence loaded');
            end

            info = struct();
            info.duration_ms = obj.seq_file.manifest.duration_ms;
            info.n_trials = obj.seq_file.manifest.n_trials;
            info.n_events = height(obj.seq_file.events);
            info.fs_hz = obj.seq_file.manifest.fs_hz;
            info.n_channels = obj.seq_file.manifest.n_channels;
            info.audio_hash = obj.seq_file.manifest.audio_hash;
        end
    end

    methods (Access = private)
        function validate_sequence_file(obj, seq_file)
            % Validate SequenceFile structure

            required_fields = {'audio', 'ttl', 'events', 'manifest'};
            for i = 1:length(required_fields)
                if ~isfield(seq_file, required_fields{i})
                    error('DAQEngine:InvalidSequence', ...
                        'SequenceFile missing required field: %s', required_fields{i});
                end
            end

            % Validate manifest
            if ~isfield(seq_file.manifest, 'fs_hz')
                error('DAQEngine:InvalidSequence', 'Manifest missing fs_hz');
            end
        end

        function init_hardware_session(obj)
            % Initialize NI-DAQ hardware session (hardware mode only)

            if ~isfield(obj.config, 'device_id')
                error('DAQEngine:MissingConfig', 'Hardware mode requires device_id');
            end

            % Note: Actual DAQ initialization would use MATLAB's Data Acquisition Toolbox
            % For now, this is a placeholder
            fprintf('Hardware session initialized: %s\n', obj.config.device_id);
        end

        function result = play_hardware(obj)
            % Play SequenceFile on real hardware
            %
            % Note: This requires NI-DAQ hardware and Data Acquisition Toolbox

            error('DAQEngine:NotImplemented', ...
                'Hardware playback requires NI-DAQ and Data Acquisition Toolbox. Use dry_run mode for testing.');
        end

        function result = play_dry_run(obj)
            % Simulate playback (no hardware)

            fprintf('Starting dry-run playback...\n');

            start_time = datetime('now');
            obj.state = 'playing';

            % Simulate playback timing
            if obj.config.real_time
                % Real-time simulation: pause for actual duration
                pause(obj.seq_file.manifest.duration_ms / 1000);
            else
                % Fast simulation: no pause
            end

            end_time = datetime('now');
            duration_ms = milliseconds(end_time - start_time);

            % Build events table with simulated timestamps
            events = obj.seq_file.events;
            events.timestamp_ms = events.time_ms;  % In dry-run, timestamps = scheduled times

            % Build TTL events if mapping provided
            ttl_events = [];
            if isfield(obj.config, 'ttl_mapping')
                ttl_events = obj.build_ttl_events();
            end

            % Package result
            result = struct();
            result.success = true;
            result.start_time = datestr(start_time, 'yyyy-mm-dd HH:MM:SS.FFF');
            result.end_time = datestr(end_time, 'yyyy-mm-dd HH:MM:SS.FFF');
            result.duration_ms = duration_ms;
            result.events_played = height(events);
            result.events = events;
            result.ttl_events = ttl_events;
            result.sequence_hash = obj.seq_file.manifest.audio_hash;

            fprintf('Dry-run playback complete: %d events played\n', result.events_played);
        end

        function ttl_events = build_ttl_events(obj)
            % Build TTL events from TTL codes and mapping

            ttl_mapping = obj.config.ttl_mapping;
            events = obj.seq_file.events;

            ttl_events = table();
            ttl_events.sample_index = events.sample_index;
            ttl_events.time_ms = events.time_ms;
            ttl_events.code = events.code;
            ttl_events.channel = cell(height(events), 1);

            for i = 1:height(events)
                code = events.code(i);
                if isKey(ttl_mapping, code)
                    ttl_events.channel{i} = ttl_mapping(code);
                else
                    ttl_events.channel{i} = 'unmapped';
                end
            end
        end
    end
end
