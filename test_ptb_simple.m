% test_ptb_simple.m
% Simple test to see what's actually happening with PTB

fprintf('Testing Psychtoolbox availability...\n\n');

% Test 1: Check if Screen is in path
fprintf('Test 1: Is Screen function available?\n');
if exist('Screen', 'file')
    fprintf('  ✓ Screen function found in path\n');
    fprintf('    Location: %s\n', which('Screen'));
else
    fprintf('  ✗ Screen function not found\n');
end
fprintf('\n');

% Test 2: Try calling Screen with verbose error
fprintf('Test 2: Trying Screen(''Version'')...\n');
try
    v = Screen('Version');
    fprintf('  ✓ Success!\n');
    fprintf('    Version: %s\n', v.version);
catch ME
    fprintf('  ✗ Error occurred:\n');
    fprintf('    Message: %s\n', ME.message);
    fprintf('    Identifier: %s\n', ME.identifier);
    if ~isempty(ME.stack)
        fprintf('    Location: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
    end
end
fprintf('\n');

% Test 3: Try simpler Screen call
fprintf('Test 3: Trying Screen(''Screens'')...\n');
try
    screens = Screen('Screens');
    fprintf('  ✓ Success!\n');
    fprintf('    Found %d screen(s): %s\n', length(screens), mat2str(screens));
catch ME
    fprintf('  ✗ Error occurred:\n');
    fprintf('    Message: %s\n', ME.message);
end
fprintf('\n');

% Test 4: Check PsychToolbox root
fprintf('Test 4: PsychToolbox root directory\n');
try
    ptbRoot = PsychtoolboxRoot;
    fprintf('  ✓ PsychToolbox root: %s\n', ptbRoot);
catch
    fprintf('  ✗ PsychtoolboxRoot function not found\n');
end
fprintf('\n');

fprintf('Diagnosis complete. Share this output.\n');
