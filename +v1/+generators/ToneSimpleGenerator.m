classdef ToneSimpleGenerator < handle
    % ToneSimpleGenerator - Generates pure sinusoidal tones
    %
    % Implements the tone.simple stimulus type from schemas/v1/stimuli/tone.simple.schema.json
    %
    % Contract:
    %   - Pure function: same inputs → same output
    %   - Deterministic with seed
    %   - Envelope applied last
    %   - No hardware calls
    %   - Full metadata output
    %
    % Example:
    %   generator = v1.generators.ToneSimpleGenerator();
    %   params = struct('frequency_hz', 1000, 'duration_ms', 150, ...);
    %   [audio, metadata] = generator.generate(params, context);

    methods
        function [audio, metadata] = generate(obj, params, context)
            % Generate a pure tone
            %
            % Args:
            %   params: Struct with stimulus parameters
            %   context: GeneratorContext with fs_hz, sampler, etc.
            %
            % Returns:
            %   audio: Audio buffer [samples × channels]
            %   metadata: Struct with peak, rms, duration_ms, hash, realized_params

            % Sample numeric fields if needed
            realized_params = obj.sample_parameters(params, context);

            % Validate realized parameters
            obj.validate_parameters(realized_params);

            % Extract parameters
            freq_hz = realized_params.frequency_hz;
            duration_ms = realized_params.duration_ms;
            level = realized_params.level;
            routing = realized_params.routing;

            if isfield(realized_params, 'phase_deg')
                phase_deg = realized_params.phase_deg;
            else
                phase_deg = 0;
            end

            if isfield(realized_params, 'envelope')
                envelope = realized_params.envelope;
            else
                envelope = struct('attack_ms', 5, 'release_ms', 5, 'shape', 'cosine');
            end

            % Get RNG stream for deterministic generation
            if isfield(realized_params, 'seed')
                stream = context.get_rng_stream(['tone_' num2str(realized_params.seed)]);
            else
                stream = context.get_rng_stream('tone_default');
            end

            % Convert duration to samples
            n_samples = context.ms_to_samples(duration_ms);

            % Generate time vector
            t = (0:n_samples-1)' / context.fs_hz;

            % Generate tone (before envelope)
            phase_rad = phase_deg * pi / 180;
            tone = sin(2 * pi * freq_hz * t + phase_rad);

            % Apply envelope
            tone_env = obj.apply_envelope(tone, envelope, context);

            % Apply level
            tone_scaled = obj.apply_level(tone_env, level);

            % Check for clipping
            peak = max(abs(tone_scaled));
            clipped = peak > 1.0;
            if clipped
                % Clip to prevent overflow
                tone_scaled = max(-1.0, min(1.0, tone_scaled));
                warning('ToneSimpleGenerator:Clipping', ...
                    'Signal clipped (peak was %g)', peak);
            end

            % Route to channels
            audio = obj.route_to_channels(tone_scaled, routing);

            % Compute metadata
            metadata = struct();
            metadata.peak = max(abs(audio(:)));
            metadata.rms = sqrt(mean(audio(:).^2));
            metadata.duration_ms = context.samples_to_ms(size(audio, 1));
            metadata.clipped = clipped;
            metadata.realized_params = realized_params;

            % Compute hash for provenance
            metadata.hash = obj.compute_hash(audio, realized_params);
        end

        function realized = sample_parameters(obj, params, context)
            % Sample any numeric fields that are distributions
            %
            % Args:
            %   params: Input parameters (may have distributions)
            %   context: GeneratorContext with sampler
            %
            % Returns:
            %   realized: Parameters with sampled values

            realized = struct();

            % Sample frequency
            if isfield(params, 'frequency_hz')
                realized.frequency_hz = context.sample_field(params.frequency_hz, 'frequency_hz');
            else
                error('ToneSimpleGenerator:MissingFrequency', 'frequency_hz is required');
            end

            % Sample duration
            if isfield(params, 'duration_ms')
                realized.duration_ms = context.sample_field(params.duration_ms, 'duration_ms');
            else
                error('ToneSimpleGenerator:MissingDuration', 'duration_ms is required');
            end

            % Sample level
            if isfield(params, 'level')
                level = params.level;
                if isstruct(level) && isfield(level, 'value')
                    realized.level = level;
                    % Sample the value field if it's a distribution
                    realized.level.value = context.sample_field(level.value, 'level_value');
                else
                    realized.level = struct('value', level, 'unit', 'linear_0_1');
                end
            else
                error('ToneSimpleGenerator:MissingLevel', 'level is required');
            end

            % Copy other fields
            if isfield(params, 'phase_deg')
                realized.phase_deg = context.sample_field(params.phase_deg, 'phase_deg');
            end

            if isfield(params, 'envelope')
                realized.envelope = params.envelope;
            end

            if isfield(params, 'routing')
                realized.routing = params.routing;
            else
                error('ToneSimpleGenerator:MissingRouting', 'routing is required');
            end

            if isfield(params, 'seed')
                realized.seed = params.seed;
            end
        end

        function validate_parameters(obj, params)
            % Validate realized parameters
            %
            % Args:
            %   params: Realized parameters to validate

            if params.frequency_hz <= 0
                error('ToneSimpleGenerator:InvalidFrequency', ...
                    'Frequency must be positive');
            end

            if params.duration_ms <= 0
                error('ToneSimpleGenerator:InvalidDuration', ...
                    'Duration must be positive');
            end

            if params.level.value < 0
                error('ToneSimpleGenerator:InvalidLevel', ...
                    'Level must be non-negative');
            end
        end

        function tone_env = apply_envelope(obj, tone, envelope, context)
            % Apply envelope (attack and release ramps)
            %
            % Args:
            %   tone: Audio signal [samples × 1]
            %   envelope: Struct with attack_ms, release_ms, shape
            %   context: GeneratorContext
            %
            % Returns:
            %   tone_env: Tone with envelope applied

            n_samples = length(tone);
            attack_samples = context.ms_to_samples(envelope.attack_ms);
            release_samples = context.ms_to_samples(envelope.release_ms);

            % Create envelope
            env = ones(n_samples, 1);

            % Attack ramp
            if attack_samples > 0 && attack_samples < n_samples
                attack_ramp = obj.create_ramp(attack_samples, envelope.shape);
                env(1:attack_samples) = attack_ramp;
            end

            % Release ramp
            if release_samples > 0 && release_samples < n_samples
                release_ramp = obj.create_ramp(release_samples, envelope.shape);
                env(end-release_samples+1:end) = flipud(release_ramp);
            end

            % Apply envelope
            tone_env = tone .* env;
        end

        function ramp = create_ramp(obj, n_samples, shape)
            % Create a ramp (0 → 1)
            %
            % Args:
            %   n_samples: Length of ramp
            %   shape: 'linear', 'cosine', or 'exponential'
            %
            % Returns:
            %   ramp: Vector from 0 to 1

            t = linspace(0, 1, n_samples)';

            switch shape
                case 'linear'
                    ramp = t;

                case 'cosine'
                    % Raised cosine (smooth)
                    ramp = 0.5 * (1 - cos(pi * t));

                case 'exponential'
                    % Exponential ramp
                    ramp = (exp(3*t) - 1) / (exp(3) - 1);

                otherwise
                    % Default to cosine
                    ramp = 0.5 * (1 - cos(pi * t));
            end
        end

        function tone_scaled = apply_level(obj, tone, level)
            % Apply level scaling
            %
            % Args:
            %   tone: Audio signal
            %   level: Struct with value and unit
            %
            % Returns:
            %   tone_scaled: Scaled audio

            switch level.unit
                case 'linear_0_1'
                    % Direct linear scaling
                    tone_scaled = tone * level.value;

                case 'dB_FS'
                    % dB FS (0 dB = full scale)
                    linear_scale = 10^(level.value / 20);
                    tone_scaled = tone * linear_scale;

                case 'dB_SPL'
                    % For dB SPL, would need calibration
                    % For now, treat as dB FS
                    warning('ToneSimpleGenerator:CalibrationNeeded', ...
                        'dB_SPL requires calibration, treating as dB_FS');
                    linear_scale = 10^(level.value / 20);
                    tone_scaled = tone * linear_scale;

                otherwise
                    error('ToneSimpleGenerator:UnknownUnit', ...
                        'Unknown level unit: %s', level.unit);
            end
        end

        function audio = route_to_channels(obj, signal, routing)
            % Route signal to specified channels
            %
            % Args:
            %   signal: Mono signal [samples × 1]
            %   routing: Struct with channels field
            %
            % Returns:
            %   audio: Multi-channel audio [samples × channels]

            channels = routing.channels;
            n_channels = length(channels);

            % Create output buffer
            audio = zeros(length(signal), n_channels);

            % Route to each channel (for now, same signal to all)
            for i = 1:n_channels
                audio(:, i) = signal;
            end

            % TODO: Handle pan if specified
        end

        function hash = compute_hash(obj, audio, params)
            % Compute hash for provenance
            %
            % Args:
            %   audio: Generated audio
            %   params: Realized parameters
            %
            % Returns:
            %   hash: SHA-256 hash string

            % Simple hash based on audio content and key parameters
            % In production, use proper SHA-256
            hash_input = [audio(:); params.frequency_hz; params.duration_ms];
            hash = sprintf('%08x', sum(abs(hash_input)) * 1e6);
        end
    end
end
