function stimulus_lib = load_stimulus_library(base_path)
% LOAD_STIMULUS_LIBRARY - Load stimulus library
%
% INPUTS:
%   base_path - string, path to stimuli directory
%
% OUTPUTS:
%   stimulus_lib - containers.Map with:
%                  key: stimulus_id (string)
%                  value: struct, stimulus specification

    stimulus_lib = containers.Map('KeyType', 'char', 'ValueType', 'any');
    
    if ~exist(base_path, 'dir')
        warning('Maestro:DirectoryNotFound', ...
            'Stimuli directory not found: %s', base_path);
        return;
    end
    
    % Look for library.json
    library_file = fullfile(base_path, 'library.json');
    if exist(library_file, 'file')
        try
            library = jsondecode(fileread(library_file));
            
            % Library should be a struct or array of stimuli
            if isstruct(library)
                stim_ids = fieldnames(library);
                for i = 1:length(stim_ids)
                    stim_id = stim_ids{i};
                    stimulus_lib(stim_id) = library.(stim_id);
                end
            end
        catch ME
            warning('Maestro:LoadError', ...
                'Error loading stimulus library: %s', ME.message);
        end
    end
    
    % Also load individual .json files
    json_files = dir(fullfile(base_path, '*.json'));
    for i = 1:length(json_files)
        % Skip library.json
        if strcmp(json_files(i).name, 'library.json')
            continue;
        end
        
        json_file = fullfile(base_path, json_files(i).name);
        
        try
            stim_spec = jsondecode(fileread(json_file));
            
            % Get stimulus_id from filename or spec
            [~, stim_id, ~] = fileparts(json_file);
            if isfield(stim_spec, 'stimulus_id')
                stim_id = stim_spec.stimulus_id;
            end
            
            stimulus_lib(stim_id) = stim_spec;
            
        catch ME
            warning('Maestro:LoadError', ...
                'Error loading stimulus from %s: %s', ...
                json_file, ME.message);
        end
    end
end