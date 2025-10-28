classdef config_manager
    % config_manager - Manages saving configured blocks to the playlist
    methods (Static)
        function save_to_playlist(fig)
            % Saves the currently configured block to the playlist

            handles = fig.UserData;

            % Get instance name
            instance_name = handles.instance_name_field.Value;
            if isempty(strtrim(instance_name))
                uialert(fig, 'Please enter an instance name for this block.', ...
                    'Missing Instance Name', 'Icon', 'warning');
                return;
            end

            % Check if template is loaded
            if ~isfield(handles, 'current_template_config') || isempty(handles.current_template_config)
                uialert(fig, 'No block template selected. Select a template first.', ...
                    'No Template', 'Icon', 'warning');
                return;
            end

            % Start with the original template config
            block_config = handles.current_template_config;

            % Update config with current control values
            if isfield(handles, 'control_map') && ~isempty(handles.control_map)
                keys_list = keys(handles.control_map);
                for i = 1:length(keys_list)
                    mapping = handles.control_map(keys_list{i});
                    control = mapping.control;
                    config_path = mapping.path;

                    % Get value from control
                    if isprop(control, 'Value')
                        value = control.Value;

                        % Update the config at the specified path
                        block_config = gui_helpers.config_manager.set_nested_field(block_config, config_path, value);
                    end
                end
            end

            % Add metadata
            block_config.instance_name = instance_name;
            block_config.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

            % Add to playlist
            listbox = handles.playlist_list;

            % Initialize UserData if empty
            if isempty(listbox.UserData)
                listbox.UserData = {};
            end

            % Add to playlist
            listbox.Items{end+1} = instance_name;
            listbox.UserData{end+1} = block_config;

            % Select the newly added item
            listbox.Value = instance_name;

            fprintf('✓ Added "%s" to playlist (%d blocks total)\n', instance_name, length(listbox.Items));
        end

        function s = set_nested_field(s, path, value)
            % Sets a nested field using dot notation path
            % E.g., path = 'trial_params.num_trials' sets s.trial_params.num_trials = value

            parts = strsplit(path, '.');

            % Build the nested struct if it doesn't exist
            current = s;
            for i = 1:(length(parts) - 1)
                if ~isfield(current, parts{i})
                    current.(parts{i}) = struct();
                end
                current = current.(parts{i});
            end

            % Use subsasgn to set the final value
            subs = struct('type', '.', 'subs', parts{1});
            for i = 2:length(parts)
                subs(i) = struct('type', '.', 'subs', parts{i});
            end

            s = subsasgn(s, subs, value);
        end
    end
end
