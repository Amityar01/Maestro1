% debug_ptb_dependencies.m
% Find out EXACTLY what DLLs are missing from Screen.mexw64

fprintf('═══════════════════════════════════════\n');
fprintf('   PTB Dependency Debugger\n');
fprintf('═══════════════════════════════════════\n\n');

%% 1. Locate Screen.mexw64
fprintf('STEP 1: Locating Screen.mexw64...\n');
screen_path = which('Screen');
if isempty(screen_path)
    error('Screen.mexw64 not found in path!');
end
fprintf('  Found: %s\n', screen_path);
fprintf('  Size: %.1f MB\n\n', dir(screen_path).bytes / 1024 / 1024);

%% 2. Check MATLAB architecture
fprintf('STEP 2: Checking MATLAB architecture...\n');
if strcmp(computer('arch'), 'win64')
    fprintf('  ✓ MATLAB is 64-bit (correct for .mexw64)\n');
else
    fprintf('  ✗ MATLAB is NOT 64-bit!\n');
    fprintf('    You need 64-bit MATLAB for this PTB version\n');
    return;
end
fprintf('  MATLAB version: %s\n\n', version);

%% 3. Try to load the MEX file and catch detailed error
fprintf('STEP 3: Attempting to load Screen.mexw64...\n');
try
    % Force load the MEX file
    Screen('Version');
    fprintf('  ✓ SUCCESS! Screen loaded fine.\n');
    fprintf('    This script should not have been needed!\n');
    return;
catch ME
    fprintf('  ✗ Failed to load\n');
    fprintf('    Error: %s\n\n', ME.message);
end

%% 4. Use Windows dependency checker
fprintf('STEP 4: Checking dependencies with system tools...\n');
fprintf('  Creating batch file to check DLL dependencies...\n');

% Create a batch file to run dumpbin (if available)
batch_file = fullfile(tempdir, 'check_ptb_deps.bat');
fid = fopen(batch_file, 'w');
fprintf(fid, '@echo off\n');
fprintf(fid, 'echo Checking for dumpbin (Visual Studio tool)...\n');
fprintf(fid, 'where dumpbin >nul 2>&1\n');
fprintf(fid, 'if %%ERRORLEVEL%% EQU 0 (\n');
fprintf(fid, '    echo Found dumpbin, checking dependencies...\n');
fprintf(fid, '    dumpbin /dependents "%s"\n', screen_path);
fprintf(fid, ') else (\n');
fprintf(fid, '    echo dumpbin not found - need Visual Studio installed\n');
fprintf(fid, ')\n');
fclose(fid);

[status, result] = system(batch_file);
fprintf('%s\n', result);

%% 5. Check for common missing DLLs manually
fprintf('\nSTEP 5: Checking for commonly required DLLs...\n');

% Common DLLs that PTB needs
required_dlls = {
    'VCRUNTIME140.dll'
    'VCRUNTIME140_1.dll'
    'MSVCP140.dll'
    'CONCRT140.dll'
    'api-ms-win-crt-runtime-l1-1-0.dll'
    'KERNEL32.dll'
    'USER32.dll'
    'GDI32.dll'
    'opengl32.dll'
};

system_path = getenv('PATH');
system_dirs = strsplit(system_path, ';');
windows_dir = getenv('SystemRoot');

for i = 1:length(required_dlls)
    dll_name = required_dlls{i};
    fprintf('  Checking %s... ', dll_name);
    
    % Check system directories
    found = false;
    search_dirs = [system_dirs, ...
                   {fullfile(windows_dir, 'System32')}, ...
                   {fullfile(windows_dir, 'SysWOW64')}];
    
    for j = 1:length(search_dirs)
        dll_path = fullfile(search_dirs{j}, dll_name);
        if exist(dll_path, 'file')
            fprintf('✓ Found in %s\n', search_dirs{j});
            found = true;
            break;
        end
    end
    
    if ~found
        fprintf('✗ NOT FOUND!\n');
    end
end

%% 6. Recommendations
fprintf('\n═══════════════════════════════════════\n');
fprintf('   DIAGNOSIS & SOLUTIONS\n');
fprintf('═══════════════════════════════════════\n\n');

fprintf('Based on the error, the most likely causes are:\n\n');

fprintf('1. MISSING VISUAL C++ REDISTRIBUTABLES (most common)\n');
fprintf('   Download and install ALL of these:\n');
fprintf('   • VC++ 2015-2022 (latest): https://aka.ms/vs/17/release/vc_redist.x64.exe\n');
fprintf('   • VC++ 2013: https://aka.ms/highdpimfc2013x64enu\n');
fprintf('   • VC++ 2012: https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe\n');
fprintf('   After installing, RESTART MATLAB and try again.\n\n');

fprintf('2. CORRUPTED PTB INSTALLATION\n');
fprintf('   Solution:\n');
fprintf('   a) Delete: C:\\Users\\amity\\Downloads\\Psychtoolbox\n');
fprintf('   b) Download: http://psychtoolbox.org/download.html#zip-files\n');
fprintf('   c) Extract to C:\\toolbox\\Psychtoolbox\n');
fprintf('   d) Run: cd(''C:\\toolbox\\Psychtoolbox''); SetupPsychtoolbox\n\n');

fprintf('3. WRONG PTB VERSION FOR YOUR MATLAB\n');
fprintf('   Your MATLAB: %s\n', version);
fprintf('   Check compatibility: http://psychtoolbox.org/requirements.html\n');
fprintf('   PTB 3.0.19 requires MATLAB R2012a or later\n\n');

fprintf('4. ANTIVIRUS/SECURITY BLOCKING\n');
fprintf('   Try temporarily disabling antivirus\n');
fprintf('   or add exception for: %s\n\n', fileparts(screen_path));

fprintf('═══════════════════════════════════════\n');
fprintf('   NEXT STEPS\n');
fprintf('═══════════════════════════════════════\n\n');
fprintf('1. Install ALL Visual C++ redistributables above (MOST IMPORTANT)\n');
fprintf('2. Restart MATLAB\n');
fprintf('3. Run: Screen(''Version'')\n');
fprintf('4. If still fails, try fresh PTB install from zip\n');
fprintf('5. If STILL fails, report your MATLAB version and I''ll dig deeper\n\n');
