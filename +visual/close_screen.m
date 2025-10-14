% Maestro/+visual/close_screen.m
function close_screen()
% CLOSE_SCREEN - Closes all Psychtoolbox screens and shows the cursor.

sca; % Closes the screen
ShowCursor; % Make the mouse cursor visible again
ListenChar(0); % Restore keyboard input to the command window
fprintf('✓ Psychtoolbox screen closed.\n');

end