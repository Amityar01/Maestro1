% Maestro/save_segment_data.m
function save_segment_data(out_dir, ao, do, loopback, trial_log, ttl_log, cfg)
% SAVE_SEGMENT_DATA - Saves all outputs from a segment run

fprintf('Saving data to %s...\n', out_dir);

% Save waveforms
audiowrite(fullfile(out_dir, 'AO_commanded.wav'), ao, 192000);
audiowrite(fullfile(out_dir, 'AI_loopback.wav'), loopback, 192000);

% Save logs as CSV
writetable(trial_log, fullfile(out_dir, 'trials.csv'));
writetable(ttl_log, fullfile(out_dir, 'ttl_events.csv'));

% Save config as JSON (requires MATLAB 2016b+ with jsonencode)
try
    fid = fopen(fullfile(out_dir, 'config.json'), 'w');
    fprintf(fid, '%s', jsonencode(cfg, "PrettyPrint", true));
    fclose(fid);
catch
    warning('Could not save config as JSON. Saving as .mat file instead.');
    save(fullfile(out_dir, 'config.mat'), 'cfg');
end

fprintf('✓ Data saved.\n');
end