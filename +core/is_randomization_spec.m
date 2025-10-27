function result = is_randomization_spec(value)
% IS_RANDOMIZATION_SPEC - Check if value is a randomization specification
%
% INPUTS:
%   value - any type
%
% OUTPUTS:
%   result - boolean, true if value is a randomization spec

    result = false;
    
    % Must be a struct
    if ~isstruct(value)
        return;
    end
    
    % Must have 'type' field
    if ~isfield(value, 'type')
        return;
    end
    
    % Type must be a randomization type
    valid_types = {'random_uniform', 'random_gaussian', 'random_choice'};
    if ismember(value.type, valid_types)
        result = true;
    end
end