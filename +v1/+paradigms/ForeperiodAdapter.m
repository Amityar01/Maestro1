classdef ForeperiodAdapter < handle
    % ForeperiodAdapter - Converts foreperiod configs → trial plans
    %
    % The foreperiod paradigm presents a cue followed by an outcome
    % after a variable delay (foreperiod). Tests temporal preparation
    % and expectancy.
    %
    % Each trial: cue → delay (foreperiod) → outcome
    %
    % Contract:
    %   - Input: foreperiod config + n_trials
    %   - Output: trial_plan with 2-element trials (cue + outcome)
    %   - Deterministic: same seed → same sequence
    %
    % Example:
    %   adapter = v1.paradigms.ForeperiodAdapter();
    %   config = struct('cue', ..., 'outcome', ..., 'foreperiods', [...], ...);
    %   trial_plan = adapter.generate_trial_plan(config, 100);

    methods
        function trial_plan = generate_trial_plan(obj, config, n_trials)
            % Generate trial plan from foreperiod configuration
            %
            % Args:
            %   config: Foreperiod configuration struct with fields:
            %     - cue: Cue stimulus configuration
            %     - outcome: Outcome stimulus configuration (single outcome)
            %       OR
            %     - outcomes: Array of outcome configurations with probabilities
            %     - foreperiods: Array of foreperiod durations (ms)
            %     - foreperiod_probs: Probability for each foreperiod
            %     - selection: Selection mode config (mode, seed)
            %     - iti: Inter-trial interval
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

            % Generate foreperiod sequence
            foreperiod_indices = obj.select_foreperiods(config, n_trials);

            % Generate outcome sequence (if multiple outcomes)
            if isfield(config, 'outcomes') && iscell(config.outcomes)
                outcome_indices = obj.select_outcomes(config, n_trials);
            else
                outcome_indices = ones(n_trials, 1);  % Single outcome
            end

            % Build trial plan
            trial_plan = obj.build_trial_plan(foreperiod_indices, outcome_indices, config, n_trials);
        end

        function validate_config(obj, config)
            % Validate foreperiod configuration

            % Check required fields
            if ~isfield(config, 'cue')
                error('ForeperiodAdapter:InvalidConfig', 'Config must have cue');
            end

            % Check for either outcome or outcomes
            if ~isfield(config, 'outcome') && ~isfield(config, 'outcomes')
                error('ForeperiodAdapter:InvalidConfig', 'Config must have outcome or outcomes');
            end

            % Validate outcomes if provided
            if isfield(config, 'outcomes')
                if ~iscell(config.outcomes) || isempty(config.outcomes)
                    error('ForeperiodAdapter:InvalidConfig', 'outcomes must be a non-empty cell array');
                end

                % Extract and validate outcome probabilities
                outcome_probs = zeros(1, length(config.outcomes));
                for i = 1:length(config.outcomes)
                    if ~isfield(config.outcomes{i}, 'probability')
                        error('ForeperiodAdapter:InvalidConfig', ...
                            'Each outcome must have a probability field');
                    end
                    outcome_probs(i) = config.outcomes{i}.probability;
                end

                % Validate probabilities sum to 1
                prob_sum = sum(outcome_probs);
                if abs(prob_sum - 1.0) > 0.001
                    error('ForeperiodAdapter:InvalidProbabilities', ...
                        'Outcome probabilities must sum to 1.0 (got %.3f)', prob_sum);
                end
            end

            if ~isfield(config, 'foreperiods') || isempty(config.foreperiods)
                error('ForeperiodAdapter:InvalidConfig', 'Config must have foreperiods array');
            end

            if ~isfield(config, 'foreperiod_probs')
                error('ForeperiodAdapter:InvalidConfig', 'Config must have foreperiod_probs');
            end

            if ~isfield(config, 'iti')
                error('ForeperiodAdapter:InvalidConfig', 'Config must have iti field');
            end

            if ~isfield(config, 'selection')
                error('ForeperiodAdapter:InvalidConfig', 'Config must have selection field');
            end

            % Validate probabilities sum to 1
            prob_sum = sum(config.foreperiod_probs);
            if abs(prob_sum - 1.0) > 0.001
                error('ForeperiodAdapter:InvalidProbabilities', ...
                    'Foreperiod probabilities must sum to 1.0 (got %.3f)', prob_sum);
            end

            % Validate arrays match length
            if length(config.foreperiods) ~= length(config.foreperiod_probs)
                error('ForeperiodAdapter:InvalidConfig', ...
                    'foreperiods and foreperiod_probs must have same length');
            end
        end

        function foreperiod_indices = select_foreperiods(obj, config, n_trials)
            % Select foreperiods based on selection mode

            mode = config.selection.mode;

            switch mode
                case 'iid'
                    foreperiod_indices = obj.select_iid(config, n_trials);
                case 'balanced_shuffle'
                    foreperiod_indices = obj.select_balanced_shuffle(config, n_trials);
                otherwise
                    error('ForeperiodAdapter:UnknownMode', 'Unknown selection mode: %s', mode);
            end
        end

        function foreperiod_indices = select_iid(obj, config, n_trials)
            % IID selection

            probabilities = config.foreperiod_probs;
            cum_probs = cumsum(probabilities);

            foreperiod_indices = zeros(n_trials, 1);
            for i = 1:n_trials
                r = rand();
                foreperiod_indices(i) = find(r <= cum_probs, 1, 'first');
            end
        end

        function foreperiod_indices = select_balanced_shuffle(obj, config, n_trials)
            % Balanced shuffle: exact proportions

            probabilities = config.foreperiod_probs;
            n_foreperiods = length(probabilities);

            % Compute exact counts
            counts = round(probabilities * n_trials);

            % Adjust for rounding errors
            count_sum = sum(counts);
            if count_sum ~= n_trials
                [~, max_idx] = max(counts);
                counts(max_idx) = counts(max_idx) + (n_trials - count_sum);
            end

            % Build sequence
            foreperiod_indices = [];
            for i = 1:n_foreperiods
                foreperiod_indices = [foreperiod_indices; repmat(i, counts(i), 1)];
            end

            % Shuffle
            foreperiod_indices = foreperiod_indices(randperm(length(foreperiod_indices)));
        end

        function outcome_indices = select_outcomes(obj, config, n_trials)
            % Select outcomes based on selection mode

            % Extract outcome probabilities
            outcome_probs = zeros(1, length(config.outcomes));
            for i = 1:length(config.outcomes)
                outcome_probs(i) = config.outcomes{i}.probability;
            end

            mode = config.selection.mode;

            switch mode
                case 'iid'
                    outcome_indices = obj.select_outcomes_iid(outcome_probs, n_trials);
                case 'balanced_shuffle'
                    outcome_indices = obj.select_outcomes_balanced(outcome_probs, n_trials);
                otherwise
                    error('ForeperiodAdapter:UnknownMode', 'Unknown selection mode: %s', mode);
            end
        end

        function outcome_indices = select_outcomes_iid(obj, probabilities, n_trials)
            % IID selection for outcomes

            cum_probs = cumsum(probabilities);

            outcome_indices = zeros(n_trials, 1);
            for i = 1:n_trials
                r = rand();
                outcome_indices(i) = find(r <= cum_probs, 1, 'first');
            end
        end

        function outcome_indices = select_outcomes_balanced(obj, probabilities, n_trials)
            % Balanced shuffle for outcomes: exact proportions

            n_outcomes = length(probabilities);

            % Compute exact counts
            counts = round(probabilities * n_trials);

            % Adjust for rounding errors
            count_sum = sum(counts);
            if count_sum ~= n_trials
                [~, max_idx] = max(counts);
                counts(max_idx) = counts(max_idx) + (n_trials - count_sum);
            end

            % Build sequence
            outcome_indices = [];
            for i = 1:n_outcomes
                outcome_indices = [outcome_indices; repmat(i, counts(i), 1)];
            end

            % Shuffle
            outcome_indices = outcome_indices(randperm(length(outcome_indices)));
        end

        function trial_plan = build_trial_plan(obj, foreperiod_indices, outcome_indices, config, n_trials)
            % Build trial plan from foreperiod and outcome sequences

            % Initialize trial plan
            trial_plan = struct();
            trial_plan.n_trials = n_trials;

            % Get ITI value
            if isfield(config.iti, 'value')
                trial_plan.iti_ms = config.iti.value;
            else
                trial_plan.iti_ms = obj.get_representative_value(config.iti);
            end

            % Get cue duration
            cue_duration = obj.get_duration(config.cue);

            % Determine if using single outcome or multiple outcomes
            use_multiple_outcomes = isfield(config, 'outcomes') && iscell(config.outcomes);

            % Build trials
            trial_plan.trials = cell(n_trials, 1);

            for i = 1:n_trials
                foreperiod_idx = foreperiod_indices(i);
                foreperiod_ms = config.foreperiods(foreperiod_idx);

                % Create cue element
                cue_element = struct();
                cue_element.stimulus_ref = config.cue.stimulus_ref;
                cue_element.scheduled_onset_ms = 0;
                cue_element.duration_ms = cue_duration;
                cue_element.role = 'cue';

                % Create outcome element based on outcome type
                if use_multiple_outcomes
                    outcome_idx = outcome_indices(i);
                    outcome_config = config.outcomes{outcome_idx};

                    % Check if this is an omission trial
                    is_omission = isfield(outcome_config, 'is_omission') && outcome_config.is_omission;

                    if is_omission
                        % For omission trials, create a silent/null outcome
                        outcome_element = struct();
                        outcome_element.stimulus_ref = 'omission';
                        outcome_element.scheduled_onset_ms = foreperiod_ms;
                        outcome_element.duration_ms = 0;
                        outcome_element.role = 'outcome';
                        outcome_element.is_omission = true;
                    else
                        % Regular outcome
                        outcome_element = struct();
                        outcome_element.stimulus_ref = outcome_config.stimulus_ref;
                        outcome_element.scheduled_onset_ms = foreperiod_ms;
                        outcome_element.duration_ms = obj.get_duration(outcome_config);
                        outcome_element.role = 'outcome';
                        if isfield(outcome_config, 'label')
                            outcome_element.label = outcome_config.label;
                        end
                    end
                else
                    % Single outcome (backwards compatibility)
                    outcome_element = struct();
                    outcome_element.stimulus_ref = config.outcome.stimulus_ref;
                    outcome_element.scheduled_onset_ms = foreperiod_ms;
                    outcome_element.duration_ms = obj.get_duration(config.outcome);
                    outcome_element.role = 'outcome';
                end

                % Create trial
                trial = struct();
                trial.trial_index = i - 1;  % 0-based
                trial.label = sprintf('FP_%dms', foreperiod_ms);
                trial.foreperiod_ms = foreperiod_ms;
                trial.elements = {cue_element, outcome_element};

                trial_plan.trials{i} = trial;
            end

            % Add metadata
            trial_plan.metadata = struct();
            trial_plan.metadata.paradigm = 'foreperiod';
            trial_plan.metadata.n_foreperiods = length(config.foreperiods);
            trial_plan.metadata.foreperiods_ms = config.foreperiods;
            trial_plan.metadata.selection_mode = config.selection.mode;

            if use_multiple_outcomes
                trial_plan.metadata.n_outcomes = length(config.outcomes);
            end

            if isfield(config.selection, 'seed')
                trial_plan.metadata.selection_seed = config.selection.seed;
            end
        end

        function duration = get_duration(obj, stimulus_config)
            % Get duration from stimulus config

            if isfield(stimulus_config, 'duration_ms')
                if isstruct(stimulus_config.duration_ms)
                    duration = obj.get_representative_value(stimulus_config.duration_ms);
                else
                    duration = stimulus_config.duration_ms;
                end
            else
                duration = 150;  % Default
            end
        end

        function value = get_representative_value(obj, numeric_field)
            % Get representative scalar from numeric field

            if ~isstruct(numeric_field)
                value = numeric_field;
                return;
            end

            if isfield(numeric_field, 'value')
                value = numeric_field.value;
            elseif strcmp(numeric_field.dist, 'uniform')
                value = (numeric_field.min + numeric_field.max) / 2;
            elseif strcmp(numeric_field.dist, 'normal')
                value = numeric_field.mean;
            else
                value = 150;  % Default
            end
        end
    end
end
