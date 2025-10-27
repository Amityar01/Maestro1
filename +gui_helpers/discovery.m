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
            % using MATLAB's robust 'what()' function to handle packages.
            component_map = containers.Map();
            
            % Use 'what' to get the actual path to the package
            package_info = what(package_name);
            if isempty(package_info)
                fprintf('Warning: Could not find package "%s". Is it on the MATLAB path?\n', package_name);
                return;
            end
            
            package_path = package_info(1).path;
            
            listing = dir(fullfile(package_path, '*.m'));
            for i = 1:numel(listing)
                [~, name, ~] = fileparts(listing(i).name);
                json_file = fullfile(package_path, [name '.json']);
                
                if exist(json_file, 'file')
                    try
                        metadata = jsondecode(fileread(json_file));
                        
                        % --- FIX: Sanitize package name for str2func ---
                        % Convert file path style (+folder/sub) to package style (folder.sub)
                        clean_package_name = strrep(package_name, '+', '');
                        clean_package_name = strrep(clean_package_name, '/', '.');
                        clean_package_name = strrep(clean_package_name, '\', '.');
                        
                        function_string = [clean_package_name '.' name];
                        metadata.function_handle = str2func(function_string);
                        
                        component_map(name) = metadata;
                        fprintf('  ✓ Discovered Component: %s\n', name);
                    catch ME
                        fprintf('Warning: Could not parse component JSON %s. Reason: %s\n', json_file, ME.message);
                    end
                end
            end
        end
    end
end

