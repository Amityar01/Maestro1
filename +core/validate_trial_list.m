function [is_valid, errors] = validate_trial_list(trial_list, builder_schema)
% VALIDATE_TRIAL_LIST - Validate trial list structure
%
% INPUTS:
%   trial_list     - array of trial structs
%   builder_schema - struct, builder schema (for reference)
%
% OUTPUTS:
%   is_valid - boolean
%   errors   - cell array of error messages

    errors = {};
    
    % Must be struct array
    if ~isstruct(trial_list)
        errors{end+1} = 'Trial list must be struct array';
        is_valid = false;
        return;
    end
    
    % Each trial must have required fields
    required_fields = {'trial_id', 'trial_num', 'trial_type', ...
                      'presentations', 'iti_sec', 'metadata'};
    
    for t = 1:length(trial_list)
        trial = trial_list(t);
        
        % Check required fields
        for i = 1:length(required_fields)
            if ~isfield(trial, required_fields{i})
                errors{end+1} = sprintf('Trial %d missing field: %s', ...
                    t, required_fields{i});
            end
        end
        
        % trial_num must match index
        if isfield(trial, 'trial_num') && trial.trial_num ~= t
            errors{end+1} = sprintf('Trial %d has incorrect trial_num: %d', ...
                t, trial.trial_num);
        end
        
        % presentations must be non-empty struct array
        if ~isfield(trial, 'presentations') || isempty(trial.presentations)
            errors{end+1} = sprintf('Trial %d has no presentations', t);
            continue;
        end
        
        % Validate each presentation
        for p = 1:length(trial.presentations)
            pres = trial.presentations(p);
            
            % Must have required fields
            pres_required = {'presentation_id', 'stimulus_spec', 'onset_ms'};
            for i = 1:length(pres_required)
                if ~isfield(pres, pres_required{i})
                    errors{end+1} = sprintf('Trial %d presentation %d missing: %s', ...
                        t, p, pres_required{i});
                end
            end
            
            % onset_ms must be non-negative
            if isfield(pres, 'onset_ms') && pres.onset_ms < 0
                errors{end+1} = sprintf('Trial %d presentation %d has negative onset', t, p);
            end
        end
        
        % Presentations should be ordered by onset
        if length(trial.presentations) > 1
            for p = 2:length(trial.presentations)
                if trial.presentations(p).onset_ms < trial.presentations(p-1).onset_ms
                    errors{end+1} = sprintf('Trial %d presentations not ordered by onset', t);
                    break;
                end
            end
        end
        
        % iti_sec must be non-negative
        if isfield(trial, 'iti_sec') && trial.iti_sec < 0
            errors{end+1} = sprintf('Trial %d has negative ITI', t);
        end
    end
    
    is_valid = isempty(errors);
end