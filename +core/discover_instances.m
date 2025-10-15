function instances = discover_instances(base_path)
% DISCOVER_INSTANCES - Find all saved block instances
%
% INPUTS:
%   base_path - string, path to instances directory
%
% OUTPUTS:
%   instances - containers.Map with:
%               key: instance_id (string)
%               value: struct, parsed instance specification

    instances = containers.Map('KeyType', 'char', 'ValueType', 'any');
    
    if ~exist(base_path, 'dir')
        warning('Maestro:DirectoryNotFound', ...
            'Instances directory not found: %s', base_path);
        return;
    end
    
    % Find all .json files
    json_files = dir(fullfile(base_path, '*.json'));
    
    for i = 1:length(json_files)
        json_file = fullfile(base_path, json_files(i).name);
        
        try
            % Load and parse instance
            instance = jsondecode(fileread(json_file));
            
            % Check if it's a valid instance
            if ~isfield(instance, 'instance_id') || ...
               ~isfield(instance, 'builder_type') || ...
               ~isfield(instance, 'parameters')
                warning('Maestro:InvalidInstance', ...
                    'File does not appear to be a valid instance: %s', json_file);
                continue;
            end
            
            % Store by instance_id
            instance_id = instance.instance_id;
            instances(instance_id) = instance;
            
        catch ME
            warning('Maestro:LoadError', ...
                'Error loading instance from %s: %s', ...
                json_file, ME.message);
        end
    end
end