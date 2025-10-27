classdef TestConfigurationManager < matlab.unittest.TestCase
    % TESTCONFIGURATIONMANAGER - Unit tests for ConfigurationManager
    %
    % Tests all methods of the ConfigurationManager class including
    % JSON file operations, struct merging, and metadata creation.

    properties (TestParameter)
    end

    properties
        TestDir
    end

    methods (TestClassSetup)
        function createTestDirectory(testCase)
            % Create temporary directory for test files
            testCase.TestDir = fullfile(tempdir, 'maestro_test_config');
            if ~exist(testCase.TestDir, 'dir')
                mkdir(testCase.TestDir);
            end
        end
    end

    methods (TestClassTeardown)
        function removeTestDirectory(testCase)
            % Clean up test directory
            if exist(testCase.TestDir, 'dir')
                rmdir(testCase.TestDir, 's');
            end
        end
    end

    methods (Test)
        % ============================================================
        % JSON File Operations Tests
        % ============================================================

        function testLoadJsonFile_ValidFile(testCase)
            % Test loading a valid JSON file

            % Create test file
            test_data = struct('field1', 'value1', 'field2', 123);
            test_file = fullfile(testCase.TestDir, 'test_valid.json');
            fid = fopen(test_file, 'w');
            fprintf(fid, '%s', jsonencode(test_data));
            fclose(fid);

            % Load and verify
            loaded = core.config.ConfigurationManager.load_json_file(test_file);
            testCase.verifyEqual(loaded.field1, 'value1');
            testCase.verifyEqual(loaded.field2, 123);
        end

        function testLoadJsonFile_FileNotFound(testCase)
            % Test loading non-existent file throws error

            non_existent = fullfile(testCase.TestDir, 'does_not_exist.json');
            testCase.verifyError(...
                @() core.config.ConfigurationManager.load_json_file(non_existent), ...
                'ConfigurationManager:FileNotFound');
        end

        function testLoadJsonFile_InvalidJson(testCase)
            % Test loading invalid JSON throws error

            test_file = fullfile(testCase.TestDir, 'test_invalid.json');
            fid = fopen(test_file, 'w');
            fprintf(fid, 'not valid json {{}');
            fclose(fid);

            testCase.verifyError(...
                @() core.config.ConfigurationManager.load_json_file(test_file), ...
                'ConfigurationManager:ParseError');
        end

        function testSaveJsonFile_ValidData(testCase)
            % Test saving data to JSON file

            test_data = struct('field1', 'value1', 'nested', struct('a', 1, 'b', 2));
            test_file = fullfile(testCase.TestDir, 'test_save.json');

            core.config.ConfigurationManager.save_json_file(test_file, test_data);

            % Verify file exists and can be loaded
            testCase.verifyTrue(isfile(test_file));
            loaded = core.config.ConfigurationManager.load_json_file(test_file);
            testCase.verifyEqual(loaded.field1, 'value1');
            testCase.verifyEqual(loaded.nested.a, 1);
        end

        % ============================================================
        % Struct Manipulation Tests
        % ============================================================

        function testMergeStructs_BothValid(testCase)
            % Test merging two valid structs

            dest = struct('a', 1, 'b', 2);
            src = struct('b', 3, 'c', 4);

            result = core.config.ConfigurationManager.merge_structs(dest, src);

            testCase.verifyEqual(result.a, 1);  % Preserved from dest
            testCase.verifyEqual(result.b, 3);  % Overridden by src
            testCase.verifyEqual(result.c, 4);  % Added from src
        end

        function testMergeStructs_EmptyDest(testCase)
            % Test merging when destination is empty

            src = struct('a', 1, 'b', 2);
            result = core.config.ConfigurationManager.merge_structs(struct(), src);

            testCase.verifyEqual(result.a, 1);
            testCase.verifyEqual(result.b, 2);
        end

        function testMergeStructs_EmptySrc(testCase)
            % Test merging when source is empty

            dest = struct('a', 1, 'b', 2);
            result = core.config.ConfigurationManager.merge_structs(dest, struct());

            testCase.verifyEqual(result.a, 1);
            testCase.verifyEqual(result.b, 2);
        end

        function testCoerceScalarStruct_ValidStruct(testCase)
            % Test coercing a valid scalar struct

            s = struct('field', 'value');
            result = core.config.ConfigurationManager.coerce_scalar_struct(s, struct());

            testCase.verifyEqual(result.field, 'value');
        end

        function testCoerceScalarStruct_StructArray(testCase)
            % Test coercing struct array returns first element

            s(1).field = 'first';
            s(2).field = 'second';

            result = core.config.ConfigurationManager.coerce_scalar_struct(s, struct());
            testCase.verifyEqual(result.field, 'first');
        end

        function testCoerceScalarStruct_CellWithStruct(testCase)
            % Test coercing cell containing struct

            s = {struct('field', 'value')};
            result = core.config.ConfigurationManager.coerce_scalar_struct(s, struct());

            testCase.verifyEqual(result.field, 'value');
        end

        function testCoerceScalarStruct_Empty(testCase)
            % Test coercing empty value returns default

            default = struct('default_field', 'default_value');
            result = core.config.ConfigurationManager.coerce_scalar_struct([], default);

            testCase.verifyEqual(result.default_field, 'default_value');
        end

        % ============================================================
        % Field Access Tests
        % ============================================================

        function testGetFieldOrDefault_FieldExists(testCase)
            % Test getting existing field

            s = struct('field', 'value');
            result = core.config.ConfigurationManager.get_field_or_default(...
                s, 'field', 'default');

            testCase.verifyEqual(result, 'value');
        end

        function testGetFieldOrDefault_FieldMissing(testCase)
            % Test getting missing field returns default

            s = struct('other_field', 'value');
            result = core.config.ConfigurationManager.get_field_or_default(...
                s, 'missing_field', 'default');

            testCase.verifyEqual(result, 'default');
        end

        function testGetFieldOrDefault_FieldEmpty(testCase)
            % Test getting empty field returns default

            s = struct('field', []);
            result = core.config.ConfigurationManager.get_field_or_default(...
                s, 'field', 'default');

            testCase.verifyEqual(result, 'default');
        end

        function testValidateRequiredField_FieldExists(testCase)
            % Test validating existing required field passes

            s = struct('required_field', 'value');

            % Should not throw
            core.config.ConfigurationManager.validate_required_field(...
                s, 'required_field', 'test_struct');
        end

        function testValidateRequiredField_FieldMissing(testCase)
            % Test validating missing required field throws

            s = struct('other_field', 'value');

            testCase.verifyError(...
                @() core.config.ConfigurationManager.validate_required_field(...
                    s, 'required_field', 'test_struct'), ...
                'ConfigurationManager:MissingField');
        end

        % ============================================================
        % Metadata Creation Tests
        % ============================================================

        function testCreateSessionMetadata_MinimalConfig(testCase)
            % Test creating metadata with minimal configuration

            run_config = struct('subject', 'TEST01');
            metadata = core.config.ConfigurationManager.create_session_metadata(run_config);

            % Verify required fields
            testCase.verifyEqual(metadata.subject, 'TEST01');
            testCase.verifyEqual(metadata.session_num, 1);  % Default
            testCase.verifyTrue(isfield(metadata, 'started_at'));
            testCase.verifyTrue(isfield(metadata, 'random_seed'));
            testCase.verifyEqual(metadata.engine_id, 'audio_only');  % Default
        end

        function testCreateSessionMetadata_FullConfig(testCase)
            % Test creating metadata with full configuration

            run_config = struct(...
                'subject', 'TEST02', ...
                'session_num', 5, ...
                'experimenter', 'Dr. Smith', ...
                'notes', 'Test notes', ...
                'engine_id', 'custom_engine', ...
                'logging_level', 'debug');

            metadata = core.config.ConfigurationManager.create_session_metadata(run_config);

            testCase.verifyEqual(metadata.subject, 'TEST02');
            testCase.verifyEqual(metadata.session_num, 5);
            testCase.verifyEqual(metadata.experimenter, 'Dr. Smith');
            testCase.verifyEqual(metadata.notes, 'Test notes');
            testCase.verifyEqual(metadata.engine_id, 'custom_engine');
            testCase.verifyEqual(metadata.logging_level, 'debug');
        end

        function testCreateSessionMetadata_MissingSubject(testCase)
            % Test creating metadata without subject throws error

            run_config = struct('session_num', 1);

            testCase.verifyError(...
                @() core.config.ConfigurationManager.create_session_metadata(run_config), ...
                'ConfigurationManager:MissingField');
        end

        % ============================================================
        % Engine Config Normalization Tests
        % ============================================================

        function testNormalizeEngineConfig_WithGlobalSettings(testCase)
            % Test normalizing engine config from global settings

            global_settings = struct(...
                'sampling_rate_hz', 192000, ...
                'engine_config', struct('device_id', 'Dev1'));

            override_config = struct('vendor', 'ni');

            result = core.config.ConfigurationManager.normalize_engine_config(...
                global_settings, override_config);

            testCase.verifyEqual(result.sampling_rate_hz, 192000);
            testCase.verifyEqual(result.device_id, 'Dev1');
            testCase.verifyEqual(result.vendor, 'ni');
        end

        function testNormalizeEngineConfig_SamplingRateInheritance(testCase)
            % Test sampling rate inheritance from global settings

            global_settings = struct('sampling_rate_hz', 96000);
            override_config = struct();

            result = core.config.ConfigurationManager.normalize_engine_config(...
                global_settings, override_config);

            testCase.verifyEqual(result.sampling_rate_hz, 96000);
        end
    end
end
