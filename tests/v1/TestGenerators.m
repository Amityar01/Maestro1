classdef TestGenerators < matlab.unittest.TestCase
    % TestGenerators - Unit tests for generator framework and tone.simple
    %
    % These tests define the API and behavior we want.
    % Following TDD: write tests first, implement to make them pass.

    properties
        context
        sampler
    end

    methods (TestMethodSetup)
        function createContext(testCase)
            % Setup generator context for tests
            rng_manager = v1.sampling.RNGStreamManager(42);
            scope_manager = v1.sampling.ScopeManager();
            testCase.sampler = v1.sampling.NumericFieldSampler(rng_manager, scope_manager);

            % Create generator context
            testCase.context = v1.generators.GeneratorContext(...
                'fs_hz', 192000, ...
                'sampler', testCase.sampler);

            % Set RNG manager
            testCase.context.set_rng_manager(rng_manager);
        end
    end

    methods (Test)
        %% GeneratorContext Tests

        function testContextCreation(testCase)
            % Test that context can be created with required fields
            testCase.verifyEqual(testCase.context.fs_hz, 192000);
            testCase.verifyEqual(testCase.context.sampler, testCase.sampler);
        end

        function testContextHasRNGStream(testCase)
            % Context should provide access to RNG stream
            stream = testCase.context.get_rng_stream('test');
            testCase.verifyClass(stream, 'RandStream');
        end

        function testContextSampleField(testCase)
            % Context should provide convenient sampling method
            field_spec = struct('value', 1000);
            value = testCase.context.sample_field(field_spec, 'freq');
            testCase.verifyEqual(value, 1000);
        end

        %% tone.simple Generator Tests

        function testToneGeneratorExists(testCase)
            % Verify tone.simple generator exists and has generate method
            generator = v1.generators.ToneSimpleGenerator();
            testCase.verifyTrue(ismethod(generator, 'generate'));
        end

        function testToneGenerateBasic(testCase)
            % Generate a simple 1000 Hz tone
            generator = v1.generators.ToneSimpleGenerator();

            params = struct();
            params.frequency_hz = 1000;
            params.duration_ms = 100;
            params.level = struct('value', 0.5, 'unit', 'linear_0_1');
            params.envelope = struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine');
            params.routing = struct('channels', [0 1]);

            [audio, metadata] = generator.generate(params, testCase.context);

            % Verify audio shape
            expected_samples = round(0.1 * 192000);  % 100ms at 192kHz
            testCase.verifyEqual(size(audio, 1), expected_samples);
            testCase.verifyEqual(size(audio, 2), 2);  % Stereo

            % Verify audio is not silent
            testCase.verifyGreaterThan(max(abs(audio(:))), 0.1);

            % Verify metadata exists
            testCase.verifyTrue(isfield(metadata, 'peak'));
            testCase.verifyTrue(isfield(metadata, 'rms'));
            testCase.verifyTrue(isfield(metadata, 'duration_ms'));
        end

        function testToneDeterminism(testCase)
            % Same params + seed should produce identical audio
            generator = v1.generators.ToneSimpleGenerator();

            params = struct();
            params.frequency_hz = 1000;
            params.duration_ms = 50;
            params.level = struct('value', 0.5, 'unit', 'linear_0_1');
            params.seed = 12345;
            params.envelope = struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine');
            params.routing = struct('channels', [0]);

            [audio1, ~] = generator.generate(params, testCase.context);
            [audio2, ~] = generator.generate(params, testCase.context);

            testCase.verifyEqual(audio1, audio2, 'Same seed should produce identical audio');
        end

        function testToneFrequency(testCase)
            % Generated tone should have correct frequency
            generator = v1.generators.ToneSimpleGenerator();

            params = struct();
            params.frequency_hz = 1000;
            params.duration_ms = 1000;  % 1 second for good FFT resolution
            params.level = struct('value', 0.5, 'unit', 'linear_0_1');
            params.envelope = struct('attack_ms', 0, 'release_ms', 0, 'shape', 'linear');
            params.routing = struct('channels', [0]);

            [audio, ~] = generator.generate(params, testCase.context);

            % FFT to check frequency
            n = length(audio);
            fft_result = abs(fft(audio));
            fft_result = fft_result(1:floor(n/2));

            freqs = (0:floor(n/2)-1) * (testCase.context.fs_hz / n);
            [~, peak_idx] = max(fft_result);
            peak_freq = freqs(peak_idx);

            testCase.verifyEqual(peak_freq, 1000, 'AbsTol', 10, ...
                'Peak frequency should be ~1000 Hz');
        end

        function testToneEnvelope(testCase)
            % Envelope should be applied (check ramps)
            generator = v1.generators.ToneSimpleGenerator();

            params = struct();
            params.frequency_hz = 1000;
            params.duration_ms = 100;
            params.level = struct('value', 0.5, 'unit', 'linear_0_1');
            params.envelope = struct('attack_ms', 10, 'release_ms', 10, 'shape', 'linear');
            params.routing = struct('channels', [0]);

            [audio, ~] = generator.generate(params, testCase.context);

            % First sample should be near zero (attack ramp)
            testCase.verifyLessThan(abs(audio(1)), 0.01, ...
                'First sample should be near zero');

            % Last sample should be near zero (release ramp)
            testCase.verifyLessThan(abs(audio(end)), 0.01, ...
                'Last sample should be near zero');

            % Middle should be significantly louder than edges (envelope working)
            mid_idx = round(length(audio) / 2);
            testCase.verifyGreaterThan(abs(audio(mid_idx)), abs(audio(1)), ...
                'Middle should be louder than start');
            testCase.verifyGreaterThan(abs(audio(mid_idx)), abs(audio(end)), ...
                'Middle should be louder than end');
        end

        function testToneSampling(testCase)
            % Test with sampled (jittered) frequency
            generator = v1.generators.ToneSimpleGenerator();

            params = struct();
            params.frequency_hz = struct('dist', 'uniform', 'min', 900, 'max', 1100, 'scope', 'per_trial');
            params.duration_ms = 100;
            params.level = struct('value', 0.5, 'unit', 'linear_0_1');
            params.envelope = struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine');
            params.routing = struct('channels', [0]);

            % Should sample frequency from distribution
            [audio1, metadata1] = generator.generate(params, testCase.context);
            [audio2, metadata2] = generator.generate(params, testCase.context);

            % Metadata should record realized frequency
            testCase.verifyTrue(isfield(metadata1, 'realized_params'));
            testCase.verifyTrue(isfield(metadata1.realized_params, 'frequency_hz'));

            freq1 = metadata1.realized_params.frequency_hz;
            freq2 = metadata2.realized_params.frequency_hz;

            testCase.verifyGreaterThanOrEqual(freq1, 900);
            testCase.verifyLessThanOrEqual(freq1, 1100);

            % Should be different (per_trial sampling)
            testCase.verifyNotEqual(freq1, freq2, ...
                'per_trial sampling should produce different frequencies');
        end

        function testToneMetadata(testCase)
            % Metadata should include all required fields
            generator = v1.generators.ToneSimpleGenerator();

            params = struct();
            params.frequency_hz = 1000;
            params.duration_ms = 100;
            params.level = struct('value', 0.7, 'unit', 'linear_0_1');
            params.envelope = struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine');
            params.routing = struct('channels', [0]);

            [audio, metadata] = generator.generate(params, testCase.context);

            % Required metadata fields
            testCase.verifyTrue(isfield(metadata, 'peak'));
            testCase.verifyTrue(isfield(metadata, 'rms'));
            testCase.verifyTrue(isfield(metadata, 'duration_ms'));
            testCase.verifyTrue(isfield(metadata, 'hash'));
            testCase.verifyTrue(isfield(metadata, 'realized_params'));

            % Peak should be reasonable
            testCase.verifyLessThanOrEqual(metadata.peak, 1.0);
            testCase.verifyGreaterThan(metadata.peak, 0.5);

            % RMS should be less than peak
            testCase.verifyLessThan(metadata.rms, metadata.peak);

            % Duration should match
            testCase.verifyEqual(metadata.duration_ms, 100, 'AbsTol', 1);
        end

        function testTonePhase(testCase)
            % Test phase parameter
            generator = v1.generators.ToneSimpleGenerator();

            params = struct();
            params.frequency_hz = 1000;
            params.duration_ms = 100;
            params.phase_deg = 90;  % Start at peak
            params.level = struct('value', 0.5, 'unit', 'linear_0_1');
            params.envelope = struct('attack_ms', 0, 'release_ms', 0, 'shape', 'linear');
            params.routing = struct('channels', [0]);

            [audio, ~] = generator.generate(params, testCase.context);

            % With 90 deg phase and no envelope, first sample should be near peak
            % (accounting for cosine ramp if any)
            testCase.verifyGreaterThan(abs(audio(100)), 0.4, ...
                'Phase should affect starting point');
        end

        function testToneStereo(testCase)
            % Test stereo output with routing
            generator = v1.generators.ToneSimpleGenerator();

            params = struct();
            params.frequency_hz = 1000;
            params.duration_ms = 50;
            params.level = struct('value', 0.5, 'unit', 'linear_0_1');
            params.envelope = struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine');
            params.routing = struct('channels', [0 1]);

            [audio, ~] = generator.generate(params, testCase.context);

            testCase.verifyEqual(size(audio, 2), 2, 'Should have 2 channels');

            % Both channels should be identical (no pan)
            testCase.verifyEqual(audio(:,1), audio(:,2), ...
                'Stereo with no pan should be identical');
        end

        function testToneValidation(testCase)
            % Invalid params should error
            generator = v1.generators.ToneSimpleGenerator();

            params = struct();
            params.frequency_hz = -1000;  % Invalid: negative frequency
            params.duration_ms = 100;
            params.level = struct('value', 0.5, 'unit', 'linear_0_1');
            params.envelope = struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine');
            params.routing = struct('channels', [0]);

            % Should error due to validation
            testCase.verifyError(...
                @() generator.generate(params, testCase.context), ...
                'ToneSimpleGenerator:InvalidFrequency');
        end

        function testToneClipping(testCase)
            % Very high level should not clip
            generator = v1.generators.ToneSimpleGenerator();

            params = struct();
            params.frequency_hz = 1000;
            params.duration_ms = 100;
            params.level = struct('value', 1.5, 'unit', 'linear_0_1');  % Above 1.0
            params.envelope = struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine');
            params.routing = struct('channels', [0]);

            [audio, metadata] = generator.generate(params, testCase.context);

            % Should clip or warn, but not crash
            testCase.verifyLessThanOrEqual(max(abs(audio(:))), 1.0, ...
                'Audio should not exceed ±1.0');

            % Metadata should indicate clipping
            testCase.verifyTrue(isfield(metadata, 'clipped') || metadata.peak <= 1.0);
        end
    end
end
