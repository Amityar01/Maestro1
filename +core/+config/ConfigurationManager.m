classdef ConfigurationManager
    % CONFIGURATIONMANAGER - Handles configuration loading and merging
    %
    % This class extracts configuration management logic from RunnerCore
    % to follow the Single Responsibility Principle.
    %
    % Usage:
    %   config = ConfigurationManager.load_experiment_config(file_path);
    %   merged = ConfigurationManager.merge_configs(base, override);

    methods (Static)
        function config = load_json_file(file_path)
            % LOAD_JSON_FILE - Load and parse a JSON configuration file
            %
            % INPUTS:
            %   file_path - string, path to JSON file
            %
            % OUTPUTS:
            %   config - struct, parsed configuration

            if ~isfile(file_path)
                error('ConfigurationManager:FileNotFound', ...
                    'Configuration file not found: %s', file_path);
            end

            try
                json_text = fileread(file_path);
                config = jsondecode(json_text);
            catch ME
                error('ConfigurationManager:ParseError', ...
                    'Failed to parse JSON file %s: %s', ...
                    file_path, ME.message);
            end
        end

        function save_json_file(file_path, data)
            % SAVE_JSON_FILE - Save data as JSON file
            %
            % INPUTS:
            %   file_path - string, output file path
            %   data - struct, data to save

            try
                json_text = jsonencode(data);
                fid = fopen(file_path, 'w');
                if fid == -1
                    error('ConfigurationManager:IO', ...
                        'Cannot write to file: %s', file_path);
                end
                fprintf(fid, '%s', json_text);
                fclose(fid);
            catch ME
                error('ConfigurationManager:WriteError', ...
                    'Failed to write JSON file %s: %s', ...
                    file_path, ME.message);
            end
        end

        function dest = merge_structs(dest, src)
            % MERGE_STRUCTS - Merge source struct into destination struct
            %
            % Fields from src override fields in dest
            %
            % INPUTS:
            %   dest - struct, destination (will be modified)
            %   src - struct, source (values to merge in)
            %
            % OUTPUTS:
            %   dest - struct, merged result

            % Validate inputs
            if ~isstruct(dest) || numel(dest) ~= 1
                dest = struct();
            end
            if ~isstruct(src) || numel(src) ~= 1
                return;
            end

            % Merge all fields from src into dest
            field_names = fieldnames(src);
            for i = 1:numel(field_names)
                field = field_names{i};
                dest.(field) = src.(field);
            end
        end

        function result = coerce_scalar_struct(value, default_value)
            % COERCE_SCALAR_STRUCT - Ensure value is a scalar struct
            %
            % Handles MATLAB's tendency to return struct arrays or cells
            %
            % INPUTS:
            %   value - any type
            %   default_value - struct, default if value is invalid
            %
            % OUTPUTS:
            %   result - scalar struct

            if nargin < 2
                default_value = struct();
            end

            % Handle empty
            if isempty(value)
                result = default_value;
                return;
            end

            % Handle struct
            if isstruct(value)
                result = value(min(1, end));
                return;
            end

            % Handle cell containing struct
            if iscell(value) && ~isempty(value) && isstruct(value{1})
                result = value{1};
                return;
            end

            % Default
            result = default_value;
        end

        function value = get_field_or_default(structure, field_name, default_value)
            % GET_FIELD_OR_DEFAULT - Get field value or return default
            %
            % INPUTS:
            %   structure - struct
            %   field_name - string, field name
            %   default_value - any, default if field missing or empty
            %
            % OUTPUTS:
            %   value - field value or default

            if isfield(structure, field_name) && ~isempty(structure.(field_name))
                value = structure.(field_name);
            else
                value = default_value;
            end
        end

        function validate_required_field(structure, field_name, context_name)
            % VALIDATE_REQUIRED_FIELD - Ensure required field exists
            %
            % Throws error if field is missing or empty
            %
            % INPUTS:
            %   structure - struct
            %   field_name - string, required field name
            %   context_name - string, context for error message

            if ~isfield(structure, field_name) || isempty(structure.(field_name))
                error('ConfigurationManager:MissingField', ...
                    'Missing required field "%s" in %s', ...
                    field_name, context_name);
            end
        end

        function config = normalize_engine_config(global_settings, override_config)
            % NORMALIZE_ENGINE_CONFIG - Extract and merge engine configuration
            %
            % INPUTS:
            %   global_settings - struct, experiment global settings
            %   override_config - struct, additional config to merge
            %
            % OUTPUTS:
            %   config - struct, normalized engine configuration

            config = core.config.ConfigurationManager.coerce_scalar_struct(...
                override_config, struct());

            % Merge engine config from global settings
            if isfield(global_settings, 'engine_config') && ...
                    ~isempty(global_settings.engine_config)
                engine_config = core.config.ConfigurationManager.coerce_scalar_struct(...
                    global_settings.engine_config, struct());
                config = core.config.ConfigurationManager.merge_structs(...
                    config, engine_config);
            end

            % Merge sampling rate from global settings if not in config
            if isfield(global_settings, 'sampling_rate_hz') && ...
                    ~isfield(config, 'sampling_rate_hz')
                config.sampling_rate_hz = global_settings.sampling_rate_hz;
            end
        end

        function metadata = create_session_metadata(run_config)
            % CREATE_SESSION_METADATA - Create standardized session metadata
            %
            % INPUTS:
            %   run_config - struct, runtime configuration
            %
            % OUTPUTS:
            %   metadata - struct, session metadata

            % Validate required fields
            core.config.ConfigurationManager.validate_required_field(...
                run_config, 'subject', 'run_config');

            % Build metadata with defaults
            metadata = struct();
            metadata.subject = char(run_config.subject);
            metadata.session_num = core.config.ConfigurationManager.get_field_or_default(...
                run_config, 'session_num', 1);
            metadata.experimenter = char(core.config.ConfigurationManager.get_field_or_default(...
                run_config, 'experimenter', ''));
            metadata.notes = char(core.config.ConfigurationManager.get_field_or_default(...
                run_config, 'notes', ''));
            metadata.started_at = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
            metadata.random_seed = randi(2^31-1);
            rng(metadata.random_seed);
            metadata.engine_id = char(core.config.ConfigurationManager.get_field_or_default(...
                run_config, 'engine_id', 'audio_only'));
            metadata.logging_level = char(core.config.ConfigurationManager.get_field_or_default(...
                run_config, 'logging_level', 'full'));

            % Add version information
            metadata.versions = struct();
            metadata.versions.matlab = version;
            metadata.versions.matlab_release = version('-release');
        end
    end
end
