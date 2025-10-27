function results = run_tests(varargin)
% RUN_TESTS - Execute Maestro unit test suite
%
% This script runs all unit tests for the Maestro codebase and generates
% a comprehensive test report.
%
% Usage:
%   run_tests()               % Run all tests
%   run_tests('verbose')      % Run with verbose output
%   run_tests('coverage')     % Run with code coverage analysis
%   run_tests('class', 'TestConfigurationManager')  % Run specific test class
%
% Examples:
%   results = run_tests();
%   results = run_tests('verbose');
%   results = run_tests('class', 'TestConstants');
%
% Outputs:
%   results - TestResult array with test results

    % Parse input arguments
    p = inputParser;
    addOptional(p, 'mode', 'normal', @(x) ismember(x, {'normal', 'verbose', 'coverage'}));
    addParameter(p, 'class', '', @ischar);
    parse(p, varargin{:});

    mode = p.Results.mode;
    specific_class = p.Results.class;

    % Setup path
    maestro_root = fileparts(mfilename('fullpath'));
    addpath(genpath(maestro_root));

    % Display header
    fprintf('\n');
    fprintf('════════════════════════════════════════════════════════════════\n');
    fprintf('  Maestro Unit Test Suite\n');
    fprintf('════════════════════════════════════════════════════════════════\n');
    fprintf('\n');

    % Create test suite
    if ~isempty(specific_class)
        % Run specific test class
        fprintf('Running tests from: %s\n\n', specific_class);
        suite = testsuite(specific_class);
    else
        % Run all tests in tests/ directory
        test_dir = fullfile(maestro_root, 'tests');
        if ~exist(test_dir, 'dir')
            error('Tests directory not found: %s', test_dir);
        end

        fprintf('Discovering tests in: %s\n', test_dir);
        suite = testsuite(test_dir);
        fprintf('Found %d test classes\n\n', length(suite));
    end

    % Create test runner based on mode
    switch mode
        case 'verbose'
            runner = matlab.unittest.TestRunner.withTextOutput(...
                'OutputDetail', matlab.unittest.Verbosity.Detailed);

        case 'coverage'
            % Coverage analysis (if available)
            runner = matlab.unittest.TestRunner.withTextOutput;
            try
                import matlab.unittest.plugins.CodeCoveragePlugin;
                source_folder = fullfile(maestro_root, '+core');
                runner.addPlugin(CodeCoveragePlugin.forFolder(source_folder));
                fprintf('Code coverage enabled for: %s\n\n', source_folder);
            catch
                warning('Code coverage plugin not available. Running without coverage.');
            end

        otherwise
            runner = matlab.unittest.TestRunner.withTextOutput;
    end

    % Run tests
    fprintf('════════════════════════════════════════════════════════════════\n');
    fprintf('  Executing Tests\n');
    fprintf('════════════════════════════════════════════════════════════════\n\n');

    start_time = tic;
    results = runner.run(suite);
    elapsed_time = toc(start_time);

    % Display summary
    fprintf('\n');
    fprintf('════════════════════════════════════════════════════════════════\n');
    fprintf('  Test Results Summary\n');
    fprintf('════════════════════════════════════════════════════════════════\n');
    fprintf('\n');
    fprintf('  Total Tests:     %d\n', length(results));
    fprintf('  Passed:          %d\n', sum([results.Passed]));
    fprintf('  Failed:          %d\n', sum([results.Failed]));
    fprintf('  Incomplete:      %d\n', sum([results.Incomplete]));
    fprintf('  Execution Time:  %.2f seconds\n', elapsed_time);
    fprintf('\n');

    % Display failed tests if any
    failed_tests = results([results.Failed]);
    if ~isempty(failed_tests)
        fprintf('════════════════════════════════════════════════════════════════\n');
        fprintf('  Failed Tests\n');
        fprintf('════════════════════════════════════════════════════════════════\n\n');

        for i = 1:length(failed_tests)
            fprintf('  %d. %s\n', i, failed_tests(i).Name);

            % Try to get diagnostic information (compatible with different MATLAB versions)
            try
                if isfield(failed_tests(i).Details, 'DiagnosticRecord')
                    disp_record = failed_tests(i).Details.DiagnosticRecord;
                    if ~isempty(disp_record)
                        fprintf('     %s\n', disp_record(1).Event);
                    end
                elseif isfield(failed_tests(i), 'Details')
                    % Some MATLAB versions have different structure
                    fprintf('     See test output above for details\n');
                end
            catch
                % If we can't access diagnostics, just skip it
                fprintf('     See test output above for details\n');
            end
        end
        fprintf('\n');
    end

    % Overall pass/fail
    if all([results.Passed])
        fprintf('✓ All tests passed!\n\n');
    else
        fprintf('✗ Some tests failed. Review output above.\n\n');
    end

    % Return results
    if nargout == 0
        clear results;
    end
end
