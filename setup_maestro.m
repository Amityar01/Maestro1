function setup_maestro()
% SETUP_MAESTRO - Add Maestro to MATLAB path and verify installation
%
% Run this once after installing Maestro

    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════╗\n');
    fprintf('║   Maestro V2 - Setup                          ║\n');
    fprintf('╚════════════════════════════════════════════════╝\n');
    fprintf('\n');
    
    % Get current directory
    maestro_root = pwd;
    
    fprintf('Setting up Maestro in: %s\n\n', maestro_root);
    
    % Check required directories exist
    fprintf('1. Checking directory structure...\n');
    required_dirs = {'+core', '+generators', '+builders', '+engines'};
    all_exist = true;
    
    for i = 1:length(required_dirs)
        dir_path = fullfile(maestro_root, required_dirs{i});
        if exist(dir_path, 'dir')
            fprintf('   ✓ %s\n', required_dirs{i});
        else
            fprintf('   ✗ %s NOT FOUND - creating...\n', required_dirs{i});
            mkdir(dir_path);
            all_exist = false;
        end
    end
    
    % Check if MaestroContext.m exists
    fprintf('\n2. Checking core files...\n');
    context_file = fullfile(maestro_root, '+core', 'MaestroContext.m');
    if exist(context_file, 'file')
        fprintf('   ✓ MaestroContext.m found\n');
    else
        fprintf('   ✗ MaestroContext.m NOT FOUND!\n');
        fprintf('   Please make sure +core/MaestroContext.m exists\n');
        return;
    end
    
    % Add to path
    fprintf('\n3. Adding to MATLAB path...\n');
    addpath(maestro_root);
    fprintf('   ✓ Added: %s\n', maestro_root);
    
    % Save path
    fprintf('\n4. Saving path...\n');
    try
        savepath;
        fprintf('   ✓ Path saved\n');
    catch
        fprintf('   ⚠ Could not save path (permission issue)\n');
        fprintf('   Run this setup script each session, or manually save path\n');
    end
    
    % Test MaestroContext
    fprintf('\n5. Testing MaestroContext...\n');
    try
        ctx = core.MaestroContext(maestro_root);
        fprintf('   ✓ MaestroContext created successfully\n');
        
        fprintf('\n   Discovery results:\n');
        fprintf('   - Generators: %d\n', length(ctx.generators));
        fprintf('   - Builders:   %d\n', length(ctx.builders));
        fprintf('   - Engines:    %d\n', length(ctx.engines));
        
    catch ME
        fprintf('   ✗ Error creating MaestroContext:\n');
        fprintf('   %s\n', ME.message);
        return;
    end
    
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════╗\n');
    fprintf('║   ✓ Setup complete!                           ║\n');
    fprintf('╚════════════════════════════════════════════════╝\n');
    fprintf('\n');
    fprintf('Quick start:\n');
    fprintf('  ctx = core.MaestroContext();\n');
    fprintf('  ctx.list_generators();\n');
    fprintf('  ctx.list_builders();\n');
    fprintf('  ctx.list_engines();\n');
    fprintf('\n');
end