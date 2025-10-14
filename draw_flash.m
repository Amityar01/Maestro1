% Maestro/+visual/draw_flash.m
function draw_flash(win, params)
% DRAW_FLASH - Draw a tilted bar stimulus using Psychtoolbox.

% --- Sanity check to confirm this updated file is running ---
fprintf('--- Running UPDATED draw_flash.m ---\n');

% win: Psychtoolbox window handle
% params: Struct with visual parameters:
%   .orientation_deg: Tilt angle in degrees from vertical
%   .size_deg: [width, height] in degrees of visual angle
%   .position_deg: [x, y] center position from screen center
%   .color: [R, G, B] color vector (0-255)

% --- Screen and stimulus geometry (assumes setup from paper) ---
viewing_distance_cm = 60;
[width_px, ~] = Screen('WindowSize', win);

% --- FIXED: Get screenNumber directly from the window handle ---
screenNumber = Screen('WindowScreenNumber', win);
[width_cm, ~] = Screen('DisplaySize', screenNumber);
px_per_cm = width_px / width_cm;

% Convert degrees of visual angle to pixels
size_px = tan(deg2rad(params.size_deg / 2)) * 2 * viewing_distance_cm * px_per_cm;
position_px = tan(deg2rad(params.position_deg / 2)) * 2 * viewing_distance_cm * px_per_cm;

% Screen center
[xCenter, yCenter] = RectCenter(Screen('Rect', win));
destRect = [0 0 size_px(1) size_px(2)];
destRect = CenterRectOnPointd(destRect, xCenter + position_px(1), yCenter + position_px(2));

% Create a texture for the bar stimulus
barTexture = Screen('MakeTexture', win, ...
    repmat(uint8(params.color'), 1, round(size_px(1))) );

% Draw the texture with the specified orientation
Screen('DrawTexture', win, barTexture, [], destRect, params.orientation_deg);

end