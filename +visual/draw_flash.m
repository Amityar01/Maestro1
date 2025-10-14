% Maestro/+visual/draw_flash.m
function draw_flash(win, params)
% DRAW_FLASH - Draws a parameter-controlled, rotated bar stimulus.
%
% This version uses a robust method for visual angle calculation and the
% modern 'DrawTexture' command for reliable drawing.

% --- Parameters ---
viewing_distance_cm = 60;

% --- Screen Geometry ---
[~, screen_height_px] = Screen('WindowSize', win);
screenNumber = Screen('WindowScreenNumber', win);
[~, screen_height_mm] = Screen('DisplaySize', screenNumber);
screen_height_cm = screen_height_mm / 10;
px_per_cm = screen_height_px / screen_height_cm;

% --- Convert Degrees to Pixels ---
size_cm = 2 * viewing_distance_cm * tan(deg2rad(params.size_deg / 2));
size_px = size_cm * px_per_cm;

offset_cm = viewing_distance_cm * tan(deg2rad(params.position_deg));
offset_px = offset_cm * px_per_cm;

% --- Define Rectangle for Drawing ---
[xCenter, yCenter] = RectCenter(Screen('Rect', win));
final_center_x = xCenter + offset_px(1);
final_center_y = yCenter + offset_px(2);

% Define the destination rectangle based on its size and final center point
destRect = [0 0 size_px(1) size_px(2)];
destRect = CenterRectOnPointd(destRect, final_center_x, final_center_y);

% --- Draw the Rotated Rectangle using the Modern Method ---
% Create a simple texture of the correct color.
flashTexture = Screen('MakeTexture', win, repmat(uint8(params.color(:)), 1, 10));

% Draw the texture, passing the rotation angle directly to the function.
Screen('DrawTexture', win, flashTexture, [], destRect, params.orientation_deg);

end