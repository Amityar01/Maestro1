classdef PluginDiscovery
    % PLUGINDISCOVERY - Unified plugin discovery system
    %
    % This class consolidates discovery logic for all plugin types
    % (generators, builders, engines) into a single, well-tested implementation.
    %
    % Usage:
    %   generators = PluginDiscovery.discover_generators(path);
    %   builders = PluginDiscovery.discover_builders(path);
    %   engines = PluginDiscovery.discover_engines(path);

    methods (Static)
        function plugins = discover_generators(base_path)
            % DISCOVER_GENERATORS - Find all generator plugins
            %
            % INPUTS:
            %   base_path - string, path to +generators directory
            %
            % OUTPUTS:
            %   plugins - containers.Map with generator info

            config = struct();
            config.plugin_type = 'generator';
            config.schema_filename = 'schema.json';
            config.schema_type = 'maestro-generator-v1';
            config.required_fields = {'generator_type', 'version', 'implementation'};
            config.type_field = 'generator_type';
            config.func_field = 'generate_func';

            plugins = core.discovery.PluginDiscovery.discover_plugins(...
                base_path, config);
        end

        function plugins = discover_builders(base_path)
            % DISCOVER_BUILDERS - Find all builder plugins
            %
            % INPUTS:
            %   base_path - string, path to +builders directory
            %
            % OUTPUTS:
            %   plugins - containers.Map with builder info

            config = struct();
            config.plugin_type = 'builder';
            config.schema_filename = 'template.schema.json';
            config.schema_type = 'maestro-builder-v1';
            config.required_fields = {'builder_type', 'version', 'implementation'};
            config.type_field = 'builder_type';
            config.func_field = 'build_func';

            plugins = core.discovery.PluginDiscovery.discover_plugins(...
                base_path, config);
        end

        function plugins = discover_engines(base_path)
            % DISCOVER_ENGINES - Find all execution engine plugins
            %
            % INPUTS:
            %   base_path - string, path to +engines directory
            %
            % OUTPUTS:
            %   plugins - containers.Map with engine info

            config = struct();
            config.plugin_type = 'engine';
            config.schema_filename = 'schema.json';
            config.schema_type = 'maestro-engine-v1';
            config.required_fields = {'engine_type', 'version', 'implementation'};
            config.type_field = 'engine_type';
            config.func_field = 'execute_func';

            plugins = core.discovery.PluginDiscovery.discover_plugins(...
                base_path, config);
        end
    end

    methods (Static, Access = private)
        function plugins = discover_plugins(base_path, config)
            % DISCOVER_PLUGINS - Unified plugin discovery implementation
            %
            % INPUTS:
            %   base_path - string, path to plugin directory
            %   config - struct with discovery configuration:
            %            .plugin_type - 'generator', 'builder', or 'engine'
            %            .schema_filename - name of schema file to find
            %            .schema_type - expected schema type (e.g., 'maestro-generator-v1')
            %            .required_fields - cell array of required schema fields
            %            .type_field - field name for plugin type
            %            .func_field - field name for function handle in output

            plugins = containers.Map('KeyType', 'char', 'ValueType', 'any');

            % Validate base path exists
            if ~exist(base_path, 'dir')
                warning('Maestro:DirectoryNotFound', ...
                    '%s directory not found: %s', ...
                    config.plugin_type, base_path);
                return;
            end

            % Find all schema files recursively
            all_schemas = core.discovery.PluginDiscovery.find_schema_files(...
                base_path, config.schema_filename);

            % Process each schema file
            for i = 1:length(all_schemas)
                schema_file = all_schemas{i};

                try
                    % Load and validate schema
                    schema = jsondecode(fileread(schema_file));

                    % Validate schema type (handle $schema -> x_schema conversion)
                    if ~core.discovery.PluginDiscovery.validate_schema_type(...
                            schema, config.schema_type)
                        continue;
                    end

                    % Validate required fields
                    missing = core.discovery.PluginDiscovery.check_required_fields(...
                        schema, config.required_fields);

                    if ~isempty(missing)
                        warning('Maestro:InvalidSchema', ...
                            '%s schema missing required fields: %s\nFile: %s', ...
                            config.plugin_type, strjoin(missing, ', '), schema_file);
                        continue;
                    end

                    % Get plugin type identifier
                    plugin_type = schema.(config.type_field);
                    plugin_path = fileparts(schema_file);

                    % Create function handle
                    func_name = schema.implementation.function;
                    try
                        func_handle = str2func(func_name);
                    catch ME
                        warning('Maestro:FunctionNotFound', ...
                            'Cannot create function handle for %s: %s\nFile: %s', ...
                            func_name, ME.message, schema_file);
                        continue;
                    end

                    % Store plugin info
                    plugin_info = struct();
                    plugin_info.schema = schema;
                    plugin_info.(config.func_field) = func_handle;
                    plugin_info.path = plugin_path;
                    plugin_info.schema_file = schema_file;

                    plugins(plugin_type) = plugin_info;

                catch ME
                    warning('Maestro:DiscoveryError', ...
                        'Error loading %s from %s: %s', ...
                        config.plugin_type, schema_file, ME.message);
                end
            end
        end

        function schema_files = find_schema_files(base_path, filename)
            % FIND_SCHEMA_FILES - Recursively find all files with given name
            %
            % INPUTS:
            %   base_path - string, directory to search
            %   filename - string, name of file to find
            %
            % OUTPUTS:
            %   schema_files - cell array of full paths to found files

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
                    sub_schemas = core.discovery.PluginDiscovery.find_schema_files(...
                        full_path, filename);
                    schema_files = [schema_files, sub_schemas]; %#ok<AGROW>
                elseif strcmp(item.name, filename)
                    % Found a schema file
                    schema_files{end+1} = full_path; %#ok<AGROW>
                end
            end
        end

        function is_valid = validate_schema_type(schema, expected_type)
            % VALIDATE_SCHEMA_TYPE - Check if schema matches expected type
            %
            % Handles MATLAB's JSON decode behavior where $schema becomes x_schema

            schema_field = '';

            if isfield(schema, 'x_schema')
                schema_field = schema.x_schema;
            elseif isfield(schema, '$schema')
                schema_field = schema.('$schema');
            end

            is_valid = strcmp(schema_field, expected_type);
        end

        function missing = check_required_fields(schema, required_fields)
            % CHECK_REQUIRED_FIELDS - Identify missing required fields
            %
            % INPUTS:
            %   schema - struct, parsed schema
            %   required_fields - cell array of field names
            %
            % OUTPUTS:
            %   missing - cell array of missing field names

            missing = {};
            for i = 1:length(required_fields)
                field = required_fields{i};
                if ~isfield(schema, field)
                    missing{end+1} = field; %#ok<AGROW>
                end
            end
        end
    end
end
