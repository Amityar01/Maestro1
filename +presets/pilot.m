% +presets/pilot.m
function cfg = pilot()
% PILOT - Pilot preset: presence locking + omission test

cfg = struct();
cfg.name = "Pilot";
cfg.description = "Presence locking followed by omission test";

% --- Segment 1: Presence Lock (100% S2) ---
cfg.segments(1).name = "Lock";
cfg.segments(1).n_trials = 300;
cfg.segments(1).ratios.p_O1 = 0; % Not used, but good practice
cfg.segments(1).ratios.p_O2 = 1.0;
cfg.segments(1).ratios.p_omit = 0;

% --- Segment 2: Omission Test (90% S2, 10% Omit) ---
cfg.segments(2).name = "Test";
cfg.segments(2).n_trials = 800;
cfg.segments(2).ratios.p_O1 = 0;
cfg.segments(2).ratios.p_O2 = 0.90;
cfg.segments(2).ratios.p_omit = 0.10;

% --- Common Parameters for the entire experiment ---
cfg.stim_params.s1_type = "single_tone"; % or "pip_train"
cfg.stim_params.s2_type = "tone";        % or "noise"

cfg.timing.delay_ms = 500;
cfg.timing.iti_min_sec = 2.0;
cfg.timing.iti_max_sec = 5.0;

% --- Constraints ---
cfg.constraints.max_omit_run = 2;
end