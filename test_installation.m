% TEST_INSTALLATION - Quick test to verify Maestro is installed correctly
%
% Run this script to check if the core system is working

fprintf('\n');
fprintf('╔════════════════════════════════════════════════╗\n');
fprintf('║   Maestro V2 - Installation Test              ║\n');
fprintf('╚════════════════════════════════════════════════╝\n');
fprintf('\n');

% Check if we're in the right directory
if ~exist('+core', 'dir')
    error('Please run this script from the maestro_v2 root directory');
end

% Make sure current directory is on path
addpath(pwd);

% Test 1: Can we create MaestroContext?
fprintf('1. Testing MaestroContext creation...\n');
try
    ctx = core.MaestroContext();
    fprintf('   ✓ MaestroContext created\n');
catch ME
    fprintf('   ✗ FAILED: %s\n', ME.message);
    fprintf('\n');
    fprintf('   Try running: setup_maestro\n');
    return;
end

% Test 2: Check core functions exist by checking files
fprintf('\n2. Checking core functions...\n');
core_files = {
    '+core/discover_generators.m'
    '+core/discover_builders.m'
    '+core/discover_engines.m'
    '+core/validate_parameters.m'
    '+core/resolve_randomization.m'
};

all_exist = true;
for i = 1:length(core_files)
    filepath = core_files{i};
    if exist(filepath, 'file')
        fprintf('   ✓ %s\n', filepath);
    else
        fprintf('   ✗ %s NOT FOUND\n', filepath);
        all_exist = false;
    end
end

if ~all_exist
    fprintf('\n   Some core functions are missing!\n');
    return;
end

% Test 3: Test core functionality
fprintf('\n3. Testing core functionality...\n');
try
    % Test parameter validation
    param_schema = struct();
    param_schema.test_param = struct(...
        'type', 'float', ...
        'required', true, ...
        'constraints', struct('min', 0, 'max', 100) ...
    );
    
    params = struct('test_param', 50);
    [valid, errors] = core.validate_parameters(params, param_schema);
    assert(valid, 'Parameter validation failed');
    fprintf('   ✓ Parameter validation works\n');
    
    % Test randomization
    rand_spec = struct('type', 'random_uniform', 'min', 0, 'max', 1);
    is_rand = core.is_randomization_spec(rand_spec);
    assert(is_rand, 'Randomization detection failed');
    fprintf('   ✓ Randomization detection works\n');
    
    % Test randomization resolution
    params = struct('test_param', rand_spec);
    context = struct('rng_seed', 42);
    resolved = core.resolve_randomization(params, context);
    assert(isnumeric(resolved.test_param), 'Randomization resolution failed');
    fprintf('   ✓ Randomization resolution works\n');
    
catch ME
    fprintf('   ✗ Tests failed: %s\n', ME.message);
    return;
end

fprintf('\n');
fprintf('╔════════════════════════════════════════════════╗\n');
fprintf('║   ✓ Installation successful!                  ║\n');
fprintf('╚════════════════════════════════════════════════╝\n');
fprintf('\n');
fprintf('Maestro core system is ready!\n\n');
fprintf('Next steps:\n');
fprintf('  1. Create your first generator:\n');
fprintf('     - Add to +generators/+audio/+tone/\n');
fprintf('     - Create schema.json and generator.m\n');
fprintf('  2. Create your first builder:\n');
fprintf('     - Add to +builders/+oddball/\n');
fprintf('     - Create template.schema.json and builder.m\n');
fprintf('  3. Create your first engine:\n');
fprintf('     - Add to +engines/+audio_only/\n');
fprintf('     - Create schema.json and engine.m\n');
fprintf('\n');
fprintf('Quick test:\n');
fprintf('  ctx = core.MaestroContext();\n');
fprintf('  ctx.list_generators();\n');
fprintf('\n');