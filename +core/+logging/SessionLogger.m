classdef SessionLogger < handle
    % SESSIONLOGGER - Manage session-level logging
    %
    % Creates and manages session directory structure:
    %   sessions/YYYYMMDD_SUBJID_sessNN/
    %     ├── metadata.json
    %     ├── sequence.json
    %     ├── events.log
    %     ├── notes.txt
    %     └── block_XXX/
    %
    % Usage:
    %   logger = SessionLogger(subject_id, session_num, experimenter, experiment);
    %   block_logger = logger.start_block(block_idx, block_config);
    %   logger.end_block(block_logger, n_trials);
    %   logger.finalize('completed');
    
    properties (SetAccess = private)
        session_dir       % Path to session directory
        session_id        % Session identifier (YYYYMMDD_SUBJID_sessNN)
        metadata          % Session metadata struct
        event_log_fid     % File handle for events.log
    end
    
    methods
        function obj = SessionLogger(subject_id, session_num, experimenter, experiment)
            % Constructor - Create session directory and initialize logging
            %
            % INPUTS:
            %   subject_id - Subject identifier (e.g., 'S001', 'DEMO')
            %   session_num - Session number (integer)
            %   experimenter - Experimenter name
            %   experiment - Experiment specification struct
            
            % Create session ID
            timestamp = datestr(now, 'yyyymmdd');
            obj.session_id = sprintf('%s_%s_sess%02d', timestamp, subject_id, session_num);
            
            % Create session directory
            obj.session_dir = fullfile('sessions', obj.session_id);
            if ~exist(obj.session_dir, 'dir')
                mkdir(obj.session_dir);
            end
            
            % Initialize metadata
            obj.metadata = struct();
            obj.metadata.session_id = obj.session_id;
            obj.metadata.subject_id = subject_id;
            obj.metadata.session_number = session_num;
            obj.metadata.experimenter = experimenter;
            obj.metadata.date = datestr(now, 'yyyy-mm-dd');
            obj.metadata.start_time = datestr(now, 'HH:MM:SS');
            obj.metadata.experiment_id = experiment.experiment_id;
            
            % Copy experiment as sequence
            obj.save_sequence(experiment);
            
            % Open event log
            event_log_path = fullfile(obj.session_dir, 'events.log');
            obj.event_log_fid = fopen(event_log_path, 'w');
            
            % Log session start
            obj.log_event('INFO', sprintf('Session started: %s', obj.session_id));
            obj.log_event('INFO', sprintf('Subject: %s', subject_id));
            obj.log_event('INFO', sprintf('Experimenter: %s', experimenter));
        end
        
        function block_logger = start_block(obj, block_idx, block_config)
            % Start a new block with logging
            %
            % INPUTS:
            %   block_idx - Block index (1-based)
            %   block_config - Block configuration struct
            %
            % OUTPUTS:
            %   block_logger - BlockLogger instance
            
            obj.log_event('INFO', sprintf('Starting block %d', block_idx));
            
            % Create block directory
            block_dir = fullfile(obj.session_dir, sprintf('block_%03d', block_idx));
            if ~exist(block_dir, 'dir')
                mkdir(block_dir);
            end
            
            % Create and return block logger
            block_logger = core.logging.BlockLogger(block_dir, block_idx, block_config);
        end
        
        function end_block(obj, block_logger, n_trials)
            % End a block and close its logger
            %
            % INPUTS:
            %   block_logger - BlockLogger instance
            %   n_trials - Number of trials executed
            
            block_logger.close();
            obj.log_event('INFO', sprintf('Block %d completed (%d trials)', ...
                block_logger.block_idx, n_trials));
        end
        
        function log_event(obj, level, message)
            % Log an event to events.log
            %
            % INPUTS:
            %   level - Event level ('INFO', 'WARNING', 'ERROR')
            %   message - Event message
            
            timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            fprintf(obj.event_log_fid, '%s [%s] %s\n', timestamp, level, message);
            
            % Also print to console if WARNING or ERROR
            if strcmp(level, 'WARNING') || strcmp(level, 'ERROR')
                fprintf('[%s] %s\n', level, message);
            end
        end
        
        function add_note(obj, note)
            % Add experimenter note to notes.txt
            %
            % INPUTS:
            %   note - Note text
            
            notes_file = fullfile(obj.session_dir, 'notes.txt');
            fid = fopen(notes_file, 'a');
            fprintf(fid, '[%s] %s\n', datestr(now, 'HH:MM:SS'), note);
            fclose(fid);
            
            obj.log_event('INFO', sprintf('Note added: %s', note));
        end
        
        function finalize(obj, status)
            % Finalize session and save metadata
            %
            % INPUTS:
            %   status - Session status ('completed', 'aborted', 'error')
            
            % Update metadata
            obj.metadata.end_time = datestr(now, 'HH:MM:SS');
            obj.metadata.status = status;
            
            % Calculate duration
            try
                start_dt = datetime(obj.metadata.start_time, 'InputFormat', 'HH:mm:ss');
                end_dt = datetime(obj.metadata.end_time, 'InputFormat', 'HH:mm:ss');
                obj.metadata.duration_sec = seconds(end_dt - start_dt);
            catch
                obj.metadata.duration_sec = NaN;
            end
            
            % Save metadata as JSON
            metadata_file = fullfile(obj.session_dir, 'metadata.json');
            json_text = jsonencode(obj.metadata);
            fid = fopen(metadata_file, 'w');
            fprintf(fid, '%s', json_text);
            fclose(fid);
            
            % Log and close event log
            obj.log_event('INFO', sprintf('Session ended: %s', status));
            fclose(obj.event_log_fid);
        end
        
        function save_sequence(obj, experiment)
            % Save experiment configuration as sequence.json
            %
            % INPUTS:
            %   experiment - Experiment specification struct
            
            seq_file = fullfile(obj.session_dir, 'sequence.json');
            json_text = jsonencode(experiment);
            fid = fopen(seq_file, 'w');
            fprintf(fid, '%s', json_text);
            fclose(fid);
        end
    end
end