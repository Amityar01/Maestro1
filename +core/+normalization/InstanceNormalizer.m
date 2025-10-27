classdef InstanceNormalizer
    % INSTANCENORMALIZER - Handles block instance normalization
    %
    % This class extracts instance normalization logic from RunnerCore
    % to follow the Single Responsibility Principle.
    %
    % Usage:
    %   instance = InstanceNormalizer.normalize(instance);
    %   instance = InstanceNormalizer.ensure_block_instance(spec);

    methods (Static)
        function instance = normalize_block_instance(instance)
            % NORMALIZE_BLOCK_INSTANCE - Ensure instance has required fields
            %
            % INPUTS:
            %   instance - struct or cell, block instance
            %
            % OUTPUTS:
            %   instance - struct, normalized scalar block instance

            % Handle cell arrays (take first element)
            if iscell(instance)
                if isempty(instance)
                    error('InstanceNormalizer:InvalidInstance', ...
                        'block_instance is an empty cell');
                end
                instance = instance{1};
            end

            % Validate it's a struct
            if ~isstruct(instance)
                error('InstanceNormalizer:InvalidInstance', ...
                    'block_instance must be a struct');
            end

            % Ensure scalar (take first if array)
            if numel(instance) ~= 1
                instance = instance(1);
            end

            % Validate required field: builder_type
            if ~isfield(instance, 'builder_type') || isempty(instance.builder_type)
                error('InstanceNormalizer:MissingField', ...
                    'block_instance is missing required field "builder_type"');
            end

            % Ensure instance_id exists
            if ~isfield(instance, 'instance_id') || isempty(instance.instance_id)
                instance.instance_id = char(java.util.UUID.randomUUID());
            end

            % Ensure parameters field exists
            if ~isfield(instance, 'parameters') || ...
                    isempty(instance.parameters) || ...
                    ~isstruct(instance.parameters)
                instance.parameters = struct();
            end
        end

        function instance = ensure_block_instance(spec, context)
            % ENSURE_BLOCK_INSTANCE - Convert spec to block instance
            %
            % Accepts various input formats and returns normalized instance
            %
            % INPUTS:
            %   spec - struct, can be block_instance or builder spec
            %   context - MaestroContext (optional, for builder execution)
            %
            % OUTPUTS:
            %   instance - struct, normalized block instance

            if nargin < 2
                context = [];
            end

            % Case 1: spec contains block_instance field
            if isfield(spec, 'block_instance') && ~isempty(spec.block_instance)
                instance = core.config.ConfigurationManager.coerce_scalar_struct(...
                    spec.block_instance, struct());

                % Inherit builder_type from parent if missing
                if ~isfield(instance, 'builder_type')
                    if isfield(spec, 'builder_type')
                        instance.builder_type = char(spec.builder_type);
                    elseif isfield(spec, 'type')
                        instance.builder_type = char(spec.type);
                    else
                        error('InstanceNormalizer:MissingField', ...
                            'block_instance missing builder_type');
                    end
                end

                instance = core.normalization.InstanceNormalizer.normalize_block_instance(...
                    instance);
                return;
            end

            % Case 2: Direct builder spec - need to execute builder
            if isfield(spec, 'builder_type')
                builder_type = char(spec.builder_type);
            elseif isfield(spec, 'type')
                builder_type = char(spec.type);
            else
                error('InstanceNormalizer:InvalidBlockSpec', ...
                    'Spec missing builder_type/type');
            end

            % Execute builder to get instance
            if isempty(context)
                error('InstanceNormalizer:MissingContext', ...
                    'MaestroContext required to execute builder');
            end

            build_func = str2func(sprintf('builders.%s.build', builder_type));
            try
                instance = build_func(spec);
            catch
                try
                    instance = build_func(spec, context);
                catch ME
                    error('InstanceNormalizer:BuilderError', ...
                        'Failed to execute builder %s: %s', ...
                        builder_type, ME.message);
                end
            end

            % Ensure builder_type is set
            instance = core.config.ConfigurationManager.coerce_scalar_struct(...
                instance, struct());
            if ~isfield(instance, 'builder_type') || isempty(instance.builder_type)
                instance.builder_type = builder_type;
            end

            instance = core.normalization.InstanceNormalizer.normalize_block_instance(...
                instance);
        end

        function instance = load_block_instance_from_file(block_file, maestro_root, context)
            % LOAD_BLOCK_INSTANCE_FROM_FILE - Load instance from JSON file
            %
            % INPUTS:
            %   block_file - string, path to block JSON file
            %   maestro_root - string, root directory for relative path resolution
            %   context - MaestroContext (optional, for builder execution)
            %
            % OUTPUTS:
            %   instance - struct, normalized block instance

            if nargin < 3
                context = [];
            end

            % Resolve file path
            if isstring(block_file) || ischar(block_file)
                file_path = char(block_file);
            else
                error('InstanceNormalizer:InvalidBlockFile', ...
                    'block_file must be a string path');
            end

            % Check if file exists, try library/blocks if not
            if ~isfile(file_path)
                candidate = fullfile(maestro_root, 'library', 'blocks', file_path);
                if isfile(candidate)
                    file_path = candidate;
                else
                    error('InstanceNormalizer:BlockFileNotFound', ...
                        'block_file not found: %s', file_path);
                end
            end

            % Load JSON data
            data = core.config.ConfigurationManager.load_json_file(file_path);

            % Case 1: File contains block_instance field
            if isfield(data, 'block_instance') && ~isempty(data.block_instance)
                instance = core.config.ConfigurationManager.coerce_scalar_struct(...
                    data.block_instance, struct());

                % Inherit builder_type from parent if missing
                if ~isfield(instance, 'builder_type')
                    if isfield(data, 'builder_type')
                        instance.builder_type = char(data.builder_type);
                    elseif isfield(data, 'type')
                        instance.builder_type = char(data.type);
                    end
                end

                instance = core.normalization.InstanceNormalizer.normalize_block_instance(...
                    instance);
            else
                % Case 2: Treat whole file as builder spec
                instance = core.normalization.InstanceNormalizer.ensure_block_instance(...
                    core.config.ConfigurationManager.coerce_scalar_struct(data, struct()), ...
                    context);
            end
        end

        function blocks = normalize_blocks_from_artifact(artifact_data, maestro_root, context)
            % NORMALIZE_BLOCKS_FROM_ARTIFACT - Extract blocks from artifact
            %
            % Handles various artifact formats (single block, sequence, etc.)
            %
            % INPUTS:
            %   artifact_data - struct, loaded artifact data
            %   maestro_root - string, root directory
            %   context - MaestroContext
            %
            % OUTPUTS:
            %   blocks - cell array of normalized block instances

            blocks = {};

            % Determine artifact structure
            if isfield(artifact_data, 'blocks')
                blocks_data = artifact_data.blocks;
            elseif isfield(artifact_data, 'sequence')
                blocks_data = artifact_data.sequence;
            elseif isfield(artifact_data, 'block_instance') || ...
                   isfield(artifact_data, 'builder_type') || ...
                   isfield(artifact_data, 'type')
                % Single block
                blocks = {core.normalization.InstanceNormalizer.ensure_block_instance(...
                    artifact_data, context)};
                return;
            else
                error('InstanceNormalizer:UnknownArtifact', ...
                    'Unrecognized artifact format (no blocks/sequence/block_instance)');
            end

            % Process blocks (handle both cell array and single struct)
            if iscell(blocks_data)
                blocks = cell(1, numel(blocks_data));
                for i = 1:numel(blocks_data)
                    blocks{i} = core.normalization.InstanceNormalizer.normalize_block_entry(...
                        blocks_data{i}, maestro_root, context);
                end
            elseif isstruct(blocks_data)
                blocks = {core.normalization.InstanceNormalizer.normalize_block_entry(...
                    blocks_data, maestro_root, context)};
            else
                error('InstanceNormalizer:InvalidBlocksFormat', ...
                    'blocks/sequence must be struct or cell array');
            end
        end
    end

    methods (Static, Access = private)
        function instance = normalize_block_entry(entry, maestro_root, context)
            % NORMALIZE_BLOCK_ENTRY - Convert a single block entry to instance
            %
            % Handles block_file, block_instance, or direct builder spec

            entry = core.config.ConfigurationManager.coerce_scalar_struct(...
                entry, struct());

            % Case 1: Entry references a file
            if isfield(entry, 'block_file') && ~isempty(entry.block_file)
                instance = core.normalization.InstanceNormalizer.load_block_instance_from_file(...
                    entry.block_file, maestro_root, context);
                return;
            end

            % Case 2: Entry contains block_instance or direct spec
            instance = core.normalization.InstanceNormalizer.ensure_block_instance(...
                entry, context);
        end
    end
end
