classdef BlockLogger < handle
    % BLOCKLOGGER - Log trial-by-trial stimulus presentation
    %
    % Creates stimuli.csv with complete trial information
    %
    % Usage:
    %   logger = BlockLogger(block_dir, block_idx, block_config);
    %   logger.log_trial(trial_data);
    %   logger.close();
    
    properties (SetAccess = private)
        csv_fid         % File handle for stimuli.csv
        block_idx       % Block index
        block_dir       % Block directory path
        trial_count     % Number of trials logged
        csv_columns     % Column names for CSV (dynamic)
    end
    
    methods
        function obj = BlockLogger(block_dir, block_idx, block_config)
            % Constructor - Initialize block logging
            %
            % INPUTS:
            %   block_dir - Path to block directory
            %   block_idx - Block index (1-based)
            %   block_config - Block configuration struct
            
            obj.block_dir = block_dir;
            obj.block_idx = block_idx;
            obj.trial_count = 0;
            obj.csv_columns = {};
            
            % Save block configuration
            config_file = fullfile(block_dir, 'block_config.json');
            json_text = jsonencode(block_config);
            fid = fopen(config_file, 'w');
            fprintf(fid, '%s', json_text);
            fclose(fid);
            
            % Open CSV file
            csv_path = fullfile(block_dir, 'stimuli.csv');
            obj.csv_fid = fopen(csv_path, 'w');
        end
        
        function log_trial(obj, trial_data)
            % Log a single trial to CSV
            %
            % INPUTS:
            %   trial_data - struct with trial information
            %                Required fields: trial_index, block_index, trial_type
            %                Additional fields: stimulus parameters
            
            obj.trial_count = obj.trial_count + 1;
            
            % On first trial, write header
            if obj.trial_count == 1
                obj.csv_columns = fieldnames(trial_data);
                obj.write_header(obj.csv_columns);
            end
            
            % Write data row
            for i = 1:length(obj.csv_columns)
                col_name = obj.csv_columns{i};
                value = trial_data.(col_name);
                
                % Format based on type
                if i > 1
                    fprintf(obj.csv_fid, ',');
                end
                
                if isnumeric(value)
                    if isinteger(value) || (value == floor(value))
                        fprintf(obj.csv_fid, '%d', value);
                    else
                        fprintf(obj.csv_fid, '%.6f', value);
                    end
                elseif islogical(value)
                    fprintf(obj.csv_fid, '%d', value);
                elseif ischar(value) || isstring(value)
                    fprintf(obj.csv_fid, '%s', value);
                else
                    fprintf(obj.csv_fid, '%s', mat2str(value));
                end
            end
            fprintf(obj.csv_fid, '\n');
        end
        
        function write_header(obj, columns)
            % Write CSV header
            %
            % INPUTS:
            %   columns - Cell array of column names
            
            for i = 1:length(columns)
                if i > 1
                    fprintf(obj.csv_fid, ',');
                end
                fprintf(obj.csv_fid, '%s', columns{i});
            end
            fprintf(obj.csv_fid, '\n');
        end
        
        function close(obj)
            % Close CSV file
            
            if ~isempty(obj.csv_fid) && obj.csv_fid > 0
                fclose(obj.csv_fid);
                obj.csv_fid = -1;
            end
        end
    end
    
    methods (Access = private)
        function delete(obj)
            % Destructor - ensure file is closed
            obj.close();
        end
    end
end