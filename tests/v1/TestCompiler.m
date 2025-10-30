classdef TestCompiler < matlab.unittest.TestCase
    % TestCompiler - Tests for SequenceFile compiler
    %
    % Following TDD: These tests define the API we want.
    % The CompilerCore should convert element tables → SequenceFiles.
    %
    % Test coverage:
    %   - Element table → audio buffer compilation
    %   - TTL code injection at element onsets
    %   - Audio stitching with timing
    %   - Metadata packaging (trial table, element table, manifest)
    %   - Hash computation for provenance
    %   - SequenceFile structure validation
    %   - Integration with generators
    %   - Multi-element trials (Local-Global)

    properties
        compiler
        fs_hz
        stimulus_library
        rng_manager
        sampler
        context
    end

    methods (TestMethodSetup)
        function setup(testCase)
            % Create compiler instance
            testCase.compiler = v1.compilation.CompilerCore();

            % Setup audio parameters
            testCase.fs_hz = 48000;  % 48 kHz sampling rate

            % Setup stimulus library (mock definitions)
            testCase.stimulus_library = containers.Map();
            testCase.stimulus_library('tone_1000hz') = struct(...
                'type', 'tone.simple', ...
                'frequency_hz', 1000, ...
                'duration_ms', 150, ...
                'level', struct('value', 0.7, 'unit', 'linear_0_1'), ...
                'envelope', struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine'), ...
                'routing', struct('channels', [0 1]));

            testCase.stimulus_library('tone_1200hz') = struct(...
                'type', 'tone.simple', ...
                'frequency_hz', 1200, ...
                'duration_ms', 150, ...
                'level', struct('value', 0.7, 'unit', 'linear_0_1'), ...
                'envelope', struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine'), ...
                'routing', struct('channels', [0 1]));

            % Setup RNG and sampling
            testCase.rng_manager = v1.sampling.RNGStreamManager(12345);
            testCase.sampler = v1.sampling.NumericFieldSampler(testCase.rng_manager);
            testCase.context = v1.generators.GeneratorContext('fs_hz', testCase.fs_hz, ...
                                                              'sampler', testCase.sampler);
            testCase.context.set_rng_manager(testCase.rng_manager);
        end
    end

    methods (Test)
        %% Basic Functionality

        function testBasicCompilation(testCase)
            % Test basic element table → SequenceFile compilation
            element_table = testCase.create_simple_element_table(3);  % 3 elements

            seq_file = testCase.compiler.compile(element_table, testCase.stimulus_library, ...
                                                 testCase.fs_hz, testCase.context);

            % Verify SequenceFile structure
            testCase.verifyTrue(isstruct(seq_file), 'Output should be struct');
            testCase.verifyTrue(isfield(seq_file, 'audio'), 'Should have audio');
            testCase.verifyTrue(isfield(seq_file, 'ttl'), 'Should have ttl');
            testCase.verifyTrue(isfield(seq_file, 'events'), 'Should have events');
            testCase.verifyTrue(isfield(seq_file, 'trial_table'), 'Should have trial_table');
            testCase.verifyTrue(isfield(seq_file, 'element_table'), 'Should have element_table');
            testCase.verifyTrue(isfield(seq_file, 'manifest'), 'Should have manifest');
        end

        function testAudioBufferSize(testCase)
            % Test that audio buffer is correctly sized
            element_table = testCase.create_simple_element_table(3);

            % Last element ends at: 1300 ms (element 2 onset) + 150 ms (duration) = 1450 ms
            % Buffer should be at least 1450 ms = 69600 samples at 48 kHz
            expected_min_samples = ceil(1.450 * testCase.fs_hz);

            seq_file = testCase.compiler.compile(element_table, testCase.stimulus_library, ...
                                                 testCase.fs_hz, testCase.context);

            testCase.verifyGreaterThanOrEqual(size(seq_file.audio, 1), expected_min_samples, ...
                'Audio buffer should cover all elements');
        end

        function testAudioChannels(testCase)
            % Test that audio has correct number of channels
            element_table = testCase.create_simple_element_table(2);

            seq_file = testCase.compiler.compile(element_table, testCase.stimulus_library, ...
                                                 testCase.fs_hz, testCase.context);

            % Stimuli routed to [0 1] → 2 channels
            testCase.verifyEqual(size(seq_file.audio, 2), 2, 'Should have 2 audio channels');
        end

        %% TTL Code Injection

        function testTTLCodeInjection(testCase)
            % Test that TTL codes are injected at correct sample indices
            element_table = testCase.create_simple_element_table(3);

            % Add TTL codes
            element_table.ttl_code = [1; 2; 1];

            seq_file = testCase.compiler.compile(element_table, testCase.stimulus_library, ...
                                                 testCase.fs_hz, testCase.context);

            % TTL buffer should match audio buffer length
            testCase.verifyEqual(size(seq_file.ttl, 1), size(seq_file.audio, 1), ...
                'TTL and audio buffers should have same length');

            % Check TTL codes at element onsets
            onset_samples = round(element_table.absolute_onset_ms / 1000 * testCase.fs_hz) + 1;

            for i = 1:height(element_table)
                sample_idx = onset_samples(i);
                testCase.verifyEqual(seq_file.ttl(sample_idx), element_table.ttl_code(i), ...
                    sprintf('TTL code %d should be at sample %d', element_table.ttl_code(i), sample_idx));
            end
        end

        function testTTLPulseDuration(testCase)
            % Test that TTL pulses have correct duration (e.g., 10 samples)
            element_table = testCase.create_simple_element_table(1);
            element_table.ttl_code = 5;

            seq_file = testCase.compiler.compile(element_table, testCase.stimulus_library, ...
                                                 testCase.fs_hz, testCase.context);

            onset_sample = round(element_table.absolute_onset_ms(1) / 1000 * testCase.fs_hz) + 1;
            ttl_pulse_duration = 10;  % samples

            % Check pulse is high for 10 samples
            pulse_region = seq_file.ttl(onset_sample : onset_sample + ttl_pulse_duration - 1);
            testCase.verifyTrue(all(pulse_region == 5), 'TTL pulse should be high for 10 samples');

            % Check pulse returns to 0 after
            if onset_sample + ttl_pulse_duration <= length(seq_file.ttl)
                testCase.verifyEqual(seq_file.ttl(onset_sample + ttl_pulse_duration), 0, ...
                    'TTL should return to 0 after pulse');
            end
        end

        %% Audio Generation

        function testAudioGeneration(testCase)
            % Test that audio is generated for each element
            element_table = testCase.create_simple_element_table(2);

            seq_file = testCase.compiler.compile(element_table, testCase.stimulus_library, ...
                                                 testCase.fs_hz, testCase.context);

            % Audio should be non-zero where stimuli are placed
            onset_sample_1 = round(element_table.absolute_onset_ms(1) / 1000 * testCase.fs_hz) + 1;
            duration_samples = round(element_table.duration_ms(1) / 1000 * testCase.fs_hz);

            audio_region_1 = seq_file.audio(onset_sample_1 : onset_sample_1 + duration_samples - 1, 1);

            testCase.verifyGreaterThan(max(abs(audio_region_1)), 0, ...
                'Audio should be non-zero during stimulus');
        end

        function testSilenceBetweenElements(testCase)
            % Test that there's silence between elements (ITI)
            element_table = testCase.create_simple_element_table(2);

            seq_file = testCase.compiler.compile(element_table, testCase.stimulus_library, ...
                                                 testCase.fs_hz, testCase.context);

            % Gap between element 0 (ends at 150 ms) and element 1 (starts at 650 ms)
            % Check silence from 200 ms to 600 ms
            silence_start = round(0.200 * testCase.fs_hz) + 1;
            silence_end = round(0.600 * testCase.fs_hz);

            silence_region = seq_file.audio(silence_start:silence_end, 1);
            testCase.verifyLessThan(max(abs(silence_region)), 1e-6, ...
                'Should be silence between elements');
        end

        %% Events Table

        function testEventsTable(testCase)
            % Test that events table is generated
            element_table = testCase.create_simple_element_table(3);
            element_table.ttl_code = [1; 2; 1];

            seq_file = testCase.compiler.compile(element_table, testCase.stimulus_library, ...
                                                 testCase.fs_hz, testCase.context);

            % Events table should have one row per element
            testCase.verifyEqual(height(seq_file.events), 3, 'Should have 3 events');

            % Check event structure
            testCase.verifyTrue(ismember('sample_index', seq_file.events.Properties.VariableNames));
            testCase.verifyTrue(ismember('time_ms', seq_file.events.Properties.VariableNames));
            testCase.verifyTrue(ismember('trial_index', seq_file.events.Properties.VariableNames));
            testCase.verifyTrue(ismember('element_index', seq_file.events.Properties.VariableNames));
            testCase.verifyTrue(ismember('code', seq_file.events.Properties.VariableNames));
        end

        %% Metadata

        function testTrialTable(testCase)
            % Test that trial_table is preserved
            element_table = testCase.create_simple_element_table(3);

            seq_file = testCase.compiler.compile(element_table, testCase.stimulus_library, ...
                                                 testCase.fs_hz, testCase.context);

            % Should have trial_table with unique trials
            testCase.verifyTrue(istable(seq_file.trial_table));
            unique_trials = unique(element_table.trial_index);
            testCase.verifyEqual(height(seq_file.trial_table), length(unique_trials), ...
                'Trial table should have one row per trial');
        end

        function testElementTable(testCase)
            % Test that element_table is preserved
            element_table = testCase.create_simple_element_table(3);

            seq_file = testCase.compiler.compile(element_table, testCase.stimulus_library, ...
                                                 testCase.fs_hz, testCase.context);

            testCase.verifyEqual(seq_file.element_table, element_table, ...
                'Element table should be preserved');
        end

        function testManifest(testCase)
            % Test that manifest contains provenance information
            element_table = testCase.create_simple_element_table(2);

            seq_file = testCase.compiler.compile(element_table, testCase.stimulus_library, ...
                                                 testCase.fs_hz, testCase.context);

            % Check manifest fields
            testCase.verifyTrue(isfield(seq_file.manifest, 'version'));
            testCase.verifyTrue(isfield(seq_file.manifest, 'fs_hz'));
            testCase.verifyTrue(isfield(seq_file.manifest, 'n_channels'));
            testCase.verifyTrue(isfield(seq_file.manifest, 'n_trials'));
            testCase.verifyTrue(isfield(seq_file.manifest, 'n_elements'));
            testCase.verifyTrue(isfield(seq_file.manifest, 'duration_samples'));
            testCase.verifyTrue(isfield(seq_file.manifest, 'duration_ms'));
            testCase.verifyTrue(isfield(seq_file.manifest, 'compiled_at'));

            % Check values
            testCase.verifyEqual(seq_file.manifest.fs_hz, testCase.fs_hz);
            testCase.verifyEqual(seq_file.manifest.n_elements, height(element_table));
        end

        %% Multi-Element Trials (Local-Global)

        function testLocalGlobalCompilation(testCase)
            % Test compilation of Local-Global trial (4 elements per trial)
            element_table = testCase.create_local_global_element_table();

            seq_file = testCase.compiler.compile(element_table, testCase.stimulus_library, ...
                                                 testCase.fs_hz, testCase.context);

            % Should have 4 events (4 elements in one trial)
            testCase.verifyEqual(height(seq_file.events), 4);

            % Elements should be at 0, 100, 200, 300 ms
            expected_times = [0; 100; 200; 300];
            testCase.verifyEqual(seq_file.events.time_ms, expected_times, 'AbsTol', 0.1);
        end

        %% Hash Computation

        function testAudioHashComputation(testCase)
            % Test that audio hash is computed and stored
            element_table = testCase.create_simple_element_table(2);

            seq_file = testCase.compiler.compile(element_table, testCase.stimulus_library, ...
                                                 testCase.fs_hz, testCase.context);

            testCase.verifyTrue(isfield(seq_file.manifest, 'audio_hash'));
            testCase.verifyEqual(length(seq_file.manifest.audio_hash), 64, ...
                'SHA-256 hash should be 64 hex characters');
        end

        function testDeterministicCompilation(testCase)
            % Test that same inputs produce same audio (deterministic)
            element_table = testCase.create_simple_element_table(2);

            seq_file1 = testCase.compiler.compile(element_table, testCase.stimulus_library, ...
                                                  testCase.fs_hz, testCase.context);
            seq_file2 = testCase.compiler.compile(element_table, testCase.stimulus_library, ...
                                                  testCase.fs_hz, testCase.context);

            testCase.verifyEqual(seq_file1.audio, seq_file2.audio, ...
                'Same inputs should produce identical audio');
            testCase.verifyEqual(seq_file1.manifest.audio_hash, seq_file2.manifest.audio_hash, ...
                'Hashes should match for identical audio');
        end

        %% Edge Cases

        function testEmptyElementTable(testCase)
            % Test compilation with no elements (edge case)
            element_table = table();
            element_table.trial_index = [];
            element_table.element_index = [];
            element_table.stimulus_ref = {};
            element_table.absolute_onset_ms = [];
            element_table.duration_ms = [];
            element_table.label = {};

            seq_file = testCase.compiler.compile(element_table, testCase.stimulus_library, ...
                                                 testCase.fs_hz, testCase.context);

            % Should produce minimal SequenceFile (e.g., 1 second of silence)
            testCase.verifyTrue(isstruct(seq_file));
            testCase.verifyGreaterThan(size(seq_file.audio, 1), 0, 'Should have some audio buffer');
        end

        function testSingleElement(testCase)
            % Test compilation with single element
            element_table = testCase.create_simple_element_table(1);

            seq_file = testCase.compiler.compile(element_table, testCase.stimulus_library, ...
                                                 testCase.fs_hz, testCase.context);

            testCase.verifyEqual(height(seq_file.events), 1);
            testCase.verifyEqual(seq_file.manifest.n_elements, 1);
        end
    end

    methods (Access = private)
        function element_table = create_simple_element_table(testCase, n_elements)
            % Create simple element table for testing (oddball-like)
            %
            % Elements spaced by 500 ms ITI + 150 ms duration = 650 ms per trial

            trial_indices = (0:n_elements-1)';
            element_indices = zeros(n_elements, 1);
            stimulus_refs = repmat({'tone_1000hz'}, n_elements, 1);
            absolute_onsets = (0:n_elements-1)' * 650;  % 0, 650, 1300, ...
            durations = repmat(150, n_elements, 1);
            labels = repmat({'standard'}, n_elements, 1);

            element_table = table(trial_indices, element_indices, stimulus_refs, ...
                                 absolute_onsets, durations, labels, ...
                                 'VariableNames', {'trial_index', 'element_index', ...
                                                  'stimulus_ref', 'absolute_onset_ms', ...
                                                  'duration_ms', 'label'});
        end

        function element_table = create_local_global_element_table(testCase)
            % Create Local-Global element table (AAAB pattern = 4 elements)

            trial_indices = [0; 0; 0; 0];
            element_indices = [0; 1; 2; 3];
            stimulus_refs = {'tone_1000hz'; 'tone_1000hz'; 'tone_1000hz'; 'tone_1200hz'};
            absolute_onsets = [0; 100; 200; 300];
            durations = [50; 50; 50; 50];
            labels = repmat({'AAAB'}, 4, 1);
            symbols = {'A'; 'A'; 'A'; 'B'};

            element_table = table(trial_indices, element_indices, stimulus_refs, ...
                                 absolute_onsets, durations, labels, symbols, ...
                                 'VariableNames', {'trial_index', 'element_index', ...
                                                  'stimulus_ref', 'absolute_onset_ms', ...
                                                  'duration_ms', 'label', 'symbol'});
        end
    end
end
