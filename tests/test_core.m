function test_core()
% TEST_CORE - Test core system functionality
%
% Run this to verify the core system is working

    fprintf('Testing Maestro Core System\n');
    fprintf('═══════════════════════════════════════════════\n\n');
    
    % Test 1: MaestroContext creation
    test_context_creation();
    
    % Test 2: Discovery functions
    test_discovery();
    
    % Test 3: Validation functions
    test_validation();
    
    fprintf('\n✓ All core tests passed!\n');
end

function test_context_creation()
    fprintf('Test 1: Creating MaestroContext...\n');
    
    try
        ctx = MaestroContext();
        assert(isa(ctx, 'MaestroContext'), 'Context not created');
        fprintf('  ✓ MaestroContext created successfully\n');
    catch ME
        fprintf('  ✗ Failed: %s\n', ME.message);
        rethrow(ME);
    end
end

function test_discovery()
    fprintf('\nTest 2: Testing discovery functions...\n');
    
    % These will return empty maps if directories don't exist yet
    % That's OK - we're just testing the functions work
    
    try
        gens = core.discover_generators('+generators');
        fprintf('  ✓ discover_generators works (found %d)\n', length(gens));
        
        builders = core.discover_builders('+builders');
        fprintf('  ✓ discover_builders works (found %d)\n', length(builders));
        
        engines = core.discover_engines('+engines');
        fprintf('  ✓ discover_engines works (found %d)\n', length(engines));
        
        stims = core.load_stimulus_library('stimuli');
        fprintf('  ✓ load_stimulus_library works (found %d)\n', length(stims));
        
    catch ME
        fprintf('  ✗ Failed: %s\n', ME.message);
        rethrow(ME);
    end
end

function test_validation()
    fprintf('\nTest 3: Testing validation functions...\n');
    
    % Test parameter validation
    param_schema = struct();
    param_schema.test_param = struct(...
        'type', 'float', ...
        'required', true, ...
        'constraints', struct('min', 0, 'max', 100) ...
    );
    
    % Valid parameters
    params = struct('test_param', 50);
    [valid, errors] = core.validate_parameters(params, param_schema);
    assert(valid, 'Valid params marked as invalid');
    fprintf('  ✓ validate_parameters works (valid case)\n');
    
    % Invalid parameters (missing required)
    params = struct();
    [valid, errors] = core.validate_parameters(params, param_schema);
    assert(~valid, 'Invalid params marked as valid');
    assert(~isempty(errors), 'No errors reported');
    fprintf('  ✓ validate_parameters works (invalid case)\n');
    
    % Test randomization detection
    rand_spec = struct('type', 'random_uniform', 'min', 0, 'max', 1);
    assert(core.is_randomization_spec(rand_spec), 'Failed to detect rand spec');
    fprintf('  ✓ is_randomization_spec works\n');
    
    % Test randomization resolution
    params = struct('test_param', rand_spec);
    context = struct('rng_seed', 42);
    resolved = core.resolve_randomization(params, context);
    assert(isnumeric(resolved.test_param), 'Randomization not resolved');
    assert(resolved.test_param >= 0 && resolved.test_param <= 1, ...
        'Resolved value out of range');
    fprintf('  ✓ resolve_randomization works\n');
end