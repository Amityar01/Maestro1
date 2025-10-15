function [field_map, final_y] = create_ui_from_struct(parent, data, y_pos, field_path, field_map)
% CREATE_UI_FROM_STRUCT - Recursively creates UI elements from a struct.

if nargin < 5
    field_map = containers.Map('KeyType', 'char', 'ValueType', 'any');
end

fields = fieldnames(data);
label_width = 150;
field_width = 150;
height = 22;
spacing = 5;
indent_base = 20;

% Calculate indent level
if isempty(field_path)
    indent_level = 0;
else
    indent_level = length(strfind(field_path, '.'));
end
indent = indent_base + (indent_level * 15);

for i = 1:numel(fields)
    field_name = fields{i};
    current_val = data.(field_name);
    
    % Build the full path
    if isempty(field_path)
        current_path = field_name;
    else
        current_path = [field_path, '.', field_name];
    end
    
    % Create Label
    uilabel(parent, ...
        'Text', field_name, ...
        'Position', [indent, y_pos, label_width, height]);
    
    y_pos = y_pos - (height + spacing);
    
    % Create control based on type
    if isstruct(current_val)
        % Recursively handle nested structs
        [field_map, y_pos] = create_ui_from_struct(...
            parent, current_val, y_pos, current_path, field_map);
        
    elseif isnumeric(current_val) || ischar(current_val) || isstring(current_val)
        % Editable field
        edit_field = uieditfield(parent, 'text', ...
            'Value', num2str(current_val), ...
            'Position', [indent + label_width + 5, y_pos + height + spacing, field_width, height]);
        
        % Store in map
        field_map(current_path) = edit_field;
    end
end

final_y = y_pos;
end