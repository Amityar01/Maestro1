classdef Constants
    % CONSTANTS - Centralized constants for Maestro system
    %
    % This class provides a single source of truth for all system constants,
    % eliminating magic numbers scattered throughout the codebase.
    %
    % Usage:
    %   fs = Constants.DEFAULT_SAMPLING_RATE_HZ;
    %   ref_db = Constants.CALIBRATION_REFERENCE_DB;

    properties (Constant)
        % ═══════════════════════════════════════════════════════════════
        % AUDIO SYSTEM CONSTANTS
        % ═══════════════════════════════════════════════════════════════

        % Sampling rates
        DEFAULT_SAMPLING_RATE_HZ = 192000;  % Default DAQ sampling rate
        MIN_SAMPLING_RATE_HZ = 8000;        % Minimum supported rate
        MAX_SAMPLING_RATE_HZ = 500000;      % Maximum supported rate

        % Audio levels and calibration
        CALIBRATION_REFERENCE_DB = 100;     % Reference: 100 dB SPL
        CALIBRATION_REFERENCE_AMPLITUDE = 1.0;  % Reference amplitude
        DEFAULT_RAMP_MS = 5;                % Default ramp duration (ms)
        MAX_AUDIO_AMPLITUDE = 1.0;          % Maximum audio amplitude
        MIN_AUDIO_AMPLITUDE = -1.0;         % Minimum audio amplitude

        % ═══════════════════════════════════════════════════════════════
        % DAQ/HARDWARE CONSTANTS
        % ═══════════════════════════════════════════════════════════════

        % Default DAQ configuration
        DEFAULT_DAQ_VENDOR = 'ni';          % National Instruments
        DEFAULT_DAQ_DEVICE = 'Dev1';        % Default device ID
        DEFAULT_AUDIO_CHANNEL = 'ao0';      % Default audio output channel
        DEFAULT_TRIGGER_CHANNEL = 'ao1';    % Default TTL trigger channel

        % TTL trigger configuration
        DEFAULT_TTL_VOLTAGE = 5.0;          % TTL pulse voltage (V)
        DEFAULT_TTL_DURATION_MS = 10;       % TTL pulse duration (ms)

        % ═══════════════════════════════════════════════════════════════
        % TIMING CONSTANTS
        % ═══════════════════════════════════════════════════════════════

        DEFAULT_ITI_SEC = 1.0;              % Default inter-trial interval (sec)
        MIN_ITI_SEC = 0.0;                  % Minimum ITI (sec)
        MAX_ITI_SEC = 10.0;                 % Maximum ITI (sec)

        % ═══════════════════════════════════════════════════════════════
        % EXPERIMENT DEFAULTS
        % ═══════════════════════════════════════════════════════════════

        DEFAULT_ENGINE_TYPE = 'audio_only'; % Default execution engine
        DEFAULT_LOGGING_LEVEL = 'full';     % Default logging verbosity
        DEFAULT_SESSION_NUMBER = 1;         % Default session number

        % ═══════════════════════════════════════════════════════════════
        % VALIDATION CONSTANTS
        % ═══════════════════════════════════════════════════════════════

        % Schema versions
        SCHEMA_VERSION_GENERATOR = 'maestro-generator-v1';
        SCHEMA_VERSION_BUILDER = 'maestro-builder-v1';
        SCHEMA_VERSION_ENGINE = 'maestro-engine-v1';

        % File patterns
        GENERATOR_SCHEMA_FILENAME = 'schema.json';
        BUILDER_SCHEMA_FILENAME = 'template.schema.json';
        ENGINE_SCHEMA_FILENAME = 'schema.json';

        % ═══════════════════════════════════════════════════════════════
        % DIRECTORY STRUCTURE
        % ═══════════════════════════════════════════════════════════════

        DIR_SESSIONS = 'sessions';          % Session data directory
        DIR_LIBRARY = 'library';            % Library directory
        DIR_BLOCKS = 'blocks';              % Block definitions subdirectory
        DIR_SEQUENCES = 'sequences';        % Sequences subdirectory
        DIR_STIMULI = 'stimuli';            % Stimuli subdirectory
        DIR_GENERATORS = '+generators';     % Generators package
        DIR_BUILDERS = '+builders';         % Builders package
        DIR_ENGINES = '+engines';           % Engines package

        % ═══════════════════════════════════════════════════════════════
        % FILE NAMING PATTERNS
        % ═══════════════════════════════════════════════════════════════

        FILENAME_METADATA = 'metadata.json';
        FILENAME_SEQUENCE = 'sequence.json';
        FILENAME_EXECUTION_PLAN = 'execution_plan.json';
        FILENAME_RUN_RESULT = 'run_result.json';
        FILENAME_EVENTS_LOG = 'events.log';
        FILENAME_NOTES = 'notes.txt';

        % ═══════════════════════════════════════════════════════════════
        % DATETIME FORMATS
        % ═══════════════════════════════════════════════════════════════

        FORMAT_DATETIME = 'yyyy-MM-dd HH:mm:ss';
        FORMAT_DATE = 'yyyy-MM-dd';
        FORMAT_TIME = 'HH:mm:ss';
        FORMAT_TIMESTAMP_FILE = 'yyyymmdd_HHMMSS';
        FORMAT_SESSION_ID = 'yyyymmdd';

        % ═══════════════════════════════════════════════════════════════
        % NUMERIC LIMITS
        % ═══════════════════════════════════════════════════════════════

        MAX_FREQUENCY_HZ = 20000;           % Maximum audio frequency
        MIN_FREQUENCY_HZ = 20;              % Minimum audio frequency
        MAX_DURATION_MS = 10000;            % Maximum stimulus duration
        MIN_DURATION_MS = 1;                % Minimum stimulus duration
        MAX_TRIALS_PER_BLOCK = 10000;       % Maximum trials per block
        MIN_TRIALS_PER_BLOCK = 1;           % Minimum trials per block

        % ═══════════════════════════════════════════════════════════════
        % RANDOM NUMBER GENERATION
        % ═══════════════════════════════════════════════════════════════

        MAX_RANDOM_SEED = 2^31 - 1;         % Maximum random seed value

        % ═══════════════════════════════════════════════════════════════
        % STATUS CODES
        % ═══════════════════════════════════════════════════════════════

        STATUS_IDLE = 'idle';
        STATUS_PREPARED = 'prepared';
        STATUS_RUNNING = 'running';
        STATUS_COMPLETED = 'completed';
        STATUS_FAILED = 'failed';
        STATUS_ABORTED = 'aborted';

        % Logging levels
        LOG_LEVEL_INFO = 'INFO';
        LOG_LEVEL_WARNING = 'WARNING';
        LOG_LEVEL_ERROR = 'ERROR';
    end

    methods (Static)
        function validate_sampling_rate(sampling_rate_hz)
            % VALIDATE_SAMPLING_RATE - Ensure sampling rate is in valid range
            %
            % INPUTS:
            %   sampling_rate_hz - numeric, sampling rate to validate
            %
            % Throws error if out of range

            if sampling_rate_hz < core.Constants.MIN_SAMPLING_RATE_HZ || ...
               sampling_rate_hz > core.Constants.MAX_SAMPLING_RATE_HZ
                error('Constants:InvalidSamplingRate', ...
                    'Sampling rate must be between %d and %d Hz', ...
                    core.Constants.MIN_SAMPLING_RATE_HZ, ...
                    core.Constants.MAX_SAMPLING_RATE_HZ);
            end
        end

        function validate_frequency(freq_hz)
            % VALIDATE_FREQUENCY - Ensure frequency is in valid range
            %
            % INPUTS:
            %   freq_hz - numeric, frequency to validate

            if freq_hz < core.Constants.MIN_FREQUENCY_HZ || ...
               freq_hz > core.Constants.MAX_FREQUENCY_HZ
                error('Constants:InvalidFrequency', ...
                    'Frequency must be between %d and %d Hz', ...
                    core.Constants.MIN_FREQUENCY_HZ, ...
                    core.Constants.MAX_FREQUENCY_HZ);
            end
        end

        function validate_duration(dur_ms)
            % VALIDATE_DURATION - Ensure duration is in valid range
            %
            % INPUTS:
            %   dur_ms - numeric, duration to validate

            if dur_ms < core.Constants.MIN_DURATION_MS || ...
               dur_ms > core.Constants.MAX_DURATION_MS
                error('Constants:InvalidDuration', ...
                    'Duration must be between %d and %d ms', ...
                    core.Constants.MIN_DURATION_MS, ...
                    core.Constants.MAX_DURATION_MS);
            end
        end
    end
end
