classdef config
    % Central configuration for Maestro

    properties (Constant)
        % Directory paths (relative to Maestro root)
        BLOCKS_DIR = fullfile('library', 'blocks')
        SEQUENCES_DIR = fullfile('library', 'sequences')
        SESSIONS_DIR = 'sessions'
        GENERATORS_DIR = '+generators'
        BUILDERS_DIR = '+builders'
        ENGINES_DIR = '+engines'

        % File patterns
        BLOCK_EXTENSION = '.json'
        SEQUENCE_EXTENSION = '.json'
        SCHEMA_FILENAME = 'schema.json'
        BUILDER_SCHEMA_FILENAME = 'template.schema.json'

        % Defaults
        DEFAULT_SAMPLING_RATE = 192000
        DEFAULT_ENGINE = 'audio_only'

        % Schema version
        BLOCK_FORMAT_VERSION = '1.0.0' % Added for block files
        SEQUENCE_FORMAT_VERSION = '1.0.0' % Added for sequence files
    end

    methods (Static)
        function path = get_block_path(block_filename)
            % Get full path to a block file or the block directory
            % INPUTS:
            %   block_filename (optional) - Name of the block file (e.g., 'my_block.json')
            % OUTPUTS:
            %   path - Full path to the file, or path to the directory if no filename given

            if nargin < 1 || isempty(block_filename)
                % Return the directory path if no filename is provided
                path = core.config.BLOCKS_DIR;
            else
                 % Return the full file path if filename is provided
                 path = fullfile(core.config.BLOCKS_DIR, block_filename);
            end
        end

        function path = get_sequence_path(sequence_filename)
            % Get full path to a sequence file or the sequence directory
             % INPUTS:
            %   sequence_filename (optional) - Name of the sequence file (e.g., 'my_seq.json')
            % OUTPUTS:
            %   path - Full path to the file, or path to the directory if no filename given

            if nargin < 1 || isempty(sequence_filename)
                 % Return the directory path if no filename is provided
                path = core.config.SEQUENCES_DIR;
            else
                % Return the full file path if filename is provided
                path = fullfile(core.config.SEQUENCES_DIR, sequence_filename);
             end
        end

        function path = get_session_dir(session_id)
            % Get path to a session directory or the main sessions directory
             % INPUTS:
            %   session_id (optional) - ID of the specific session
            % OUTPUTS:
            %   path - Full path to the session dir, or path to the parent dir if no ID given

            if nargin < 1 || isempty(session_id)
                 path = core.config.SESSIONS_DIR; % Return parent directory
            else
                path = fullfile(core.config.SESSIONS_DIR, session_id); % Return specific session dir
            end
        end

        % --- Functions returning only directory paths ---
        function path = get_generator_dir()
             path = core.config.GENERATORS_DIR;
        end
         function path = get_builder_dir()
             path = core.config.BUILDERS_DIR;
        end
         function path = get_engine_dir()
             path = core.config.ENGINES_DIR;
        end
    end
end