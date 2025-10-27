function success = smoke_test()
% SMOKE_TEST - Quick smoke test for Maestro infrastructure
%
% This script performs basic sanity checks on the refactored infrastructure
% without requiring the full unittest framework. Useful for quick validation.
%
% Usage:
%   success = smoke_test();
%
% Returns:
%   success - boolean, true if all smoke tests pass

    fprintf('\n');
    fprintf('════════════════════════════════════════════════════════════════\n');
    fprintf('  Maestro Smoke Test\n');
    fprintf('════════════════════════════════════════════════════════════════\n');
    fprintf('\n');

    success = true;
    test_count = 0;
    passed_count = 0;

    % Helper function to run a test
    function run_test(name, test_func)
        test_count = test_count + 1;
        fprintf('[%d] Testing %s... ', test_count, name);
        try
            test_func();
            fprintf('✓ PASS\n');
            passed_count = passed_count + 1;
        catch ME
            fprintf('✗ FAIL\n');
            fprintf('    Error: %s\n', ME.message);
            success = false;
        end
    end

    % Test 1: Constants class exists and has required constants
    run_test('Constants class', @() test_constants());

    % Test 2: ConfigurationManager can merge structs
    run_test('ConfigurationManager.merge_structs', @() test_config_merge());

    % Test 3: ValidationHelpers can validate numeric ranges
    run_test('ValidationHelpers.validate_numeric_range', @() test_validation());

    % Test 4: PluginDiscovery class exists
    run_test('PluginDiscovery class', @() test_discovery());

    % Test 5: DAQManager can be constructed
    run_test('DAQManager construction', @() test_daq_manager());

    % Test 6: InstanceNormalizer exists
    run_test('InstanceNormalizer class', @() test_instance_normalizer());

    % Display summary
    fprintf('\n');
    fprintf('════════════════════════════════════════════════════════════════\n');
    fprintf('  Summary: %d/%d tests passed\n', passed_count, test_count);
    fprintf('════════════════════════════════════════════════════════════════\n');
    fprintf('\n');

    if success
        fprintf('✓ All smoke tests passed!\n\n');
    else
        fprintf('✗ Some smoke tests failed.\n\n');
    end
end

% ============================================================
% Individual Test Functions
% ============================================================

function test_constants()
    % Test Constants class
    assert(isnumeric(core.Constants.DEFAULT_SAMPLING_RATE_HZ));
    assert(core.Constants.DEFAULT_SAMPLING_RATE_HZ == 192000);
    assert(ischar(core.Constants.DEFAULT_DAQ_VENDOR));
    core.Constants.validate_sampling_rate(192000);  % Should not throw
end

function test_config_merge()
    % Test ConfigurationManager.merge_structs
    dest = struct('a', 1, 'b', 2);
    src = struct('b', 3, 'c', 4);
    result = core.config.ConfigurationManager.merge_structs(dest, src);
    assert(result.a == 1);
    assert(result.b == 3);
    assert(result.c == 4);
end

function test_validation()
    % Test ValidationHelpers
    core.validation.ValidationHelpers.validate_numeric_range(50, 'test', 0, 100, false);

    % Test that validation fails correctly
    try
        core.validation.ValidationHelpers.validate_numeric_range(150, 'test', 0, 100, false);
        error('Should have thrown error');
    catch ME
        assert(contains(ME.identifier, 'ValidationHelpers'));
    end
end

function test_discovery()
    % Test PluginDiscovery class exists
    methods_list = methods('core.discovery.PluginDiscovery');
    assert(any(strcmp(methods_list, 'discover_generators')));
    assert(any(strcmp(methods_list, 'discover_builders')));
    assert(any(strcmp(methods_list, 'discover_engines')));
end

function test_daq_manager()
    % Test DAQManager construction
    daq_mgr = engines.audio_only.DAQManager(192000, struct());
    assert(daq_mgr.sampling_rate_hz == 192000);
    assert(~daq_mgr.is_initialized);

    % Test TTL generation
    ttl = daq_mgr.generate_ttl_pulse(1000);
    assert(length(ttl) == 1000);
    assert(size(ttl, 2) == 1);  % Column vector
end

function test_instance_normalizer()
    % Test InstanceNormalizer class exists
    methods_list = methods('core.normalization.InstanceNormalizer');
    assert(any(strcmp(methods_list, 'normalize_block_instance')));
    assert(any(strcmp(methods_list, 'ensure_block_instance')));
end
