function [is_valid, errors] = validate_experiment(experiment, context)
% VALIDATE_EXPERIMENT - Validate complete experiment specification
%
% INPUTS:
%   experiment - struct, experiment specification
%   context    - MaestroContext object
%
% OUTPUTS:
%   is_valid - boolean
%   errors   - cell array of error messages

    errors = {};
    
    % Check required fields
    required = {'experiment_id', 'global_settings', 'sequence'};
    for i = 1:length(required)
        if ~isfield(experiment, required{i})
            errors{end+1} = sprintf('Experiment missing field: %s', required{i});
        end
    end
    
    if ~isempty(errors)
        is_valid = false;
        return;
    end
    
    % Validate global settings
    gs = experiment.global_settings;
    if ~isfield(gs, 'engine_type')
        errors{end+1} = 'global_settings missing engine_type';
    end
    if ~isfield(gs, 'sampling_rate_hz')
        errors{end+1} = 'global_settings missing sampling_rate_hz';
    end
    
    % Check engine exists
    if isfield(gs, 'engine_type')
        if ~isKey(context.engines, gs.engine_type)
            errors{end+1} = sprintf('Unknown engine type: %s', gs.engine_type);
        end
    end
    
    % Validate sequence
    if isempty(experiment.sequence)
        errors{end+1} = 'Experiment sequence is empty';
    end
    
    for i = 1:length(experiment.sequence)
        block = experiment.sequence(i);
        
        if ~isfield(block, 'block_instance')
            errors{end+1} = sprintf('Sequence block %d missing block_instance', i);
        end
    end
    
    is_valid = isempty(errors);
end