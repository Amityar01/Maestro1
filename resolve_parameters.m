% maestro2/resolve_parameters.m
function resolved = resolve_parameters(params)
% RESOLVE_PARAMETERS - Convert parameter specs to actual values
%
% Handles:
%   - Fixed values: params.freq_hz = 4000
%   - Random uniform: params.freq_hz = struct('type', 'random_uniform', 'min', 1000, 'max', 2000)
%   - Random Gaussian: params.level_db = struct('type', 'random_gaussian', 'mean', 60, 'std', 5)

resolved = struct();
fields = fieldnames(params);

for i = 1:length(fields)
    field = fields{i};
    value = params.(field);
    
    % Check if this is a randomization specification struct
    if isstruct(value) && isfield(value, 'type')
        switch value.type
            case 'random_uniform'
                % Pick a random value from a uniform distribution (min to max)
                resolved.(field) = value.min + (value.max - value.min) * rand();
            
            case 'random_gaussian'
                % Pick a random value from a Gaussian (normal) distribution
                resolved.(field) = value.mean + value.std * randn();
            
            otherwise
                error('Unknown parameter randomization type: %s', value.type);
        end
    else
        % It's a fixed value, just copy it
        resolved.(field) = value;
    end
end
end