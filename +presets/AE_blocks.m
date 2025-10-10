% +presets/AE_blocks.m
function cfg = AE_blocks()
% AE_BLOCKS - The full 5-block probabilistic experiment

cfg = struct();
cfg.name = "AE_Blocks_5_Parametric";
cfg.description = "Parametric sweep of outcome probabilities";

% Define the 5 probability structures
ratios(1).p_O1 = 0.90; ratios(1).p_O2 = 0.05; % Block A
ratios(2).p_O1 = 0.75; ratios(2).p_O2 = 0.20; % Block B
ratios(3).p_O1 = 0.475; ratios(3).p_O2 = 0.475;% Block C
ratios(4).p_O1 = 0.20; ratios(4).p_O2 = 0.75; % Block D
ratios(5).p_O1 = 0.05; ratios(5).p_O2 = 0.90; % Block E

% All blocks have 5% omissions
for i = 1:5, ratios(i).p_omit = 0.05; end

% Build the 5 segments
block_names = ["A_90_5", "B_75_20", "C_50_50", "D_20_75", "E_5_90"];
for i = 1:5
    cfg.segments(i).name = block_names(i);
    cfg.segments(i).n_trials = 800; % Example, can be changed
    cfg.segments(i).ratios = ratios(i);
end

% --- Common Parameters ---
cfg.stim_params.s1_type = "single_tone";
cfg.stim_params.s2_type = "noise";

cfg.timing.delay_ms = 500;
cfg.timing.iti_min_sec = 2.0;
cfg.timing.iti_max_sec = 5.0;

% --- Constraints ---
cfg.constraints.max_omit_run = 3;
end