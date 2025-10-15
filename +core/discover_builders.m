function builders = discover_builders(base_path)
% DISCOVER_BUILDERS - Find all builder plugins

    builders = containers.Map('KeyType', 'char', 'ValueType', 'any');
    
    if ~exist(base_path, 'dir')
        warning('Maestro:DirectoryNotFound', ...
            'Builders directory not found: %s', base_path);
        return;
    end
    
    % Find all template.schema.json files
    all_schemas = find_schema_files(base_path, 'template.schema.json');
    
    for i = 1:length(all_schemas)
        schema_file = all_schemas{i};
        
        try
            % Load and parse schema
            schema = jsondecode(fileread(schema_file));
            
            % Validate it's a builder schema (handle $schema -> x_schema conversion)
            if isfield(schema, 'x_schema')
                schema_field = schema.x_schema;
            elseif isfield(schema, '$schema')
                schema_field = schema.('$schema');
            else
                continue;
            end
            
            if ~strcmp(schema_field, 'maestro-builder-v1')
                continue;
            end
            
            % Validate required fields
            required_fields = {'builder_type', 'version', 'implementation'};
            missing = {};
            for j = 1:length(required_fields)
                if ~isfield(schema, required_fields{j})
                    missing{end+1} = required_fields{j}; %#ok<AGROW>
                end
            end
            
            if ~isempty(missing)
                warning('Maestro:InvalidSchema', ...
                    'Builder schema missing required fields: %s\nFile: %s', ...
                    strjoin(missing, ', '), schema_file);
                continue;
            end
            
            % Get builder info
            builder_type = schema.builder_type;
            builder_path = fileparts(schema_file);
            
            % Create function handle
            func_name = schema.implementation.function;
            try
                build_func = str2func(func_name);
            catch ME
                warning('Maestro:FunctionNotFound', ...
                    'Cannot create function handle for %s: %s\nFile: %s', ...
                    func_name, ME.message, schema_file);
                continue;
            end
            
            % Store builder info
            builder_info = struct();
            builder_info.schema = schema;
            builder_info.build_func = build_func;
            builder_info.path = builder_path;
            builder_info.schema_file = schema_file;
            
            builders(builder_type) = builder_info;
            
        catch ME
            warning('Maestro:DiscoveryError', ...
                'Error loading builder from %s: %s', ...
                schema_file, ME.message);
        end
    end
end

function schema_files = find_schema_files(base_path, filename)
    % Recursively find all files with given name
    schema_files = {};
    items = dir(base_path);
    
    for i = 1:length(items)
        item = items(i);
        if strcmp(item.name, '.') || strcmp(item.name, '..')
            continue;
        end
        
        full_path = fullfile(base_path, item.name);
        
        if item.isdir
            sub_schemas = find_schema_files(full_path, filename);
            schema_files = [schema_files, sub_schemas]; %#ok<AGROW>
        elseif strcmp(item.name, filename)
            schema_files{end+1} = full_path; %#ok<AGROW>
        end
    end
end