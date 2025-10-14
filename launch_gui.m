% Maestro/launch_gui.m
function launch_gui()
% LAUNCH_GUI - The main entry point for the Maestro Experimental GUI.
%
% This function creates the figure, panels, and all interactive components
% for designing and running experimental playlists.

clear; clc;
fprintf('Launching Maestro GUI...\n');

% --- Main Figure ---
fig = uifigure('Name', 'Maestro - Experiment Controller', ...
               'Position', [100 100 1200 700]);

% =========================================================================
% --- Panel 1: Block Library (Templates) ---
% =========================================================================
p1 = uipanel(fig, 'Title', 'Block Library', 'Position', [20 20 250 660]);

template_list = uilistbox(p1, 'Position', [10 10 230 610]);
template_list.Items = {'Loading...'}; % Placeholder

% --- Populate the template list ---
template_dir = 'block_templates';
json_files = dir(fullfile(template_dir, '*.json'));
template_names = {};
template_data = {};
for i = 1:numel(json_files)
    try
        json_path = fullfile(template_dir, json_files(i).name);
        data = jsondecode(fileread(json_path));
        template_names{end+1} = data.name;
        template_data{end+1} = json_path;
    catch
        fprintf('Warning: Could not parse %s\n', json_files(i).name);
    end
end
template_list.Items = template_names;
template_list.UserData = template_data; % Store file paths

% =========================================================================
% --- Panel 2: Block Editor ---
% =========================================================================
p2 = uipanel(fig, 'Title', 'Block Editor', 'Position', [290 20 450 660]);

% Read-only info fields
uilabel(p2, 'Text', 'Template:', 'FontWeight', 'bold', 'Position', [20 615 100 22]);
template_name_label = uilabel(p2, 'Text', 'None Selected', 'Position', [130 615 300 22]);
uilabel(p2, 'Text', 'Description:', 'FontWeight', 'bold', 'Position', [20 590 100 22]);
template_desc_label = uilabel(p2, 'Text', '', 'Position', [130 590 300 22], 'WordWrap', 'on');

% Panel to hold the dynamically generated parameter fields
param_panel = uipanel(p2, 'BorderType', 'none', 'Position', [0 100 450 480]);

% Fields for saving the instance
uilabel(p2, 'Text', 'Instance Name:', 'FontWeight', 'bold', 'Position', [20 60 100 22]);
instance_name_field = uieditfield(p2, 'text', 'Position', [130 60 200 22]);

add_to_playlist_btn = uibutton(p2, 'Text', 'Add to Playlist', 'Position', [130 20 200 30]);

% =========================================================================
% --- Panel 3: Experiment Playlist ---
% =========================================================================
p3 = uipanel(fig, 'Title', 'Experiment Playlist', 'Position', [760 20 420 660]);

playlist_list = uilistbox(p3, 'Position', [10 70 400 550]);

% Playlist manipulation buttons
move_up_btn = uibutton(p3, 'Text', 'Move Up', 'Position', [10 30 80 30]);
move_down_btn = uibutton(p3, 'Text', 'Move Down', 'Position', [100 30 80 30]);
remove_btn = uibutton(p3, 'Text', 'Remove', 'Position', [190 30 80 30]);
randomize_btn = uibutton(p3, 'Text', 'Randomize', 'Position', [280 30 80 30]);

% Main execution button
run_experiment_btn = uibutton(fig, 'Text', 'RUN EXPERIMENT', ...
    'FontWeight', 'bold', 'FontSize', 16, 'Position', [760 640 420 40], ...
    'BackgroundColor', [0.8 0.9 0.8]);

% Store handles to key components for access in callbacks
handles = struct(...
    'template_list', template_list, ...
    'param_panel', param_panel, ...
    'template_name_label', template_name_label, ...
    'template_desc_label', template_desc_label, ...
    'instance_name_field', instance_name_field, ...
    'playlist_list', playlist_list ...
);
fig.UserData = handles;

% --- Assign Callbacks ---
template_list.ValueChangedFcn = @(src, event) templateSelectedCallback(fig);
add_to_playlist_btn.ButtonPushedFcn = @(src, event) addToPlaylistCallback(fig);
run_experiment_btn.ButtonPushedFcn = @(src, event) runExperimentCallback(fig);
remove_btn.ButtonPushedFcn = @(src, event) removeFromPlaylistCallback(fig);
move_up_btn.ButtonPushedFcn = @(src, event) moveInPlaylistCallback(fig, 'up');
move_down_btn.ButtonPushedFcn = @(src, event) moveInPlaylistCallback(fig, 'down');
randomize_btn.ButtonPushedFcn = @(src, event) randomizePlaylistCallback(fig);

fprintf('✓ GUI Ready.\n');
end


% =========================================================================
% --- CALLBACK FUNCTIONS ---
% =========================================================================

function templateSelectedCallback(fig)
    handles = fig.UserData;
    
    % --- Clear previous dynamic UI ---
    delete(handles.param_panel.Children);
    
    % --- Load selected template ---
    selected_idx = find(strcmp(handles.template_list.Items, handles.template_list.Value));
    json_path = handles.template_list.UserData{selected_idx};
    config = jsondecode(fileread(json_path));
    
    % --- Update info labels ---
    handles.template_name_label.Text = config.name;
    handles.template_desc_label.Text = config.description;
    
    % --- Dynamically create UI for editable parameters ---
    y_pos = 440; % Starting Y position for UI elements
    
    % Create a list of top-level fields that should be editable
    editable_fields = {'n_trials', 'deviant_probability', 'standard', 'deviant', 'timing'};
    
    for i = 1:numel(editable_fields)
        field_name = editable_fields{i};
        if isfield(config, field_name)
            % Create a bold title label for the section
            uilabel(handles.param_panel, 'Text', upper(field_name), 'FontWeight', 'bold', 'Position', [10, y_pos, 200, 22]);
            y_pos = y_pos - 30;
            
            % Use helper to create UI for this section
            gui_helpers.create_ui_from_struct(handles.param_panel, config.(field_name), y_pos, field_name);
            
            % This is a rough way to update y_pos, needs refinement for deeply nested structs
            y_pos = y_pos - 150; % Adjust this based on expected size
        end
    end
end

function addToPlaylistCallback(fig)
    handles = fig.UserData;
    
    % --- Get instance name ---
    instance_name = handles.instance_name_field.Value;
    if isempty(instance_name)
        uialert(fig, 'Please enter an instance name.', 'Error');
        return;
    end
    
    % --- Load original template config ---
    selected_idx = find(strcmp(handles.template_list.Items, handles.template_list.Value));
    json_path = handles.template_list.UserData{selected_idx};
    config = jsondecode(fileread(json_path));
    
    % --- Update config with values from the editor ---
    ui_elements = findobj(handles.param_panel, '-isa', 'matlab.ui.control.EditField');
    for i = 1:numel(ui_elements)
        element = ui_elements(i);
        path_str = element.UserData.path;
        new_val_str = element.Value;
        
        % Convert string value to number if possible
        new_val_num = str2double(new_val_str);
        if ~isnan(new_val_num)
            new_val = new_val_num;
        else
            new_val = new_val_str;
        end
        
        % Update the config struct using dynamic field referencing
        % e.g., config.standard.params.freq_hz = 8000
        eval(sprintf('config%s = %s;', path_str, num2str(new_val)));
    end
    
    % --- Save new JSON instance ---
    output_filename = [instance_name, '.json'];
    output_path = fullfile('saved_blocks', output_filename);
    fid = fopen(output_path, 'w');
    fprintf(fid, '%s', jsonencode(config, "PrettyPrint", true));
    fclose(fid);
    
    % --- Add to playlist UI ---
    handles.playlist_list.Items{end+1} = instance_name;
    % Store the full path to the new json file in UserData
    if isempty(handles.playlist_list.UserData)
        handles.playlist_list.UserData = {};
    end
    handles.playlist_list.UserData{end+1} = output_path;
    
    fprintf('Saved and added to playlist: %s\n', output_path);
end

function runExperimentCallback(fig)
    handles = fig.UserData;
    
    playlist_files = handles.playlist_list.UserData;
    if isempty(playlist_files)
        uialert(fig, 'Playlist is empty.', 'Cannot Run');
        return;
    end
    
    % Basic settings (can be moved to UI later)
    device_id = 'Dev1';
    
    for i = 1:numel(playlist_files)
        block_file = playlist_files{i};
        [~, block_name, ~] = fileparts(block_file);
        
        % Create unique output directory for this run
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        out_dir = fullfile('data', [block_name, '_', timestamp]);
        
        fprintf('\n═════ RUNNING BLOCK %d of %d: %s ═════\n', i, numel(playlist_files), block_name);
        
        try
            run_experiment(block_file, device_id, out_dir);
        catch e
            uialert(fig, sprintf('Error running %s:\n%s', block_name, e.message), 'Experiment Failed');
            fprintf('! EXPERIMENT HALTED DUE TO ERROR !\n');
            return;
        end
    end
    
    uialert(fig, 'Playlist finished successfully!', 'Complete');
    fprintf('\n✓✓✓ PLAYLIST COMPLETE ✓✓✓\n');
end

function removeFromPlaylistCallback(fig)
    handles = fig.UserData;
    selected = handles.playlist_list.Value;
    if isempty(selected), return; end
    
    idx_to_remove = find(strcmp(handles.playlist_list.Items, selected));
    
    handles.playlist_list.Items(idx_to_remove) = [];
    handles.playlist_list.UserData(idx_to_remove) = [];
end

function moveInPlaylistCallback(fig, direction)
    handles = fig.UserData;
    items = handles.playlist_list.Items;
    data = handles.playlist_list.UserData;
    selected = handles.playlist_list.Value;
    if isempty(selected) || numel(items) < 2, return; end
    
    idx = find(strcmp(items, selected));
    
    if strcmp(direction, 'up') && idx > 1
        new_idx = idx - 1;
        items([new_idx, idx]) = items([idx, new_idx]);
        data([new_idx, idx]) = data([idx, new_idx]);
    elseif strcmp(direction, 'down') && idx < numel(items)
        new_idx = idx + 1;
        items([new_idx, idx]) = items([idx, new_idx]);
        data([new_idx, idx]) = data([idx, new_idx]);
    end
    
    handles.playlist_list.Items = items;
    handles.playlist_list.UserData = data;
end

function randomizePlaylistCallback(fig)
    handles = fig.UserData;
    items = handles.playlist_list.Items;
    data = handles.playlist_list.UserData;
    if numel(items) < 2, return; end
    
    new_order = randperm(numel(items));
    
    handles.playlist_list.Items = items(new_order);
    handles.playlist_list.UserData = data(new_order);
end