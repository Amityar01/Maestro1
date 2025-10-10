% +presets/pilot.m
function cfg = pilot()
% PILOT - Pilot preset: presence locking + omission test

cfg = struct();
cfg.name = "Pilot";
cfg.description = "Presence locking followed by omission test";

% --- Segment 1: Presence Lock (100% S2) ---
cfg.segments(1).name = "Lock";
cfg.segments(1).n_trials = 10;
cfg.segments(1).ratios.p_O1 = 1;
cfg.segments(1).ratios.p_O2 = 0;
cfg.segments(1).ratios.p_omit = 0;

% --- Segment 2: Omission Test (90% S2, 10% Omit) ---
cfg.segments(2).name = "Test";
cfg.segments(2).n_trials = 50;
cfg.segments(2).ratios.p_O1 = 0.9;
cfg.segments(2).ratios.p_O2 = 0.0;
cfg.segments(2).ratios.p_omit = 0.10;

% --- Common Parameters ---
% CORRECTED LINE: "train" is now "pip_train" for consistency
cfg.stim_params.s1_type = "pip_train";
cfg.stim_params.s2_type = "noise";
cfg.stim_params.s1_freq = 4000;
cfg.stim_params.s2_freq = 8000;

cfg.timing.delay_ms = 500;
cfg.timing.iti_min_sec = 1.0;
cfg.timing.iti_max_sec = 2.0;

% --- Constraints ---
cfg.constraints.max_omit_run = 2;
end