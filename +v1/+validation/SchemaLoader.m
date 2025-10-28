classdef SchemaLoader < handle
    % SchemaLoader - Loads and caches JSON schemas
    %
    % This class provides efficient loading of JSON schemas with caching
    % and reference resolution.
    %
    % Example:
    %   loader = v1.validation.SchemaLoader('schemas/v1');
    %   schema = loader.load('stimuli/tone.simple.schema.json');

    properties (Access = private)
        base_path       % Base path to schema directory
        schema_cache    % Cache of loaded schemas (containers.Map)
    end

    methods
        function obj = SchemaLoader(base_path)
            % Constructor
            %
            % Args:
            %   base_path: Path to schema directory (e.g., 'schemas/v1')

            if nargin < 1
                error('SchemaLoader:MissingBasePath', 'base_path is required');
            end

            if ~exist(base_path, 'dir')
                error('SchemaLoader:InvalidPath', 'Schema directory does not exist: %s', base_path);
            end

            obj.base_path = base_path;
            obj.schema_cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function schema = load(obj, schema_path)
            % Load a JSON schema
            %
            % Args:
            %   schema_path: Relative path from base_path (e.g., 'core/numeric_field.schema.json')
            %
            % Returns:
            %   schema: Parsed JSON schema struct

            % Check cache first
            if obj.schema_cache.isKey(schema_path)
                schema = obj.schema_cache(schema_path);
                return;
            end

            % Build full path
            full_path = fullfile(obj.base_path, schema_path);

            if ~exist(full_path, 'file')
                error('SchemaLoader:SchemaNotFound', 'Schema file not found: %s', full_path);
            end

            % Load and parse JSON
            try
                json_text = fileread(full_path);
                schema = jsondecode(json_text);
            catch ME
                error('SchemaLoader:ParseError', 'Failed to parse schema %s: %s', schema_path, ME.message);
            end

            % Cache the schema
            obj.schema_cache(schema_path) = schema;
        end

        function schema = load_by_id(obj, schema_id)
            % Load a schema by its $id
            %
            % Args:
            %   schema_id: Schema ID (e.g., 'https://maestro.neuroscience/schemas/v1/core/numeric_field')
            %
            % Returns:
            %   schema: Parsed JSON schema struct

            % Extract path from schema ID
            % Format: https://maestro.neuroscience/schemas/v1/<path>
            prefix = 'https://maestro.neuroscience/schemas/v1/';

            if ~startsWith(schema_id, prefix)
                error('SchemaLoader:InvalidSchemaId', 'Invalid schema ID format: %s', schema_id);
            end

            % Remove prefix and add .schema.json extension
            relative_path = schema_id(length(prefix)+1:end);
            schema_path = [relative_path '.schema.json'];

            schema = obj.load(schema_path);
        end

        function clear_cache(obj)
            % Clear the schema cache
            obj.schema_cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function schemas = get_all_cached(obj)
            % Get all cached schemas
            %
            % Returns:
            %   schemas: Cell array of {path, schema} pairs

            keys_list = keys(obj.schema_cache);
            schemas = cell(length(keys_list), 2);

            for i = 1:length(keys_list)
                key = keys_list{i};
                schemas{i, 1} = key;
                schemas{i, 2} = obj.schema_cache(key);
            end
        end
    end
end
