% Maestro/+visual/draw_fixation.m
function draw_fixation(win)
% DRAW_FIXATION - Draws a fixation cross at the center of the screen.
%
% Uses a black color as described in the paper for the AV rabbit task.

% Define the color for the cross (black)
crossColor = [0 0 0];

% Define the size of the cross in pixels
crossSizePx = 20;

% Define the line width
lineWidthPx = 4;

% Get the center of the screen
[xCenter, yCenter] = RectCenter(Screen('Rect', win));

% Define the coordinates for the lines of the cross
xCoords = [-crossSizePx, crossSizePx, 0, 0];
yCoords = [0, 0, -crossSizePx, crossSizePx];
allCoords = [xCoords; yCoords];

% Draw the cross
Screen('DrawLines', win, allCoords, lineWidthPx, crossColor, [xCenter yCenter], 2);

end