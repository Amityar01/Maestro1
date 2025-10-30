classdef SilenceGenerator < handle
    % SilenceGenerator - Generates silence (zeros)
    %
    % Generates a buffer of zeros for explicit silence periods.
    % Useful for gaps, omission trials, and timing control.
    %
    % Contract:
    %   - Pure function: deterministic
    %   - No hardware calls
    %   - Returns audio + metadata
    %
    % Example:
    %   generator = v1.generators.SilenceGenerator();
    %   params = struct('duration_ms', 500, 'routing', struct('channels', [0 1]));
    %   [audio, metadata] = generator.generate(params, context);

    methods
        function [audio, metadata] = generate(obj, params, context)
            % Generate silence stimulus
            %
            % Args:
            %   params: Parameter struct with fields:
            %     - duration_ms: Duration in milliseconds
            %     - routing (optional): Channel routing
            %
            %   context: GeneratorContext
            %
            % Returns:
            %   audio: Audio buffer of zeros [samples × channels]
            %   metadata: Generation metadata

            % Sample parameters
            realized_params = obj.sample_parameters(params, context);

            % Compute duration in samples
            duration_samples = context.ms_to_samples(realized_params.duration_ms);

            % Determine number of channels
            if isfield(realized_params, 'routing')
                channels = realized_params.routing.channels;
                n_channels = max(channels) + 1;  % 0-indexed
            else
                n_channels = 2;  % Default stereo
            end

            % Generate silence
            audio = zeros(duration_samples, n_channels, 'single');

            % Metadata
            metadata = struct();
            metadata.peak = 0;
            metadata.rms = 0;
            metadata.realized_params = realized_params;
            metadata.type = 'silence';
        end

        function realized_params = sample_parameters(obj, params, context)
            % Sample parameters (mostly pass-through for silence)

            realized_params = struct();

            % Sample duration_ms
            if isstruct(params.duration_ms)
                realized_params.duration_ms = context.sample_field(params.duration_ms, 'duration_ms');
            else
                realized_params.duration_ms = params.duration_ms;
            end

            % Copy routing if present
            if isfield(params, 'routing')
                realized_params.routing = params.routing;
            end
        end
    end
end
