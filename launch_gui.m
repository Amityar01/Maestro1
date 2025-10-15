% Maestro/launch_gui.m
function launch_gui()
clear; clc;
fprintf('Launching Maestro GUI...\n');

fig = uifigure('Name', 'Maestro - Experiment Controller', 'Position', [100 100 1200 700]);

% Panel 1: Block Library
p1 = uipanel(fig, 'Title', 'Block Library', 'Position', [20 20 250 660]);
template_list = uilistbox(p1, 'Position', [10 10 230 610]);

% Load templates
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
template_list.UserData = template_data;

% Panel 2: Block Editor
p2 = uipanel(fig, 'Title', 'Block Editor', 'Position', [290 20 450 660]);
uilabel(p2, 'Text', 'Template:', 'FontWeight', 'bold', 'Position', [20 615 80 22]);
template_name_label = uilabel(p2, 'Text', 'None Selected', 'Position', [105 615 330 22]);
uilabel(p2, 'Text', 'Description:', 'FontWeight', 'bold', 'Position', [20 590 80 22]);
template_desc_label = uilabel(p2, 'Text', '', 'Position', [105 590 330 22], 'WordWrap', 'on');
param_panel = uipanel(p2, 'BorderType', 'none', 'Position', [10 100 430 480], 'Scrollable', 'on');
uilabel(p2, 'Text', 'Instance Name:', 'FontWeight', 'bold', 'Position', [20 60 100 22]);
instance_name_field = uieditfield(p2, 'text', 'Position', [130 60 200 22]);
add_to_playlist_btn = uibutton(p2, 'Text', 'Add to Playlist', 'Position', [130 20 200 30]);

% Panel 3: Playlist
p3 = uipanel(fig, 'Title', 'Experiment Playlist', 'Position', [760 20 420 660]);
playlist_list = uilistbox(p3, 'Position', [10 70 400 550]);
playlist_list.Items = {};
move_up_btn = uibutton(p3, 'Text', 'Move Up', 'Position', [10 30 80 30]);
move_down_btn = uibutton(p3, 'Text', 'Move Down', 'Position', [100 30 80 30]);
remove_btn = uibutton(p3, 'Text', 'Remove', 'Position', [190 30 80 30]);
randomize_btn = uibutton(p3, 'Text', 'Randomize', 'Position', [280 30 80 30]);
run_experiment_btn = uibutton(fig, 'Text', 'RUN EXPERIMENT', 'FontWeight', 'bold', 'FontSize', 16, 'Position', [760 640 420 40], 'BackgroundColor', [0.8 0.9 0.8]);

% Store handles
handles = struct('template_list', template_list, 'param_panel', param_panel, 'template_name_label', template_name_label, 'template_desc_label', template_desc_label, 'instance_name_field', instance_name_field, 'playlist_list', playlist_list, 'field_map', containers.Map());
fig.UserData = handles;

% Callbacks
template_list.ValueChangedFcn = @(src, event) templateSelectedCallback(fig);
add_to_playlist_btn.ButtonPushedFcn = @(src, event) addToPlaylistCallback(fig);
run_experiment_btn.ButtonPushedFcn = @(src, event) runExperimentCallback(fig);
remove_btn.ButtonPushedFcn = @(src, event) removeFromPlaylistCallback(fig);
move_up_btn.ButtonPushedFcn = @(src, event) moveInPlaylistCallback(fig, 'up');
move_down_btn.ButtonPushedFcn = @(src, event) moveInPlaylistCallback(fig, 'down');
randomize_btn.ButtonPushedFcn = @(src, event) randomizePlaylistCallback(fig);

fprintf('✓ GUI Ready.\n');
end

function templateSelectedCallback(fig)
    handles = fig.UserData;
    delete(handles.param_panel.Children);
    
    selected_idx = find(strcmp(handles.template_list.Items, handles.template_list.Value));
    if isempty(selected_idx), return; end
    
    json_path = handles.template_list.UserData{selected_idx};
    config = jsondecode(fileread(json_path));
    
    handles.template_name_label.Text = config.name;
    if isfield(config, 'description')
        handles.template_desc_label.Text = config.description;
    else
        handles.template_desc_label.Text = '';
    end
    
    field_map = containers.Map();
    y_pos = 1000;
    
    editable_fields = {'n_trials', 'deviant_probability', 'omission_probability', 'standard', 'deviant', 'cue', 'outcome', 'outcomes', 'deviants', 'mismatches', 'timing'};
    
    for i = 1:numel(editable_fields)
        field_name = editable_fields{i};
        if isfield(config, field_name)
            % Section header
            uilabel(handles.param_panel, 'Text', upper(field_name), 'FontWeight', 'bold', 'FontSize', 11, 'Position', [10, y_pos, 400, 22], 'BackgroundColor', [0.95 0.95 0.95]);
            y_pos = y_pos - 30;
            
            field_value = config.(field_name);
            
            % Check if it's a struct or a simple value
            if isstruct(field_value)
                % It's a struct - use the recursive function
                [field_map, y_pos] = gui_helpers.create_ui_from_struct(handles.param_panel, field_value, y_pos, field_name, field_map);
            else
                % It's a simple value - create edit field directly
                uilabel(handles.param_panel, 'Text', field_name, 'Position', [20, y_pos, 150, 22]);
                edit_field = uieditfield(handles.param_panel, 'text', 'Value', num2str(field_value), 'Position', [175, y_pos, 150, 22]);
                field_map(field_name) = edit_field;
                y_pos = y_pos - 27;
            end
            
            y_pos = y_pos - 15;
        end
    end
    
    handles.field_map = field_map;
    fig.UserData = handles;
end

function addToPlaylistCallback(fig)
    handles = fig.UserData;
    instance_name = handles.instance_name_field.Value;
    if isempty(instance_name)
        uialert(fig, 'Please enter an instance name.', 'Error');
        return;
    end
    
    selected_idx = find(strcmp(handles.template_list.Items, handles.template_list.Value));
    if isempty(selected_idx)
        uialert(fig, 'Please select a template first.', 'Error');
        return;
    end
    
    json_path = handles.template_list.UserData{selected_idx};
    config = jsondecode(fileread(json_path));
    config = gui_helpers.update_config_from_fields(config, handles.field_map);
    
    output_dir = 'saved_blocks';
    if ~exist(output_dir, 'dir'), mkdir(output_dir); end
    
    output_path = fullfile(output_dir, [instance_name, '.json']);
    fid = fopen(output_path, 'w');
    fprintf(fid, '%s', jsonencode(config, "PrettyPrint", true));
    fclose(fid);
    
    handles.playlist_list.Items{end+1} = instance_name;
    if isempty(handles.playlist_list.UserData), handles.playlist_list.UserData = {}; end
    handles.playlist_list.UserData{end+1} = output_path;
    
    fprintf('✓ Added to playlist: %s\n', output_path);
end

function runExperimentCallback(fig)
    handles = fig.UserData;
    playlist_files = handles.playlist_list.UserData;
    if isempty(playlist_files)
        uialert(fig, 'Playlist is empty.', 'Cannot Run');
        return;
    end
    
    device_id = 'Dev1';
    for i = 1:numel(playlist_files)
        block_file = playlist_files{i};
        [~, block_name, ~] = fileparts(block_file);
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        out_dir = fullfile('data', [block_name, '_', timestamp]);
        
        fprintf('\n═════ BLOCK %d/%d: %s ═════\n', i, numel(playlist_files), block_name);
        try
            run_experiment(block_file, device_id, out_dir);
        catch e
            uialert(fig, sprintf('Error running %s:\n%s', block_name, e.message), 'Experiment Failed');
            fprintf('! EXPERIMENT HALTED !\n');
            return;
        end
    end
    
    uialert(fig, 'Playlist finished successfully!', 'Complete');
    fprintf('\n✓✓✓ COMPLETE ✓✓✓\n');
end

function removeFromPlaylistCallback(fig)
    handles = fig.UserData;
    selected = handles.playlist_list.Value;
    if isempty(selected), return; end
    idx = find(strcmp(handles.playlist_list.Items, selected));
    handles.playlist_list.Items(idx) = [];
    handles.playlist_list.UserData(idx) = [];
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