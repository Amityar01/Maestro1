classdef NumericFieldSampler < handle
    % NumericFieldSampler - Samples values from numeric field specifications
    %
    % Handles:
    %   - Scalar values
    %   - Distribution sampling (uniform, normal, loguniform, categorical)
    %   - Scope management (per_trial, per_block, per_session)
    %   - RNG stream management
    %   - Validation before sampling
    %
    % Example:
    %   rng_manager = v1.sampling.RNGStreamManager(12345);
    %   scope_manager = v1.sampling.ScopeManager();
    %   sampler = v1.sampling.NumericFieldSampler(rng_manager, scope_manager);
    %
    %   field_spec = struct('dist', 'uniform', 'min', 900, 'max', 1100, 'scope', 'per_trial');
    %   value = sampler.sample(field_spec, 'frequency_hz');

    properties (Access = private)
        rng_manager     % RNGStreamManager instance
        scope_manager   % ScopeManager instance
        validate_first  % Whether to validate before sampling (default: true)
    end

    methods
        function obj = NumericFieldSampler(rng_manager, scope_manager, validate_first)
            % Constructor
            %
            % Args:
            %   rng_manager: RNGStreamManager instance
            %   scope_manager: ScopeManager instance
            %   validate_first: Whether to validate before sampling (default: true)

            if nargin < 2
                error('NumericFieldSampler:MissingArgs', ...
                    'Requires rng_manager and scope_manager');
            end

            if nargin < 3
                validate_first = true;
            end

            obj.rng_manager = rng_manager;
            obj.scope_manager = scope_manager;
            obj.validate_first = validate_first;
        end

        function value = sample(obj, field_spec, param_name, n_samples)
            % Sample a value from a numeric field specification
            %
            % Args:
            %   field_spec: Numeric field spec (scalar or distribution)
            %   param_name: Name of parameter (for stream naming and caching)
            %   n_samples: Number of samples to draw (default: 1)
            %
            % Returns:
            %   value: Sampled value (scalar) or array if n_samples > 1

            if nargin < 4
                n_samples = 1;
            end

            % Validate if requested
            if obj.validate_first
                [valid, errors] = v1.validation.NumericFieldValidator.validate(field_spec, param_name);
                if ~valid
                    error_report = v1.validation.ValidationError.format_errors(errors);
                    error('NumericFieldSampler:ValidationFailed', ...
                        'Field validation failed:\n%s', error_report);
                end
            end

            % Check if it's a scalar value
            if isnumeric(field_spec)
                % Implicit scalar: just a number
                value = repmat(field_spec, 1, n_samples);
                return;
            end

            if isfield(field_spec, 'value') && ~isfield(field_spec, 'dist')
                % Explicit scalar: {value: X}
                value = repmat(field_spec.value, 1, n_samples);
                return;
            end

            % It's a distribution - need to sample
            dist_type = field_spec.dist;
            scope = field_spec.scope;

            % Get or create RNG stream for this parameter
            stream_name = ['param_' param_name];
            stream = obj.rng_manager.get_stream(stream_name);

            % Define sampling function
            sample_fn = @() obj.sample_from_distribution(field_spec, stream, n_samples);

            % Use scope manager to get cached or new value
            value = obj.scope_manager.get_or_sample(param_name, scope, sample_fn);
        end

        function values = sample_from_distribution(obj, field_spec, stream, n_samples)
            % Sample from a distribution
            %
            % Args:
            %   field_spec: Distribution specification
            %   stream: RandStream to use
            %   n_samples: Number of samples
            %
            % Returns:
            %   values: Sampled values

            dist_type = field_spec.dist;

            switch dist_type
                case 'uniform'
                    values = v1.sampling.DistributionSamplers.sample_uniform(...
                        field_spec, stream, n_samples);

                case 'normal'
                    values = v1.sampling.DistributionSamplers.sample_normal(...
                        field_spec, stream, n_samples);

                case 'loguniform'
                    values = v1.sampling.DistributionSamplers.sample_loguniform(...
                        field_spec, stream, n_samples);

                case 'categorical'
                    values = v1.sampling.DistributionSamplers.sample_categorical(...
                        field_spec, stream, n_samples);

                otherwise
                    error('NumericFieldSampler:UnknownDistribution', ...
                        'Unknown distribution type: %s', dist_type);
            end
        end

        function moments = compute_moments(obj, field_spec)
            % Compute expected moments (mean, variance) for a field spec
            %
            % Args:
            %   field_spec: Numeric field specification
            %
            % Returns:
            %   moments: Struct with mean, variance

            if isnumeric(field_spec)
                moments.mean = field_spec;
                moments.variance = 0;
            elseif isfield(field_spec, 'value') && ~isfield(field_spec, 'dist')
                moments.mean = field_spec.value;
                moments.variance = 0;
            else
                moments = v1.sampling.DistributionSamplers.compute_moments(field_spec);
            end
        end

        function result = sample_struct(obj, spec_struct, param_prefix)
            % Sample all numeric fields in a struct
            %
            % Args:
            %   spec_struct: Struct with numeric field specs
            %   param_prefix: Prefix for parameter names (default: '')
            %
            % Returns:
            %   result: Struct with sampled values

            if nargin < 3
                param_prefix = '';
            end

            result = struct();
            field_names = fieldnames(spec_struct);

            for i = 1:length(field_names)
                field_name = field_names{i};
                field_value = spec_struct.(field_name);

                % Build parameter name
                if isempty(param_prefix)
                    param_name = field_name;
                else
                    param_name = [param_prefix '.' field_name];
                end

                if isstruct(field_value)
                    % Check if it's a numeric field spec
                    if isfield(field_value, 'dist') || isfield(field_value, 'value')
                        % It's a numeric field - sample it
                        result.(field_name) = obj.sample(field_value, param_name);
                    else
                        % It's a nested struct - recurse
                        result.(field_name) = obj.sample_struct(field_value, param_name);
                    end
                elseif isnumeric(field_value) && isscalar(field_value)
                    % Scalar number - treat as numeric field
                    result.(field_name) = field_value;
                else
                    % Pass through other types unchanged
                    result.(field_name) = field_value;
                end
            end
        end
    end
end
