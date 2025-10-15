function generators = discover_generators(base_path)
% DISCOVER_GENERATORS - Find all generator plugins
%
% INPUTS:
%   base_path - string, path to +generators directory
%
% OUTPUTS:
%   generators - containers.Map with generator info

    generators = containers.Map('KeyType', 'char', 'ValueType', 'any');
    
    if ~exist(base_path, 'dir')
        warning('Maestro:DirectoryNotFound', ...
            'Generators directory not found: %s', base_path);
        return;
    end
    
    % Find all subdirectories recursively
    all_schemas = find_schema_files(base_path, 'schema.json');
    
    for i = 1:length(all_schemas)
        schema_file = all_schemas{i};
        
        try
            % Load and parse schema
            schema = jsondecode(fileread(schema_file));
            
            % Validate it's a generator schema
            % Note: jsondecode converts $schema to x_schema
            if isfield(schema, 'x_schema')
                schema_field = schema.x_schema;
            elseif isfield(schema, '$schema')
                schema_field = schema.('$schema');
            else
                continue;  % No schema field found
            end
            
            if ~strcmp(schema_field, 'maestro-generator-v1')
                continue;  % Not a generator schema
            end
            
            % Validate required fields
            required_fields = {'generator_type', 'version', 'implementation'};
            missing = {};
            for j = 1:length(required_fields)
                if ~isfield(schema, required_fields{j})
                    missing{end+1} = required_fields{j}; %#ok<AGROW>
                end
            end
            
            if ~isempty(missing)
                warning('Maestro:InvalidSchema', ...
                    'Schema missing required fields: %s\nFile: %s', ...
                    strjoin(missing, ', '), schema_file);
                continue;
            end
            
            % Get generator info
            gen_type = schema.generator_type;
            gen_path = fileparts(schema_file);
            
            % Create function handle
            func_name = schema.implementation.function;
            try
                gen_func = str2func(func_name);
            catch ME
                warning('Maestro:FunctionNotFound', ...
                    'Cannot create function handle for %s: %s\nFile: %s', ...
                    func_name, ME.message, schema_file);
                continue;
            end
            
            % Store generator info
            gen_info = struct();
            gen_info.schema = schema;
            gen_info.generate_func = gen_func;
            gen_info.path = gen_path;
            gen_info.schema_file = schema_file;
            
            generators(gen_type) = gen_info;
            
        catch ME
            warning('Maestro:DiscoveryError', ...
                'Error loading generator from %s: %s', ...
                schema_file, ME.message);
        end
    end
end

function schema_files = find_schema_files(base_path, filename)
    % Recursively find all files with given name
    
    schema_files = {};
    
    % Get all items in directory
    items = dir(base_path);
    
    for i = 1:length(items)
        item = items(i);
        
        % Skip . and ..
        if strcmp(item.name, '.') || strcmp(item.name, '..')
            continue;
        end
        
        full_path = fullfile(base_path, item.name);
        
        if item.isdir
            % Recursively search subdirectory
            sub_schemas = find_schema_files(full_path, filename);
            schema_files = [schema_files, sub_schemas]; %#ok<AGROW>
        elseif strcmp(item.name, filename)
            % Found a schema file
            schema_files{end+1} = full_path; %#ok<AGROW>
        end
    end
end