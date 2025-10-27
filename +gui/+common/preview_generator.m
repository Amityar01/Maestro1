classdef preview_generator
    % Generates a text preview summary based on a trial list and a schema template.

    methods (Static)
        function summary_text = generate(trial_list, block_params, preview_template)
            % Generates the preview text by iterating through the template items.

            % --- INPUT VALIDATION ---
            if ~isstruct(trial_list) && ~iscell(trial_list)
                summary_text = sprintf('[Preview Error: trial_list is not a struct or cell array (found %s)]', class(trial_list));
                warning(summary_text);
                return;
            end
             if isempty(trial_list)
                summary_text = 'Builder returned an empty trial list for preview.';
                return;
            end
            if ~isstruct(block_params)
                 summary_text = sprintf('[Preview Error: block_params is not a struct (found %s)]', class(block_params));
                 warning(summary_text);
                 return;
            end
             if ~isstruct(preview_template) && ~iscell(preview_template)
                 summary_text = sprintf('[Preview Error: preview_template is not a struct or cell array (found %s)]', class(preview_template));
                 warning(summary_text);
                 return;
             end
             % --- END INPUT VALIDATION ---


            summary_lines = {sprintf('Preview Summary (%d trials):', length(trial_list))};
            fprintf('\n--- Generating Preview ---\n');

            for i = 1:length(preview_template)
                % Ensure item is a struct before accessing fields
                if iscell(preview_template) % Handle cell array case if necessary
                    item = preview_template{i};
                else
                    item = preview_template(i);
                end

                if ~isstruct(item)
                    line = sprintf('  [Error processing preview item %d: Template item is not a struct]', i);
                    warning(line);
                    summary_lines{end+1} = line; %#ok<AGROW>
                    continue; % Skip this item
                end

                % Check for essential fields
                if ~isfield(item, 'type')
                    line = sprintf('  [Error processing preview item %d: Missing "type" field]', i);
                     warning(line);
                    summary_lines{end+1} = line; %#ok<AGROW>
                    continue;
                end
                 if ~isfield(item, 'label') && ~strcmp(item.type, 'sequence') % Sequence doesn't strictly need a label
                    line = sprintf('  [Error processing preview item %d: Missing "label" field for type "%s"]', i, item.type);
                     warning(line);
                    summary_lines{end+1} = line; %#ok<AGROW>
                    continue;
                end


                line = '';
                fprintf('Processing template item %d: type=%s\n', i, item.type);
                try
                    switch item.type
                        case 'header'
                            line = item.label;
                        case 'parameter'
                            line = gui.common.preview_generator.process_parameter(item, block_params);
                        case 'statistic'
                            line = gui.common.preview_generator.process_statistic(item, trial_list);
                        case 'sequence'
                            line = gui.common.preview_generator.process_sequence(item, trial_list);
                        otherwise
                            line = sprintf('  [Unknown preview item type: "%s"]', item.type);
                            warning('Unknown preview item type: %s', item.type);
                    end
                catch ME
                    line = sprintf('  [Error processing preview item "%s" (Index %d): %s in %s line %d]', ...
                                   item.type, i, ME.message, ME.stack(1).name, ME.stack(1).line);
                    fprintf('*** Error processing item %d:\n', i);
                    disp(item);
                    disp(ME);
                    fprintf('Error occurred in file: %s\nFunction: %s\nLine: %d\n', ...
                            ME.stack(1).file, ME.stack(1).name, ME.stack(1).line);
                end
                summary_lines{end+1} = line; %#ok<AGROW>
            end

            fprintf('--- Preview Generation Complete ---\n');
            summary_text = strjoin(summary_lines, '\n');
        end

        function line = process_parameter(item, block_params)
            % Extracts a value directly from the block's parameters
            fprintf('  Processing parameter: source=%s\n', item.source_field);
            value = gui.common.preview_generator.get_nested_field(block_params, item.source_field);
            current_line = item.label;

            if isempty(value) && ~ischar(value) % Allow empty string values
                 current_line = strrep(current_line, '{value}', '[Not Found]');
                 fprintf('    -> Value not found or invalid for %s\n', item.source_field);
                 line = current_line; return;
            end

            if isstruct(value) && isfield(value, 'generator')
                gen = value.generator; str_val = gen;
                 freq = gui.common.preview_generator.get_nested_field(value, 'parameters.freq_hz');
                 dur = gui.common.preview_generator.get_nested_field(value, 'parameters.dur_ms');
                 lvl = gui.common.preview_generator.get_nested_field(value, 'parameters.level_db');
                 details = {};
                 if ~isempty(freq), details{end+1} = sprintf('%g Hz', freq); end
                 if ~isempty(dur), details{end+1} = sprintf('%g ms', dur); end
                 if ~isempty(lvl), details{end+1} = sprintf('%g dB', lvl); end
                 if ~isempty(details), str_val = sprintf('%s (%s)', gen, strjoin(details, ', ')); end
                 current_line = strrep(current_line, '{value}', str_val);
                 current_line = gui.common.preview_generator.replace_nested_placeholders(current_line, value);
            elseif isnumeric(value) || islogical(value)
                 current_line = strrep(current_line, '{value}', num2str(value));
            elseif ischar(value) || isstring(value)
                 current_line = strrep(current_line, '{value}', value);
            else
                 current_line = strrep(current_line, '{value}', sprintf('[%s]', class(value)));
            end
            line = current_line;
            fprintf('    -> Result: %s\n', line);
        end

        function line = process_statistic(item, trial_list)
            % Calculates a statistic from the trial list
             fprintf('  Processing statistic: source=%s, calc=%s\n', item.source_field, item.calculation);
            data = gui.common.preview_generator.get_data_from_trials(trial_list, item.source_field);
            line = item.label;
            fmt = '%.3f';
            if isfield(item, 'format'), fmt = item.format; end

             if isempty(data)
                 line = strrep(line, '{count}', '0');
                 line = strrep(line, '{total}', num2str(length(trial_list)));
                 line = strrep(line, '{percentage}', '0.0');
                 line = strrep(line, '{min}', 'N/A');
                 line = strrep(line, '{max}', 'N/A');
                 line = strrep(line, '{mean}', 'N/A');
                 fprintf('    -> No data found or extracted for statistic source field "%s".\n', item.source_field);
                 return;
             end

            switch item.calculation
                case 'count_where_true'
                     try
                         logical_data = logical(data); % Attempt conversion
                         count = sum(logical_data);
                         total = length(data);
                         percentage = 100 * count / total;
                         line = strrep(line, '{count}', num2str(count));
                         line = strrep(line, '{total}', num2str(total));
                         line = strrep(line, '{percentage}', sprintf('%.1f', percentage));
                     catch convErr
                         warning('Preview Generator: Could not convert data for "%s" to logical. Error: %s', item.source_field, convErr.message);
                         line = strrep(line, '{count}', 'Err'); line = strrep(line, '{total}', num2str(length(data))); line = strrep(line, '{percentage}', 'Err');
                     end
                case 'min_max'
                     if iscell(data), is_num_cell = cellfun(@isnumeric, data) & ~cellfun(@isempty, data); numeric_data = [data{is_num_cell}];
                     elseif isnumeric(data), numeric_data = data(~isnan(data)); else, numeric_data = []; end
                     if isempty(numeric_data), line = strrep(line, '{min}', 'N/A'); line = strrep(line, '{max}', 'N/A');
                     else, line = strrep(line, '{min}', sprintf(fmt, min(numeric_data))); line = strrep(line, '{max}', sprintf(fmt, max(numeric_data))); end
                case 'mean'
                     if iscell(data), is_num_cell = cellfun(@isnumeric, data) & ~cellfun(@isempty, data); numeric_data = [data{is_num_cell}];
                     elseif isnumeric(data), numeric_data = data(~isnan(data)); else, numeric_data = []; end
                      if isempty(numeric_data), line = strrep(line, '{mean}', 'N/A');
                      else, line = strrep(line, '{mean}', sprintf(fmt, mean(numeric_data))); end
                 otherwise
                     line = sprintf('  [Unknown calculation: "%s"]', item.calculation);
                     warning('Unknown preview statistic calculation: %s', item.calculation);
            end
            fprintf('    -> Result: %s\n', line);
        end

        function lines_str = process_sequence(item, trial_list)
            % Generates a character sequence visualization
            fprintf('  Processing sequence: source=%s\n', item.source_field);
            data = gui.common.preview_generator.get_data_from_trials(trial_list, item.source_field);

             if isempty(data)
                 lines_str = '  [No sequence data found]';
                 fprintf('    -> No data found for sequence.\n'); return;
             end

            max_len = min(length(data), item.length);
            seq_chars = repmat('?', 1, max_len);

            for i = 1:max_len
                 if iscell(data), val = data{i}; else, val = data(i); end
                 if islogical(val), key = mat2str(val);
                 elseif isnumeric(val), key = num2str(val);
                 elseif ischar(val) || isstring(val), key = strtrim(char(val));
                 else key = 'unknown_type'; end

                if isfield(item, 'mapping') && isstruct(item.mapping) && isfield(item.mapping, key)
                    seq_chars(i) = item.mapping.(key);
                else
                     if (ischar(val) || isstring(val))
                         key_lower = lower(key); key_upper = upper(key);
                         if isfield(item.mapping, key_lower), seq_chars(i) = item.mapping.(key_lower);
                         elseif isfield(item.mapping, key_upper), seq_chars(i) = item.mapping.(key_upper);
                         else
                             fprintf('    -> Warning: No mapping found for key "%s" (value: %s) in sequence item %d.\n', key, mat2str(val), i);
                         end
                     else
                        fprintf('    -> Warning: No mapping found for key "%s" (value: %s) in sequence item %d.\n', key, mat2str(val), i);
                     end
                end
            end

            chars_per_line = item.chars_per_line;
            num_lines = ceil(max_len / chars_per_line);
            lines = cell(num_lines, 1);
            for i = 1:num_lines
                start_idx = (i-1) * chars_per_line + 1;
                end_idx = min(i * chars_per_line, max_len);
                 chars_for_line = cellstr(seq_chars(start_idx:end_idx)');
                 lines{i} = strjoin(chars_for_line, ' ');
            end
            lines_str = strjoin(lines, '\n');
            fprintf('    -> Generated sequence string.\n');
        end

        function data = get_data_from_trials(trial_list, source_field)
            % Helper to extract data from the trial list, robust to empty/missing fields
            num_trials = length(trial_list);
            if num_trials == 0, data = []; return; end

            first_val = [];
            first_idx = 1;
            while isempty(first_val) && first_idx <= num_trials
                first_val = gui.common.preview_generator.get_nested_field(trial_list(first_idx), source_field);
                first_idx = first_idx + 1;
            end

            if isnumeric(first_val) || islogical(first_val)
                 if islogical(first_val), data = false(1, num_trials);
                 else, data = nan(1, num_trials); end
                 is_numeric_or_logical = true;
            else
                data = cell(1, num_trials);
                is_numeric_or_logical = false;
            end

            for i = 1:num_trials
                val = gui.common.preview_generator.get_nested_field(trial_list(i), source_field);
                if is_numeric_or_logical
                    if isempty(val)
                         if islogical(data), data(i) = false; else, data(i) = NaN; end
                    else
                        try
                             if islogical(data), data(i) = logical(val);
                             elseif isnumeric(data), data(i) = double(val); end
                        catch ME_type
                            warning('Preview Generator: Type mismatch for field "%s" trial %d. Expected %s, got %s. Assigning default.', source_field, i, class(data), class(val));
                            if islogical(data), data(i) = false; else, data(i) = NaN; end
                        end
                    end
                else
                    data{i} = val;
                end
            end
        end

        function value = get_nested_field(s, field_path)
            % Access nested struct fields safely
            parts = strsplit(field_path, '.');
            value = s;
            try
                for i = 1:length(parts)
                    field_name = parts{i};
                    if ~(isstruct(value) || isobject(value))
                        value = []; return;
                    end
                    if ~isfield(value, field_name) && ~isprop(value, field_name)
                         value = []; return;
                    end
                    value = value.(field_name);
                end
            catch ME
                 fprintf('    -> get_nested_field: Error accessing "%s": %s\n', field_path, ME.message);
                 value = [];
            end
        end

        function str = get_nested_field_as_string(s, field_path)
             % Helper for regexprep replacement
             val = gui.common.preview_generator.get_nested_field(s, field_path);
             if isempty(val) && ~ischar(val), str = '[N/A]'; % Allow empty strings
             elseif isnumeric(val) || islogical(val), str = num2str(val);
             elseif ischar(val) || isstring(val), str = char(val);
             else, str = sprintf('[%s]', class(val)); end
        end

        function line = replace_nested_placeholders(line, value_struct)
            % Replaces placeholders like {value.field.subfield} using regexprep
             pattern = '\{value\.([a-zA-Z0-9_.]+)\}';
             line = regexprep(line, pattern, '${gui.common.preview_generator.get_nested_field_as_string(value_struct, "$1")}');
        end

    end % End static methods
end % End classdef