classdef GeneratorContext < handle
    % GeneratorContext - Provides common resources for generators
    %
    % Generators receive a context that provides:
    %   - Sample rate (fs_hz)
    %   - Sampler (for numeric field sampling)
    %   - RNG streams (for deterministic randomness)
    %   - Convenience methods
    %
    % Example:
    %   rng_manager = v1.sampling.RNGStreamManager(42);
    %   scope_manager = v1.sampling.ScopeManager();
    %   sampler = v1.sampling.NumericFieldSampler(rng_manager, scope_manager);
    %   context = v1.generators.GeneratorContext('fs_hz', 192000, 'sampler', sampler);

    properties (SetAccess = private)
        fs_hz          % Sample rate in Hz
        sampler        % NumericFieldSampler instance
        rng_manager    % RNGStreamManager instance
    end

    methods
        function obj = GeneratorContext(varargin)
            % Constructor
            %
            % Args (Name-Value pairs):
            %   fs_hz: Sample rate in Hz (required)
            %   sampler: NumericFieldSampler instance (required)

            p = inputParser;
            p.addParameter('fs_hz', [], @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('sampler', [], @(x) isa(x, 'v1.sampling.NumericFieldSampler'));
            p.parse(varargin{:});

            if isempty(p.Results.fs_hz)
                error('GeneratorContext:MissingFS', 'fs_hz is required');
            end

            if isempty(p.Results.sampler)
                error('GeneratorContext:MissingSampler', 'sampler is required');
            end

            obj.fs_hz = p.Results.fs_hz;
            obj.sampler = p.Results.sampler;

            % Get RNG manager from sampler (need to access through property)
            % For now, we'll create a getter method in the sampler or store it separately
            % Let's use a workaround: access through sampler's private property using subsref
            % Better: just pass it explicitly
        end

        function stream = get_rng_stream(obj, stream_name)
            % Get an RNG stream by name
            %
            % Args:
            %   stream_name: Name for the stream
            %
            % Returns:
            %   stream: RandStream object

            if isempty(obj.rng_manager)
                error('GeneratorContext:NoRNGManager', 'RNG manager not set');
            end

            stream = obj.rng_manager.get_stream(stream_name);
        end

        function set_rng_manager(obj, rng_manager)
            % Set the RNG manager (called after construction if needed)
            obj.rng_manager = rng_manager;
        end

        function value = sample_field(obj, field_spec, param_name)
            % Sample a numeric field
            %
            % Args:
            %   field_spec: Numeric field specification
            %   param_name: Parameter name
            %
            % Returns:
            %   value: Sampled value

            value = obj.sampler.sample(field_spec, param_name);
        end

        function n_samples = ms_to_samples(obj, duration_ms)
            % Convert milliseconds to samples
            %
            % Args:
            %   duration_ms: Duration in milliseconds
            %
            % Returns:
            %   n_samples: Number of samples

            n_samples = round(duration_ms * obj.fs_hz / 1000);
        end

        function duration_ms = samples_to_ms(obj, n_samples)
            % Convert samples to milliseconds
            %
            % Args:
            %   n_samples: Number of samples
            %
            % Returns:
            %   duration_ms: Duration in milliseconds

            duration_ms = (n_samples / obj.fs_hz) * 1000;
        end
    end
end
