classdef LocalGlobalAdapter < handle
    % LocalGlobalAdapter - Converts Local-Global configs → trial plans
    %
    % The Local-Global paradigm presents sequences of tokens testing
    % local regularity (AAA...) vs global regularity (AAAB pattern).
    %
    % Each trial contains MULTIPLE elements (e.g., AAAB = 4 elements)
    % separated by IOI (inter-onset interval).
    %
    % Contract:
    %   - Input: local_global config + n_trials
    %   - Output: trial_plan with multi-element trials
    %   - Deterministic: same seed → same sequence
    %   - Symbols: Track A/B for each element
    %
    % Example:
    %   adapter = v1.paradigms.LocalGlobalAdapter();
    %   config = struct('token_a', ..., 'token_b', ..., 'patterns', [...], ...);
    %   trial_plan = adapter.generate_trial_plan(config, 100);

    methods
        function trial_plan = generate_trial_plan(obj, config, n_trials)
            % Generate trial plan from Local-Global configuration
            %
            % Args:
            %   config: Local-Global configuration struct with fields:
            %     - token_a: Token A configuration (stimulus_ref, duration_ms)
            %     - token_b: Token B configuration (stimulus_ref, duration_ms)
            %     - patterns: Array of pattern structs (label, sequence, base_probability)
            %     - ioi: Inter-onset interval (numeric field)
            %     - iti: Inter-trial interval (numeric field)
            %     - selection: Selection mode config (mode, seed)
            %
            %   n_trials: Number of trials to generate
            %
            % Returns:
            %   trial_plan: Trial plan struct ready for PatternBuilderCore

            % Validate configuration
            obj.validate_config(config);

            % Initialize RNG if seed provided
            if isfield(config.selection, 'seed')
                rng(config.selection.seed, 'twister');
            end

            % Generate pattern sequence
            pattern_indices = obj.select_patterns(config, n_trials);

            % Build trial plan
            trial_plan = obj.build_trial_plan(pattern_indices, config, n_trials);
        end

        function validate_config(obj, config)
            % Validate Local-Global configuration
            %
            % Args:
            %   config: Configuration to validate

            % Check required fields
            if ~isfield(config, 'token_a')
                error('LocalGlobalAdapter:InvalidConfig', 'Config must have token_a');
            end

            if ~isfield(config, 'token_b')
                error('LocalGlobalAdapter:InvalidConfig', 'Config must have token_b');
            end

            if ~isfield(config, 'patterns') || isempty(config.patterns)
                error('LocalGlobalAdapter:InvalidConfig', 'Config must have non-empty patterns array');
            end

            if ~isfield(config, 'ioi')
                error('LocalGlobalAdapter:InvalidConfig', 'Config must have ioi field');
            end

            if ~isfield(config, 'iti')
                error('LocalGlobalAdapter:InvalidConfig', 'Config must have iti field');
            end

            if ~isfield(config, 'selection')
                error('LocalGlobalAdapter:InvalidConfig', 'Config must have selection field');
            end

            % Validate probabilities sum to 1
            probabilities = [config.patterns.base_probability];
            prob_sum = sum(probabilities);

            if abs(prob_sum - 1.0) > 0.001
                error('LocalGlobalAdapter:InvalidProbabilities', ...
                    'Pattern probabilities must sum to 1.0 (got %.3f)', prob_sum);
            end

            % Validate selection mode
            valid_modes = {'iid', 'balanced_shuffle'};
            if ~ismember(config.selection.mode, valid_modes)
                error('LocalGlobalAdapter:InvalidSelectionMode', ...
                    'Selection mode must be one of: %s', strjoin(valid_modes, ', '));
            end
        end

        function pattern_indices = select_patterns(obj, config, n_trials)
            % Select patterns based on selection mode
            %
            % Args:
            %   config: Configuration
            %   n_trials: Number of trials to generate
            %
            % Returns:
            %   pattern_indices: Array of pattern indices (1-based)

            mode = config.selection.mode;

            switch mode
                case 'iid'
                    pattern_indices = obj.select_iid(config, n_trials);
                case 'balanced_shuffle'
                    pattern_indices = obj.select_balanced_shuffle(config, n_trials);
                otherwise
                    error('LocalGlobalAdapter:UnknownMode', 'Unknown selection mode: %s', mode);
            end
        end

        function pattern_indices = select_iid(obj, config, n_trials)
            % Independent and identically distributed selection
            %
            % Args:
            %   config: Configuration
            %   n_trials: Number of trials
            %
            % Returns:
            %   pattern_indices: Randomly selected pattern indices

            probabilities = [config.patterns.base_probability];
            n_patterns = length(probabilities);

            % Compute cumulative probabilities
            cum_probs = cumsum(probabilities);

            % Draw random samples
            pattern_indices = zeros(n_trials, 1);
            for i = 1:n_trials
                r = rand();
                pattern_indices(i) = find(r <= cum_probs, 1, 'first');
            end
        end

        function pattern_indices = select_balanced_shuffle(obj, config, n_trials)
            % Balanced shuffle: exact proportions, shuffled
            %
            % Args:
            %   config: Configuration
            %   n_trials: Number of trials
            %
            % Returns:
            %   pattern_indices: Shuffled pattern indices with exact proportions

            probabilities = [config.patterns.base_probability];
            n_patterns = length(probabilities);

            % Compute exact counts
            counts = round(probabilities * n_trials);

            % Adjust for rounding errors
            count_sum = sum(counts);
            if count_sum ~= n_trials
                [~, max_idx] = max(counts);
                counts(max_idx) = counts(max_idx) + (n_trials - count_sum);
            end

            % Build sequence
            pattern_indices = [];
            for i = 1:n_patterns
                pattern_indices = [pattern_indices; repmat(i, counts(i), 1)];
            end

            % Shuffle
            pattern_indices = pattern_indices(randperm(length(pattern_indices)));
        end

        function trial_plan = build_trial_plan(obj, pattern_indices, config, n_trials)
            % Build trial plan from pattern sequence
            %
            % Args:
            %   pattern_indices: Array of pattern indices
            %   config: Configuration
            %   n_trials: Number of trials
            %
            % Returns:
            %   trial_plan: Trial plan struct

            % Initialize trial plan
            trial_plan = struct();
            trial_plan.n_trials = n_trials;

            % Get IOI value
            if isfield(config.ioi, 'value')
                ioi_ms = config.ioi.value;
            else
                ioi_ms = obj.get_representative_value(config.ioi);
            end

            % Get ITI value
            if isfield(config.iti, 'value')
                trial_plan.iti_ms = config.iti.value;
            else
                trial_plan.iti_ms = obj.get_representative_value(config.iti);
            end

            % Get token durations
            if isfield(config.token_a, 'duration_ms')
                if isstruct(config.token_a.duration_ms)
                    duration_a = obj.get_representative_value(config.token_a.duration_ms);
                else
                    duration_a = config.token_a.duration_ms;
                end
            else
                duration_a = 50;  % Default
            end

            if isfield(config.token_b, 'duration_ms')
                if isstruct(config.token_b.duration_ms)
                    duration_b = obj.get_representative_value(config.token_b.duration_ms);
                else
                    duration_b = config.token_b.duration_ms;
                end
            else
                duration_b = 50;  % Default
            end

            % Build trials
            trial_plan.trials = cell(n_trials, 1);

            for i = 1:n_trials
                pattern_idx = pattern_indices(i);
                pattern = config.patterns(pattern_idx);

                % Expand pattern sequence to elements
                elements = obj.expand_pattern(pattern.sequence, config.token_a, config.token_b, ...
                                             ioi_ms, duration_a, duration_b);

                % Create trial
                trial = struct();
                trial.trial_index = i - 1;  % 0-based
                trial.label = pattern.label;
                trial.elements = elements;

                trial_plan.trials{i} = trial;
            end

            % Add metadata
            trial_plan.metadata = struct();
            trial_plan.metadata.paradigm = 'local_global';
            trial_plan.metadata.n_patterns = length(config.patterns);
            trial_plan.metadata.selection_mode = config.selection.mode;

            if isfield(config.selection, 'seed')
                trial_plan.metadata.selection_seed = config.selection.seed;
            end
        end

        function elements = expand_pattern(obj, sequence, token_a, token_b, ioi_ms, duration_a, duration_b)
            % Expand pattern sequence to element list
            %
            % Args:
            %   sequence: Pattern string (e.g., 'AAAB')
            %   token_a: Token A config
            %   token_b: Token B config
            %   ioi_ms: Inter-onset interval
            %   duration_a: Duration for A tokens
            %   duration_b: Duration for B tokens
            %
            % Returns:
            %   elements: Cell array of element structs

            n_elements = length(sequence);
            elements = cell(n_elements, 1);

            for i = 1:n_elements
                symbol = sequence(i);

                % Create element
                element = struct();

                % Select token based on symbol
                if symbol == 'A'
                    element.stimulus_ref = token_a.stimulus_ref;
                    element.duration_ms = duration_a;
                else  % 'B'
                    element.stimulus_ref = token_b.stimulus_ref;
                    element.duration_ms = duration_b;
                end

                % Compute onset (IOI spacing)
                element.scheduled_onset_ms = (i - 1) * ioi_ms;

                % Add symbol for tracking
                element.symbol = symbol;

                elements{i} = element;
            end
        end

        function value = get_representative_value(obj, numeric_field)
            % Get a representative scalar value from a numeric field
            %
            % Args:
            %   numeric_field: Scalar or numeric field struct
            %
            % Returns:
            %   value: Representative scalar value

            if ~isstruct(numeric_field)
                value = numeric_field;
                return;
            end

            % Handle different distribution types
            if isfield(numeric_field, 'value')
                value = numeric_field.value;
            elseif strcmp(numeric_field.dist, 'uniform')
                value = (numeric_field.min + numeric_field.max) / 2;
            elseif strcmp(numeric_field.dist, 'normal')
                value = numeric_field.mean;
            elseif strcmp(numeric_field.dist, 'loguniform')
                value = exp((log(numeric_field.min) + log(numeric_field.max)) / 2);
            elseif strcmp(numeric_field.dist, 'categorical')
                value = numeric_field.values(1);
            else
                error('LocalGlobalAdapter:UnknownDistribution', ...
                    'Unknown distribution type: %s', numeric_field.dist);
            end
        end
    end
end
