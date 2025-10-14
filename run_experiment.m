% Maestro/run_experiment.m
function run_experiment(block_json_file, device_id, out_dir)
% RUN_EXPERIMENT - Run a single block from a JSON template.

fprintf('═══════════════════════════════════════\n');
fprintf('   Maestro - Experiment Execution\n');
fprintf('═══════════════════════════════════════\n\n');

% --- 1. Load Block Configuration ---
fprintf('Loading block: %s\n', block_json_file);
config = jsondecode(fileread(block_json_file));
fprintf('  Block type: %s\n', config.block_type);
fprintf('  Name: %s\n\n', config.name);

% --- 2. Determine Paradigm Type and Branch ---
if ~isfield(config, 'paradigm_type')
    config.paradigm_type = 'audio_only';
end
fprintf('Detected paradigm type: %s\n', config.paradigm_type);

% --- 3. Initialize Hardware ---
FS = 192000;
daq_session = hardware.init_daq(device_id, FS);

% --- 4. Build Trial List ---
fprintf('Building trial list...\n');
builder_func = str2func(['trials.builders.build_' config.block_type]);
trial_list = builder_func(config);
trial_list = trials.add_timing(trial_list, config.timing);
fprintf('\n');


% =========================================================================
% --- ENGINE 1: AUDIO-ONLY (COMPILE-THEN-EXECUTE) ---
% =========================================================================
if strcmp(config.paradigm_type, 'audio_only')
    fprintf('Running with high-precision audio-only engine.\n');
    [ao_waveform, do_waveform, trial_log, ttl_log] = build_segment_waveforms(trial_list, FS);
    loopback_timetable = hardware.play_block(daq_session, ao_waveform, do_waveform);
    loopback_data = loopback_timetable.Dev1_ai0;
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    save_segment_data(out_dir, ao_waveform, do_waveform, loopback_data, trial_log, ttl_log, config);

% =========================================================================
% --- ENGINE 2: AUDIOVISUAL (REAL-TIME LOOP) ---
% =========================================================================
elseif strcmp(config.paradigm_type, 'audiovisual')
    fprintf('Running with audiovisual real-time engine.\n');
    try
        [win, ~] = visual.init_screen();
        ifi = Screen('GetFlipInterval', win);
        
        fprintf('Pre-generating unique audio stimuli...\n');
        unique_audio_stims = containers.Map;
        for i = 1:numel(trial_list)
            pres = trial_list(i).presentations(1);
            if isfield(pres, 'audio_stim')
                stim_key = jsonencode(pres.audio_stim);
                if ~isKey(unique_audio_stims, stim_key)
                    stim = pres.audio_stim;
                    waveform = generate_stimulus(stim.stim_type, stim.params, FS);
                    unique_audio_stims(stim_key) = waveform;
                end
            end
        end
        fprintf('  ✓ Found %d unique audio snippets.\n\n', length(unique_audio_stims));
        
        ttl_log = table();
        current_sample = 1;
        
        fprintf('Starting real-time trial loop...\n');
        for k = 1:numel(trial_list)
            trial = trial_list(k);
            pres = trial.presentations(1);
            
            % --- Fixation is temporarily removed ---
            % visual.draw_fixation(win);
            
            if isfield(pres, 'visual_stim')
                visual.draw_flash(win, pres.visual_stim.params);
            end
            
            audio_waveform = [];
            if isfield(pres, 'audio_stim')
                stim_key = jsonencode(pres.audio_stim);
                audio_waveform = unique_audio_stims(stim_key);
            end
            
            ttl_pulse = ones(round(FS * 0.002), 1);
            do_channel = zeros(size(audio_waveform));
            ttl_end = min(length(ttl_pulse), length(do_channel));
            do_channel(1:ttl_end) = ttl_pulse(1:ttl_end);
            output_data = [audio_waveform, do_channel];
            
            vbl = Screen('Flip', win);
            [~] = readwrite(daq_session, output_data);
            
            event_name = sprintf('T%d_P1_%s', k, trial.trial_type);
            ttl_log = [ttl_log; {current_sample, vbl, event_name}];
            current_sample = current_sample + length(audio_waveform);
            
            % --- Clear the screen after the flash ---
            stim_duration_sec = pres.audio_stim.params.dur_ms / 1000;
            % visual.draw_fixation(win); % Also removed here
            Screen('Flip', win, vbl + stim_duration_sec - (ifi / 2));
            
            WaitSecs(trial.iti_sec);
        end
        
        fprintf('✓ Trial loop complete.\n');
        visual.close_screen();
        ttl_log.Properties.VariableNames = {'SampleIndex', 'VBLTimestamp', 'Event'};
        if ~exist(out_dir, 'dir'), mkdir(out_dir); end
        save_realtime_data(out_dir, struct2table(trial_list), ttl_log, config);
        
    catch e
        fprintf('\n! An error occurred during the real-time loop.\n');
        visual.close_screen();
        rethrow(e);
    end
end

hardware.release(daq_session);
fprintf('\n✓ Block execution complete!\n');
fprintf('  Data saved to: %s\n', out_dir);

end

function save_realtime_data(out_dir, trial_log, ttl_log, cfg)
fprintf('Saving real-time data to %s...\n', out_dir);
writetable(trial_log, fullfile(out_dir, 'trials.csv'));
writetable(ttl_log, fullfile(out_dir, 'ttl_events.csv'));
fid = fopen(fullfile(out_dir, 'config.json'), 'w');
fprintf(fid, '%s', jsonencode(cfg, "PrettyPrint", true));
fclose(fid);
fprintf('✓ Data saved.\n');
end