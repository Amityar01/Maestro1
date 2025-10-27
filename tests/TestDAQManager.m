classdef TestDAQManager < matlab.unittest.TestCase
    % TESTDAQMANAGER - Unit tests for DAQManager
    %
    % Tests DAQ configuration, initialization, and signal generation.
    % Note: These tests don't require actual hardware.

    methods (Test)
        % ============================================================
        % Construction Tests
        % ============================================================

        function testConstructor_MinimalConfig(testCase)
            % Test construction with minimal configuration

            daq_mgr = engines.audio_only.DAQManager(192000, struct());

            testCase.verifyEqual(daq_mgr.sampling_rate_hz, 192000);
            testCase.verifyFalse(daq_mgr.is_initialized);
        end

        function testConstructor_DefaultsApplied(testCase)
            % Test that defaults are applied correctly

            daq_mgr = engines.audio_only.DAQManager(96000, struct());

            % Verify defaults from Constants
            testCase.verifyEqual(daq_mgr.vendor, core.Constants.DEFAULT_DAQ_VENDOR);
            testCase.verifyEqual(daq_mgr.device_id, core.Constants.DEFAULT_DAQ_DEVICE);
            testCase.verifyEqual(daq_mgr.audio_channels{1}, core.Constants.DEFAULT_AUDIO_CHANNEL);
            testCase.verifyEqual(daq_mgr.trigger_channel, core.Constants.DEFAULT_TRIGGER_CHANNEL);
        end

        function testConstructor_CustomConfig(testCase)
            % Test construction with custom configuration

            config = struct();
            config.vendor = 'custom_vendor';
            config.device_id = 'CustomDev';
            config.audio_channels = {'ao2', 'ao3'};
            config.trigger_channel = 'ao4';

            daq_mgr = engines.audio_only.DAQManager(48000, config);

            testCase.verifyEqual(daq_mgr.vendor, 'custom_vendor');
            testCase.verifyEqual(daq_mgr.device_id, 'CustomDev');
            testCase.verifyEqual(length(daq_mgr.audio_channels), 2);
            testCase.verifyEqual(daq_mgr.trigger_channel, 'ao4');
        end

        function testConstructor_SingleChannelString(testCase)
            % Test that single channel as string is converted to cell

            config = struct();
            config.audio_channels = 'ao0';

            daq_mgr = engines.audio_only.DAQManager(192000, config);

            testCase.verifyTrue(iscell(daq_mgr.audio_channels));
            testCase.verifyEqual(length(daq_mgr.audio_channels), 1);
            testCase.verifyEqual(daq_mgr.audio_channels{1}, 'ao0');
        end

        function testConstructor_TriggerConfig(testCase)
            % Test trigger configuration

            config = struct();
            config.trigger_config = struct(...
                'voltage', 3.3, ...
                'duration_ms', 5);

            daq_mgr = engines.audio_only.DAQManager(192000, config);

            testCase.verifyEqual(daq_mgr.trigger_config.voltage, 3.3);
            testCase.verifyEqual(daq_mgr.trigger_config.duration_ms, 5);
        end

        % ============================================================
        % TTL Pulse Generation Tests
        % ============================================================

        function testGenerateTTLPulse_DefaultConfig(testCase)
            % Test TTL pulse generation with default config

            daq_mgr = engines.audio_only.DAQManager(192000, struct());
            n_samples = 192000;  % 1 second

            ttl_signal = daq_mgr.generate_ttl_pulse(n_samples);

            % Verify output shape
            testCase.verifyEqual(size(ttl_signal, 1), n_samples);
            testCase.verifyEqual(size(ttl_signal, 2), 1);  % Column vector

            % Verify pulse characteristics
            pulse_samples = round(core.Constants.DEFAULT_TTL_DURATION_MS * 192000 / 1000);
            testCase.verifyEqual(ttl_signal(1), core.Constants.DEFAULT_TTL_VOLTAGE);
            testCase.verifyEqual(ttl_signal(pulse_samples), core.Constants.DEFAULT_TTL_VOLTAGE);
            testCase.verifyEqual(ttl_signal(pulse_samples + 1), 0);
            testCase.verifyEqual(ttl_signal(end), 0);
        end

        function testGenerateTTLPulse_CustomConfig(testCase)
            % Test TTL pulse generation with custom config

            config = struct();
            config.trigger_config = struct(...
                'voltage', 3.3, ...
                'duration_ms', 20);

            daq_mgr = engines.audio_only.DAQManager(96000, config);
            n_samples = 96000;

            ttl_signal = daq_mgr.generate_ttl_pulse(n_samples);

            % Verify custom voltage
            testCase.verifyEqual(ttl_signal(1), 3.3);

            % Verify custom duration
            pulse_samples = round(20 * 96000 / 1000);
            testCase.verifyEqual(ttl_signal(pulse_samples), 3.3);
            testCase.verifyEqual(ttl_signal(pulse_samples + 1), 0);
        end

        function testGenerateTTLPulse_VeryShortDuration(testCase)
            % Test TTL pulse with very short duration

            config = struct();
            config.trigger_config = struct(...
                'voltage', 5.0, ...
                'duration_ms', 0.1);  % 0.1 ms

            daq_mgr = engines.audio_only.DAQManager(192000, config);
            n_samples = 1000;

            ttl_signal = daq_mgr.generate_ttl_pulse(n_samples);

            % Verify at least 1 sample is high
            testCase.verifyGreaterThan(max(ttl_signal), 0);

            % Verify most samples are zero
            testCase.verifyLessThan(nnz(ttl_signal), 0.1 * n_samples);
        end

        function testGenerateTTLPulse_DifferentSamplingRates(testCase)
            % Test TTL pulse generation at different sampling rates

            rates = [8000, 48000, 96000, 192000, 500000];

            for rate = rates
                daq_mgr = engines.audio_only.DAQManager(rate, struct());
                n_samples = rate;  % 1 second

                ttl_signal = daq_mgr.generate_ttl_pulse(n_samples);

                % Verify correct length
                testCase.verifyEqual(length(ttl_signal), n_samples);

                % Verify pulse exists
                testCase.verifyGreaterThan(max(ttl_signal), 0);

                % Verify mostly zeros after pulse
                testCase.verifyLessThan(nnz(ttl_signal), 0.2 * n_samples);
            end
        end

        % ============================================================
        % Information Retrieval Tests
        % ============================================================

        function testGetInfo_ReturnsCorrectStructure(testCase)
            % Test that get_info returns correct structure

            config = struct();
            config.vendor = 'test_vendor';
            config.device_id = 'TestDev';
            config.audio_channels = {'ao0', 'ao1'};

            daq_mgr = engines.audio_only.DAQManager(192000, config);
            info = daq_mgr.get_info();

            % Verify all required fields present
            testCase.verifyTrue(isfield(info, 'vendor_info'));
            testCase.verifyTrue(isfield(info, 'device_info'));
            testCase.verifyTrue(isfield(info, 'sampling_rate_hz'));
            testCase.verifyTrue(isfield(info, 'audio_channels'));
            testCase.verifyTrue(isfield(info, 'n_channels'));
            testCase.verifyTrue(isfield(info, 'trigger_config'));
            testCase.verifyTrue(isfield(info, 'is_initialized'));

            % Verify values
            testCase.verifyEqual(info.vendor_info, 'test_vendor');
            testCase.verifyEqual(info.device_info, 'TestDev');
            testCase.verifyEqual(info.sampling_rate_hz, 192000);
            testCase.verifyEqual(info.n_channels, 3);  % 2 audio + 1 trigger
            testCase.verifyFalse(info.is_initialized);
        end

        function testGetInfo_ChannelCount(testCase)
            % Test channel count calculation

            % Single audio channel
            config1 = struct('audio_channels', {{'ao0'}});
            daq_mgr1 = engines.audio_only.DAQManager(192000, config1);
            info1 = daq_mgr1.get_info();
            testCase.verifyEqual(info1.n_channels, 2);  % 1 audio + 1 trigger

            % Multiple audio channels
            config2 = struct('audio_channels', {{'ao0', 'ao1', 'ao2'}});
            daq_mgr2 = engines.audio_only.DAQManager(192000, config2);
            info2 = daq_mgr2.get_info();
            testCase.verifyEqual(info2.n_channels, 4);  % 3 audio + 1 trigger
        end

        % ============================================================
        % Configuration Validation Tests
        % ============================================================

        function testConfiguration_EmptyConfig(testCase)
            % Test that empty config uses all defaults

            daq_mgr = engines.audio_only.DAQManager(192000, struct());
            info = daq_mgr.get_info();

            testCase.verifyEqual(info.vendor_info, core.Constants.DEFAULT_DAQ_VENDOR);
            testCase.verifyEqual(info.device_info, core.Constants.DEFAULT_DAQ_DEVICE);
            testCase.verifyEqual(info.trigger_config.voltage, core.Constants.DEFAULT_TTL_VOLTAGE);
            testCase.verifyEqual(info.trigger_config.duration_ms, core.Constants.DEFAULT_TTL_DURATION_MS);
        end

        function testConfiguration_PartialConfig(testCase)
            % Test that partial config merges with defaults

            config = struct('vendor', 'custom_vendor');
            daq_mgr = engines.audio_only.DAQManager(192000, config);
            info = daq_mgr.get_info();

            % Custom value used
            testCase.verifyEqual(info.vendor_info, 'custom_vendor');

            % Defaults used for rest
            testCase.verifyEqual(info.device_info, core.Constants.DEFAULT_DAQ_DEVICE);
            testCase.verifyEqual(length(info.audio_channels), 1);
        end

        % ============================================================
        % State Management Tests
        % ============================================================

        function testInitializationState_InitiallyFalse(testCase)
            % Test that is_initialized is initially false

            daq_mgr = engines.audio_only.DAQManager(192000, struct());
            testCase.verifyFalse(daq_mgr.is_initialized);

            info = daq_mgr.get_info();
            testCase.verifyFalse(info.is_initialized);
        end

        % Note: We can't test actual initialization without hardware,
        % but we've tested all the configuration and helper methods.
    end
end
