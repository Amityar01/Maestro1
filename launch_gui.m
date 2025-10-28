function launch_gui()
    % Main entry point for the Maestro v2 GUI.
    
    clear; clc;
    fprintf('Launching Maestro v2 GUI...\n');

    % --- ROBUST PATH SETUP ---
    try
        script_path = fileparts(mfilename('fullpath'));
        if ~strcmp(pwd, script_path)
            cd(script_path); % Change to the script's directory
        end
        addpath(script_path); % Add the root directory to the path
        rehash toolboxcache;  % Force MATLAB to recognize new packages
        fprintf(' -> Path setup complete.\n');
    catch ME
        warning('Could not automatically set up path. Error: %s', ME.message);
        return;
    end

    % --- Create Figure and Panels ---
    fig = uifigure('Name', 'Maestro v2 - Modular Controller', 'Position', [100 100 1200 700]);
    p1 = uipanel(fig, 'Title', 'Block Templates', 'Position', [20 20 250 660]);
    p2 = uipanel(fig, 'Title', 'Parameter Editor', 'Position', [290 20 500 660]);
    p3 = uipanel(fig, 'Title', 'Experiment Playlist', 'Position', [810 20 370 660]);
    
    % --- Panel 1: Template List ---
    template_list = uilistbox(p1, 'Position', [10 10 230 610]);

    % --- Panel 2: Parameter Editor ---
    editor_panel = uipanel(p2, 'BorderType', 'none', 'Position', [10 70 480 550], 'Scrollable', 'on');
    uilabel(p2, 'Text', 'Instance Name:', 'Position', [15 40 100 22], 'FontWeight', 'bold');
    instance_name_field = uieditfield(p2, 'text', 'Position', [120 40 250 22]);
    save_button = uibutton(p2, 'Text', 'Save to Playlist', 'Position', [120 10 250 22], 'BackgroundColor', [0.1 0.5 0.8], 'FontColor', 'white');
    
    % --- Panel 3: Playlist ---
    playlist_list = uilistbox(p3, 'Position', [10 70 350 550]);
    move_up_btn = uibutton(p3, 'Text', 'Up', 'Position', [10 40 80 22]);
    move_down_btn = uibutton(p3, 'Text', 'Down', 'Position', [100 40 80 22]);
    remove_btn = uibutton(p3, 'Text', 'Remove', 'Position', [190 40 80 22]);
    run_experiment_btn = uibutton(p3, 'Text', 'RUN EXPERIMENT', 'Position', [10 10 350 22], 'BackgroundColor', [0.2 0.8 0.2], 'FontColor', 'white', 'FontWeight', 'bold');

    % --- Discover All Components ---
    fprintf('Discovering components...\n');
    handles = struct();
    handles.fig = fig;
    handles.editor_panel = editor_panel;
    handles.instance_name_field = instance_name_field;
    handles.playlist_list = playlist_list;
    
    % --- CORRECTED DISCOVERY CALLS ---
    handles.builders = gui_helpers.discovery.find_components('+trials/+builders');
    handles.stimuli = gui_helpers.discovery.find_components('+stim');
    
    [template_names, template_files] = gui_helpers.discovery.find_templates('block_templates');
    template_list.Items = template_names;
    template_list.UserData = struct('files', {template_files});
    
    fprintf(' -> Found %d templates, %d builders, %d stimuli.\n', ...
        numel(template_names), handles.builders.Count, handles.stimuli.Count);
    
    fig.UserData = handles;
    
    % --- Assign Callbacks ---
    template_list.ValueChangedFcn = @(src, ~) gui_helpers.dynamic_builder.templateSelectedCallback(fig, src);
    save_button.ButtonPushedFcn = @(src, ~) gui_helpers.config_manager.save_to_playlist(fig);
    
    % Add playlist management callbacks
    move_up_btn.ButtonPushedFcn = @(src, ~) manage_playlist('up', fig);
    move_down_btn.ButtonPushedFcn = @(src, ~) manage_playlist('down', fig);
    remove_btn.ButtonPushedFcn = @(src, ~) manage_playlist('remove', fig);

    % Add experiment execution callback
    run_experiment_btn.ButtonPushedFcn = @(src, ~) run_experiment_from_gui(fig);

    fprintf('✓ GUI Ready.\n');
end

function manage_playlist(action, fig)
    % Handles moving items up/down or removing them from the playlist.
    handles = fig.UserData;
    listbox = handles.playlist_list;
    selected_item = listbox.Value;
    if isempty(selected_item), return; end
    
    idx = find(strcmp(listbox.Items, selected_item));
    
    switch action
        case 'remove'
            listbox.Items(idx) = [];
            if ~isempty(listbox.UserData)
                listbox.UserData(idx) = [];
            end
        case 'up'
            if idx > 1
                items = listbox.Items;
                data = listbox.UserData;
                items([idx-1, idx]) = items([idx, idx-1]);
                if ~isempty(data)
                    data([idx-1, idx]) = data([idx, idx-1]);
                    listbox.UserData = data;
                end
                listbox.Items = items;
                listbox.Value = selected_item;
            end
        case 'down'
            if idx < numel(listbox.Items)
                items = listbox.Items;
                data = listbox.UserData;
                items([idx, idx+1]) = items([idx+1, idx]);
                 if ~isempty(data)
                    data([idx, idx+1]) = data([idx+1, idx]);
                    listbox.UserData = data;
                end
                listbox.Items = items;
                listbox.Value = selected_item;
            end
    end
end

function run_experiment_from_gui(fig)
    % Executes experiment from the current playlist

    handles = fig.UserData;
    listbox = handles.playlist_list;

    % Check if playlist is empty
    if isempty(listbox.Items)
        uialert(fig, 'Playlist is empty. Add blocks to the playlist before running.', ...
            'Empty Playlist', 'Icon', 'warning');
        return;
    end

    % Get playlist data (block configurations)
    playlist_data = listbox.UserData;
    if isempty(playlist_data)
        uialert(fig, 'Playlist contains no block data.', ...
            'Invalid Playlist', 'Icon', 'error');
        return;
    end

    % Prompt for session information
    prompt = {'Subject ID:', 'Experimenter:', 'Session Number:'};
    dlgtitle = 'Session Information';
    dims = [1 35];
    definput = {'S001', getenv('USER'), '1'};
    answer = inputdlg(prompt, dlgtitle, dims, definput);

    if isempty(answer)
        return; % User cancelled
    end

    subject_id = answer{1};
    experimenter = answer{2};
    session_num = str2double(answer{3});

    % Validate inputs
    if isempty(subject_id) || isempty(experimenter) || isnan(session_num)
        uialert(fig, 'All session fields are required.', ...
            'Invalid Input', 'Icon', 'error');
        return;
    end

    % Show progress dialog
    progress = uiprogressdlg(fig, 'Title', 'Running Experiment', ...
        'Message', 'Initializing...', 'Indeterminate', 'on');

    try
        % Create MaestroContext
        progress.Message = 'Loading Maestro context...';
        context = MaestroContext(pwd);

        % Build experiment specification from playlist
        progress.Message = 'Building experiment specification...';
        experiment_spec = struct();
        experiment_spec.experiment_id = sprintf('%s_session%d', subject_id, session_num);
        experiment_spec.global_settings = struct();
        experiment_spec.global_settings.sampling_rate_hz = core.Constants.DEFAULT_SAMPLING_RATE_HZ;
        experiment_spec.global_settings.subject_id = subject_id;
        experiment_spec.global_settings.experimenter = experimenter;
        experiment_spec.global_settings.session_number = session_num;

        % Add blocks from playlist
        experiment_spec.sequence = cell(1, length(playlist_data));
        for i = 1:length(playlist_data)
            block_config = playlist_data{i};

            % Normalize block instance
            block_instance = core.normalization.InstanceNormalizer.ensure_block_instance(block_config);

            % Store in sequence
            experiment_spec.sequence{i} = block_instance;
        end

        % Validate experiment spec
        progress.Message = 'Validating experiment specification...';
        core.validation.ValidationHelpers.validate_experiment_spec(experiment_spec);

        % Create session directory and prepare for execution
        progress.Message = 'Creating session directory...';
        session_id = sprintf('%s_%s', experiment_spec.experiment_id, ...
            datestr(now, 'yyyymmdd_HHMMSS'));
        session_dir = fullfile(pwd, 'sessions', session_id);
        if ~exist(session_dir, 'dir')
            mkdir(session_dir);
        end

        % Save experiment specification
        spec_file = fullfile(session_dir, 'experiment_spec.json');
        core.config.ConfigurationManager.save_json_file(experiment_spec, spec_file);

        % Execute experiment
        progress.Message = sprintf('Executing experiment with %d blocks...', length(experiment_spec.sequence));
        progress.Indeterminate = 'off';
        progress.Value = 0;

        % Run experiment with logging
        result = context.run_experiment_with_logging(experiment_spec, session_dir);

        progress.Value = 1;
        close(progress);

        % Show success message
        if strcmp(result.status, core.Constants.STATUS_COMPLETED)
            uialert(fig, sprintf('Experiment completed successfully!\nSession ID: %s\nResults saved to: %s', ...
                session_id, session_dir), 'Success', 'Icon', 'success');
        else
            uialert(fig, sprintf('Experiment finished with status: %s\nCheck session logs for details.', ...
                result.status), 'Experiment Finished', 'Icon', 'warning');
        end

    catch ME
        close(progress);
        uialert(fig, sprintf('Error running experiment:\n%s\n\nDetails: %s', ...
            ME.message, ME.identifier), 'Experiment Error', 'Icon', 'error');
        fprintf('Full error details:\n');
        disp(getReport(ME));
    end
end

