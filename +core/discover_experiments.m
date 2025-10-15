function experiments = discover_experiments(base_path)
% DISCOVER_EXPERIMENTS - Find all saved experiments
%
% INPUTS:
%   base_path - string, path to experiments directory
%
% OUTPUTS:
%   experiments - containers.Map with:
%                 key: experiment_id (string)
%                 value: struct, parsed experiment specification

    experiments = containers.Map('KeyType', 'char', 'ValueType', 'any');
    
    if ~exist(base_path, 'dir')
        warning('Maestro:DirectoryNotFound', ...
            'Experiments directory not found: %s', base_path);
        return;
    end
    
    % Find all .json files
    json_files = dir(fullfile(base_path, '*.json'));
    
    for i = 1:length(json_files)
        json_file = fullfile(base_path, json_files(i).name);
        
        try
            % Load and parse experiment
            experiment = jsondecode(fileread(json_file));
            
            % Check if it's a valid experiment
            if ~isfield(experiment, 'experiment_id') || ...
               ~isfield(experiment, 'global_settings') || ...
               ~isfield(experiment, 'sequence')
                warning('Maestro:InvalidExperiment', ...
                    'File does not appear to be a valid experiment: %s', json_file);
                continue;
            end
            
            % Store by experiment_id
            experiment_id = experiment.experiment_id;
            experiments(experiment_id) = experiment;
            
        catch ME
            warning('Maestro:LoadError', ...
                'Error loading experiment from %s: %s', ...
                json_file, ME.message);
        end
    end
end