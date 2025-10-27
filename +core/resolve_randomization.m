function resolved_params = resolve_randomization(params, context)
% RESOLVE_RANDOMIZATION - Convert randomization specs to concrete values
%
% INPUTS:
%   params  - struct, parameters (may contain randomization specs)
%   context - struct, must contain .rng_seed (optional)
%
% OUTPUTS:
%   resolved_params - struct, all randomization resolved to concrete values

    resolved_params = params;
    
    % Set random seed if provided
    if isfield(context, 'rng_seed') && ~isempty(context.rng_seed)
        rng(context.rng_seed);
    end
    
    % Resolve each parameter
    param_names = fieldnames(params);
    for i = 1:length(param_names)
        param_name = param_names{i};
        param_value = params.(param_name);
        
        if core.is_randomization_spec(param_value)
            % Resolve randomization
            resolved_params.(param_name) = resolve_single_randomization(param_value);
        end
    end
end

function value = resolve_single_randomization(spec)
    % Resolve a single randomization specification
    
    switch spec.type
        case 'random_uniform'
            value = spec.min + (spec.max - spec.min) * rand();
            
        case 'random_gaussian'
            value = spec.mean + spec.std * randn();
            
            % Apply clipping if specified
            if isfield(spec, 'clip_min')
                value = max(value, spec.clip_min);
            end
            if isfield(spec, 'clip_max')
                value = min(value, spec.clip_max);
            end
            
        case 'random_choice'
            if isfield(spec, 'weights')
                % Weighted choice
                weights = spec.weights / sum(spec.weights);  % Normalize
                cumsum_weights = cumsum(weights);
                r = rand();
                idx = find(r <= cumsum_weights, 1, 'first');
            else
                % Uniform choice
                idx = randi(length(spec.options));
            end
            value = spec.options{idx};
            
        otherwise
            error('Unknown randomization type: %s', spec.type);
    end
end