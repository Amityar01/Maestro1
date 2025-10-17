classdef block_utils
    % BLOCK_UTILS - Utility functions for block management

    methods (Static)
        function schema = load_schema(builder_type, context)
            % Load schema for a builder type

            if ~isKey(context.builders, builder_type)
                error('Unknown builder type: %s', builder_type);
            end

            builder_info = context.builders(builder_type);

            % Use config for path
            schema_file = fullfile(builder_info.path, core.config.BUILDER_SCHEMA_FILENAME);
            if ~exist(schema_file, 'file')
                error('Schema file not found: %s', schema_file);
            end

            fid = fopen(schema_file, 'r');
            schema_text = fread(fid, '*char')';
            fclose(fid);

            schema = jsondecode(schema_text);
        end

        function block = load_block(block_file_path)
            % Load block from JSON file and handle migration

            if ~exist(block_file_path, 'file')
                error('Block file not found: %s', block_file_path);
            end

            fid = fopen(block_file_path, 'r');
            block_text = fread(fid, '*char')';
            fclose(fid);

            block = jsondecode(block_text);

            % --- Migration ---
            if ~isfield(block, 'format_version')
                 warning('Block "%s" is old format (missing format_version). Attempting migration.', block.block_id);
                 block = gui.blocks.block_utils.migrate_block_v0_to_v1(block);
            end

            % --- Version Check ---
            current_version = core.config.BLOCK_FORMAT_VERSION;
            if ~strcmp(block.format_version, current_version)
                 warning('Block format version mismatch for "%s": File is %s, System expects %s. Compatibility issues may arise.', ...
                     block.block_id, block.format_version, current_version);
            end
        end

        function block = migrate_block_v0_to_v1(block)
            % Example migration function (add more logic as format changes)
            block.format_version = '1.0.0'; % Add the version field

             % Check for old ITI fields and convert if necessary
             if isfield(block.parameters, 'iti_min_sec') || isfield(block.parameters, 'iti_max_sec')
                 if ~isfield(block.parameters, 'iti_sec') % Only if new field doesn't exist
                     min_iti = 1.0; % Default
                     max_iti = 2.0; % Default
                     if isfield(block.parameters, 'iti_min_sec')
                         min_iti = block.parameters.iti_min_sec;
                         block.parameters = rmfield(block.parameters, 'iti_min_sec');
                     end
                      if isfield(block.parameters, 'iti_max_sec')
                         max_iti = block.parameters.iti_max_sec;
                         block.parameters = rmfield(block.parameters, 'iti_max_sec');
                     end
                     % Store as [min, max] array, assuming jitter
                     block.parameters.iti_sec = [min_iti, max_iti];
                     warning('Migrated old iti_min/max_sec to iti_sec=[min, max] for block "%s"', block.block_id);
                 else
                     % Both old and new exist, remove old ones
                     if isfield(block.parameters, 'iti_min_sec')
                         block.parameters = rmfield(block.parameters, 'iti_min_sec');
                     end
                      if isfield(block.parameters, 'iti_max_sec')
                         block.parameters = rmfield(block.parameters, 'iti_max_sec');
                     end
                 end
             end

            % Ensure metadata struct exists
            if ~isfield(block, 'metadata')
                block.metadata = struct();
            end
            % Add default metadata fields if missing
            if ~isfield(block.metadata, 'created_by')
                block.metadata.created_by = ''; % Or 'Unknown'
            end
             if ~isfield(block.metadata, 'tags')
                block.metadata.tags = {}; % Use empty cell array
            end

            fprintf('  -> Migrated block "%s" to format %s\n', block.block_id, block.format_version);
        end

        function save_block(block, block_file_path)
            % Save block to JSON file, ensuring format_version

            % Add/update format version
            block.format_version = core.config.BLOCK_FORMAT_VERSION;

            % Ensure directory exists
            [dir_path, ~, ~] = fileparts(block_file_path);
            if ~exist(dir_path, 'dir')
                mkdir(dir_path);
            end

            % Save as formatted JSON
            json_text = jsonencode(block);
            fid = fopen(block_file_path, 'w');
            fprintf(fid, '%s', json_text);
            fclose(fid);
        end

        function [is_valid, errors] = validate_block(block, schema, context)
            % Validate block against schema (refactored for clarity)

            errors = {}; % Initialize as 0x0 cell

            % Basic structure checks
            if ~isfield(block, 'block_id') || isempty(block.block_id)
                errors{end+1, 1} = 'Missing block_id';
            end
            if ~isfield(block, 'builder_type')
                errors{end+1, 1} = 'Missing builder_type';
            elseif ~strcmp(block.builder_type, schema.builder_type)
                 errors{end+1, 1} = sprintf('Builder type mismatch: Block says "%s", Schema is for "%s"', block.builder_type, schema.builder_type);
            end
            if ~isfield(block, 'parameters')
                errors{end+1, 1} = 'Missing parameters struct';
                is_valid = isempty(errors); % Exit early if no parameters
                return;
            end
             if ~isfield(block, 'format_version')
                 errors{end+1, 1} = 'Missing format_version field';
             end

            % Combine all parameter definitions from schema
            all_param_defs = struct();
             if isfield(schema, 'required_inputs')
                 all_param_defs = mergestructs(all_param_defs, schema.required_inputs);
             end
             if isfield(schema, 'optional_inputs')
                 all_param_defs = mergestructs(all_param_defs, schema.optional_inputs);
             end

            % Check for missing required parameters
            if isfield(schema, 'required_inputs')
                required_names = fieldnames(schema.required_inputs);
                for i = 1:length(required_names)
                    if ~isfield(block.parameters, required_names{i})
                         errors{end+1, 1} = sprintf('Missing required parameter: %s', required_names{i});
                    end
                end
            end

            % Check all parameters present in the block
            params_in_block = fieldnames(block.parameters);
            for i = 1:length(params_in_block)
                param_name = params_in_block{i};
                param_value = block.parameters.(param_name);

                if ~isfield(all_param_defs, param_name)
                    errors{end+1, 1} = sprintf('Unknown parameter found in block: %s (Is schema outdated?)', param_name);
                    continue; % Skip validation for unknown params
                end

                param_def = all_param_defs.(param_name);

                % Validate the value against the definition
                [val_valid, val_err] = core.validate_parameter_value(param_value, param_def);
                if ~val_valid
                    errors{end+1, 1} = sprintf('Invalid value for "%s": %s', param_name, val_err);
                end

                 % Special validation for stimulus_specification
                if strcmp(param_def.type, 'stimulus_specification')
                    stim_errors = gui.blocks.block_utils.validate_stimulus_parameter(param_value, param_name, context);
                    errors = [errors; stim_errors]; %#ok<AGROW>
                end
            end

            is_valid = isempty(errors);
        end

        function errors = validate_stimulus_parameter(stim_value, param_name, context)
             % Sub-function to validate a stimulus parameter within a block
             errors = {};
             if ~isstruct(stim_value)
                 errors{end+1, 1} = sprintf('Stimulus "%s" must be a struct (found %s). Click "Edit..." to configure.', param_name, class(stim_value));
                 return;
             end
             if ~isfield(stim_value, 'generator') || isempty(stim_value.generator)
                  errors{end+1, 1} = sprintf('Stimulus "%s" is missing "generator" field or it is empty.', param_name);
                  return; % Cannot proceed without generator info
             end
             if ~isKey(context.generators, stim_value.generator)
                  errors{end+1, 1} = sprintf('Stimulus "%s" specifies an unknown generator: "%s"', param_name, stim_value.generator);
                  return; % Cannot proceed without valid generator
             end
             if ~isfield(stim_value, 'parameters')
                 errors{end+1, 1} = sprintf('Stimulus "%s" (generator: %s) is missing the "parameters" field.', param_name, stim_value.generator);
                 return; % Cannot validate parameters if field is missing
             end

             % Validate parameters against the generator's schema
             gen_schema = context.generators(stim_value.generator).schema;
             if ~isfield(gen_schema, 'parameters')
                 % Generator has no parameters, check if block provided any
                 if ~isempty(fieldnames(stim_value.parameters))
                      errors{end+1, 1} = sprintf('Stimulus "%s" (generator: %s) provides parameters, but the generator schema defines none.', param_name, stim_value.generator);
                 end
             else
                 % Generator has parameters, validate them
                 [gen_valid, gen_errs] = core.validate_parameters(stim_value.parameters, gen_schema.parameters);
                 if ~gen_valid
                     errors{end+1, 1} = sprintf('Invalid parameters for stimulus "%s" (generator: %s):', param_name, stim_value.generator);
                     if ~iscolumn(gen_errs)
                         gen_errs = gen_errs';
                     end
                     new_errors = cellfun(@(e) ['  - ' e], gen_errs, 'UniformOutput', false);
                     errors = [errors; new_errors];
                 end
             end
        end

        function text = format_parameters(params, indent)
            % Format parameters as human-readable text (unchanged)
            if nargin < 2
                indent = 0;
            end
            lines = {};
            indent_str = repmat('  ', 1, indent);
            fields = fieldnames(params);
            for i = 1:length(fields)
                field_name = fields{i};
                value = params.(field_name);
                if isstruct(value) && isfield(value, 'generator') % Special handling for stimulus spec
                     lines{end+1} = sprintf('%s%s: [Stimulus: %s]', indent_str, field_name, value.generator);
                     % Optionally recurse into value.parameters with increased indent
                     sub_text = gui.blocks.block_utils.format_parameters(value.parameters, indent + 1);
                     lines{end+1} = sub_text;
                elseif isstruct(value) % Other structs
                    lines{end+1} = sprintf('%s%s:', indent_str, field_name);
                    sub_text = gui.blocks.block_utils.format_parameters(value, indent + 1);
                    lines{end+1} = sub_text;
                elseif isnumeric(value) && isscalar(value)
                    if value == floor(value)
                        lines{end+1} = sprintf('%s%s: %d', indent_str, field_name, value);
                    else
                        lines{end+1} = sprintf('%s%s: %.3g', indent_str, field_name, value); % Use %g for auto precision
                    end
                elseif isnumeric(value) && isvector(value)
                    if numel(value) <= 6
                         array_str = sprintf('%.3g, ', value);
                         array_str = ['[' array_str(1:end-2) ']'];
                         lines{end+1} = sprintf('%s%s: %s', indent_str, field_name, array_str);
                    else
                        lines{end+1} = sprintf('%s%s: [%d numbers, range %.3g to %.3g]', ...
                            indent_str, field_name, numel(value), min(value), max(value));
                    end
                elseif ischar(value) || isstring(value)
                    lines{end+1} = sprintf('%s%s: "%s"', indent_str, field_name, value); % Add quotes
                elseif islogical(value)
                    if value
                        lines{end+1} = sprintf('%s%s: true', indent_str, field_name);
                    else
                        lines{end+1} = sprintf('%s%s: false', indent_str, field_name);
                    end
                elseif iscell(value)
                     lines{end+1} = sprintf('%s%s: {%d cell elements}', indent_str, field_name, numel(value));
                else
                    lines{end+1} = sprintf('%s%s: [%s]', indent_str, field_name, class(value)); % Show class
                end
            end
            text = strjoin(lines, '\n');
        end


        function blocks = list_blocks()
            % List all blocks in library using core.config

            blocks = {};
            library_dir = core.config.get_block_path(); % Call with no args gets the directory

            if ~exist(library_dir, 'dir')
                warning('Block library directory not found: %s', library_dir);
                return;
            end

            % Find all JSON files
            files = dir(fullfile(library_dir, ['*' core.config.BLOCK_EXTENSION]));

            for i = 1:length(files)
                % Skip backup files
                if endsWith(files(i).name, '.backup')
                    continue;
                end

                try
                    file_path = fullfile(files(i).folder, files(i).name);
                    block = gui.blocks.block_utils.load_block(file_path); % Load handles migration/version check

                    % Basic check for essential fields after potential migration
                    if ~isfield(block, 'block_id') || ~isfield(block, 'builder_type')
                         warning('Skipping invalid file (missing block_id or builder_type): %s', files(i).name);
                        continue;
                    end

                    info = struct();
                    info.file = file_path; % Store full path
                    info.name = files(i).name; % Filename for display
                    info.block_id = block.block_id;
                    info.builder_type = block.builder_type;
                    info.description = '';
                     if isfield(block, 'description')
                        info.description = block.description;
                    end
                    % Add metadata display info
                     info.metadata_summary = '';
                     if isfield(block, 'metadata')
                         summary_parts = {};
                         if isfield(block.metadata, 'created_by') && ~isempty(block.metadata.created_by)
                             summary_parts{end+1} = ['By: ' block.metadata.created_by];
                         end
                         if isfield(block.metadata, 'tags') && ~isempty(block.metadata.tags)
                              tag_str = strjoin(block.metadata.tags, ', ');
                              if length(tag_str) > 30 % Truncate long tag lists
                                  tag_str = [tag_str(1:27) '...'];
                              end
                             summary_parts{end+1} = ['Tags: ' tag_str];
                         end
                         info.metadata_summary = strjoin(summary_parts, ' | ');
                     end

                    blocks{end+1} = info;
                catch ME
                     warning('Error processing block file %s: %s', files(i).name, ME.message);
                    % Skip invalid files silently in listing, but warn
                end
            end
             % Sort blocks alphabetically by block_id for consistency
             if ~isempty(blocks)
                [~, sort_idx] = sort(cellfun(@(x) lower(x.block_id), blocks, 'UniformOutput', false));
                blocks = blocks(sort_idx);
             end
        end
    end % End static methods
end % End classdef

function s = mergestructs(s1, s2)
    % Helper to merge fields from s2 into s1
    s = s1;
    f = fieldnames(s2);
    for i = 1:length(f)
        s.(f{i}) = s2.(f{i});
    end
end