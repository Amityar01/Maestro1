classdef block_utils
    % BLOCK_UTILS - Utility functions for block management

    methods (Static)
        function schema = load_schema(builder_type, context)
            % Load schema for a builder type
            %
            % INPUTS:
            %   builder_type - Builder name (e.g., 'oddball')
            %   context - MaestroContext
            %
            % OUTPUTS:
            %   schema - Schema struct

            if ~isKey(context.builders, builder_type)
                error('Unknown builder type: %s', builder_type);
            end

            builder_info = context.builders(builder_type);

            % Load schema from file
            schema_file = fullfile(builder_info.path, 'template.schema.json');
            if ~exist(schema_file, 'file')
                error('Schema file not found: %s', schema_file);
            end

            fid = fopen(schema_file, 'r');
            schema_text = fread(fid, '*char')';
            fclose(fid);

            schema = jsondecode(schema_text);
        end

        function block = load_block(block_file)
            % Load block from JSON file
            %
            % INPUTS:
            %   block_file - Path to block JSON file
            %
            % OUTPUTS:
            %   block - Block struct

            if ~exist(block_file, 'file')
                error('Block file not found: %s', block_file);
            end

            fid = fopen(block_file, 'r');
            block_text = fread(fid, '*char')';
            fclose(fid);

            block = jsondecode(block_text);
        end

        function save_block(block, block_file)
            % Save block to JSON file
            %
            % INPUTS:
            %   block - Block struct
            %   block_file - Path to save to

            % Ensure directory exists
            [dir_path, ~, ~] = fileparts(block_file);
            if ~exist(dir_path, 'dir')
                mkdir(dir_path);
            end

            % Save as formatted JSON
            json_text = jsonencode(block);
            fid = fopen(block_file, 'w');
            fprintf(fid, '%s', json_text);
            fclose(fid);
        end

       % In Maestro/+gui/+blocks/block_utils.m
       % In Maestro/+gui/+blocks/block_utils.m
        % In Maestro/+gui/+blocks/block_utils.m
        function [is_valid, errors] = validate_block(block, schema, context)
            % Validate block against schema
            %
            % INPUTS:
            %   block - Block struct
            %   schema - Schema struct
            %   context - MaestroContext (for validating generators)
            %
            % OUTPUTS:
            %   is_valid - Boolean
            %   errors - Cell array of error messages

            errors = {}; % Initialize as 0x0 cell

            % Check required fields
            if ~isfield(block, 'block_id') || isempty(block.block_id)
                errors{end+1, 1} = 'Missing block_id'; % Force column
            end
            if ~isfield(block, 'builder_type')
                errors{end+1, 1} = 'Missing builder_type'; % Force column
            end
            if ~isfield(block, 'parameters')
                errors{end+1, 1} = 'Missing parameters struct'; % Force column
                is_valid = false;
                return;
            end

            % 1. Combine all parameter definitions from schema
            all_param_defs = struct();
            if isfield(schema, 'required_inputs')
                req_names = fieldnames(schema.required_inputs);
                for i = 1:length(req_names)
                    fname = req_names{i};
                    all_param_defs.(fname) = schema.required_inputs.(fname);
                end
            end
            if isfield(schema, 'optional_inputs')
                opt_names = fieldnames(schema.optional_inputs);
                 for i = 1:length(opt_names)
                    fname = opt_names{i};
                    all_param_defs.(fname) = schema.optional_inputs.(fname);
                end
            end
            
            % 2. Check for missing required parameters
            if isfield(schema, 'required_inputs')
                required_names = fieldnames(schema.required_inputs);
                for i = 1:length(required_names)
                    if ~isfield(block.parameters, required_names{i})
                         errors{end+1, 1} = sprintf('Missing required parameter: %s', required_names{i});
                    end
                end
            end

            % 3. Check all parameters that ARE present
            params_in_block = fieldnames(block.parameters);
            for i = 1:length(params_in_block)
                param_name = params_in_block{i};
                
                % --- START FIX ---
                % Skip validation if the parameter doesn't exist (can happen
                % if reading old block files that lack optional params)
                if ~isfield(block.parameters, param_name)
                    continue;
                end
                param_value = block.parameters.(param_name);
                % --- END FIX ---
                
                % Check if this parameter is defined in the schema
                if ~isfield(all_param_defs, param_name)
                    errors{end+1, 1} = sprintf('Unknown parameter: %s', param_name);
                    continue;
                end
                
                param_def = all_param_defs.(param_name);
                
                % --- START FIX ---
                % Correctly call the core validation function
                [val_valid, val_err] = core.validate_parameter_value(param_value, param_def);
                % --- END FIX ---
                
                if ~val_valid
                    errors{end+1, 1} = sprintf('Invalid value for %s: %s', param_name, val_err);
                end
                
                % Special check for stimulus_specification
                if strcmp(param_def.type, 'stimulus_specification')
                    if ~isstruct(param_value)
                        errors{end+1, 1} = sprintf('Stimulus "%s" is not a valid struct. Click "Edit..." to configure.', param_name);
                        continue; 
                    end
                    if nargin < 3 || isempty(context)
                        errors{end+1, 1} = sprintf('Cannot validate stimulus "%s" without context', param_name);
                        continue;
                    end
                    if ~isfield(param_value, 'generator') || isempty(param_value.generator)
                         errors{end+1, 1} = sprintf('Stimulus "%s" is missing "generator" field', param_name);
                    elseif ~isKey(context.generators, param_value.generator)
                         errors{end+1, 1} = sprintf('Stimulus "%s" specifies an unknown generator: %s', param_name, param_value.generator);
                    else
                         % --- START FIX ---
                         % Ensure parameters field exists before validating it
                         if ~isfield(param_value, 'parameters')
                             errors{end+1, 1} = sprintf('Stimulus "%s" (generator: %s) is missing the "parameters" field.', param_name, param_value.generator);
                         else
                             gen_schema = context.generators(param_value.generator).schema;
                             % Correctly call core.validate_parameters
                             [gen_valid, gen_errs] = core.validate_parameters(param_value.parameters, gen_schema.parameters);
                             if ~gen_valid
                                 errors{end+1, 1} = sprintf('Invalid parameters for stimulus "%s" (generator: %s):', param_name, param_value.generator);
                                 if ~iscolumn(gen_errs)
                                     gen_errs = gen_errs';
                                 end
                                 new_errors = cellfun(@(e) ['  - ' e], gen_errs, 'UniformOutput', false);
                                 errors = [errors; new_errors];
                             end
                         end
                         % --- END FIX ---
                    end
                end
            end
            
            is_valid = isempty(errors);
        end
        
        function text = format_parameters(params, indent)
            % Format parameters as human-readable text
            %
            % INPUTS:
            %   params - Struct with parameters
            %   indent - Indentation level (default: 0)
            %
            % OUTPUTS:
            %   text - Formatted text

            if nargin < 2
                indent = 0;
            end

            lines = {};
            indent_str = repmat('  ', 1, indent);

            fields = fieldnames(params);
            for i = 1:length(fields)
                field_name = fields{i};
                value = params.(field_name);

                if isstruct(value)
                    % Nested struct - recurse
                    lines{end+1} = sprintf('%s%s:', indent_str, field_name);
                    sub_text = gui.blocks.block_utils.format_parameters(value, indent + 1);
                    lines{end+1} = sub_text;

                elseif isnumeric(value) && length(value) == 1
                    % Single number
                    if value == floor(value)
                        lines{end+1} = sprintf('%s%s: %d', indent_str, field_name, value);
                    else
                        lines{end+1} = sprintf('%s%s: %.3f', indent_str, field_name, value);
                    end

                elseif isnumeric(value) && length(value) > 1
                    % Array
                    if length(value) <= 10
                        % Short array - show inline
                        array_str = sprintf('%.3f, ', value);
                        array_str = ['[' array_str(1:end-2) ']'];
                        lines{end+1} = sprintf('%s%s: %s', indent_str, field_name, array_str);
                    else
                        % Long array - show summary
                        lines{end+1} = sprintf('%s%s: [%d elements, range %.3f to %.3f]', ...
                            indent_str, field_name, length(value), min(value), max(value));
                    end

                elseif ischar(value) || isstring(value)
                    % String
                    lines{end+1} = sprintf('%s%s: %s', indent_str, field_name, value);

                elseif islogical(value)
                    % Boolean
                    if value
                        lines{end+1} = sprintf('%s%s: true', indent_str, field_name);
                    else
                        lines{end+1} = sprintf('%s%s: false', indent_str, field_name);
                    end

                else
                    % Unknown type - use mat2str
                    lines{end+1} = sprintf('%s%s: %s', indent_str, field_name, mat2str(value));
                end
            end

            text = strjoin(lines, '\n');
        end

        function blocks = list_blocks()
            % List all blocks in library
            %
            % OUTPUTS:
            %   blocks - Cell array of structs with:
            %            .file - Full path
            %            .name - Display name
            %            .builder_type - Builder type

            blocks = {};

            library_dir = 'library/blocks';
            if ~exist(library_dir, 'dir')
                return;
            end

            % Find all JSON files
            files = dir(fullfile(library_dir, '*.json'));

            for i = 1:length(files)
                try
                    file_path = fullfile(files(i).folder, files(i).name);
                    block = gui.blocks.block_utils.load_block(file_path);
                    
                    if ~isfield(block, 'block_id') || ~isfield(block, 'builder_type')
                        continue; % Not a valid block file
                    end

                    info = struct();
                    info.file = file_path;
                    info.name = files(i).name;
                    info.block_id = block.block_id;
                    info.builder_type = block.builder_type;
                    info.description = '';
                    if isfield(block, 'description')
                        info.description = block.description;
                    end

                    blocks{end+1} = info;
                catch
                    % Skip invalid files
                end
            end
        end
    end
end