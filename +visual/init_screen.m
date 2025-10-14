% Maestro/+visual/init_screen.m
function [win, winRect] = init_screen()
% INIT_SCREEN - Initialize Psychtoolbox screen for visual stimuli.
%
% Opens a window, sets basic parameters, and returns the window handle.

% Suppress verbose Psychtoolbox messages
Screen('Preference', 'Verbosity', 1);
Screen('Preference', 'SkipSyncTests', 1); % Use 1 for debugging, 0 for real experiments

% Find the screen number for the external monitor (if any)
screens = Screen('Screens');
screenNumber = max(screens);

% Define black and gray colors
black = BlackIndex(screenNumber);
grey = black + (WhiteIndex(screenNumber) - black) * 0.3; % 30% grey background

% Open an on-screen window and color it grey
[win, winRect] = PsychImaging('OpenWindow', screenNumber, grey);

% Set the blend function for anti-aliasing
Screen('BlendFunction', win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

% Set text font and size for instructions (optional)
Screen('TextFont', win, 'Ariel');
Screen('TextSize', win, 36);

% Hide the mouse cursor
HideCursor;

fprintf('✓ Psychtoolbox screen initialized.\n');

end