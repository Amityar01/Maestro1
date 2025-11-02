classdef NoiseBandpassGenerator < handle
    % NoiseBandpassGenerator - Generates bandpass-filtered noise stimuli
    %
    % Generates Gaussian white noise filtered to a specific frequency band.
    % Useful for spectral masking, control stimuli, and auditory research.
    %
    % Contract:
    %   - Pure function: deterministic with seed
    %   - No hardware calls
    %   - Envelope applied last
    %   - Returns audio + metadata
    %
    % Example:
    %   generator = v1.generators.NoiseBandpassGenerator();
    %   params = struct('low_freq_hz', 1000, 'high_freq_hz', 2000, ...
    %                  'duration_ms', 200, 'level', ...);
    %   [audio, metadata] = generator.generate(params, context);

    methods
        function [audio, metadata] = generate(obj, params, context)
            % Generate bandpass noise stimulus
            %
            % Args:
            %   params: Parameter struct with fields:
            %     - low_freq_hz: Lower cutoff frequency (Hz)
            %     - high_freq_hz: Upper cutoff frequency (Hz)
            %     - duration_ms: Duration in milliseconds
            %     - level: Level specification (value, unit, calibration_ref)
            %     - envelope (optional): Attack/release envelope
            %     - routing (optional): Channel routing
            %     - seed (optional): RNG seed for reproducibility
            %
            %   context: GeneratorContext with fs_hz, sampler, RNG
            %
            % Returns:
            %   audio: Audio buffer [samples × channels]
            %   metadata: Generation metadata (peak, RMS, hash, etc.)

            % Sample all parameters (handles numeric fields)
            realized_params = obj.sample_parameters(params, context);

            % Get duration in samples
            duration_samples = context.ms_to_samples(realized_params.duration_ms);

            % Set RNG seed if provided
            if isfield(realized_params, 'seed')
                rng(realized_params.seed, 'twister');
            end

            % Generate white noise
            noise = randn(duration_samples, 1);

            % Apply bandpass filter
            audio_filtered = obj.apply_bandpass_filter(noise, realized_params.low_freq_hz, ...
                                                       realized_params.high_freq_hz, context.fs_hz);

            % Apply envelope if specified
            if isfield(realized_params, 'envelope')
                audio_enveloped = obj.apply_envelope(audio_filtered, realized_params.envelope, context);
            else
                audio_enveloped = audio_filtered;
            end

            % Apply level scaling
            audio_scaled = obj.apply_level(audio_enveloped, realized_params.level);

            % Route to channels
            if isfield(realized_params, 'routing')
                audio = obj.route_to_channels(audio_scaled, realized_params.routing);
            else
                % Default: stereo
                audio = [audio_scaled, audio_scaled];
            end

            % Compute metadata
            metadata = struct();
            metadata.peak = max(abs(audio(:)));
            metadata.rms = sqrt(mean(audio(:).^2));
            metadata.realized_params = realized_params;
            metadata.hash = obj.compute_hash(audio);
        end

        function realized_params = sample_parameters(obj, params, context)
            % Sample all numeric field parameters
            %
            % Args:
            %   params: Raw parameters
            %   context: GeneratorContext
            %
            % Returns:
            %   realized_params: Sampled scalar parameters

            realized_params = struct();

            % Sample low_freq_hz
            if isstruct(params.low_freq_hz)
                realized_params.low_freq_hz = context.sample_field(params.low_freq_hz, 'low_freq_hz');
            else
                realized_params.low_freq_hz = params.low_freq_hz;
            end

            % Sample high_freq_hz
            if isstruct(params.high_freq_hz)
                realized_params.high_freq_hz = context.sample_field(params.high_freq_hz, 'high_freq_hz');
            else
                realized_params.high_freq_hz = params.high_freq_hz;
            end

            % Sample duration_ms
            if isstruct(params.duration_ms)
                realized_params.duration_ms = context.sample_field(params.duration_ms, 'duration_ms');
            else
                realized_params.duration_ms = params.duration_ms;
            end

            % Copy level (handled later)
            realized_params.level = params.level;

            % Copy optional fields
            if isfield(params, 'envelope')
                realized_params.envelope = params.envelope;
            end
            if isfield(params, 'routing')
                realized_params.routing = params.routing;
            end
            if isfield(params, 'seed')
                realized_params.seed = params.seed;
            end
        end

        function audio_filtered = apply_bandpass_filter(obj, audio, low_freq, high_freq, fs_hz)
            % Apply bandpass filter to audio
            %
            % Args:
            %   audio: Input audio [samples × 1]
            %   low_freq: Lower cutoff frequency (Hz)
            %   high_freq: Upper cutoff frequency (Hz)
            %   fs_hz: Sampling rate (Hz)
            %
            % Returns:
            %   audio_filtered: Filtered audio

            % Design bandpass filter (Butterworth, 4th order)
            nyquist = fs_hz / 2;
            low_norm = low_freq / nyquist;
            high_norm = high_freq / nyquist;

            % Ensure frequencies are in valid range
            low_norm = max(0.001, min(0.999, low_norm));
            high_norm = max(0.001, min(0.999, high_norm));

            if low_norm >= high_norm
                error('NoiseBandpassGenerator:InvalidFrequencies', ...
                    'low_freq must be < high_freq');
            end

            [b, a] = butter(4, [low_norm, high_norm], 'bandpass');

            % Apply filter
            audio_filtered = filtfilt(b, a, audio);
        end

        function audio_env = apply_envelope(obj, audio, envelope, context)
            % Apply attack/release envelope
            %
            % Args:
            %   audio: Input audio
            %   envelope: Envelope struct (attack_ms, release_ms, shape)
            %   context: GeneratorContext
            %
            % Returns:
            %   audio_env: Audio with envelope applied

            n_samples = length(audio);
            attack_samples = context.ms_to_samples(envelope.attack_ms);
            release_samples = context.ms_to_samples(envelope.release_ms);

            % Create envelope
            env = ones(n_samples, 1);

            % Attack ramp
            if attack_samples > 0
                if strcmp(envelope.shape, 'linear')
                    env(1:attack_samples) = linspace(0, 1, attack_samples)';
                elseif strcmp(envelope.shape, 'cosine')
                    env(1:attack_samples) = (1 - cos(linspace(0, pi, attack_samples))) / 2;
                end
            end

            % Release ramp
            if release_samples > 0
                release_start = n_samples - release_samples + 1;
                if strcmp(envelope.shape, 'linear')
                    env(release_start:end) = linspace(1, 0, release_samples)';
                elseif strcmp(envelope.shape, 'cosine')
                    env(release_start:end) = (1 + cos(linspace(0, pi, release_samples))) / 2;
                end
            end

            audio_env = audio .* env;
        end

        function audio_scaled = apply_level(obj, audio, level)
            % Apply level scaling
            %
            % Args:
            %   audio: Input audio
            %   level: Level struct (value, unit)
            %
            % Returns:
            %   audio_scaled: Scaled audio

            if strcmp(level.unit, 'linear_0_1')
                audio_scaled = audio * level.value;
            elseif strcmp(level.unit, 'dB_FS')
                linear_gain = 10^(level.value / 20);
                audio_scaled = audio * linear_gain;
            else
                error('NoiseBandpassGenerator:UnknownLevelUnit', ...
                    'Unknown level unit: %s', level.unit);
            end

            % Normalize if RMS-based level is used
            if isfield(level, 'rms_target')
                current_rms = sqrt(mean(audio_scaled.^2));
                if current_rms > 0
                    audio_scaled = audio_scaled * (level.rms_target / current_rms);
                end
            end
        end

        function audio_routed = route_to_channels(obj, audio_mono, routing)
            % Route mono audio to specified channels
            %
            % Args:
            %   audio_mono: Mono audio [samples × 1]
            %   routing: Routing struct (channels, pan optional)
            %
            % Returns:
            %   audio_routed: Multi-channel audio

            channels = routing.channels;
            n_channels = max(channels) + 1;  % 0-indexed
            n_samples = length(audio_mono);

            audio_routed = zeros(n_samples, n_channels, 'single');

            % Simple routing: full amplitude to all specified channels
            for i = 1:length(channels)
                ch = channels(i) + 1;  % Convert to 1-indexed
                audio_routed(:, ch) = audio_mono;
            end
        end

        function hash_str = compute_hash(obj, audio)
            % Compute simple hash of audio (first 16 hex chars of SHA-256)

            audio_bytes = typecast(audio(:), 'uint8');
            hash_obj = java.security.MessageDigest.getInstance('SHA-256');
            hash_obj.update(audio_bytes);
            hash_bytes = hash_obj.digest();

            hash_str = '';
            for i = 1:min(8, length(hash_bytes))
                hash_str = [hash_str, sprintf('%02x', typecast(hash_bytes(i), 'uint8'))];
            end
        end
    end
end
