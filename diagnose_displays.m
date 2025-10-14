% diagnose_displays.m
% Diagnostic script to identify and characterize displays for visual stimuli
%
% This script will:
% 1. List all available displays
% 2. Show resolution, refresh rate, and physical properties
% 3. Help identify the secondary display for stimulus presentation
% 4. Calculate pixels-per-degree for accurate visual angle conversion
% 5. Run basic tests to verify Psychtoolbox functionality

fprintf('═══════════════════════════════════════════════════════\n');
fprintf('   Display Diagnostics for Visual Stimuli\n');
fprintf('═══════════════════════════════════════════════════════\n\n');

%% 1. Check if Psychtoolbox is available
fprintf('STEP 1: Checking Psychtoolbox installation...\n');
try
    Screen('Version');
    ptb_version = Screen('Version');
    fprintf('  ✓ Psychtoolbox found\n');
    fprintf('    Version: %d.%d.%d\n', ptb_version.major, ptb_version.minor, ptb_version.point);
    fprintf('    Date: %s\n\n', ptb_version.date);
catch
    error('Psychtoolbox not found! Install from: http://psychtoolbox.org/');
end

%% 2. Query all available screens
fprintf('STEP 2: Querying available displays...\n');
screens = Screen('Screens');
n_screens = length(screens);
fprintf('  Found %d display(s): [%s]\n\n', n_screens, num2str(screens));

%% 3. Get detailed info for each screen
all_info = struct();

for i = 1:n_screens
    screen_num = screens(i);
    fprintf('═══ SCREEN %d ═══\n', screen_num);
    
    % Resolution
    [width_px, height_px] = Screen('WindowSize', screen_num);
    fprintf('  Resolution: %d × %d pixels\n', width_px, height_px);
    
    % Refresh rate
    refresh_rate = Screen('FrameRate', screen_num);
    if refresh_rate == 0
        refresh_rate = 60; % Default assumption
        fprintf('  Refresh Rate: ~%d Hz (estimated)\n', refresh_rate);
    else
        fprintf('  Refresh Rate: %.2f Hz\n', refresh_rate);
    end
    
    % Frame duration
    frame_duration_ms = 1000 / refresh_rate;
    fprintf('  Frame Duration: %.2f ms\n', frame_duration_ms);
    
    % Physical screen dimensions (if available)
    [width_mm, height_mm] = Screen('DisplaySize', screen_num);
    if width_mm > 0 && height_mm > 0
        fprintf('  Physical Size: %.1f × %.1f mm (%.1f × %.1f inches)\n', ...
            width_mm, height_mm, width_mm/25.4, height_mm/25.4);
        
        % Calculate PPI
        ppi_h = width_px / (width_mm / 25.4);
        ppi_v = height_px / (height_mm / 25.4);
        fprintf('  Pixels Per Inch: %.1f (H) × %.1f (V)\n', ppi_h, ppi_v);
    else
        fprintf('  Physical Size: Not available from system\n');
        width_mm = NaN;
        height_mm = NaN;
    end
    
    % Store info
    all_info(i).screen_num = screen_num;
    all_info(i).width_px = width_px;
    all_info(i).height_px = height_px;
    all_info(i).refresh_rate = refresh_rate;
    all_info(i).frame_duration_ms = frame_duration_ms;
    all_info(i).width_mm = width_mm;
    all_info(i).height_mm = height_mm;
    
    fprintf('\n');
end

%% 4. Calculate visual angle conversions
fprintf('STEP 4: Visual Angle Calculations\n');
viewing_distance_cm = 60; % From paper
fprintf('  Using viewing distance: %d cm\n\n', viewing_distance_cm);

for i = 1:n_screens
    screen_num = screens(i);
    fprintf('  Screen %d:\n', screen_num);
    
    if ~isnan(all_info(i).width_mm)
        % Calculate pixels per degree of visual angle
        % tan(θ) = opposite / adjacent
        % For 1 degree: opposite = viewing_distance * tan(1°)
        
        screen_width_cm = all_info(i).width_mm / 10;
        screen_height_cm = all_info(i).height_mm / 10;
        
        % Degrees subtended by full screen
        deg_horizontal = 2 * atand(screen_width_cm / 2 / viewing_distance_cm);
        deg_vertical = 2 * atand(screen_height_cm / 2 / viewing_distance_cm);
        
        fprintf('    Screen subtends: %.1f° (H) × %.1f° (V)\n', ...
            deg_horizontal, deg_vertical);
        
        % Pixels per degree
        px_per_deg_h = all_info(i).width_px / deg_horizontal;
        px_per_deg_v = all_info(i).height_px / deg_vertical;
        
        fprintf('    Pixels per degree: %.1f (H) × %.1f (V)\n', ...
            px_per_deg_h, px_per_deg_v);
        
        % Store
        all_info(i).px_per_deg_h = px_per_deg_h;
        all_info(i).px_per_deg_v = px_per_deg_v;
        
        % Calculate dimensions for paper's stimuli
        flash_width_deg = 0.28;
        flash_height_deg = 1.2;
        
        flash_width_px = round(flash_width_deg * px_per_deg_h);
        flash_height_px = round(flash_height_deg * px_per_deg_v);
        
        fprintf('    Flash dimensions (%.2f° × %.2f°): %d × %d pixels\n', ...
            flash_width_deg, flash_height_deg, flash_width_px, flash_height_px);
        
        all_info(i).flash_width_px = flash_width_px;
        all_info(i).flash_height_px = flash_height_px;
    else
        fprintf('    Cannot calculate visual angles (physical size unknown)\n');
        fprintf('    You will need to manually measure your screen\n');
        all_info(i).px_per_deg_h = NaN;
        all_info(i).px_per_deg_v = NaN;
    end
    
    fprintf('\n');
end

%% 5. Identify recommended display
fprintf('STEP 5: Display Recommendations\n');
if n_screens == 1
    fprintf('  Only one display found (Screen %d)\n', screens(1));
    fprintf('  This will be used for stimulus presentation\n');
    recommended_screen = screens(1);
else
    fprintf('  Multiple displays found:\n');
    fprintf('  - Screen 0 is typically the PRIMARY display (experimenter)\n');
    fprintf('  - Screen 1+ are SECONDARY displays (subject/stimulus)\n\n');
    fprintf('  RECOMMENDATION: Use Screen %d for stimulus presentation\n', max(screens));
    recommended_screen = max(screens);
end
fprintf('\n');

%% 6. Test basic PTB functionality
fprintf('STEP 6: Testing Psychtoolbox Drawing\n');
fprintf('  This will open a test window on Screen %d for 3 seconds\n', recommended_screen);
fprintf('  Press any key to continue, or Ctrl+C to skip...\n');
pause;

try
    % Suppress PTB warnings for cleaner output
    Screen('Preference', 'SuppressAllWarnings', 1);
    Screen('Preference', 'VisualDebugLevel', 0);
    Screen('Preference', 'SkipSyncTests', 1); % For testing only!
    
    fprintf('  Opening window...\n');
    [window, window_rect] = Screen('OpenWindow', recommended_screen, [128 128 128]);
    
    % Get actual refresh rate
    ifi = Screen('GetFlipInterval', window);
    actual_refresh = 1 / ifi;
    fprintf('  ✓ Window opened\n');
    fprintf('  Measured refresh rate: %.2f Hz (%.2f ms per frame)\n', ...
        actual_refresh, ifi * 1000);
    
    % Draw a test rectangle (simulating a flash)
    center_x = window_rect(3) / 2;
    center_y = window_rect(4) / 2;
    
    if ~isnan(all_info(recommended_screen == screens).flash_width_px)
        rect_width = all_info(recommended_screen == screens).flash_width_px;
        rect_height = all_info(recommended_screen == screens).flash_height_px;
    else
        rect_width = 20;  % Fallback
        rect_height = 80;
    end
    
    test_rect = [center_x - rect_width/2, ...
                 center_y - rect_height/2, ...
                 center_x + rect_width/2, ...
                 center_y + rect_height/2];
    
    % Draw vertical bar
    Screen('FillRect', window, [255 255 255], test_rect);
    
    % Draw fixation cross
    cross_size = 20;
    Screen('DrawLine', window, [0 0 0], center_x - cross_size, center_y, ...
        center_x + cross_size, center_y, 2);
    Screen('DrawLine', window, [0 0 0], center_x, center_y - cross_size, ...
        center_x, center_y + cross_size, 2);
    
    Screen('Flip', window);
    fprintf('  ✓ Drew test rectangle + fixation cross\n');
    fprintf('  White bar represents a "flash" stimulus\n');
    fprintf('  Black cross represents fixation point\n');
    
    % Wait 3 seconds
    WaitSecs(3);
    
    % Clean up
    Screen('CloseAll');
    fprintf('  ✓ Test complete\n\n');
    
catch ME
    Screen('CloseAll');
    fprintf('  ✗ Error during test: %s\n\n', ME.message);
end

%% 7. Summary and recommendations
fprintf('═══════════════════════════════════════════════════════\n');
fprintf('   SUMMARY\n');
fprintf('═══════════════════════════════════════════════════════\n\n');

fprintf('Recommended Configuration:\n');
fprintf('  • Stimulus Screen: %d\n', recommended_screen);
fprintf('  • Resolution: %d × %d\n', all_info(recommended_screen == screens).width_px, ...
    all_info(recommended_screen == screens).height_px);
fprintf('  • Refresh Rate: %.1f Hz\n', all_info(recommended_screen == screens).refresh_rate);

if ~isnan(all_info(recommended_screen == screens).px_per_deg_h)
    fprintf('  • Pixels per degree: %.1f (H) × %.1f (V)\n', ...
        all_info(recommended_screen == screens).px_per_deg_h, ...
        all_info(recommended_screen == screens).px_per_deg_v);
    fprintf('  • Flash size: %d × %d pixels\n', ...
        all_info(recommended_screen == screens).flash_width_px, ...
        all_info(recommended_screen == screens).flash_height_px);
else
    fprintf('\n  ⚠ WARNING: Physical screen dimensions not available!\n');
    fprintf('  Please manually measure your screen:\n');
    fprintf('    1. Measure width and height in cm\n');
    fprintf('    2. Calculate pixels per degree using:\n');
    fprintf('       px_per_deg = resolution_px / (2 * atand(size_cm/2/60))\n\n');
end

fprintf('\nTiming Constraints:\n');
fprintf('  • Frame duration: %.2f ms\n', all_info(recommended_screen == screens).frame_duration_ms);
fprintf('  • Target flash duration: 100 ms = %d frames\n', ...
    round(100 / all_info(recommended_screen == screens).frame_duration_ms));
fprintf('  • Target ISI: 400 ms = %d frames\n', ...
    round(400 / all_info(recommended_screen == screens).frame_duration_ms));

fprintf('\nNext Steps:\n');
fprintf('  1. Save these parameters for visual stimulus configuration\n');
fprintf('  2. If physical size is unknown, measure your screen manually\n');
fprintf('  3. Create visual stimulus generation functions (+visual/ package)\n');
fprintf('  4. Integrate with existing audio + DAQ system\n\n');

%% 8. Save results
save_file = 'display_config.mat';
save(save_file, 'all_info', 'recommended_screen', 'viewing_distance_cm');
fprintf('✓ Display information saved to: %s\n\n', save_file);

fprintf('═══════════════════════════════════════════════════════\n');
fprintf('   Diagnostics Complete!\n');
fprintf('═══════════════════════════════════════════════════════\n');
