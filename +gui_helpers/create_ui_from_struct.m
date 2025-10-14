% Maestro/+gui_helpers/create_ui_from_struct.m
function create_ui_from_struct(parent, data, y_pos, field_path)
% CREATE_UI_FROM_STRUCT - Recursively creates UI elements from a struct.
%
% This function traverses a struct and generates labels and edit fields
% for each parameter, arranging them vertically within a parent panel.

fields = fieldnames(data);
width = 200;
height = 22;
spacing = 5;

for i = 1:numel(fields)
    field_name = fields{i};
    current_val = data.(field_name);
    current_path = [field_path, '.', field_name];

    % --- Create the Label for the parameter name ---
    uilabel(parent, ...
        'Text', field_name, ...
        'Position', [20, y_pos, width, height]);

    % --- Create the appropriate control based on data type ---
    if isstruct(current_val)
        % If the value is another struct, recurse into it
        y_pos = y_pos - (height + spacing);
        create_ui_from_struct(parent, current_val, y_pos, current_path);
    elseif isnumeric(current_val) || ischar(current_val)
        % For numbers or strings, create an editable field
        ui_edit = uieditfield(parent, 'text', ...
            'Value', num2str(current_val), ...
            'Position', [160, y_pos, width, height]);
        
        % Store the full path to this parameter in the component's UserData
        % e.g., 'standard.audio.params.freq_hz'
        ui_edit.UserData = struct('path', current_path);
    end
    
    y_pos = y_pos - (height + spacing);
end

end