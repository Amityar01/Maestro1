classdef TestDAQEngine < matlab.unittest.TestCase
    % TestDAQEngine - Tests for DAQ playback engine
    %
    % Following TDD: These tests define the API we want.
    % The DAQEngine should play SequenceFiles on NI-DAQ hardware.
    %
    % Test coverage:
    %   - SequenceFile loading and validation
    %   - Hardware configuration (channels, sample rate)
    %   - Dry-run mode (no hardware required)
    %   - Playback control (start, stop, pause)
    %   - Event recording and timing
    %   - TTL output synchronization
    %   - Error handling (hardware not found, wrong sample rate)

    properties
        engine
        mock_seq_file
    end

    methods (TestMethodSetup)
        function setup(testCase)
            % Create DAQ engine instance
            testCase.engine = v1.daq.DAQEngine();

            % Create mock SequenceFile for testing
            testCase.mock_seq_file = testCase.create_mock_sequence_file();
        end
    end

    methods (Test)
        %% Basic Functionality

        function testEngineCreation(testCase)
            % Test that engine can be created
            testCase.verifyTrue(isa(testCase.engine, 'v1.daq.DAQEngine'));
        end

        function testLoadSequenceFile(testCase)
            % Test loading a SequenceFile
            testCase.engine.load_sequence(testCase.mock_seq_file);

            testCase.verifyTrue(testCase.engine.is_loaded(), 'SequenceFile should be loaded');
        end

        function testGetSequenceInfo(testCase)
            % Test retrieving SequenceFile information
            testCase.engine.load_sequence(testCase.mock_seq_file);

            info = testCase.engine.get_sequence_info();

            testCase.verifyTrue(isfield(info, 'duration_ms'));
            testCase.verifyTrue(isfield(info, 'n_trials'));
            testCase.verifyTrue(isfield(info, 'n_events'));
            testCase.verifyTrue(isfield(info, 'fs_hz'));
        end

        %% Hardware Configuration

        function testConfigureHardware(testCase)
            % Test hardware configuration
            config = struct();
            config.device_id = 'Dev1';
            config.audio_channels = [0 1];
            config.ttl_channel = 'port0/line0';
            config.mode = 'dry_run';  % No actual hardware

            testCase.engine.configure(config);

            testCase.verifyTrue(testCase.engine.is_configured(), 'Should be configured');
        end

        function testGetHardwareConfig(testCase)
            % Test retrieving hardware configuration
            config = struct();
            config.device_id = 'Dev1';
            config.audio_channels = [0 1];
            config.ttl_channel = 'port0/line0';
            config.mode = 'dry_run';

            testCase.engine.configure(config);
            retrieved_config = testCase.engine.get_config();

            testCase.verifyEqual(retrieved_config.device_id, 'Dev1');
            testCase.verifyEqual(retrieved_config.audio_channels, [0 1]);
        end

        %% Dry-Run Mode

        function testDryRunPlayback(testCase)
            % Test playback in dry-run mode (no hardware)
            config = struct();
            config.mode = 'dry_run';

            testCase.engine.configure(config);
            testCase.engine.load_sequence(testCase.mock_seq_file);

            % Should complete without error
            result = testCase.engine.play();

            testCase.verifyTrue(result.success, 'Dry-run should succeed');
            testCase.verifyTrue(isfield(result, 'duration_ms'));
            testCase.verifyTrue(isfield(result, 'events_played'));
        end

        function testDryRunTiming(testCase)
            % Test that dry-run mode tracks timing correctly
            config = struct();
            config.mode = 'dry_run';
            config.real_time = false;  % Fast simulation

            testCase.engine.configure(config);
            testCase.engine.load_sequence(testCase.mock_seq_file);

            tic;
            result = testCase.engine.play();
            elapsed = toc;

            % Fast simulation should complete quickly
            testCase.verifyLessThan(elapsed, 1.0, 'Fast simulation should be < 1s');
            testCase.verifyEqual(result.events_played, 3, 'Should play all 3 events');
        end

        %% Playback Control

        function testPlaybackState(testCase)
            % Test playback state tracking
            config = struct();
            config.mode = 'dry_run';

            testCase.engine.configure(config);
            testCase.engine.load_sequence(testCase.mock_seq_file);

            testCase.verifyEqual(testCase.engine.get_state(), 'ready');

            % After play, state should be 'completed'
            testCase.engine.play();
            testCase.verifyEqual(testCase.engine.get_state(), 'completed');
        end

        function testStopPlayback(testCase)
            % Test stopping playback mid-sequence
            config = struct();
            config.mode = 'dry_run';
            config.real_time = true;  % Slow playback for testing stop

            testCase.engine.configure(config);
            testCase.engine.load_sequence(testCase.mock_seq_file);

            % Start playback in background (would need async support)
            % For now, test that stop() method exists and doesn't error
            testCase.verifyTrue(ismethod(testCase.engine, 'stop'));
        end

        function testResetEngine(testCase)
            % Test resetting engine after playback
            config = struct();
            config.mode = 'dry_run';

            testCase.engine.configure(config);
            testCase.engine.load_sequence(testCase.mock_seq_file);
            testCase.engine.play();

            testCase.engine.reset();

            testCase.verifyEqual(testCase.engine.get_state(), 'idle');
            testCase.verifyFalse(testCase.engine.is_loaded());
        end

        %% Event Recording

        function testEventRecording(testCase)
            % Test that events are recorded during playback
            config = struct();
            config.mode = 'dry_run';

            testCase.engine.configure(config);
            testCase.engine.load_sequence(testCase.mock_seq_file);

            result = testCase.engine.play();

            testCase.verifyTrue(isfield(result, 'events'));
            testCase.verifyEqual(height(result.events), 3, 'Should record 3 events');
        end

        function testEventTimestamps(testCase)
            % Test that event timestamps are recorded
            config = struct();
            config.mode = 'dry_run';

            testCase.engine.configure(config);
            testCase.engine.load_sequence(testCase.mock_seq_file);

            result = testCase.engine.play();

            % Events should have timestamp field
            testCase.verifyTrue(ismember('timestamp_ms', result.events.Properties.VariableNames));

            % Timestamps should be increasing
            timestamps = result.events.timestamp_ms;
            testCase.verifyTrue(all(diff(timestamps) >= 0), 'Timestamps should be monotonic');
        end

        %% Validation

        function testLoadWithoutSequence(testCase)
            % Test that playing without loading sequence causes error
            config = struct();
            config.mode = 'dry_run';

            testCase.engine.configure(config);

            testCase.verifyError(...
                @() testCase.engine.play(), ...
                'DAQEngine:NoSequence');
        end

        function testPlayWithoutConfiguration(testCase)
            % Test that playing without configuration causes error
            testCase.engine.load_sequence(testCase.mock_seq_file);

            testCase.verifyError(...
                @() testCase.engine.play(), ...
                'DAQEngine:NotConfigured');
        end

        function testInvalidSampleRate(testCase)
            % Test error when SequenceFile sample rate doesn't match hardware
            config = struct();
            config.mode = 'dry_run';
            config.fs_hz = 96000;  % Different from SequenceFile (48000)

            testCase.engine.configure(config);
            testCase.engine.load_sequence(testCase.mock_seq_file);

            testCase.verifyError(...
                @() testCase.engine.play(), ...
                'DAQEngine:SampleRateMismatch');
        end

        %% TTL Output

        function testTTLMapping(testCase)
            % Test TTL code to channel mapping
            config = struct();
            config.mode = 'dry_run';
            config.ttl_mapping = containers.Map([1 2], {'port0/line0', 'port0/line1'});

            testCase.engine.configure(config);
            testCase.engine.load_sequence(testCase.mock_seq_file);

            result = testCase.engine.play();

            % Verify TTL codes were mapped
            testCase.verifyTrue(isfield(result, 'ttl_events'));
        end

        %% Metadata

        function testPlaybackMetadata(testCase)
            % Test that playback metadata is returned
            config = struct();
            config.mode = 'dry_run';

            testCase.engine.configure(config);
            testCase.engine.load_sequence(testCase.mock_seq_file);

            result = testCase.engine.play();

            testCase.verifyTrue(isfield(result, 'start_time'));
            testCase.verifyTrue(isfield(result, 'end_time'));
            testCase.verifyTrue(isfield(result, 'duration_ms'));
            testCase.verifyTrue(isfield(result, 'success'));
        end

        function testSequenceHash(testCase)
            % Test that sequence hash is included in playback metadata
            config = struct();
            config.mode = 'dry_run';

            testCase.engine.configure(config);
            testCase.engine.load_sequence(testCase.mock_seq_file);

            result = testCase.engine.play();

            testCase.verifyTrue(isfield(result, 'sequence_hash'));
            testCase.verifyEqual(result.sequence_hash, testCase.mock_seq_file.manifest.audio_hash);
        end
    end

    methods (Access = private)
        function seq_file = create_mock_sequence_file(testCase)
            % Create mock SequenceFile for testing

            % Simple 3-element sequence
            fs_hz = 48000;
            duration_samples = fs_hz * 2;  % 2 seconds

            % Audio: zeros with 3 tone bursts
            audio = zeros(duration_samples, 2, 'single');

            % Add some non-zero audio at event times
            event_samples = [1, round(0.65*fs_hz), round(1.3*fs_hz)];
            for i = 1:length(event_samples)
                sample_idx = event_samples(i);
                burst_length = round(0.15 * fs_hz);  % 150ms
                if sample_idx + burst_length <= duration_samples
                    audio(sample_idx:sample_idx+burst_length-1, :) = 0.5;
                end
            end

            % TTL codes
            ttl = zeros(duration_samples, 1, 'uint8');
            for i = 1:length(event_samples)
                sample_idx = event_samples(i);
                ttl(sample_idx:sample_idx+9) = i;  % 10-sample pulse
            end

            % Events table
            events = table();
            events.sample_index = event_samples';
            events.time_ms = [0; 650; 1300];
            events.trial_index = [0; 1; 2];
            events.element_index = [0; 0; 0];
            events.code = [1; 2; 1];

            % Trial table
            trial_table = table();
            trial_table.trial_index = [0; 1; 2];
            trial_table.label = {'standard'; 'deviant'; 'standard'};
            trial_table.n_elements = [1; 1; 1];

            % Manifest
            manifest = struct();
            manifest.version = 'v1.0';
            manifest.fs_hz = fs_hz;
            manifest.n_channels = 2;
            manifest.n_trials = 3;
            manifest.n_elements = 3;
            manifest.duration_samples = duration_samples;
            manifest.duration_ms = 2000;
            manifest.compiled_at = datestr(now);
            manifest.audio_hash = 'mock_hash_1234567890abcdef';

            % Package
            seq_file = struct();
            seq_file.audio = audio;
            seq_file.ttl = ttl;
            seq_file.events = events;
            seq_file.trial_table = trial_table;
            seq_file.manifest = manifest;
        end
    end
end
