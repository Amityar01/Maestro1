classdef ClickTrainFixedGenerator < handle
    % ClickTrainFixedGenerator - Generates rhythmic click trains
    %
    % Generates a sequence of brief clicks at a fixed rate.
    % Useful for rhythm perception, entrainment studies, and timing research.
    %
    % Contract:
    %   - Pure function: deterministic
    %   - No hardware calls
    %   - Returns audio + metadata
    %
    % Example:
    %   generator = v1.generators.ClickTrainFixedGenerator();
    %   params = struct('click_rate_hz', 10, 'n_clicks', 20, ...
    %                  'click_duration_ms', 1, 'level', ...);
    %   [audio, metadata] = generator.generate(params, context);

    methods
        function [audio, metadata] = generate(obj, params, context)
            % Generate click train stimulus
            %
            % Args:
            %   params: Parameter struct with fields:
            %     - click_rate_hz: Click rate in Hz
            %     - n_clicks: Number of clicks
            %     - click_duration_ms: Duration of each click (ms)
            %     - level: Level specification
            %     - envelope (optional): Envelope for entire train
            %     - routing (optional): Channel routing
            %
            %   context: GeneratorContext
            %
            % Returns:
            %   audio: Audio buffer [samples × channels]
            %   metadata: Generation metadata

            % Sample parameters
            realized_params = obj.sample_parameters(params, context);

            % Compute timing
            ioi_ms = 1000 / realized_params.click_rate_hz;  % Inter-onset interval
            total_duration_ms = ioi_ms * (realized_params.n_clicks - 1) + realized_params.click_duration_ms;
            total_samples = context.ms_to_samples(total_duration_ms);

            % Initialize audio buffer
            audio = zeros(total_samples, 1);

            % Generate clicks
            click_duration_samples = context.ms_to_samples(realized_params.click_duration_ms);
            ioi_samples = context.ms_to_samples(ioi_ms);

            for i = 1:realized_params.n_clicks
                click_onset = (i - 1) * ioi_samples + 1;
                click_end = min(click_onset + click_duration_samples - 1, total_samples);

                % Create click (rectangular pulse)
                audio(click_onset:click_end) = 1.0;
            end

            % Apply envelope to entire train if specified
            if isfield(realized_params, 'envelope')
                audio = obj.apply_envelope(audio, realized_params.envelope, context);
            end

            % Apply level
            audio = obj.apply_level(audio, realized_params.level);

            % Route to channels
            if isfield(realized_params, 'routing')
                audio_routed = obj.route_to_channels(audio, realized_params.routing);
            else
                audio_routed = [audio, audio];  % Stereo
            end

            % Metadata
            metadata = struct();
            metadata.peak = max(abs(audio_routed(:)));
            metadata.rms = sqrt(mean(audio_routed(:).^2));
            metadata.realized_params = realized_params;
            metadata.n_clicks = realized_params.n_clicks;
            metadata.total_duration_ms = total_duration_ms;
        end

        function realized_params = sample_parameters(obj, params, context)
            realized_params = struct();

            if isstruct(params.click_rate_hz)
                realized_params.click_rate_hz = context.sample_field(params.click_rate_hz, 'click_rate_hz');
            else
                realized_params.click_rate_hz = params.click_rate_hz;
            end

            if isstruct(params.n_clicks)
                realized_params.n_clicks = round(context.sample_field(params.n_clicks, 'n_clicks'));
            else
                realized_params.n_clicks = params.n_clicks;
            end

            if isstruct(params.click_duration_ms)
                realized_params.click_duration_ms = context.sample_field(params.click_duration_ms, 'click_duration_ms');
            else
                realized_params.click_duration_ms = params.click_duration_ms;
            end

            realized_params.level = params.level;

            if isfield(params, 'envelope')
                realized_params.envelope = params.envelope;
            end
            if isfield(params, 'routing')
                realized_params.routing = params.routing;
            end
        end

        function audio_env = apply_envelope(obj, audio, envelope, context)
            n_samples = length(audio);
            attack_samples = context.ms_to_samples(envelope.attack_ms);
            release_samples = context.ms_to_samples(envelope.release_ms);

            env = ones(n_samples, 1);

            if attack_samples > 0
                env(1:attack_samples) = linspace(0, 1, attack_samples)';
            end

            if release_samples > 0
                release_start = n_samples - release_samples + 1;
                env(release_start:end) = linspace(1, 0, release_samples)';
            end

            audio_env = audio .* env;
        end

        function audio_scaled = apply_level(obj, audio, level)
            if strcmp(level.unit, 'linear_0_1')
                audio_scaled = audio * level.value;
            elseif strcmp(level.unit, 'dB_FS')
                linear_gain = 10^(level.value / 20);
                audio_scaled = audio * linear_gain;
            else
                error('ClickTrainFixedGenerator:UnknownLevelUnit', 'Unknown level unit: %s', level.unit);
            end
        end

        function audio_routed = route_to_channels(obj, audio_mono, routing)
            channels = routing.channels;
            n_channels = max(channels) + 1;
            n_samples = length(audio_mono);

            audio_routed = zeros(n_samples, n_channels, 'single');

            for i = 1:length(channels)
                ch = channels(i) + 1;
                audio_routed(:, ch) = audio_mono;
            end
        end
    end
end
