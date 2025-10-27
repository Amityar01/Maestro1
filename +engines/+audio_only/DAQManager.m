classdef DAQManager < handle
    % DAQMANAGER - Manages DAQ session initialization and cleanup
    %
    % This class extracts DAQ management logic from execute.m
    % to improve testability and separation of concerns.
    %
    % Usage:
    %   daq_mgr = DAQManager(sampling_rate_hz, config);
    %   daq_mgr.initialize();
    %   daq_mgr.play_audio(audio_data);
    %   daq_mgr.cleanup();

    properties (SetAccess = private)
        sampling_rate_hz    % Sampling rate
        config              % DAQ configuration struct
        session             % DAQ session object
        vendor              % Vendor string
        device_id           % Device identifier
        audio_channels      % Cell array of audio channel names
        trigger_channel     % Trigger channel name
        trigger_config      % Trigger configuration struct
        is_initialized      % Boolean flag
    end

    methods
        function obj = DAQManager(sampling_rate_hz, config)
            % DAQMANAGER - Constructor
            %
            % INPUTS:
            %   sampling_rate_hz - numeric, sampling rate
            %   config - struct, DAQ configuration (optional)

            obj.sampling_rate_hz = sampling_rate_hz;

            if nargin < 2 || isempty(config)
                config = struct();
            end
            obj.config = config;

            % Extract configuration with defaults from Constants
            obj.vendor = obj.get_config_field('vendor', core.Constants.DEFAULT_DAQ_VENDOR);
            obj.device_id = obj.get_config_field('device_id', core.Constants.DEFAULT_DAQ_DEVICE);

            % Audio channels (support single channel or cell array)
            if isfield(config, 'audio_channels')
                channels = config.audio_channels;
                if ischar(channels) || isstring(channels)
                    obj.audio_channels = {char(channels)};
                else
                    obj.audio_channels = channels;
                end
            else
                obj.audio_channels = {core.Constants.DEFAULT_AUDIO_CHANNEL};
            end

            obj.trigger_channel = obj.get_config_field('trigger_channel', ...
                core.Constants.DEFAULT_TRIGGER_CHANNEL);

            % Trigger configuration
            if isfield(config, 'trigger_config')
                obj.trigger_config = config.trigger_config;
            else
                obj.trigger_config = struct();
                obj.trigger_config.voltage = core.Constants.DEFAULT_TTL_VOLTAGE;
                obj.trigger_config.duration_ms = core.Constants.DEFAULT_TTL_DURATION_MS;
            end

            obj.is_initialized = false;
        end

        function initialize(obj)
            % INITIALIZE - Initialize DAQ session
            %
            % Creates and configures the DAQ session with all channels

            if obj.is_initialized
                warning('DAQManager:AlreadyInitialized', ...
                    'DAQ session already initialized');
                return;
            end

            fprintf('Initializing DAQ...\n');

            % Create session
            obj.session = daq.createSession(obj.vendor);
            obj.session.Rate = obj.sampling_rate_hz;

            % Add audio output channels
            for i = 1:length(obj.audio_channels)
                addAnalogOutputChannel(obj.session, obj.device_id, ...
                    obj.audio_channels{i}, 'Voltage');
            end

            % Add trigger channel
            addAnalogOutputChannel(obj.session, obj.device_id, ...
                obj.trigger_channel, 'Voltage');

            obj.is_initialized = true;

            % Display configuration
            fprintf('  ✓ DAQ initialized\n');
            fprintf('    Sampling rate: %d Hz\n', obj.sampling_rate_hz);
            fprintf('    Vendor: %s\n', obj.vendor);
            fprintf('    Device: %s\n', obj.device_id);
            fprintf('    Audio channels: %s\n', strjoin(obj.audio_channels, ', '));
            fprintf('    Trigger channel: %s\n', obj.trigger_channel);
            fprintf('\n');
        end

        function play_trial(obj, audio_data, ttl_signal)
            % PLAY_TRIAL - Queue and play audio with TTL trigger
            %
            % INPUTS:
            %   audio_data - column vector, audio samples
            %   ttl_signal - column vector, TTL trigger signal

            if ~obj.is_initialized
                error('DAQManager:NotInitialized', ...
                    'DAQ session not initialized. Call initialize() first.');
            end

            % Combine audio + TTL into output matrix
            % [audio_ch1, ..., audio_chN, trigger]
            if size(audio_data, 2) == 1
                % Single channel audio - replicate for all audio channels if needed
                audio_matrix = repmat(audio_data, 1, length(obj.audio_channels));
            else
                audio_matrix = audio_data;
            end

            output_matrix = [audio_matrix, ttl_signal];

            % Queue data
            queueOutputData(obj.session, output_matrix);

            % Start playback (blocking)
            startForeground(obj.session);
        end

        function play_trial_async(obj, audio_data, ttl_signal)
            % PLAY_TRIAL_ASYNC - Queue and play audio asynchronously
            %
            % INPUTS:
            %   audio_data - column vector, audio samples
            %   ttl_signal - column vector, TTL trigger signal
            %
            % Returns immediately. Use wait() to block until complete.

            if ~obj.is_initialized
                error('DAQManager:NotInitialized', ...
                    'DAQ session not initialized. Call initialize() first.');
            end

            % Combine audio + TTL into output matrix
            if size(audio_data, 2) == 1
                audio_matrix = repmat(audio_data, 1, length(obj.audio_channels));
            else
                audio_matrix = audio_data;
            end

            output_matrix = [audio_matrix, ttl_signal];

            % Queue and start background playback
            queueOutputData(obj.session, output_matrix);
            startBackground(obj.session);
        end

        function wait(obj)
            % WAIT - Wait for asynchronous playback to complete

            if ~obj.is_initialized
                return;
            end

            wait(obj.session);
        end

        function ttl_signal = generate_ttl_pulse(obj, n_samples)
            % GENERATE_TTL_PULSE - Generate TTL trigger pulse
            %
            % INPUTS:
            %   n_samples - integer, total number of samples
            %
            % OUTPUTS:
            %   ttl_signal - column vector, TTL pulse signal

            voltage = obj.trigger_config.voltage;
            duration_ms = obj.trigger_config.duration_ms;

            % Calculate pulse duration in samples
            pulse_samples = round(duration_ms * obj.sampling_rate_hz / 1000);

            % Create pulse
            ttl_signal = zeros(n_samples, 1);
            ttl_signal(1:pulse_samples) = voltage;
        end

        function cleanup(obj)
            % CLEANUP - Close and release DAQ session

            if ~obj.is_initialized
                return;
            end

            try
                if ~isempty(obj.session) && isvalid(obj.session)
                    stop(obj.session);
                    release(obj.session);
                end
                obj.is_initialized = false;
            catch ME
                warning('DAQManager:CleanupError', ...
                    'Error during cleanup: %s', ME.message);
            end
        end

        function info = get_info(obj)
            % GET_INFO - Get DAQ configuration information
            %
            % OUTPUTS:
            %   info - struct with configuration details

            info = struct();
            info.vendor_info = obj.vendor;
            info.device_info = obj.device_id;
            info.sampling_rate_hz = obj.sampling_rate_hz;
            info.audio_channels = obj.audio_channels;
            info.n_channels = length(obj.audio_channels) + 1;  % audio + trigger
            info.trigger_config = obj.trigger_config;
            info.is_initialized = obj.is_initialized;
        end
    end

    methods (Access = private)
        function value = get_config_field(obj, field_name, default_value)
            % GET_CONFIG_FIELD - Get configuration field or default
            %
            % INPUTS:
            %   field_name - string, field name
            %   default_value - any, default if field missing
            %
            % OUTPUTS:
            %   value - field value or default

            if isfield(obj.config, field_name) && ~isempty(obj.config.(field_name))
                value = obj.config.(field_name);
            else
                value = default_value;
            end
        end
    end

    methods
        function delete(obj)
            % Destructor - ensure cleanup on object destruction
            obj.cleanup();
        end
    end
end
