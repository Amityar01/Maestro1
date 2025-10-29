classdef PatternBuilderCore < handle
    % PatternBuilderCore - Expands trial plans into element tables
    %
    % The Pattern Builder is the heart of the compilation pipeline.
    % It takes a trial plan (trials with elements) and expands it into
    % a flat element table with absolute timing.
    %
    % Contract:
    %   - Input: trial_plan struct with trials and timing parameters
    %   - Output: MATLAB table with absolute timing for all elements
    %   - Handles: ITI, IOI, refractory periods, metadata preservation
    %   - Pure function: deterministic, no side effects
    %
    % Example:
    %   builder = v1.compilation.PatternBuilderCore();
    %   trial_plan = struct('n_trials', 3, 'iti_ms', 500, 'trials', {...});
    %   element_table = builder.build(trial_plan);

    methods
        function element_table = build(obj, trial_plan)
            % Build element table from trial plan
            %
            % Args:
            %   trial_plan: Struct with fields:
            %     - n_trials: Number of trials
            %     - iti_ms: Inter-trial interval in milliseconds
            %     - trials: Cell array of trial structs
            %     - refractory_ms (optional): Silent period after each element
            %     - ioi_ms (optional): Inter-onset interval (for reference)
            %
            % Each trial struct contains:
            %     - trial_index: 0-based trial index
            %     - label: Trial label (string)
            %     - elements: Cell array of element structs
            %
            % Each element struct contains:
            %     - stimulus_ref: Reference to stimulus definition
            %     - scheduled_onset_ms: Onset relative to trial start
            %     - duration_ms: Element duration
            %     - role (optional): Element role (e.g., 'cue', 'outcome')
            %     - symbol (optional): Symbol for abstract patterns
            %     - envelope (optional): Envelope parameters
            %
            % Returns:
            %   element_table: MATLAB table with columns:
            %     - trial_index: 0-based trial index
            %     - element_index: 0-based element index within trial
            %     - stimulus_ref: Stimulus reference
            %     - absolute_onset_ms: Absolute onset time from experiment start
            %     - duration_ms: Element duration
            %     - label: Trial label
            %     - role (if any elements have roles)
            %     - symbol (if any elements have symbols)

            % Validate input
            obj.validate_trial_plan(trial_plan);

            % Extract parameters
            n_trials = trial_plan.n_trials;
            iti_ms = trial_plan.iti_ms;
            trials = trial_plan.trials;

            refractory_ms = 0;
            if isfield(trial_plan, 'refractory_ms')
                refractory_ms = trial_plan.refractory_ms;
            end

            % Pre-allocate storage for table data
            max_elements = n_trials * 10;  % Estimate, will trim later
            trial_indices = zeros(max_elements, 1);
            element_indices = zeros(max_elements, 1);
            stimulus_refs = cell(max_elements, 1);
            absolute_onsets = zeros(max_elements, 1);
            durations = zeros(max_elements, 1);
            labels = cell(max_elements, 1);
            roles = cell(max_elements, 1);
            symbols = cell(max_elements, 1);

            % Track whether we need role/symbol columns
            has_roles = false;
            has_symbols = false;

            % Build element list
            element_count = 0;
            current_time = 0;  % Absolute time cursor

            for trial_idx = 1:length(trials)
                trial = trials{trial_idx};
                trial_start_time = current_time;

                % Skip empty trials (omissions)
                if isempty(trial.elements)
                    % Empty trial still advances time by ITI
                    current_time = current_time + iti_ms;
                    continue;
                end

                % Process each element in trial
                trial_duration = 0;
                for elem_idx = 1:length(trial.elements)
                    element = trial.elements{elem_idx};

                    % Increment counter
                    element_count = element_count + 1;

                    % Store element data
                    trial_indices(element_count) = trial.trial_index;
                    element_indices(element_count) = elem_idx - 1;  % 0-based
                    stimulus_refs{element_count} = element.stimulus_ref;
                    absolute_onsets(element_count) = trial_start_time + element.scheduled_onset_ms;
                    durations(element_count) = element.duration_ms;
                    labels{element_count} = trial.label;

                    % Optional fields
                    if isfield(element, 'role')
                        roles{element_count} = element.role;
                        has_roles = true;
                    else
                        roles{element_count} = '';
                    end

                    if isfield(element, 'symbol')
                        symbols{element_count} = element.symbol;
                        has_symbols = true;
                    else
                        symbols{element_count} = '';
                    end

                    % Compute trial duration (end of last element + refractory)
                    element_end = element.scheduled_onset_ms + element.duration_ms;
                    trial_duration = max(trial_duration, element_end);
                end

                % Add refractory period to trial duration
                trial_duration = trial_duration + refractory_ms;

                % Advance time: trial duration + ITI
                current_time = trial_start_time + trial_duration + iti_ms;
            end

            % Trim to actual count
            trial_indices = trial_indices(1:element_count);
            element_indices = element_indices(1:element_count);
            stimulus_refs = stimulus_refs(1:element_count);
            absolute_onsets = absolute_onsets(1:element_count);
            durations = durations(1:element_count);
            labels = labels(1:element_count);
            roles = roles(1:element_count);
            symbols = symbols(1:element_count);

            % Build table with required columns
            element_table = table(trial_indices, element_indices, stimulus_refs, ...
                                 absolute_onsets, durations, labels, ...
                                 'VariableNames', {'trial_index', 'element_index', ...
                                                  'stimulus_ref', 'absolute_onset_ms', ...
                                                  'duration_ms', 'label'});

            % Add optional columns if present
            if has_roles
                element_table.role = roles;
            end

            if has_symbols
                element_table.symbol = symbols;
            end

            % Store trial window information in UserData
            % (for downstream use in validation/visualization)
            element_table.Properties.UserData = struct();
            element_table.Properties.UserData.trial_windows = obj.compute_trial_windows(trials);
        end

        function validate_trial_plan(obj, trial_plan)
            % Validate trial plan structure
            %
            % Args:
            %   trial_plan: Trial plan struct to validate

            % Check required fields
            required_fields = {'n_trials', 'iti_ms', 'trials'};
            for i = 1:length(required_fields)
                if ~isfield(trial_plan, required_fields{i})
                    error('PatternBuilderCore:MissingField', ...
                        'Trial plan missing required field: %s', required_fields{i});
                end
            end

            % Validate n_trials
            if ~isnumeric(trial_plan.n_trials) || trial_plan.n_trials < 0
                error('PatternBuilderCore:InvalidTrialCount', ...
                    'n_trials must be a non-negative number');
            end

            % Validate iti_ms
            if ~isnumeric(trial_plan.iti_ms) || trial_plan.iti_ms < 0
                error('PatternBuilderCore:InvalidITI', ...
                    'iti_ms must be a non-negative number');
            end

            % Validate trials is a cell array
            if ~iscell(trial_plan.trials)
                error('PatternBuilderCore:InvalidTrials', ...
                    'trials must be a cell array');
            end

            % Validate each trial
            for i = 1:length(trial_plan.trials)
                obj.validate_trial(trial_plan.trials{i}, i);
            end
        end

        function validate_trial(obj, trial, trial_num)
            % Validate a single trial structure
            %
            % Args:
            %   trial: Trial struct to validate
            %   trial_num: Trial number (for error messages)

            % Check required fields
            if ~isfield(trial, 'trial_index')
                error('PatternBuilderCore:MissingTrialIndex', ...
                    'Trial %d missing trial_index', trial_num);
            end

            if ~isfield(trial, 'label')
                error('PatternBuilderCore:MissingLabel', ...
                    'Trial %d missing label', trial_num);
            end

            if ~isfield(trial, 'elements')
                error('PatternBuilderCore:MissingElements', ...
                    'Trial %d missing elements', trial_num);
            end

            % Validate elements is a cell array
            if ~iscell(trial.elements)
                error('PatternBuilderCore:InvalidElements', ...
                    'Trial %d elements must be a cell array', trial_num);
            end

            % Validate each element
            for i = 1:length(trial.elements)
                obj.validate_element(trial.elements{i}, trial_num, i);
            end
        end

        function validate_element(obj, element, trial_num, elem_num)
            % Validate a single element structure
            %
            % Args:
            %   element: Element struct to validate
            %   trial_num: Trial number (for error messages)
            %   elem_num: Element number within trial (for error messages)

            % Check required fields
            required_fields = {'stimulus_ref', 'scheduled_onset_ms', 'duration_ms'};
            for i = 1:length(required_fields)
                if ~isfield(element, required_fields{i})
                    error('PatternBuilderCore:MissingElementField', ...
                        'Trial %d, Element %d missing required field: %s', ...
                        trial_num, elem_num, required_fields{i});
                end
            end

            % Validate scheduled_onset_ms
            if ~isnumeric(element.scheduled_onset_ms) || element.scheduled_onset_ms < 0
                error('PatternBuilderCore:InvalidOnset', ...
                    'Trial %d, Element %d has invalid scheduled_onset_ms', ...
                    trial_num, elem_num);
            end

            % Validate duration_ms
            if ~isnumeric(element.duration_ms) || element.duration_ms <= 0
                error('PatternBuilderCore:InvalidDuration', ...
                    'Trial %d, Element %d has invalid duration_ms', ...
                    trial_num, elem_num);
            end
        end

        function windows = compute_trial_windows(obj, trials)
            % Compute trial window durations
            %
            % Args:
            %   trials: Cell array of trial structs
            %
            % Returns:
            %   windows: Array of trial window durations in milliseconds

            windows = zeros(length(trials), 1);

            for i = 1:length(trials)
                trial = trials{i};

                % Empty trial has zero window
                if isempty(trial.elements)
                    windows(i) = 0;
                    continue;
                end

                % Compute window as end of last element
                max_end = 0;
                for j = 1:length(trial.elements)
                    element = trial.elements{j};
                    element_end = element.scheduled_onset_ms + element.duration_ms;
                    max_end = max(max_end, element_end);
                end

                windows(i) = max_end;
            end
        end
    end
end
