classdef TrialExecutor
    % TRIALEXECUTOR - Handles trial execution logic
    %
    % This class extracts trial execution logic from execute.m
    % to improve testability and separation of concerns.
    %
    % Usage:
    %   executor = TrialExecutor(daq_manager, context);
    %   executor.execute_trial(trial, trial_idx, block_idx, logger);

    properties (SetAccess = private)
        daq_manager       % DAQManager instance
        context           % Maestro context
        sampling_rate_hz  % Sampling rate
    end

    methods
        function obj = TrialExecutor(daq_manager, context, sampling_rate_hz)
            % TRIALEXECUTOR - Constructor
            %
            % INPUTS:
            %   daq_manager - DAQManager instance
            %   context - MaestroContext with generators
            %   sampling_rate_hz - numeric, sampling rate

            obj.daq_manager = daq_manager;
            obj.context = context;
            obj.sampling_rate_hz = sampling_rate_hz;
        end

        function execute_trial(obj, trial, trial_idx, block_idx, block_logger)
            % EXECUTE_TRIAL - Execute a single trial with logging
            %
            % INPUTS:
            %   trial - struct, trial specification with presentations
            %   trial_idx - integer, trial index (1-based)
            %   block_idx - integer, block index (1-based)
            %   block_logger - BlockLogger instance

            % Generate all stimuli for this trial
            presentations = trial.presentations;
            n_presentations = length(presentations);

            generated_stimuli = cell(1, n_presentations);
            for p = 1:n_presentations
                pres = presentations(p);
                generated_stimuli{p} = obj.generate_stimulus(pres.stimulus_spec);
            end

            % Mix presentations based on onset times
            mixed_audio = obj.mix_presentations(generated_stimuli, presentations);

            % Generate TTL trigger
            ttl_signal = obj.daq_manager.generate_ttl_pulse(length(mixed_audio));

            % Record timing
            trial_start = tic;

            % Play audio + send trigger (async)
            obj.daq_manager.play_trial_async(mixed_audio, ttl_signal);
            trigger_time = toc(trial_start);

            % Wait for playback to complete
            obj.daq_manager.wait();
            trial_duration = toc(trial_start);

            % Prepare log data
            log_data = obj.create_log_data(trial, trial_idx, block_idx, ...
                presentations, trial_start, trigger_time);

            % Log to CSV
            block_logger.log_trial(log_data);

            % Inter-trial interval
            pause(trial.iti_sec);
        end
    end

    methods (Access = private)
        function stim_output = generate_stimulus(obj, stimulus_spec)
            % GENERATE_STIMULUS - Generate a stimulus from specification
            %
            % INPUTS:
            %   stimulus_spec - struct with generator, version, parameters
            %
            % OUTPUTS:
            %   stim_output - struct with generated stimulus data

            % Create generation context
            gen_context = struct();
            gen_context.sampling_rate_hz = obj.sampling_rate_hz;

            % Get generator
            gen_type = stimulus_spec.generator;
            if ~isKey(obj.context.generators, gen_type)
                error('TrialExecutor:UnknownGenerator', ...
                    'Unknown generator: %s', gen_type);
            end

            gen_info = obj.context.generators(gen_type);

            % Generate stimulus
            stim_output = gen_info.generate_func(stimulus_spec.parameters, gen_context);
        end

        function mixed = mix_presentations(obj, stimuli, presentations)
            % MIX_PRESENTATIONS - Mix multiple presentations based on onset times
            %
            % INPUTS:
            %   stimuli - cell array of generated stimulus outputs
            %   presentations - array of presentation specs with onset_ms
            %
            % OUTPUTS:
            %   mixed - column vector, mixed audio signal

            % Find total duration needed
            max_end_time = 0;
            for p = 1:length(presentations)
                onset_ms = presentations(p).onset_ms;
                stim_dur_ms = stimuli{p}.duration_ms;
                end_time = onset_ms + stim_dur_ms;
                if end_time > max_end_time
                    max_end_time = end_time;
                end
            end

            % Create output buffer
            n_samples = round(max_end_time * obj.sampling_rate_hz / 1000);
            mixed = zeros(n_samples, 1);

            % Add each presentation at its onset time
            for p = 1:length(presentations)
                onset_samples = round(presentations(p).onset_ms * obj.sampling_rate_hz / 1000);
                stim_data = stimuli{p}.data;

                % Ensure column vector
                if size(stim_data, 2) > 1
                    stim_data = stim_data(:, 1);  % Take first channel
                end

                % Add to buffer (with bounds checking)
                start_idx = onset_samples + 1;
                end_idx = min(start_idx + length(stim_data) - 1, n_samples);
                actual_length = end_idx - start_idx + 1;

                mixed(start_idx:end_idx) = mixed(start_idx:end_idx) + ...
                    stim_data(1:actual_length);
            end

            % Clip to prevent overflow
            mixed = max(core.Constants.MIN_AUDIO_AMPLITUDE, ...
                min(core.Constants.MAX_AUDIO_AMPLITUDE, mixed));
        end

        function log_data = create_log_data(obj, trial, trial_idx, block_idx, ...
                presentations, trial_start, trigger_time)
            % CREATE_LOG_DATA - Create trial log data structure
            %
            % INPUTS:
            %   trial - trial struct
            %   trial_idx - trial index
            %   block_idx - block index
            %   presentations - presentation array
            %   trial_start - trial start time (from tic)
            %   trigger_time - trigger time (from toc)
            %
            % OUTPUTS:
            %   log_data - struct with trial information

            log_data = struct();
            log_data.trial_index = trial_idx;
            log_data.block_index = block_idx;

            % Extract trial type from metadata
            if isfield(trial, 'metadata') && isfield(trial.metadata, 'kind')
                log_data.trial_type = trial.metadata.kind;
            else
                log_data.trial_type = 'unknown';
            end

            % Extract stimulus parameters (from first presentation)
            if ~isempty(presentations)
                stim_params = presentations(1).stimulus_spec.parameters;

                % Common stimulus parameters (may not all exist)
                if isfield(stim_params, 'freq_hz')
                    log_data.freq_hz = stim_params.freq_hz;
                end
                if isfield(stim_params, 'dur_ms')
                    log_data.dur_ms = stim_params.dur_ms;
                end
                if isfield(stim_params, 'level_db')
                    log_data.level_db = stim_params.level_db;
                end
            end

            % Timing information
            log_data.onset_time_sec = trial_start;
            log_data.trigger_sent_sec = trigger_time;
            log_data.iti_sec = trial.iti_sec;
        end
    end
end
