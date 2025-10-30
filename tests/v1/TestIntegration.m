classdef TestIntegration < matlab.unittest.TestCase
    % TestIntegration - End-to-end integration tests
    %
    % Tests the complete pipeline from paradigm configuration
    % through to DAQ playback.
    %
    % Pipeline tested:
    %   Config → Adapter → Trial Plan → Pattern Builder →
    %   Element Table → Compiler → SequenceFile → DAQ Engine

    properties
        fs_hz
        rng_manager
        sampler
        context
        stimulus_library
    end

    methods (TestMethodSetup)
        function setup(testCase)
            % Setup common infrastructure
            testCase.fs_hz = 48000;
            testCase.rng_manager = v1.sampling.RNGStreamManager(42);
            testCase.sampler = v1.sampling.NumericFieldSampler(testCase.rng_manager);
            testCase.context = v1.generators.GeneratorContext('fs_hz', testCase.fs_hz, ...
                                                              'sampler', testCase.sampler);
            testCase.context.set_rng_manager(testCase.rng_manager);

            % Build stimulus library
            testCase.stimulus_library = testCase.create_stimulus_library();
        end
    end

    methods (Test)
        %% Oddball Pipeline Integration

        function testOddballPipelineComplete(testCase)
            % Test complete oddball pipeline: Config → Playback

            % Step 1: Configure oddball
            config = struct();
            config.tokens = [
                struct('label', 'standard', 'stimulus_ref', 'tone_1000hz', ...
                       'base_probability', 0.8, 'code', 1, 'duration_ms', 150)
                struct('label', 'deviant', 'stimulus_ref', 'tone_1200hz', ...
                       'base_probability', 0.2, 'code', 2, 'duration_ms', 150)
            ];
            config.selection = struct('mode', 'balanced_shuffle', 'seed', 12345);
            config.iti = struct('value', 500);

            % Step 2: Generate trial plan
            adapter = v1.paradigms.OddballAdapter();
            trial_plan = adapter.generate_trial_plan(config, 20);

            testCase.verifyEqual(trial_plan.n_trials, 20);
            testCase.verifyEqual(length(trial_plan.trials), 20);

            % Step 3: Build element table
            builder = v1.compilation.PatternBuilderCore();
            element_table = builder.build(trial_plan);

            testCase.verifyEqual(height(element_table), 20, 'Should have 20 elements');

            % Step 4: Compile to SequenceFile
            compiler = v1.compilation.CompilerCore();
            element_table.ttl_code = ones(height(element_table), 1);
            seq_file = compiler.compile(element_table, testCase.stimulus_library, ...
                                       testCase.fs_hz, testCase.context);

            testCase.verifyTrue(isstruct(seq_file));
            testCase.verifyEqual(size(seq_file.audio, 2), 2, 'Should have 2 channels');
            testCase.verifyEqual(height(seq_file.events), 20, 'Should have 20 events');

            % Step 5: Play on DAQ engine
            engine = v1.daq.DAQEngine();
            engine.configure(struct('mode', 'dry_run', 'real_time', false));
            engine.load_sequence(seq_file);
            result = engine.play();

            testCase.verifyTrue(result.success, 'Playback should succeed');
            testCase.verifyEqual(result.events_played, 20);
        end

        %% Local-Global Pipeline Integration

        function testLocalGlobalPipelineComplete(testCase)
            % Test complete Local-Global pipeline

            % Step 1: Configure Local-Global
            config = struct();
            config.token_a = struct('stimulus_ref', 'tone_1000hz', 'duration_ms', 50);
            config.token_b = struct('stimulus_ref', 'tone_1200hz', 'duration_ms', 50);
            config.patterns = [
                struct('label', 'AAAB', 'sequence', 'AAAB', 'base_probability', 0.5)
                struct('label', 'AAAA', 'sequence', 'AAAA', 'base_probability', 0.5)
            ];
            config.ioi = struct('value', 100);
            config.iti = struct('value', 800);
            config.selection = struct('mode', 'balanced_shuffle', 'seed', 99999);

            % Step 2: Generate trial plan
            adapter = v1.paradigms.LocalGlobalAdapter();
            trial_plan = adapter.generate_trial_plan(config, 10);

            testCase.verifyEqual(trial_plan.n_trials, 10);

            % Step 3: Build element table
            builder = v1.compilation.PatternBuilderCore();
            element_table = builder.build(trial_plan);

            testCase.verifyEqual(height(element_table), 40, 'Should have 40 elements (10 trials × 4)');

            % Step 4: Compile
            compiler = v1.compilation.CompilerCore();
            element_table.ttl_code = ones(height(element_table), 1);
            seq_file = compiler.compile(element_table, testCase.stimulus_library, ...
                                       testCase.fs_hz, testCase.context);

            testCase.verifyEqual(height(seq_file.events), 40);

            % Step 5: Play
            engine = v1.daq.DAQEngine();
            engine.configure(struct('mode', 'dry_run', 'real_time', false));
            engine.load_sequence(seq_file);
            result = engine.play();

            testCase.verifyTrue(result.success);
            testCase.verifyEqual(result.events_played, 40);
        end

        %% Foreperiod Pipeline Integration

        function testForeperiodPipelineComplete(testCase)
            % Test complete foreperiod pipeline

            % Step 1: Configure foreperiod
            config = struct();
            config.cue = struct('stimulus_ref', 'tone_1000hz', 'duration_ms', 50);
            config.outcome = struct('stimulus_ref', 'tone_1200hz', 'duration_ms', 50);
            config.foreperiods = [200, 400, 600];
            config.foreperiod_probs = [0.33, 0.34, 0.33];
            config.selection = struct('mode', 'balanced_shuffle', 'seed', 777);
            config.iti = struct('value', 1000);

            % Step 2: Generate trial plan
            adapter = v1.paradigms.ForeperiodAdapter();
            trial_plan = adapter.generate_trial_plan(config, 15);

            testCase.verifyEqual(trial_plan.n_trials, 15);

            % Step 3: Build element table
            builder = v1.compilation.PatternBuilderCore();
            element_table = builder.build(trial_plan);

            testCase.verifyEqual(height(element_table), 30, 'Should have 30 elements (15 trials × 2)');

            % Verify roles
            testCase.verifyTrue(ismember('role', element_table.Properties.VariableNames));

            % Step 4: Compile
            compiler = v1.compilation.CompilerCore();
            element_table.ttl_code = ones(height(element_table), 1);
            seq_file = compiler.compile(element_table, testCase.stimulus_library, ...
                                       testCase.fs_hz, testCase.context);

            testCase.verifyEqual(height(seq_file.events), 30);

            % Step 5: Play
            engine = v1.daq.DAQEngine();
            engine.configure(struct('mode', 'dry_run', 'real_time', false));
            engine.load_sequence(seq_file);
            result = engine.play();

            testCase.verifyTrue(result.success);
            testCase.verifyEqual(result.events_played, 30);
        end

        %% Determinism Across Pipeline

        function testPipelineDeterminism(testCase)
            % Test that same seed produces identical results throughout pipeline

            config = struct();
            config.tokens = [
                struct('label', 'standard', 'stimulus_ref', 'tone_1000hz', ...
                       'base_probability', 0.8, 'code', 1, 'duration_ms', 150)
                struct('label', 'deviant', 'stimulus_ref', 'tone_1200hz', ...
                       'base_probability', 0.2, 'code', 2, 'duration_ms', 150)
            ];
            config.selection = struct('mode', 'balanced_shuffle', 'seed', 555);
            config.iti = struct('value', 500);

            % Run pipeline twice with same seed
            adapter = v1.paradigms.OddballAdapter();
            builder = v1.compilation.PatternBuilderCore();
            compiler = v1.compilation.CompilerCore();

            % First run
            trial_plan1 = adapter.generate_trial_plan(config, 10);
            element_table1 = builder.build(trial_plan1);
            element_table1.ttl_code = ones(height(element_table1), 1);
            seq_file1 = compiler.compile(element_table1, testCase.stimulus_library, ...
                                        testCase.fs_hz, testCase.context);

            % Second run (reset RNG with same seed)
            testCase.rng_manager = v1.sampling.RNGStreamManager(42);
            testCase.sampler = v1.sampling.NumericFieldSampler(testCase.rng_manager);
            testCase.context = v1.generators.GeneratorContext('fs_hz', testCase.fs_hz, ...
                                                              'sampler', testCase.sampler);
            testCase.context.set_rng_manager(testCase.rng_manager);

            trial_plan2 = adapter.generate_trial_plan(config, 10);
            element_table2 = builder.build(trial_plan2);
            element_table2.ttl_code = ones(height(element_table2), 1);
            seq_file2 = compiler.compile(element_table2, testCase.stimulus_library, ...
                                        testCase.fs_hz, testCase.context);

            % Verify determinism
            testCase.verifyEqual(seq_file1.audio, seq_file2.audio, 'Audio should be identical');
            testCase.verifyEqual(seq_file1.manifest.audio_hash, seq_file2.manifest.audio_hash, ...
                'Hashes should match');
        end

        %% HDF5 Round-Trip

        function testHDF5RoundTrip(testCase)
            % Test SequenceFile HDF5 export and import

            % Generate simple sequence
            config = struct();
            config.tokens = [
                struct('label', 'standard', 'stimulus_ref', 'tone_1000hz', ...
                       'base_probability', 1.0, 'code', 1, 'duration_ms', 150)
            ];
            config.selection = struct('mode', 'balanced_shuffle', 'seed', 11111);
            config.iti = struct('value', 500);

            adapter = v1.paradigms.OddballAdapter();
            trial_plan = adapter.generate_trial_plan(config, 5);

            builder = v1.compilation.PatternBuilderCore();
            element_table = builder.build(trial_plan);
            element_table.ttl_code = ones(height(element_table), 1);

            compiler = v1.compilation.CompilerCore();
            seq_file_original = compiler.compile(element_table, testCase.stimulus_library, ...
                                                 testCase.fs_hz, testCase.context);

            % Write to HDF5
            test_file = 'test_integration_sequence.h5';
            compiler.write_hdf5(seq_file_original, test_file);

            % Read back
            seq_file_loaded = compiler.read_hdf5(test_file);

            % Verify integrity
            testCase.verifyEqual(seq_file_loaded.audio, seq_file_original.audio);
            testCase.verifyEqual(seq_file_loaded.ttl, seq_file_original.ttl);
            testCase.verifyEqual(height(seq_file_loaded.events), height(seq_file_original.events));
            testCase.verifyEqual(seq_file_loaded.manifest.audio_hash, seq_file_original.manifest.audio_hash);

            % Cleanup
            if exist(test_file, 'file')
                delete(test_file);
            end
        end
    end

    methods (Access = private)
        function library = create_stimulus_library(testCase)
            % Create stimulus library for testing

            library = containers.Map();

            library('tone_1000hz') = struct(...
                'type', 'tone.simple', ...
                'frequency_hz', 1000, ...
                'duration_ms', 150, ...
                'level', struct('value', 0.7, 'unit', 'linear_0_1'), ...
                'envelope', struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine'), ...
                'routing', struct('channels', [0 1]));

            library('tone_1200hz') = struct(...
                'type', 'tone.simple', ...
                'frequency_hz', 1200, ...
                'duration_ms', 150, ...
                'level', struct('value', 0.7, 'unit', 'linear_0_1'), ...
                'envelope', struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine'), ...
                'routing', struct('channels', [0 1]));
        end
    end
end
