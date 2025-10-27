classdef sequence_utils
    % SEQUENCE_UTILS - Utility functions for sequence management

    methods (Static)

        function summary = estimate_duration_and_trials(seq)
            % Estimate total duration, trials, and per-block details.
            % This function is now guaranteed to always return a struct with all fields.

            % --- FIX: Initialize all fields to ensure consistent output structure ---
            summary = struct(...
                'total_sec', 0, ...
                'total_trials', 0, ...
                'block_details', [], ...
                'errors', {{}} ... % Initialize as empty cell
            );

            % Return the default summary struct if the sequence has no blocks
            if ~isfield(seq, 'blocks') || isempty(seq.blocks)
                return;
            end

            total_sec = 0;
            total_trials = 0;
            
            % Handle both struct array and scalar struct for blocks
            if isscalar(seq.blocks) && isfield(seq.blocks,'block_file')
                num_blocks = 1;
            else
                num_blocks = length(seq.blocks);
            end

            block_details = repmat(struct('name','','trials',0,'duration_sec',0, 'transition_sec', 0), 1, num_blocks);

            for i = 1:num_blocks
                 if num_blocks == 1 && isstruct(seq.blocks)
                    block_entry = seq.blocks;
                 else
                    block_entry = seq.blocks(i);
                 end

                block_duration = 0;
                block_trials = 0;
                block_name = '(Unknown)';

                try
                    block_path = core.config.get_block_path(block_entry.block_file);
                    if exist(block_path, 'file')
                        block_data = gui.blocks.block_utils.load_block(block_path);
                        block_name = block_data.block_id;

                        if isfield(block_data.parameters, 'n_trials')
                            block_trials = block_data.parameters.n_trials;
                            avg_iti = 1.5; % Default
                            if isfield(block_data.parameters, 'iti_sec')
                                iti_val = block_data.parameters.iti_sec;
                                if isnumeric(iti_val)
                                    if isscalar(iti_val); avg_iti = iti_val;
                                    elseif numel(iti_val) >= 2; avg_iti = mean(iti_val); end
                                end
                            end
                            avg_iti = max(0, avg_iti);
                            avg_stim_dur_sec = 0.1; % Guess
                            block_duration = block_trials * (avg_stim_dur_sec + avg_iti);
                        else
                             summary.errors{end+1} = sprintf('Block "%s": Cannot estimate duration/trials (missing n_trials).', block_name);
                        end
                    else
                         summary.errors{end+1} = sprintf('Block file not found: "%s".', block_entry.block_file);
                         block_name = block_entry.block_file;
                    end
                catch ME
                     summary.errors{end+1} = sprintf('Error estimating block "%s": %s.', block_entry.block_file, ME.message);
                     block_name = block_entry.block_file;
                end

                total_sec = total_sec + block_duration;
                total_trials = total_trials + block_trials;
                block_details(i).name = block_name;
                block_details(i).trials = block_trials;
                block_details(i).duration_sec = block_duration;


                % Add transition duration
                transition_duration = 0;
                if isfield(block_entry, 'transition') && isfield(block_entry.transition, 'type')
                    switch block_entry.transition.type
                        case 'delay'
                            if isfield(block_entry.transition, 'duration_sec') && isnumeric(block_entry.transition.duration_sec)
                                transition_duration = max(0, block_entry.transition.duration_sec);
                            end
                        case 'button_press'
                            transition_duration = 5; % Nominal time
                    end
                end
                 total_sec = total_sec + transition_duration;
                 block_details(i).transition_sec = transition_duration;
            end

            summary.total_sec = total_sec;
            summary.total_trials = total_trials;
            summary.block_details = block_details;
        end

        function seq = load_sequence(filepath)
            % Load sequence from JSON file, handle migration
            if ~exist(filepath, 'file')
                error('Sequence file not found: %s', filepath);
            end
            fid = fopen(filepath, 'r');
            json_text = fread(fid, '*char')';
            fclose(fid);
            seq = jsondecode(json_text);
            
            % --- Migration ---
             if ~isfield(seq, 'format_version')
                 warning('Sequence "%s" is old format (missing format_version). Attempting migration.', seq.sequence_id);
                 seq = gui.sequences.sequence_utils.migrate_sequence_v0_to_v1(seq);
             end

            % --- Version Check ---
            current_version = core.config.SEQUENCE_FORMAT_VERSION;
            if ~strcmp(seq.format_version, current_version)
                 warning('Sequence format version mismatch for "%s": File is %s, System expects %s.', ...
                     seq.sequence_id, seq.format_version, current_version);
            end
        end

         function seq = migrate_sequence_v0_to_v1(seq)
             % Example migration for sequences
             seq.format_version = '1.0.0';

             % Ensure metadata exists and has basic fields
             if ~isfield(seq, 'metadata')
                 seq.metadata = struct();
             end
              if ~isfield(seq.metadata, 'created_by')
                 seq.metadata.created_by = '';
             end
              if ~isfield(seq.metadata, 'tags')
                 seq.metadata.tags = {};
             end
             % Ensure global settings has engine_config
              if ~isfield(seq.global_settings, 'engine_config')
                 seq.global_settings.engine_config = struct();
                 warning('Added empty engine_config to global_settings for sequence "%s"', seq.sequence_id);
              end

             fprintf('  -> Migrated sequence "%s" to format %s\n', seq.sequence_id, seq.format_version);
         end

        function save_sequence(seq, filepath)
            % Save sequence to JSON file, ensuring format_version
            seq.format_version = core.config.SEQUENCE_FORMAT_VERSION;
            
            % Ensure directory exists
            [dir_path, ~, ~] = fileparts(filepath);
            if ~exist(dir_path, 'dir')
                mkdir(dir_path);
            end
            
            % Save as formatted JSON
            json_text = jsonencode(seq);
            fid = fopen(filepath, 'w');
             if fid == -1
                 error('Could not open file for writing: %s', filepath);
             end
            fprintf(fid, '%s', json_text);
            fclose(fid);
        end

        function [is_valid, errors] = validate_sequence(seq, context)
            % Validate sequence structure and block references
            errors = {};

            % Basic structure
            if ~isfield(seq, 'sequence_id') || isempty(seq.sequence_id)
                errors{end+1,1} = 'Missing or empty sequence_id';
            end
            if ~isfield(seq, 'format_version')
                 errors{end+1, 1} = 'Missing format_version field';
            end
            if ~isfield(seq, 'global_settings')
                errors{end+1,1} = 'Missing global_settings struct';
            else % Validate global settings
                gs = seq.global_settings;
                if ~isfield(gs, 'sampling_rate_hz')
                    errors{end+1,1} = 'Missing sampling_rate_hz in global_settings';
                end
                if ~isfield(gs, 'engine_type')
                    errors{end+1,1} = 'Missing engine_type in global_settings';
                elseif ~isKey(context.engines, gs.engine_type)
                    errors{end+1,1} = sprintf('Unknown engine_type in global_settings: "%s"', gs.engine_type);
                end
                 if ~isfield(gs, 'engine_config') % Should exist after migration
                    errors{end+1,1} = 'Missing engine_config struct in global_settings';
                 end
            end

            % Validate blocks array
            if ~isfield(seq, 'blocks') || (~isstruct(seq.blocks) && ~iscell(seq.blocks)) || isempty(seq.blocks)
                % It's valid to have an empty block list, so don't error.
                % errors{end+1,1} = 'Missing or empty "blocks" array';
            else
                % Check each block entry in the sequence
                for i = 1:length(seq.blocks)
                    block_entry = seq.blocks(i);
                    block_label = sprintf('Block %d', i);

                    if ~isfield(block_entry, 'block_file') || isempty(block_entry.block_file)
                        errors{end+1,1} = sprintf('%s: Missing or empty block_file field', block_label);
                        continue; % Skip further checks if file missing
                    end

                    % Check if block file exists using config
                    block_path = core.config.get_block_path(block_entry.block_file);
                    if ~exist(block_path, 'file')
                        errors{end+1,1} = sprintf('%s: Block file not found: "%s"', block_label, block_entry.block_file);
                    end

                    % Check transition structure
                    if ~isfield(block_entry, 'transition')
                        errors{end+1,1} = sprintf('%s: Missing transition struct', block_label);
                    else
                        trans = block_entry.transition;
                         valid_types = {'none', 'delay', 'button_press'}; % Add more as needed
                        if ~isfield(trans, 'type') || ~ismember(trans.type, valid_types)
                             errors{end+1,1} = sprintf('%s: Missing or invalid transition type (must be one of: %s)', block_label, strjoin(valid_types, ', '));
                        else
                             % Validate type-specific fields
                            switch trans.type
                                case 'delay'
                                    if ~isfield(trans, 'duration_sec') || ~isnumeric(trans.duration_sec) || trans.duration_sec < 0
                                         errors{end+1,1} = sprintf('%s: Delay transition requires a non-negative numeric duration_sec', block_label);
                                    end
                                case 'button_press'
                                     if isfield(trans, 'message') && ~(ischar(trans.message) || isstring(trans.message))
                                          errors{end+1,1} = sprintf('%s: Button press message must be a string', block_label);
                                     end
                                case 'none' % No parameters expected
                                     extra_fields = fieldnames(trans);
                                     % Allow for empty fields if jsondecode creates them
                                     if ~all(strcmp(extra_fields, 'type')) && ~isempty(extra_fields)
                                          errors{end+1,1} = sprintf('%s: "none" transition should not have extra fields', block_label);
                                     end
                            end
                        end
                    end
                end
            end

            is_valid = isempty(errors);
        end

        function sequences = list_sequences()
            % List all sequences in library using core.config
             sequences = {};
             sequences_dir = core.config.get_sequence_path(); % Use config

             if ~exist(sequences_dir, 'dir')
                  warning('Sequence library directory not found: %s', sequences_dir);
                 return;
             end

             files = dir(fullfile(sequences_dir, ['*' core.config.SEQUENCE_EXTENSION]));

             for i = 1:length(files)
                  % Skip backup files
                 if endsWith(files(i).name, '.backup')
                     continue;
                 end
                 try
                     filepath = fullfile(files(i).folder, files(i).name);
                     seq = gui.sequences.sequence_utils.load_sequence(filepath); % Handles migration/version

                     if ~isfield(seq, 'sequence_id')
                          warning('Skipping invalid sequence file (missing sequence_id): %s', files(i).name);
                         continue;
                     end

                     info = struct();
                     info.file = filepath;
                     info.name = files(i).name;
                     info.sequence_id = seq.sequence_id;
                     info.description = '';
                     if isfield(seq, 'description')
                         info.description = seq.description;
                     end
                     info.n_blocks = 0;
                     if isfield(seq, 'blocks') && (isstruct(seq.blocks) || iscell(seq.blocks)) && ~isempty(seq.blocks)
                         info.n_blocks = length(seq.blocks);
                     end

                     sequences{end+1} = info;
                 catch ME
                      warning('Error processing sequence file %s: %s', files(i).name, ME.message);
                     % Skip invalid files
                 end
             end
             % Sort sequences alphabetically by sequence_id
              if ~isempty(sequences)
                 [~, sort_idx] = sort(cellfun(@(x) lower(x.sequence_id), sequences, 'UniformOutput', false));
                 sequences = sequences(sort_idx);
              end
         end
    end
end