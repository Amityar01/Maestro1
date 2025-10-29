classdef OddballAdapter < handle
    % OddballAdapter - Converts oddball configs → trial plans
    %
    % The oddball paradigm presents two or more stimulus types with
    % different probabilities. Standards are frequent, deviants are rare.
    %
    % Selection modes:
    %   - iid: Independent and identically distributed (true random)
    %   - balanced_shuffle: Exact proportions, shuffled
    %   - csv_preset: Predefined sequence from file/array
    %
    % Contract:
    %   - Input: oddball config + n_trials
    %   - Output: trial_plan ready for PatternBuilderCore
    %   - Deterministic: same seed → same sequence
    %   - Validates: probabilities sum to 1, constraints enforceable
    %
    % Example:
    %   adapter = v1.paradigms.OddballAdapter();
    %   config = struct('tokens', [...], 'selection', ..., 'iti', ...);
    %   trial_plan = adapter.generate_trial_plan(config, 100);

    methods
        function trial_plan = generate_trial_plan(obj, config, n_trials)
            % Generate trial plan from oddball configuration
            %
            % Args:
            %   config: Oddball configuration struct with fields:
            %     - tokens: Array of token structs (label, stimulus_ref, base_probability, code)
            %     - selection: Selection mode config (mode, seed, sequence if csv_preset)
            %     - iti: Inter-trial interval (numeric field)
            %     - constraints (optional): Constraint config (max_consecutive_*)
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

            % Generate trial sequence based on selection mode
            token_indices = obj.select_trials(config, n_trials);

            % Apply constraints if specified
            if isfield(config, 'constraints')
                token_indices = obj.apply_constraints(token_indices, config);
            end

            % Build trial plan
            trial_plan = obj.build_trial_plan(token_indices, config, n_trials);
        end

        function validate_config(obj, config)
            % Validate oddball configuration
            %
            % Args:
            %   config: Configuration to validate

            % Check required fields
            if ~isfield(config, 'tokens') || isempty(config.tokens)
                error('OddballAdapter:InvalidConfig', 'Config must have non-empty tokens array');
            end

            if ~isfield(config, 'selection')
                error('OddballAdapter:InvalidConfig', 'Config must have selection field');
            end

            if ~isfield(config, 'iti')
                error('OddballAdapter:InvalidConfig', 'Config must have iti field');
            end

            % Validate probabilities sum to 1
            probabilities = [config.tokens.base_probability];
            prob_sum = sum(probabilities);

            if abs(prob_sum - 1.0) > 0.001
                error('OddballAdapter:InvalidProbabilities', ...
                    'Token probabilities must sum to 1.0 (got %.3f)', prob_sum);
            end

            % Validate selection mode
            valid_modes = {'iid', 'balanced_shuffle', 'csv_preset'};
            if ~ismember(config.selection.mode, valid_modes)
                error('OddballAdapter:InvalidSelectionMode', ...
                    'Selection mode must be one of: %s', strjoin(valid_modes, ', '));
            end

            % Validate CSV preset has sequence
            if strcmp(config.selection.mode, 'csv_preset')
                if ~isfield(config.selection, 'sequence') || isempty(config.selection.sequence)
                    error('OddballAdapter:InvalidConfig', ...
                        'csv_preset mode requires selection.sequence field');
                end
            end
        end

        function token_indices = select_trials(obj, config, n_trials)
            % Select trials based on selection mode
            %
            % Args:
            %   config: Configuration
            %   n_trials: Number of trials to generate
            %
            % Returns:
            %   token_indices: Array of token indices (1-based)

            mode = config.selection.mode;

            switch mode
                case 'iid'
                    token_indices = obj.select_iid(config, n_trials);
                case 'balanced_shuffle'
                    token_indices = obj.select_balanced_shuffle(config, n_trials);
                case 'csv_preset'
                    token_indices = obj.select_csv_preset(config, n_trials);
                otherwise
                    error('OddballAdapter:UnknownMode', 'Unknown selection mode: %s', mode);
            end
        end

        function token_indices = select_iid(obj, config, n_trials)
            % Independent and identically distributed selection
            %
            % Args:
            %   config: Configuration
            %   n_trials: Number of trials
            %
            % Returns:
            %   token_indices: Randomly selected token indices

            probabilities = [config.tokens.base_probability];
            n_tokens = length(probabilities);

            % Compute cumulative probabilities for categorical sampling
            cum_probs = cumsum(probabilities);

            % Draw random samples
            token_indices = zeros(n_trials, 1);
            for i = 1:n_trials
                r = rand();
                token_indices(i) = find(r <= cum_probs, 1, 'first');
            end
        end

        function token_indices = select_balanced_shuffle(obj, config, n_trials)
            % Balanced shuffle: exact proportions, shuffled
            %
            % Args:
            %   config: Configuration
            %   n_trials: Number of trials
            %
            % Returns:
            %   token_indices: Shuffled token indices with exact proportions

            probabilities = [config.tokens.base_probability];
            n_tokens = length(probabilities);

            % Compute exact counts (round to nearest integer)
            counts = round(probabilities * n_trials);

            % Adjust counts to exactly match n_trials (handle rounding errors)
            count_sum = sum(counts);
            if count_sum ~= n_trials
                % Add/subtract from largest group
                [~, max_idx] = max(counts);
                counts(max_idx) = counts(max_idx) + (n_trials - count_sum);
            end

            % Build sequence with exact counts
            token_indices = [];
            for i = 1:n_tokens
                token_indices = [token_indices; repmat(i, counts(i), 1)];
            end

            % Shuffle
            token_indices = token_indices(randperm(length(token_indices)));
        end

        function token_indices = select_csv_preset(obj, config, n_trials)
            % CSV preset: use predefined sequence
            %
            % Args:
            %   config: Configuration (with selection.sequence)
            %   n_trials: Number of trials
            %
            % Returns:
            %   token_indices: Sequence from CSV (truncated if needed)

            sequence = config.selection.sequence;

            % Use first n_trials from sequence
            token_indices = sequence(1:min(n_trials, length(sequence)));

            % Pad with repetition if sequence is shorter
            if length(token_indices) < n_trials
                warning('OddballAdapter:ShortSequence', ...
                    'CSV sequence shorter than n_trials, repeating sequence');
                while length(token_indices) < n_trials
                    remaining = n_trials - length(token_indices);
                    token_indices = [token_indices; sequence(1:min(remaining, length(sequence)))];
                end
            end
        end

        function token_indices = apply_constraints(obj, token_indices, config)
            % Apply constraints to trial sequence
            %
            % Args:
            %   token_indices: Initial token sequence
            %   config: Configuration with constraints
            %
            % Returns:
            %   token_indices: Adjusted sequence respecting constraints

            constraints = config.constraints;

            % Apply max_consecutive_deviants
            if isfield(constraints, 'max_consecutive_deviants')
                token_indices = obj.enforce_max_consecutive(token_indices, config, ...
                    'deviant', constraints.max_consecutive_deviants);
            end

            % Apply max_consecutive_standards
            if isfield(constraints, 'max_consecutive_standards')
                token_indices = obj.enforce_max_consecutive(token_indices, config, ...
                    'standard', constraints.max_consecutive_standards);
            end
        end

        function token_indices = enforce_max_consecutive(obj, token_indices, config, target_label, max_consecutive)
            % Enforce max consecutive constraint for a label
            %
            % Args:
            %   token_indices: Token sequence
            %   config: Configuration
            %   target_label: Label to constrain (e.g., 'deviant')
            %   max_consecutive: Maximum consecutive occurrences
            %
            % Returns:
            %   token_indices: Adjusted sequence

            % Find token index for target label
            target_idx = find(strcmp({config.tokens.label}, target_label), 1);
            if isempty(target_idx)
                return;  % Label not found, nothing to constrain
            end

            % Scan for violations and swap
            consecutive_count = 0;
            for i = 1:length(token_indices)
                if token_indices(i) == target_idx
                    consecutive_count = consecutive_count + 1;

                    if consecutive_count > max_consecutive
                        % Find next non-target position to swap with
                        for j = i+1:length(token_indices)
                            if token_indices(j) ~= target_idx
                                % Swap
                                temp = token_indices(i);
                                token_indices(i) = token_indices(j);
                                token_indices(j) = temp;
                                consecutive_count = 0;
                                break;
                            end
                        end
                    end
                else
                    consecutive_count = 0;
                end
            end
        end

        function trial_plan = build_trial_plan(obj, token_indices, config, n_trials)
            % Build trial plan from token sequence
            %
            % Args:
            %   token_indices: Array of token indices
            %   config: Configuration
            %   n_trials: Number of trials
            %
            % Returns:
            %   trial_plan: Trial plan struct

            % Initialize trial plan
            trial_plan = struct();
            trial_plan.n_trials = n_trials;

            % Handle ITI (could be scalar or numeric field)
            if isfield(config.iti, 'value')
                trial_plan.iti_ms = config.iti.value;
            else
                % Numeric field - use mean for now (will be sampled later)
                % For trial plan, we just need a representative value
                trial_plan.iti_ms = obj.get_representative_value(config.iti);
            end

            % Build trials
            trial_plan.trials = cell(n_trials, 1);

            for i = 1:n_trials
                token_idx = token_indices(i);
                token = config.tokens(token_idx);

                % Create element for this trial
                element = struct();
                element.stimulus_ref = token.stimulus_ref;
                element.scheduled_onset_ms = 0;  % Oddball: stimulus starts at trial onset

                % Get duration from token
                if isfield(token, 'duration_ms')
                    if isstruct(token.duration_ms)
                        element.duration_ms = obj.get_representative_value(token.duration_ms);
                    else
                        element.duration_ms = token.duration_ms;
                    end
                else
                    % Default duration if not specified
                    element.duration_ms = 150;
                end

                % Create trial
                trial = struct();
                trial.trial_index = i - 1;  % 0-based
                trial.label = token.label;
                trial.code = token.code;
                trial.elements = {element};

                trial_plan.trials{i} = trial;
            end

            % Add metadata for provenance
            trial_plan.metadata = struct();
            trial_plan.metadata.paradigm = 'oddball';
            trial_plan.metadata.n_tokens = length(config.tokens);
            trial_plan.metadata.selection_mode = config.selection.mode;

            if isfield(config.selection, 'seed')
                trial_plan.metadata.selection_seed = config.selection.seed;
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
                % Scalar
                value = numeric_field.value;
            elseif strcmp(numeric_field.dist, 'uniform')
                % Use midpoint
                value = (numeric_field.min + numeric_field.max) / 2;
            elseif strcmp(numeric_field.dist, 'normal')
                % Use mean
                value = numeric_field.mean;
            elseif strcmp(numeric_field.dist, 'loguniform')
                % Use geometric mean
                value = exp((log(numeric_field.min) + log(numeric_field.max)) / 2);
            elseif strcmp(numeric_field.dist, 'categorical')
                % Use first value
                value = numeric_field.values(1);
            else
                error('OddballAdapter:UnknownDistribution', ...
                    'Unknown distribution type: %s', numeric_field.dist);
            end
        end
    end
end
