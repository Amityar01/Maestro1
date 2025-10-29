# Maestro v1 Unit Tests

Comprehensive unit test suite for v1 architecture using MATLAB's unittest framework.

## Test Classes

### TestNumericFieldValidator
Tests for numeric field validation (scalar and distributions):
- Scalar values (implicit and explicit)
- Uniform distribution validation
- Normal distribution validation
- Log-uniform distribution validation
- Categorical distribution validation
- Scope validation
- Error detection

**Tests**: 22 test methods

### TestCustomValidators
Tests for domain-specific validators:
- Probability sum validation
- Unique label validation
- Oddball configuration validation
- Local-Global configuration validation
- Error reporting

**Tests**: 16 test methods

### TestSampling
Tests for sampling framework:
- RNG stream management and determinism
- Distribution samplers (uniform, normal, loguniform, categorical)
- Scope management (per_trial, per_block, per_session)
- NumericFieldSampler integration
- Struct sampling
- Reproducibility verification

**Tests**: 28 test methods

### TestGenerators
Tests for generator framework and tone.simple:
- GeneratorContext creation and resource access
- RNG stream access for deterministic generation
- Field sampling integration
- tone.simple generator: basic generation, determinism, frequency accuracy
- Envelope application (linear, cosine, exponential)
- Level scaling (linear_0_1, dB_FS)
- Sampling integration with jittered parameters
- Metadata output (peak, RMS, hash, realized_params)
- Phase control and stereo routing
- Validation and clipping detection

**Tests**: 19 test methods

### TestPatternBuilder
Tests for pattern builder core:
- Single and multiple elements per trial expansion
- Absolute onset computation (trial timing + ITI)
- IOI (inter-onset interval) resolution
- Refractory period enforcement
- Element indexing (0-based within trials)
- Role assignment (cue/outcome preservation)
- Symbol tracking (for Local-Global patterns)
- Empty trial handling (omissions)
- Table structure validation
- Trial window computation

**Tests**: 18 test methods

### TestOddballAdapter
Tests for oddball paradigm adapter:
- Trial plan generation from oddball configs
- IID selection mode (true random sampling)
- Balanced shuffle mode (exact proportions)
- CSV preset mode (predefined sequences)
- Constraint enforcement (max consecutive deviants/standards)
- Multi-token oddball (2-tone, 3-tone)
- TTL code assignment
- Probability distribution handling
- Element timing and duration
- Determinism (seed-based reproducibility)
- Metadata preservation
- Validation and error handling

**Tests**: 22 test methods

### TestLocalGlobalAdapter
Tests for Local-Global paradigm adapter:
- Trial plan generation with multi-element trials
- Pattern expansion (AAAB → 4 elements)
- IOI timing (inter-onset interval within patterns)
- Pattern selection (IID, balanced shuffle)
- Symbol tracking (A/B in each element)
- Multi-pattern designs (AAAB, AAAA, BBBA)
- Element structure and timing
- Variable pattern lengths (4-element, 5-element)
- Token duration handling
- Determinism (seed-based reproducibility)
- Metadata preservation
- Validation and error handling

**Tests**: 21 test methods

## Running Tests

### Run All Tests
```matlab
run_tests_v1
```

### Run Specific Test Class
```matlab
run_tests_v1('TestNumericFieldValidator')
run_tests_v1('TestCustomValidators')
run_tests_v1('TestSampling')
run_tests_v1('TestGenerators')
run_tests_v1('TestPatternBuilder')
run_tests_v1('TestOddballAdapter')
run_tests_v1('TestLocalGlobalAdapter')
```

### Run with Verbose Output
```matlab
run_tests_v1('verbose')
```

### Run with Code Coverage
```matlab
run_tests_v1('coverage')
```

### Combine Options
```matlab
run_tests_v1('TestSampling', 'verbose')
```

## Using MATLAB's Test Runner Directly

```matlab
% Run all tests
runtests('tests/v1')

% Run specific test
runtests('tests/v1/TestNumericFieldValidator')

% Run with coverage
import matlab.unittest.TestRunner;
import matlab.unittest.plugins.CodeCoveragePlugin;

suite = testsuite('tests/v1');
runner = TestRunner.withTextOutput;
runner.addPlugin(CodeCoveragePlugin.forFolder('+v1'));
results = runner.run(suite);
```

## Test Coverage

Current coverage (as of latest commit):
- **Validation Framework**: ~95% coverage
- **Sampling Framework**: ~95% coverage

Target coverage: >90% for all modules

## Adding New Tests

### Creating a New Test Class

```matlab
classdef TestMyFeature < matlab.unittest.TestCase
    methods (Test)
        function testBasicFunctionality(testCase)
            result = my_feature();
            testCase.verifyTrue(result);
        end

        function testEdgeCase(testCase)
            result = my_feature('edge_case');
            testCase.verifyEqual(result, expected_value);
        end
    end
end
```

Save to `tests/v1/TestMyFeature.m`

### Test Method Setup

Use `TestMethodSetup` for initialization before each test:

```matlab
properties
    sampler
end

methods (TestMethodSetup)
    function createSampler(testCase)
        testCase.sampler = v1.sampling.NumericFieldSampler(...);
    end
end
```

### Common Assertions

```matlab
% Equality
testCase.verifyEqual(actual, expected)
testCase.verifyEqual(actual, expected, 'AbsTol', 0.01)

% Boolean
testCase.verifyTrue(condition)
testCase.verifyFalse(condition)

% Comparisons
testCase.verifyGreaterThan(value, threshold)
testCase.verifyLessThan(value, threshold)

% Empty/Not Empty
testCase.verifyEmpty(value)
testCase.verifyNotEmpty(value)

% Errors
testCase.verifyError(@() func(), 'ErrorID')
```

## Continuous Integration

These tests are designed to run in CI/CD pipelines:

```bash
# Run tests in batch mode (exits with error code if tests fail)
matlab -batch "run_tests_v1"
```

## Test Organization

```
tests/v1/
├── README.md                         (this file)
├── TestNumericFieldValidator.m      (22 tests)
├── TestCustomValidators.m           (16 tests)
├── TestSampling.m                   (28 tests)
├── TestGenerators.m                 (19 tests)
├── TestPatternBuilder.m             (18 tests)
├── TestOddballAdapter.m             (22 tests)
└── TestLocalGlobalAdapter.m         (21 tests)
```

Total: **146 unit tests**

## Milestones

- ✅ M1: Validation framework tests (38 tests)
- ✅ M2: Sampling framework tests (28 tests)
- ✅ M2: Generator tests (19 tests)
- ✅ M3: Pattern builder tests (18 tests)
- ✅ M4: Paradigm adapter tests (43 tests)
- ⏳ M5: Compiler tests (pending)
- ⏳ M6: DAQ Engine tests (pending)

## Debugging Failed Tests

If tests fail, run with verbose output:
```matlab
run_tests_v1('TestSampling', 'verbose')
```

Or debug interactively:
```matlab
% Set breakpoint in test method
dbstop in TestSampling at 142

% Run the test
runtests('tests/v1/TestSampling')
```

## Best Practices

1. **One assertion per test** (when possible) - makes failures easier to diagnose
2. **Descriptive test names** - `testUniformRangeValidation` not `test1`
3. **Setup/teardown** - Use `TestMethodSetup` and `TestMethodTeardown`
4. **Deterministic tests** - Always use fixed seeds for RNG-based tests
5. **Fast tests** - Each test should run in < 1 second
6. **Independent tests** - Tests should not depend on each other

## See Also

- Demo scripts: `test_validation_v1.m`, `test_sampling_v1.m` (interactive demonstrations)
- MATLAB unittest documentation: `doc matlab.unittest.TestCase`
- Architecture docs: `ARCHITECTURE_V1.md`
