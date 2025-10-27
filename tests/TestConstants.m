classdef TestConstants < matlab.unittest.TestCase
    % TESTCONSTANTS - Unit tests for Constants class
    %
    % Tests that all constants are properly defined and validation
    % methods work correctly.

    methods (Test)
        % ============================================================
        % Constants Existence Tests
        % ============================================================

        function testAudioConstants_Exist(testCase)
            % Test audio-related constants exist

            testCase.verifyTrue(isnumeric(core.Constants.DEFAULT_SAMPLING_RATE_HZ));
            testCase.verifyTrue(isnumeric(core.Constants.MIN_SAMPLING_RATE_HZ));
            testCase.verifyTrue(isnumeric(core.Constants.MAX_SAMPLING_RATE_HZ));
            testCase.verifyTrue(isnumeric(core.Constants.CALIBRATION_REFERENCE_DB));
            testCase.verifyTrue(isnumeric(core.Constants.DEFAULT_RAMP_MS));
        end

        function testDAQConstants_Exist(testCase)
            % Test DAQ-related constants exist

            testCase.verifyTrue(ischar(core.Constants.DEFAULT_DAQ_VENDOR));
            testCase.verifyTrue(ischar(core.Constants.DEFAULT_DAQ_DEVICE));
            testCase.verifyTrue(ischar(core.Constants.DEFAULT_AUDIO_CHANNEL));
            testCase.verifyTrue(ischar(core.Constants.DEFAULT_TRIGGER_CHANNEL));
            testCase.verifyTrue(isnumeric(core.Constants.DEFAULT_TTL_VOLTAGE));
            testCase.verifyTrue(isnumeric(core.Constants.DEFAULT_TTL_DURATION_MS));
        end

        function testTimingConstants_Exist(testCase)
            % Test timing-related constants exist

            testCase.verifyTrue(isnumeric(core.Constants.DEFAULT_ITI_SEC));
            testCase.verifyTrue(isnumeric(core.Constants.MIN_ITI_SEC));
            testCase.verifyTrue(isnumeric(core.Constants.MAX_ITI_SEC));
        end

        function testSchemaConstants_Exist(testCase)
            % Test schema-related constants exist

            testCase.verifyTrue(ischar(core.Constants.SCHEMA_VERSION_GENERATOR));
            testCase.verifyTrue(ischar(core.Constants.SCHEMA_VERSION_BUILDER));
            testCase.verifyTrue(ischar(core.Constants.SCHEMA_VERSION_ENGINE));
        end

        function testStatusConstants_Exist(testCase)
            % Test status code constants exist

            testCase.verifyTrue(ischar(core.Constants.STATUS_IDLE));
            testCase.verifyTrue(ischar(core.Constants.STATUS_RUNNING));
            testCase.verifyTrue(ischar(core.Constants.STATUS_COMPLETED));
            testCase.verifyTrue(ischar(core.Constants.LOG_LEVEL_INFO));
            testCase.verifyTrue(ischar(core.Constants.LOG_LEVEL_ERROR));
        end

        % ============================================================
        % Constants Validity Tests
        % ============================================================

        function testSamplingRates_ValidRange(testCase)
            % Test sampling rate constants are in valid range

            testCase.verifyGreaterThan(core.Constants.MIN_SAMPLING_RATE_HZ, 0);
            testCase.verifyLessThan(...
                core.Constants.MIN_SAMPLING_RATE_HZ, ...
                core.Constants.MAX_SAMPLING_RATE_HZ);
            testCase.verifyGreaterThanOrEqual(...
                core.Constants.DEFAULT_SAMPLING_RATE_HZ, ...
                core.Constants.MIN_SAMPLING_RATE_HZ);
            testCase.verifyLessThanOrEqual(...
                core.Constants.DEFAULT_SAMPLING_RATE_HZ, ...
                core.Constants.MAX_SAMPLING_RATE_HZ);
        end

        function testFrequencyLimits_ValidRange(testCase)
            % Test frequency limits are sensible

            testCase.verifyGreaterThan(core.Constants.MIN_FREQUENCY_HZ, 0);
            testCase.verifyLessThan(...
                core.Constants.MIN_FREQUENCY_HZ, ...
                core.Constants.MAX_FREQUENCY_HZ);
            testCase.verifyLessThanOrEqual(...
                core.Constants.MAX_FREQUENCY_HZ, 20000);  % Human hearing range
        end

        function testDurationLimits_ValidRange(testCase)
            % Test duration limits are sensible

            testCase.verifyGreaterThan(core.Constants.MIN_DURATION_MS, 0);
            testCase.verifyLessThan(...
                core.Constants.MIN_DURATION_MS, ...
                core.Constants.MAX_DURATION_MS);
        end

        function testAmplitudeLimits_ValidRange(testCase)
            % Test amplitude limits are in [-1, 1] range

            testCase.verifyEqual(core.Constants.MIN_AUDIO_AMPLITUDE, -1.0);
            testCase.verifyEqual(core.Constants.MAX_AUDIO_AMPLITUDE, 1.0);
        end

        function testTrialLimits_ValidRange(testCase)
            % Test trial count limits are sensible

            testCase.verifyGreaterThan(core.Constants.MIN_TRIALS_PER_BLOCK, 0);
            testCase.verifyLessThan(...
                core.Constants.MIN_TRIALS_PER_BLOCK, ...
                core.Constants.MAX_TRIALS_PER_BLOCK);
        end

        % ============================================================
        % Validation Method Tests
        % ============================================================

        function testValidateSamplingRate_ValidRates(testCase)
            % Test validation passes for valid sampling rates

            % Should not throw
            core.Constants.validate_sampling_rate(8000);
            core.Constants.validate_sampling_rate(192000);
            core.Constants.validate_sampling_rate(500000);
        end

        function testValidateSamplingRate_TooLow(testCase)
            % Test validation fails for too low sampling rate

            testCase.verifyError(...
                @() core.Constants.validate_sampling_rate(100), ...
                'Constants:InvalidSamplingRate');
        end

        function testValidateSamplingRate_TooHigh(testCase)
            % Test validation fails for too high sampling rate

            testCase.verifyError(...
                @() core.Constants.validate_sampling_rate(1000000), ...
                'Constants:InvalidSamplingRate');
        end

        function testValidateFrequency_ValidFrequencies(testCase)
            % Test validation passes for valid frequencies

            % Should not throw
            core.Constants.validate_frequency(20);      % Min
            core.Constants.validate_frequency(1000);    % Mid
            core.Constants.validate_frequency(20000);   % Max
        end

        function testValidateFrequency_TooLow(testCase)
            % Test validation fails for too low frequency

            testCase.verifyError(...
                @() core.Constants.validate_frequency(10), ...
                'Constants:InvalidFrequency');
        end

        function testValidateFrequency_TooHigh(testCase)
            % Test validation fails for too high frequency

            testCase.verifyError(...
                @() core.Constants.validate_frequency(25000), ...
                'Constants:InvalidFrequency');
        end

        function testValidateDuration_ValidDurations(testCase)
            % Test validation passes for valid durations

            % Should not throw
            core.Constants.validate_duration(1);        % Min
            core.Constants.validate_duration(100);      % Mid
            core.Constants.validate_duration(10000);    % Max
        end

        function testValidateDuration_TooShort(testCase)
            % Test validation fails for too short duration

            testCase.verifyError(...
                @() core.Constants.validate_duration(0.5), ...
                'Constants:InvalidDuration');
        end

        function testValidateDuration_TooLong(testCase)
            % Test validation fails for too long duration

            testCase.verifyError(...
                @() core.Constants.validate_duration(15000), ...
                'Constants:InvalidDuration');
        end

        % ============================================================
        % Consistency Tests
        % ============================================================

        function testSchemaFilenames_Consistent(testCase)
            % Test schema filenames are defined

            testCase.verifyTrue(ischar(core.Constants.GENERATOR_SCHEMA_FILENAME));
            testCase.verifyTrue(ischar(core.Constants.BUILDER_SCHEMA_FILENAME));
            testCase.verifyTrue(ischar(core.Constants.ENGINE_SCHEMA_FILENAME));
        end

        function testDirectoryNames_Consistent(testCase)
            % Test directory names are defined

            testCase.verifyTrue(ischar(core.Constants.DIR_SESSIONS));
            testCase.verifyTrue(ischar(core.Constants.DIR_LIBRARY));
            testCase.verifyTrue(ischar(core.Constants.DIR_GENERATORS));
            testCase.verifyTrue(ischar(core.Constants.DIR_BUILDERS));
            testCase.verifyTrue(ischar(core.Constants.DIR_ENGINES));
        end

        function testFilenames_Consistent(testCase)
            % Test standard filenames are defined

            testCase.verifyTrue(ischar(core.Constants.FILENAME_METADATA));
            testCase.verifyTrue(ischar(core.Constants.FILENAME_SEQUENCE));
            testCase.verifyTrue(ischar(core.Constants.FILENAME_EVENTS_LOG));
        end

        function testDateTimeFormats_Consistent(testCase)
            % Test datetime format strings are defined

            testCase.verifyTrue(ischar(core.Constants.FORMAT_DATETIME));
            testCase.verifyTrue(ischar(core.Constants.FORMAT_DATE));
            testCase.verifyTrue(ischar(core.Constants.FORMAT_TIME));
        end

        % ============================================================
        % Value Reasonableness Tests
        % ============================================================

        function testDefaultSamplingRate_Reasonable(testCase)
            % Test default sampling rate is a common value

            % 192 kHz is a standard DAQ sampling rate
            testCase.verifyEqual(core.Constants.DEFAULT_SAMPLING_RATE_HZ, 192000);
        end

        function testCalibration_Reasonable(testCase)
            % Test calibration constants are standard

            % 100 dB SPL = 1.0 amplitude is a common standard
            testCase.verifyEqual(core.Constants.CALIBRATION_REFERENCE_DB, 100);
            testCase.verifyEqual(core.Constants.CALIBRATION_REFERENCE_AMPLITUDE, 1.0);
        end

        function testTTLSettings_Reasonable(testCase)
            % Test TTL settings are standard

            % 5V is standard TTL voltage
            testCase.verifyEqual(core.Constants.DEFAULT_TTL_VOLTAGE, 5.0);

            % 10ms is reasonable pulse duration
            testCase.verifyEqual(core.Constants.DEFAULT_TTL_DURATION_MS, 10);
        end

        function testRampDuration_Reasonable(testCase)
            % Test default ramp duration is reasonable

            % 5ms is common for audio ramps
            testCase.verifyEqual(core.Constants.DEFAULT_RAMP_MS, 5);
            testCase.verifyGreaterThan(core.Constants.DEFAULT_RAMP_MS, 0);
            testCase.verifyLessThan(core.Constants.DEFAULT_RAMP_MS, 100);
        end
    end
end
