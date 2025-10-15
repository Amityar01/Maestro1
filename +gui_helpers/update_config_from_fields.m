function updated_config = update_config_from_fields(original_config, field_map)
% UPDATE_CONFIG_FROM_FIELDS - Safely update config from UI fields

updated_config = original_config;
paths = keys(field_map);

for i = 1:length(paths)
    path = paths{i};
    edit_field = field_map(path);
    value_str = edit_field.Value;
    
    % Convert to number if possible
    value_num = str2double(value_str);
    if ~isnan(value_num)
        new_value = value_num;
    else
        new_value = value_str;
    end
    
    % Safe nested field assignment
    updated_config = set_nested_field(updated_config, path, new_value);
end
end

function s = set_nested_field(s, path, value)
% Set nested field using subsasgn
parts = strsplit(path, '.');

subs = struct('type', '.', 'subs', parts{1});
for i = 2:length(parts)
    subs(i) = struct('type', '.', 'subs', parts{i});
end

s = subsasgn(s, subs, value);
end