function results = run_tests_v1(varargin)
    % run_tests_v1 - Run all v1 unit tests
    %
    % Usage:
    %   run_tests_v1                  % Run all tests, normal output
    %   run_tests_v1('verbose')       % Verbose output
    %   run_tests_v1('coverage')      % With code coverage
    %   run_tests_v1('test_name')     % Run specific test class
    %
    % Examples:
    %   run_tests_v1
    %   run_tests_v1('verbose')
    %   run_tests_v1('TestNumericFieldValidator')
    %   run_tests_v1('coverage')

    fprintf('\n');
    fprintf('╔═══════════════════════════════════════════════════════╗\n');
    fprintf('║       Maestro v1 Architecture - Unit Tests           ║\n');
    fprintf('╚═══════════════════════════════════════════════════════╝\n');
    fprintf('\n');

    % Parse arguments
    verbose = false;
    coverage = false;
    specific_test = '';

    for i = 1:length(varargin)
        arg = varargin{i};
        if strcmpi(arg, 'verbose')
            verbose = true;
        elseif strcmpi(arg, 'coverage')
            coverage = true;
        else
            specific_test = arg;
        end
    end

    % Setup test suite
    if isempty(specific_test)
        % Run all v1 tests
        suite = testsuite('tests/v1');
        fprintf('Running all v1 unit tests...\n\n');
    else
        % Run specific test
        test_path = fullfile('tests/v1', [specific_test '.m']);
        if exist(test_path, 'file')
            suite = testsuite(test_path);
            fprintf('Running test: %s\n\n', specific_test);
        else
            error('Test file not found: %s', test_path);
        end
    end

    % Create test runner
    import matlab.unittest.TestRunner;
    import matlab.unittest.plugins.TestReportPlugin;
    import matlab.unittest.plugins.CodeCoveragePlugin;

    runner = TestRunner.withTextOutput;

    % Add verbose output if requested
    if verbose
        import matlab.unittest.plugins.DiagnosticsRecordingPlugin;
        runner.addPlugin(DiagnosticsRecordingPlugin);
    end

    % Add coverage plugin if requested
    if coverage
        fprintf('Code coverage enabled\n');
        source_code_folder = '+v1';
        if exist(source_code_folder, 'dir')
            runner.addPlugin(CodeCoveragePlugin.forFolder(source_code_folder));
        end
    end

    % Run tests
    tic;
    results = runner.run(suite);
    elapsed = toc;

    % Display summary
    fprintf('\n');
    fprintf('═══════════════════════════════════════════════════════\n');
    fprintf('Test Summary\n');
    fprintf('═══════════════════════════════════════════════════════\n');
    fprintf('Total Tests:    %d\n', numel(results));
    fprintf('Passed:         %d\n', sum([results.Passed]));
    fprintf('Failed:         %d\n', sum([results.Failed]));
    fprintf('Incomplete:     %d\n', sum([results.Incomplete]));
    fprintf('Duration:       %.2f seconds\n', elapsed);
    fprintf('═══════════════════════════════════════════════════════\n');

    % Show failures if any
    failed_tests = results([results.Failed]);
    if ~isempty(failed_tests)
        fprintf('\nFailed Tests:\n');
        for i = 1:length(failed_tests)
            fprintf('  %d. %s\n', i, failed_tests(i).Name);
            if ~isempty(failed_tests(i).Details)
                try
                    if isfield(failed_tests(i).Details, 'DiagnosticRecord')
                        disp_record = failed_tests(i).Details.DiagnosticRecord;
                        if ~isempty(disp_record)
                            fprintf('     %s\n', disp_record(1).Event);
                        end
                    end
                catch
                    fprintf('     See test output above for details\n');
                end
            end
        end
        fprintf('\n');
    end

    % Exit status
    if all([results.Passed])
        fprintf('✓ All tests passed!\n\n');
        exit_code = 0;
    else
        fprintf('✗ Some tests failed\n\n');
        exit_code = 1;
    end

    % Summary message
    fprintf('To run specific test class:\n');
    fprintf('  run_tests_v1(''TestNumericFieldValidator'')\n');
    fprintf('  run_tests_v1(''TestSampling'')\n');
    fprintf('\nTo run with coverage:\n');
    fprintf('  run_tests_v1(''coverage'')\n');
    fprintf('\nTo run with verbose output:\n');
    fprintf('  run_tests_v1(''verbose'')\n\n');

    % Return exit code if running in batch mode
    if nargout == 0 && usejava('desktop') == 0
        exit(exit_code);
    end
end
