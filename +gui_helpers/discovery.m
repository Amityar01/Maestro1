classdef discovery
    % discovery - Contains static methods for finding and loading components.
    methods (Static)
        function [names, files] = find_templates(directory)
            % Finds all template JSON files in a directory.
            names = {};
            files = {};
            json_files = dir(fullfile(directory, '*.json'));
            for i = 1:numel(json_files)
                try
                    json_path = fullfile(directory, json_files(i).name);
                    data = jsondecode(fileread(json_path));
                    if isfield(data, 'template_info') && isfield(data.template_info, 'name')
                        names{end+1} = data.template_info.name;
                        files{end+1} = json_path;
                    end
                catch ME
                    fprintf('Warning: Could not parse template %s. Reason: %s\n', json_files(i).name, ME.message);
                end
            end
        end
        
        function component_map = find_components(package_name)
            % Discovers self-describing components (builders or stimuli)
            % Converts MATLAB package notation to filesystem paths
            component_map = containers.Map();

            % Convert package notation (e.g., 'trials.builders') to filesystem path (e.g., '+trials/+builders')
            package_parts = strsplit(package_name, '.');
            path_parts = cellfun(@(x) ['+' x], package_parts, 'UniformOutput', false);
            package_path = fullfile(path_parts{:});

            % Check if the package directory exists
            if ~exist(package_path, 'dir')
                fprintf('Warning: Could not find package directory "%s" (looking for "%s")\n', package_name, package_path);
                return;
            end

            listing = dir(fullfile(package_path, '*.m'));
            for i = 1:numel(listing)
                [~, name, ~] = fileparts(listing(i).name);
                json_file = fullfile(package_path, [name '.json']);

                if exist(json_file, 'file')
                    try
                        metadata = jsondecode(fileread(json_file));

                        % Create function handle from package name and function name
                        function_string = [package_name '.' name];
                        metadata.function_handle = str2func(function_string);

                        component_map(name) = metadata;
                        fprintf('  ✓ Discovered Component: %s (as %s)\n', name, function_string);
                    catch ME
                        fprintf('Warning: Could not parse component JSON %s. Reason: %s\n', json_file, ME.message);
                    end
                end
            end
        end
    end
end

