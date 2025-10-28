classdef ScopeManager < handle
    % ScopeManager - Manages sampling scope (per_trial, per_block, per_session)
    %
    % Handles caching of sampled values at different scopes:
    %   - per_trial: Sample once per trial (no caching)
    %   - per_block: Sample once per block (cache for block)
    %   - per_session: Sample once per session (cache for session)
    %
    % Example:
    %   manager = v1.sampling.ScopeManager();
    %   manager.set_context('block', 'block_1');
    %   value = manager.get_or_sample('param_name', 'per_block', @sample_fn);

    properties (Access = private)
        session_cache    % Cache for per_session values
        block_cache      % Cache for per_block values
        current_block_id % Current block identifier
    end

    methods
        function obj = ScopeManager()
            % Constructor
            obj.session_cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.block_cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.current_block_id = '';
        end

        function set_context(obj, context_type, context_id)
            % Set the current context (block or session)
            %
            % Args:
            %   context_type: 'block' or 'session'
            %   context_id: Identifier for this context

            switch context_type
                case 'block'
                    % If block changed, clear block cache
                    if ~strcmp(obj.current_block_id, context_id)
                        obj.current_block_id = context_id;
                        obj.block_cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
                    end

                case 'session'
                    % Clear all caches for new session
                    obj.session_cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
                    obj.block_cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
                    obj.current_block_id = '';

                otherwise
                    error('ScopeManager:InvalidContext', ...
                        'context_type must be "block" or "session"');
            end
        end

        function value = get_or_sample(obj, param_name, scope, sample_fn)
            % Get cached value or sample new one based on scope
            %
            % Args:
            %   param_name: Name of parameter (for cache key)
            %   scope: 'per_trial', 'per_block', or 'per_session'
            %   sample_fn: Function handle that returns sampled value
            %
            % Returns:
            %   value: Sampled or cached value

            switch scope
                case 'per_trial'
                    % Always sample new value
                    value = sample_fn();

                case 'per_block'
                    % Check block cache
                    if obj.block_cache.isKey(param_name)
                        value = obj.block_cache(param_name);
                    else
                        value = sample_fn();
                        obj.block_cache(param_name) = value;
                    end

                case 'per_session'
                    % Check session cache
                    if obj.session_cache.isKey(param_name)
                        value = obj.session_cache(param_name);
                    else
                        value = sample_fn();
                        obj.session_cache(param_name) = value;
                    end

                otherwise
                    error('ScopeManager:InvalidScope', ...
                        'scope must be "per_trial", "per_block", or "per_session"');
            end
        end

        function clear_block_cache(obj)
            % Clear the block cache (e.g., when moving to next block)
            obj.block_cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function clear_all(obj)
            % Clear all caches
            obj.session_cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.block_cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function cached_values = get_cached_values(obj)
            % Get all cached values (for debugging/provenance)
            %
            % Returns:
            %   cached_values: Struct with session_cache and block_cache

            cached_values = struct();

            % Convert session cache to struct
            cached_values.session = struct();
            keys_list = keys(obj.session_cache);
            for i = 1:length(keys_list)
                key = keys_list{i};
                cached_values.session.(key) = obj.session_cache(key);
            end

            % Convert block cache to struct
            cached_values.block = struct();
            keys_list = keys(obj.block_cache);
            for i = 1:length(keys_list)
                key = keys_list{i};
                cached_values.block.(key) = obj.block_cache(key);
            end
        end
    end
end
