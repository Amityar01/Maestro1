classdef CustomValidators
    % CustomValidators - Domain-specific validation rules
    %
    % Provides custom validators for:
    %   - Probabilities sum to 1.0
    %   - Unique labels
    %   - Timing feasibility
    %   - Budget constraints

    methods (Static)
        function [valid, errors] = validate_probabilities_sum(probabilities, field_path, tolerance)
            % Validate that probabilities sum to 1.0
            %
            % Args:
            %   probabilities: Array of probability values
            %   field_path: Field path for error reporting
            %   tolerance: Acceptable deviation from 1.0 (default: 0.001)
            %
            % Returns:
            %   valid: Boolean
            %   errors: Cell array of ValidationError objects

            if nargin < 3
                tolerance = 0.001;
            end

            errors = {};

            if ~isnumeric(probabilities)
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'type_mismatch', ...
                    'Probabilities must be numeric array');
                valid = false;
                return;
            end

            prob_sum = sum(probabilities);

            if abs(prob_sum - 1.0) > tolerance
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'probability_sum', ...
                    sprintf('Probabilities must sum to 1.0 (±%g)', tolerance), ...
                    prob_sum, 1.0);
            end

            % Check all probabilities in valid range
            if any(probabilities < 0) || any(probabilities > 1)
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'probability_range', ...
                    'All probabilities must be in range [0, 1]');
            end

            valid = isempty(errors);
        end

        function [valid, errors] = validate_unique_labels(labels, field_path)
            % Validate that all labels are unique
            %
            % Args:
            %   labels: Cell array of label strings
            %   field_path: Field path for error reporting
            %
            % Returns:
            %   valid: Boolean
            %   errors: Cell array of ValidationError objects

            errors = {};

            if ~iscell(labels) && ~isstring(labels)
                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'type_mismatch', ...
                    'Labels must be cell array or string array');
                valid = false;
                return;
            end

            [unique_labels, ~, indices] = unique(labels);

            if length(unique_labels) < length(labels)
                % Find duplicates
                duplicates = {};
                for i = 1:length(unique_labels)
                    label = unique_labels{i};
                    count = sum(strcmp(labels, label));
                    if count > 1
                        duplicates{end+1} = sprintf('%s (appears %d times)', label, count);
                    end
                end

                errors{end+1} = v1.validation.ValidationError(...
                    field_path, 'duplicate_labels', ...
                    sprintf('Duplicate labels found: %s', strjoin(duplicates, ', ')));
            end

            valid = isempty(errors);
        end

        function [valid, errors] = validate_timing_feasibility(trial_plan, field_path)
            % Validate that timing constraints are feasible
            %
            % Checks:
            %   - Ramps + refractory fit within IOI/ITI
            %   - Element timings don't overlap
            %
            % Args:
            %   trial_plan: Struct with timing information
            %   field_path: Field path for error reporting
            %
            % Returns:
            %   valid: Boolean
            %   errors: Cell array of ValidationError objects

            errors = {};

            % Check if ramps + stimulus duration + refractory fit in trial window
            if isfield(trial_plan, 'ramp_ms') && isfield(trial_plan, 'duration_ms') && ...
               isfield(trial_plan, 'refractory_ms') && isfield(trial_plan, 'iti_ms')

                total_time = trial_plan.ramp_ms * 2 + trial_plan.duration_ms + trial_plan.refractory_ms;
                available_time = trial_plan.iti_ms;

                if total_time > available_time
                    errors{end+1} = v1.validation.ValidationError(...
                        field_path, 'timing_infeasible', ...
                        sprintf('Total time (%g ms) exceeds available ITI (%g ms)', ...
                                total_time, available_time), ...
                        total_time, available_time);
                end
            end

            valid = isempty(errors);
        end

        function [valid, errors] = validate_budget(config, field_path)
            % Validate resource budget constraints
            %
            % Args:
            %   config: Configuration struct with budget information
            %   field_path: Field path for error reporting
            %
            % Returns:
            %   valid: Boolean
            %   errors: Cell array of ValidationError objects

            errors = {};

            % Check memory budget
            if isfield(config, 'estimated_memory_mb') && isfield(config, 'budget') && ...
               isfield(config.budget, 'max_memory_mb')

                if config.estimated_memory_mb > config.budget.max_memory_mb
                    errors{end+1} = v1.validation.ValidationError(...
                        field_path, 'budget_exceeded', ...
                        sprintf('Estimated memory (%g MB) exceeds budget (%g MB)', ...
                                config.estimated_memory_mb, config.budget.max_memory_mb), ...
                        config.estimated_memory_mb, config.budget.max_memory_mb);
                end
            end

            % Check sample count budget
            if isfield(config, 'estimated_samples') && isfield(config, 'budget') && ...
               isfield(config.budget, 'max_samples')

                if config.estimated_samples > config.budget.max_samples
                    errors{end+1} = v1.validation.ValidationError(...
                        field_path, 'budget_exceeded', ...
                        sprintf('Estimated samples (%d) exceeds budget (%d)', ...
                                config.estimated_samples, config.budget.max_samples), ...
                        config.estimated_samples, config.budget.max_samples);
                end
            end

            valid = isempty(errors);
        end

        function [valid, errors] = validate_oddball_config(oddball_config)
            % Validate complete oddball paradigm configuration
            %
            % Args:
            %   oddball_config: Oddball configuration struct
            %
            % Returns:
            %   valid: Boolean
            %   errors: Cell array of ValidationError objects

            errors = {};

            % Extract token probabilities
            if isfield(oddball_config, 'tokens')
                probabilities = zeros(1, length(oddball_config.tokens));
                labels = cell(1, length(oddball_config.tokens));

                for i = 1:length(oddball_config.tokens)
                    token = oddball_config.tokens{i};
                    if isfield(token, 'base_probability')
                        probabilities(i) = token.base_probability;
                    end
                    if isfield(token, 'label')
                        labels{i} = token.label;
                    end
                end

                % Validate probabilities sum
                [prob_valid, prob_errs] = v1.validation.CustomValidators.validate_probabilities_sum(...
                    probabilities, 'tokens.*.base_probability');
                errors = [errors prob_errs];

                % Validate unique labels
                [label_valid, label_errs] = v1.validation.CustomValidators.validate_unique_labels(...
                    labels, 'tokens.*.label');
                errors = [errors label_errs];
            end

            valid = isempty(errors);
        end

        function [valid, errors] = validate_local_global_config(lg_config)
            % Validate complete local-global paradigm configuration
            %
            % Args:
            %   lg_config: Local-global configuration struct
            %
            % Returns:
            %   valid: Boolean
            %   errors: Cell array of ValidationError objects

            errors = {};

            % Validate pattern probabilities
            if isfield(lg_config, 'patterns')
                probabilities = zeros(1, length(lg_config.patterns));
                pattern_names = cell(1, length(lg_config.patterns));

                for i = 1:length(lg_config.patterns)
                    pattern = lg_config.patterns{i};
                    if isfield(pattern, 'probability')
                        probabilities(i) = pattern.probability;
                    end
                    if isfield(pattern, 'name')
                        pattern_names{i} = pattern.name;
                    end
                end

                % Validate probabilities sum
                [prob_valid, prob_errs] = v1.validation.CustomValidators.validate_probabilities_sum(...
                    probabilities, 'patterns.*.probability');
                errors = [errors prob_errs];

                % Validate unique pattern names
                [name_valid, name_errs] = v1.validation.CustomValidators.validate_unique_labels(...
                    pattern_names, 'patterns.*.name');
                errors = [errors name_errs];

                % Validate symbols referenced in patterns exist in symbols array
                if isfield(lg_config, 'symbols')
                    symbol_chars = cellfun(@(s) s.symbol, lg_config.symbols, 'UniformOutput', false);

                    for i = 1:length(lg_config.patterns)
                        pattern = lg_config.patterns{i};
                        if isfield(pattern, 'elements')
                            for j = 1:length(pattern.elements)
                                element = pattern.elements{j};
                                if isfield(element, 'symbol')
                                    if ~ismember(element.symbol, symbol_chars)
                                        errors{end+1} = v1.validation.ValidationError(...
                                            sprintf('patterns[%d].elements[%d].symbol', i-1, j-1), ...
                                            'invalid_reference', ...
                                            sprintf('Symbol "%s" not found in symbols array', element.symbol), ...
                                            element.symbol);
                                    end
                                end
                            end
                        end
                    end
                end
            end

            valid = isempty(errors);
        end
    end
end
