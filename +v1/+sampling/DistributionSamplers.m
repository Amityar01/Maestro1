classdef DistributionSamplers
    % DistributionSamplers - Pure functions for sampling from distributions
    %
    % All samplers are pure functions that take:
    %   - Distribution parameters
    %   - RNG stream
    %   - Number of samples
    %
    % And return:
    %   - Sampled values (array)

    methods (Static)
        function values = sample_uniform(params, stream, n_samples)
            % Sample from uniform distribution
            %
            % Args:
            %   params: Struct with min, max
            %   stream: RandStream object
            %   n_samples: Number of samples to draw
            %
            % Returns:
            %   values: Array of sampled values

            if nargin < 3
                n_samples = 1;
            end

            % Validate params
            if ~isfield(params, 'min') || ~isfield(params, 'max')
                error('DistributionSamplers:MissingParams', ...
                    'Uniform distribution requires min and max');
            end

            if params.min >= params.max
                error('DistributionSamplers:InvalidParams', ...
                    'min must be less than max');
            end

            % Sample
            u = rand(stream, 1, n_samples);
            values = params.min + u * (params.max - params.min);
        end

        function values = sample_normal(params, stream, n_samples)
            % Sample from normal distribution (with optional clipping)
            %
            % Args:
            %   params: Struct with mean, std, optional clip_min, clip_max
            %   stream: RandStream object
            %   n_samples: Number of samples to draw
            %
            % Returns:
            %   values: Array of sampled values

            if nargin < 3
                n_samples = 1;
            end

            % Validate params
            if ~isfield(params, 'mean') || ~isfield(params, 'std')
                error('DistributionSamplers:MissingParams', ...
                    'Normal distribution requires mean and std');
            end

            if params.std < 0
                error('DistributionSamplers:InvalidParams', ...
                    'std must be non-negative');
            end

            % Sample
            values = params.mean + params.std * randn(stream, 1, n_samples);

            % Apply clipping if specified
            if isfield(params, 'clip_min')
                values = max(values, params.clip_min);
            end

            if isfield(params, 'clip_max')
                values = min(values, params.clip_max);
            end
        end

        function values = sample_loguniform(params, stream, n_samples)
            % Sample from log-uniform distribution
            %
            % Args:
            %   params: Struct with min, max (both must be > 0)
            %   stream: RandStream object
            %   n_samples: Number of samples to draw
            %
            % Returns:
            %   values: Array of sampled values

            if nargin < 3
                n_samples = 1;
            end

            % Validate params
            if ~isfield(params, 'min') || ~isfield(params, 'max')
                error('DistributionSamplers:MissingParams', ...
                    'Log-uniform distribution requires min and max');
            end

            if params.min <= 0 || params.max <= 0
                error('DistributionSamplers:InvalidParams', ...
                    'Log-uniform min and max must be > 0');
            end

            if params.min >= params.max
                error('DistributionSamplers:InvalidParams', ...
                    'min must be less than max');
            end

            % Sample in log space
            log_min = log(params.min);
            log_max = log(params.max);

            u = rand(stream, 1, n_samples);
            log_values = log_min + u * (log_max - log_min);
            values = exp(log_values);
        end

        function values = sample_categorical(params, stream, n_samples)
            % Sample from categorical distribution
            %
            % Args:
            %   params: Struct with categories, probabilities
            %   stream: RandStream object
            %   n_samples: Number of samples to draw
            %
            % Returns:
            %   values: Array of sampled values

            if nargin < 3
                n_samples = 1;
            end

            % Validate params
            if ~isfield(params, 'categories') || ~isfield(params, 'probabilities')
                error('DistributionSamplers:MissingParams', ...
                    'Categorical distribution requires categories and probabilities');
            end

            if length(params.categories) ~= length(params.probabilities)
                error('DistributionSamplers:InvalidParams', ...
                    'categories and probabilities must have same length');
            end

            % Normalize probabilities (in case they don't sum to exactly 1.0)
            probs = params.probabilities / sum(params.probabilities);

            % Compute cumulative probabilities
            cumprobs = cumsum(probs);

            % Sample
            values = zeros(1, n_samples);
            for i = 1:n_samples
                u = rand(stream);
                idx = find(u <= cumprobs, 1, 'first');
                values(i) = params.categories(idx);
            end
        end

        function moments = compute_moments(params)
            % Compute expected mean and variance for a distribution
            %
            % Args:
            %   params: Distribution parameters (with dist field)
            %
            % Returns:
            %   moments: Struct with mean, variance

            moments = struct();

            if ~isfield(params, 'dist')
                % Scalar value
                if isfield(params, 'value')
                    moments.mean = params.value;
                    moments.variance = 0;
                else
                    moments.mean = NaN;
                    moments.variance = NaN;
                end
                return;
            end

            switch params.dist
                case 'uniform'
                    moments.mean = (params.min + params.max) / 2;
                    moments.variance = (params.max - params.min)^2 / 12;

                case 'normal'
                    moments.mean = params.mean;
                    moments.variance = params.std^2;

                case 'loguniform'
                    % For log-uniform, median is geometric mean
                    moments.mean = exp((log(params.min) + log(params.max)) / 2);
                    % Variance is more complex, approximate
                    log_var = (log(params.max) - log(params.min))^2 / 12;
                    moments.variance = moments.mean^2 * (exp(log_var) - 1);

                case 'categorical'
                    % Weighted average
                    moments.mean = sum(params.categories .* params.probabilities);
                    % Weighted variance
                    mean_val = moments.mean;
                    moments.variance = sum(params.probabilities .* (params.categories - mean_val).^2);

                otherwise
                    moments.mean = NaN;
                    moments.variance = NaN;
            end
        end
    end
end
