classdef SchemaRegistry < handle
    % Loads and caches builder parameter schemas from +builders/+<name>/schema.json

    properties (Access=private)
        cache containers.Map
        root  char
    end

    methods
        function obj = SchemaRegistry(maestroRoot)
            if nargin < 1 || isempty(maestroRoot)
                % infer root from where this file lives: <root> / +core / +validation / SchemaRegistry.m
                here = fileparts(mfilename('fullpath'));
                obj.root = fileparts(fileparts(here));
            else
                obj.root = maestroRoot;
            end
            obj.cache = containers.Map('KeyType','char','ValueType','any');
        end

        function schema = get(obj, builder_type)
            bt = char(builder_type);
            if obj.cache.isKey(bt)
                schema = obj.cache(bt); return;
            end
            schemaPath = fullfile(obj.root, '+builders', ['+' bt], 'schema.json');
            if ~isfile(schemaPath)
                error('SchemaRegistry:MissingSchema', ...
                      'No schema.json for builder "%s". Expected at: %s', bt, schemaPath);
            end
            txt = fileread(schemaPath);
            schema = jsondecode(txt);
            obj.cache(bt) = schema;
        end
    end
end
