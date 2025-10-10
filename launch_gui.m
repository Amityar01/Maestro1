% Maestro/launch_gui.m
function launch_gui()
% LAUNCH_GUI - Main graphical interface for the Maestro experiment system

% --- Create the Main Figure ---
fig = uifigure('Name', 'Maestro Block Runner', 'Position', [100 100 900 700]);

% --- 1. Block Template Library Panel (Left) ---
library_panel = uipanel(fig, 'Title', 'Block Template Library', 'Position', [20 20 250 660]);

load_templates_btn = uibutton(library_panel, 'Position', [10 620 230 30], ...
    'Text', 'Load Template Folder...', 'FontSize', 12, ...
    'ButtonPushedFcn', @load_templates_callback);
    
template_list = uilistbox(library_panel, 'Position', [10 10 230 600], ...
    'Items', {'(Load a folder to see templates)'});

% --- 2. Experiment Sequence Panel (Center) ---
sequence_panel = uipanel(fig, 'Title', 'Experiment Sequence (Playlist)', 'Position', [280 200 300 480]);

sequence_list = uilistbox(sequence_panel, 'Position', [10 50 280 420]);

add_btn = uibutton(sequence_panel, 'Position', [10 10 60 30], 'Text', 'Add', ...
    'ButtonPushedFcn', @add_block_callback); % Connect button to callback
remove_btn = uibutton(sequence_panel, 'Position', [80 10 60 30], 'Text', 'Remove');
copy_btn = uibutton(sequence_panel, 'Position', [150 10 60 30], 'Text', 'Copy');
paste_btn = uibutton(sequence_panel, 'Position', [220 10 60 30], 'Text', 'Paste');


% --- 3. Parameter Editor Panel (Right) ---
editor_panel = uipanel(fig, 'Title', 'Parameter Editor', 'Position', [590 200 300 480]);

% --- 4. Run Control & Metadata Panel (Bottom) ---
run_panel = uipanel(fig, 'Title', 'Session Control', 'Position', [280 20 610 170]);

uilabel(run_panel, 'Position', [10 130 80 22], 'Text', 'Animal ID:');
animal_id_field = uieditfield(run_panel, 'text', 'Position', [100 130 180 22], 'Value', 'Mouse01');

uilabel(run_panel, 'Position', [300 130 100 22], 'Text', 'Penetration ID:');
pen_id_field = uieditfield(run_panel, 'text', 'Position', [410 130 180 22], 'Value', 'p001');

run_sequence_btn = uibutton(run_panel, 'Position', [10 80 285 40], ...
    'Text', 'Run Full Sequence', 'FontSize', 14, 'FontWeight', 'bold');
    
run_selected_btn = uibutton(run_panel, 'Position', [315 80 285 40], ...
    'Text', 'Run Selected Block', 'FontSize', 14);

save_sequence_btn = uibutton(run_panel, 'Position', [10 10 285 30], 'Text', 'Save Sequence As...');
load_sequence_btn = uibutton(run_panel, 'Position', [315 10 285 30], 'Text', 'Load Sequence...');


    % --- Callback Functions ---
    
    function load_templates_callback(~,~)
        folder_path = uigetdir(pwd, 'Select a folder containing block templates');
        if folder_path == 0, return; end
        template_files = dir(fullfile(folder_path, '*.json'));
        if isempty(template_files)
            template_list.Items = {'(No .json templates found)'};
            return;
        end
        template_names = {template_files.name};
        template_list.Items = template_names;
        template_list.Value = template_names{1};
        fprintf('✓ Loaded %d templates from: %s\n', numel(template_names), folder_path);
    end

    % --- NEW CALLBACK FUNCTION ---
    function add_block_callback(~,~)
        % Get the selected template from the library
        selected_template = template_list.Value;
        
        if isempty(selected_template) || startsWith(selected_template, '(')
            % Nothing to add
            return;
        end
        
        % Add the template name to the sequence list
        % We will add a number to make each instance unique
        instance_num = numel(sequence_list.Items) + 1;
        new_item_name = sprintf('%d: %s', instance_num, selected_template);
        
        if instance_num == 1
            sequence_list.Items = {new_item_name};
        else
            sequence_list.Items = [sequence_list.Items, {new_item_name}];
        end
    end

end