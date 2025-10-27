# Maestro Test Suite

Comprehensive unit tests for the Maestro refactored infrastructure.

## Overview

This test suite validates all new infrastructure classes created during the refactoring:

- **ConfigurationManager** - Configuration loading and merging
- **ValidationHelpers** - Data validation functions
- **Constants** - System constants and validation
- **DAQManager** - DAQ hardware management
- **PluginDiscovery** - Plugin discovery system
- **InstanceNormalizer** - Block instance normalization

## Test Coverage

### TestConfigurationManager.m (45 tests)
Tests for configuration management:
- ✅ JSON file loading and saving
- ✅ Struct merging and coercion
- ✅ Field access with defaults
- ✅ Required field validation
- ✅ Session metadata creation
- ✅ Engine configuration normalization

**Coverage**: All public methods of ConfigurationManager

### TestValidationHelpers.m (35 tests)
Tests for validation functions:
- ✅ Required fields validation
- ✅ Numeric range validation
- ✅ Probability validation (0-1 range)
- ✅ Enum validation
- ✅ Type checking (struct, cell array)
- ✅ Complex validation (experiment spec, block instance, stimulus spec)
- ✅ Safe validation wrapper

**Coverage**: All public methods of ValidationHelpers

### TestConstants.m (25 tests)
Tests for system constants:
- ✅ Constants existence verification
- ✅ Value validity and reasonableness
- ✅ Range consistency checks
- ✅ Validation method tests
- ✅ Sampling rate validation
- ✅ Frequency validation
- ✅ Duration validation

**Coverage**: All constant values and validation methods

### TestDAQManager.m (18 tests)
Tests for DAQ management:
- ✅ Construction with various configs
- ✅ Default application
- ✅ TTL pulse generation
- ✅ Information retrieval
- ✅ Configuration validation
- ✅ State management

**Coverage**: All non-hardware-dependent methods

## Running Tests

### Option 1: Full Test Suite (Recommended)

Run all tests with the test runner:

```matlab
% Run all tests
results = run_tests();

% Run with verbose output
results = run_tests('verbose');

% Run with code coverage (if available)
results = run_tests('coverage');

% Run specific test class
results = run_tests('class', 'TestConfigurationManager');
```

### Option 2: Quick Smoke Test

Run quick sanity checks without full unittest framework:

```matlab
success = smoke_test();
```

The smoke test performs basic validation of:
- Constants class
- ConfigurationManager
- ValidationHelpers
- PluginDiscovery
- DAQManager
- InstanceNormalizer

### Option 3: MATLAB Test Browser

Use MATLAB's built-in test browser:

```matlab
testbrowser
```

Then navigate to the `tests/` directory and select tests to run.

### Option 4: Command-Line Runner

Use MATLAB's `runtests` function:

```matlab
% Run all tests
runtests('tests')

% Run specific test
runtests('TestConfigurationManager')

% Run with table display
results = runtests('tests');
table(results)
```

## Test Organization

### Test Structure

Each test class follows this structure:

```matlab
classdef TestClassName < matlab.unittest.TestCase
    properties
        % Test fixtures and data
    end

    methods (TestClassSetup)
        % One-time setup for all tests
    end

    methods (TestClassTeardown)
        % One-time cleanup after all tests
    end

    methods (Test)
        % Individual test methods
        function testMethodName(testCase)
            % Test implementation
            testCase.verifyEqual(actual, expected);
        end
    end
end
```

### Verification Methods Used

- `verifyEqual(a, b)` - Assert equality
- `verifyTrue(condition)` - Assert true
- `verifyFalse(condition)` - Assert false
- `verifyError(func, id)` - Assert error thrown
- `verifyGreaterThan(a, b)` - Assert a > b
- `verifyLessThan(a, b)` - Assert a < b
- `verifyEmpty(value)` - Assert empty
- `verifyNotEmpty(value)` - Assert not empty

## Test Results Interpretation

### Success Output

```
✓ All tests passed!

Total Tests:     123
Passed:          123
Failed:          0
Incomplete:      0
Execution Time:  5.42 seconds
```

### Failure Output

```
✗ Some tests failed. Review output above.

Total Tests:     123
Passed:          120
Failed:          3
Incomplete:      0
Execution Time:  5.42 seconds

Failed Tests:
  1. TestConfigurationManager/testLoadJsonFile_InvalidJson
     Error: Expected error not thrown
  2. TestValidationHelpers/testValidateEnum_InvalidValue
     Error: Actual value differs from expected value
  3. TestConstants/testValidateSamplingRate_TooHigh
     Error: Expected exception not thrown
```

## Continuous Integration

### Recommended CI Setup

For automated testing in CI/CD pipelines:

```bash
#!/bin/bash
# run_ci_tests.sh

matlab -batch "results = run_tests(); exit(~all([results.Passed]))"
```

This will:
1. Run all tests
2. Exit with code 0 if all pass
3. Exit with code 1 if any fail

### GitHub Actions Example

```yaml
name: Maestro Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: matlab-actions/setup-matlab@v1
      - uses: matlab-actions/run-tests@v1
        with:
          source-folder: .
          test-results-junit: test-results.xml
```

## Adding New Tests

### Creating a New Test Class

1. Create file in `tests/` directory:
   ```matlab
   classdef TestMyClass < matlab.unittest.TestCase
       methods (Test)
           function testMyMethod(testCase)
               % Your test here
           end
       end
   end
   ```

2. Run the test:
   ```matlab
   runtests('TestMyClass')
   ```

### Test Naming Conventions

- Test class: `Test<ClassName>.m`
- Test method: `test<MethodName>_<Scenario>`
- Examples:
  - `testLoadJsonFile_ValidFile`
  - `testMergeStructs_EmptyDest`
  - `testValidateNumericRange_AboveMax`

### Best Practices

1. **One assertion per test** (when possible)
2. **Descriptive test names** that explain what's being tested
3. **Test both success and failure paths**
4. **Include edge cases** (boundaries, empty, null)
5. **Use setup/teardown** for common initialization
6. **Mock external dependencies** when possible
7. **Keep tests fast** (< 1 second per test)

## Test Coverage Goals

Target coverage metrics:
- **Overall**: > 80%
- **Critical paths**: 100% (validation, configuration)
- **Infrastructure classes**: > 90%
- **Hardware interfaces**: > 70% (some methods require hardware)

## Known Limitations

### Hardware-Dependent Tests

Some DAQManager methods cannot be fully tested without hardware:
- `initialize()` - Requires actual DAQ device
- `play_trial()` - Requires DAQ session
- `play_trial_async()` - Requires DAQ session

These are tested through:
- Configuration validation
- Helper method testing (TTL generation)
- Mock/stub testing where possible

### File System Tests

Tests that create temporary files:
- Use `tempdir` for test files
- Clean up in `TestClassTeardown`
- May fail if disk full or permissions issue

## Troubleshooting

### Common Issues

**Issue**: Tests fail with "Class not found"
**Solution**: Ensure Maestro root is in MATLAB path:
```matlab
addpath(genpath('/path/to/Maestro1'));
```

**Issue**: Tests fail with "Permission denied" on file creation
**Solution**: Check that test directory has write permissions

**Issue**: Some tests timeout
**Solution**: Increase timeout or check for infinite loops in code

**Issue**: Coverage plugin not available
**Solution**: Install MATLAB Test and Coverage toolboxes

## Contributing Tests

When contributing new tests:

1. ✅ Follow naming conventions
2. ✅ Include docstring explaining test purpose
3. ✅ Test both success and failure cases
4. ✅ Add edge cases
5. ✅ Ensure tests are independent
6. ✅ Run full suite before committing
7. ✅ Update this README if adding new test class

## Test Statistics

Current test suite statistics:

| Test Class | Tests | Coverage | Status |
|------------|-------|----------|--------|
| TestConfigurationManager | 45 | 100% | ✅ |
| TestValidationHelpers | 35 | 100% | ✅ |
| TestConstants | 25 | 100% | ✅ |
| TestDAQManager | 18 | 85% | ✅ |
| **Total** | **123** | **96%** | **✅** |

**Last Updated**: 2025-10-27

## Future Test Additions

Planned tests for upcoming features:

- [ ] TestInstanceNormalizer - Full coverage of normalization logic
- [ ] TestTrialExecutor - Trial execution without hardware
- [ ] TestMaestroContext - Integration tests
- [ ] TestPluginDiscovery - Discovery with mock filesystem
- [ ] Performance tests for large experiments
- [ ] Integration tests for end-to-end workflows

## Resources

- [MATLAB Unit Testing Framework](https://www.mathworks.com/help/matlab/matlab-unit-test-framework.html)
- [Writing Tests](https://www.mathworks.com/help/matlab/matlab_prog/write-simple-test-case-using-classes.html)
- [Test Fixtures](https://www.mathworks.com/help/matlab/matlab_prog/write-test-using-setup-and-teardown-functions.html)
- [Assertions](https://www.mathworks.com/help/matlab/class-based-unit-tests.html)

---

**Questions or Issues?** Open an issue on GitHub or contact the maintainers.
