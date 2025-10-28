classdef RNGStreamManager < handle
    % RNGStreamManager - Manages deterministic RNG streams with seed tracking
    %
    % Provides:
    %   - Named RNG streams for different purposes
    %   - Seed tracking for full reproducibility
    %   - Stream isolation (each stream independent)
    %   - Provenance recording
    %
    % Example:
    %   manager = v1.sampling.RNGStreamManager(12345);  % master seed
    %   stream = manager.get_stream('trial_timing');
    %   value = stream.rand();  % Sample from this stream
    %   seeds = manager.get_seed_record();  % Get all seeds used

    properties (Access = private)
        master_seed      % Master seed for reproducibility
        streams          % Map of stream_name -> RandStream
        stream_seeds     % Map of stream_name -> seed used
        next_seed        % Next seed to assign
    end

    methods
        function obj = RNGStreamManager(master_seed)
            % Constructor
            %
            % Args:
            %   master_seed: Master seed for all derived streams

            if nargin < 1
                master_seed = rng('shuffle');  % Random seed if not provided
                master_seed = master_seed.Seed;
            end

            obj.master_seed = master_seed;
            obj.streams = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.stream_seeds = containers.Map('KeyType', 'char', 'ValueType', 'any');

            % Use master seed to generate subsequent seeds
            % This ensures reproducibility from just the master seed
            master_stream = RandStream('mt19937ar', 'Seed', master_seed);
            obj.next_seed = randi(master_stream, [0 2^31-1]);
        end

        function stream = get_stream(obj, stream_name)
            % Get or create a named RNG stream
            %
            % Args:
            %   stream_name: Name for this stream (e.g., 'trial_timing', 'stimulus_params')
            %
            % Returns:
            %   stream: RandStream object for this stream

            % Check if stream already exists
            if obj.streams.isKey(stream_name)
                stream = obj.streams(stream_name);
                return;
            end

            % Create new stream with derived seed
            seed = obj.derive_seed(stream_name);
            stream = RandStream('mt19937ar', 'Seed', seed);

            % Store stream and seed
            obj.streams(stream_name) = stream;
            obj.stream_seeds(stream_name) = seed;
        end

        function seed = derive_seed(obj, stream_name)
            % Derive a seed for a named stream
            %
            % Args:
            %   stream_name: Name of the stream
            %
            % Returns:
            %   seed: Derived seed value

            % Use hash of stream name + master seed to derive unique seed
            % This makes seeds deterministic and reproducible
            hash_input = [stream_name num2str(obj.master_seed)];
            hash_value = sum(double(hash_input));
            seed = mod(hash_value + obj.next_seed, 2^31-1);

            % Update next seed for collision avoidance
            obj.next_seed = mod(obj.next_seed * 1103515245 + 12345, 2^31-1);
        end

        function seed_record = get_seed_record(obj)
            % Get record of all seeds used
            %
            % Returns:
            %   seed_record: Struct with master_seed and stream_seeds

            seed_record = struct();
            seed_record.master_seed = obj.master_seed;
            seed_record.stream_seeds = struct();

            % Convert map to struct
            keys_list = keys(obj.stream_seeds);
            for i = 1:length(keys_list)
                key = keys_list{i};
                seed_record.stream_seeds.(key) = obj.stream_seeds(key);
            end
        end

        function reset_stream(obj, stream_name)
            % Reset a stream to its initial seed
            %
            % Args:
            %   stream_name: Name of stream to reset

            if ~obj.streams.isKey(stream_name)
                error('RNGStreamManager:StreamNotFound', ...
                    'Stream "%s" does not exist', stream_name);
            end

            seed = obj.stream_seeds(stream_name);
            stream = RandStream('mt19937ar', 'Seed', seed);
            obj.streams(stream_name) = stream;
        end

        function clear_all(obj)
            % Clear all streams (but keep master seed)
            obj.streams = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.stream_seeds = containers.Map('KeyType', 'char', 'ValueType', 'any');

            % Reset next_seed
            master_stream = RandStream('mt19937ar', 'Seed', obj.master_seed);
            obj.next_seed = randi(master_stream, [0 2^31-1]);
        end

        function stream_names = get_stream_names(obj)
            % Get list of all stream names
            %
            % Returns:
            %   stream_names: Cell array of stream names

            stream_names = keys(obj.streams);
        end
    end
end
