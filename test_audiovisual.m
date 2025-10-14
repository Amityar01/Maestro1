% Maestro/test_audiovisual.m
% Test the new audiovisual oddball paradigm without hardware

fprintf('═══════════════════════════════════════\n');
fprintf('   Testing Audiovisual Paradigm\n');
fprintf('═══════════════════════════════════════\n\n');

%% 1. Load JSON config
fprintf('STEP 1: Loading AV JSON configuration...\n');
config = jsondecode(fileread('block_templates/audiovisual_oddball_congruent.json'));
fprintf('  ✓ Loaded: %s\n', config.name);
fprintf('  ✓ Block type: %s\n', config.block_type);
fprintf('  ✓ Paradigm type: %s\n\n', config.paradigm_type);

%% 2. Build trial list
fprintf('STEP 2: Building AV trial list...\n');
trial_list = trials.builders.build_audiovisual_oddball(config);
fprintf('  ✓ Created %d trials\n', length(trial_list));

% Verify trial list structure
if isfield(trial_list(1).presentations(1), 'audio_stim') && isfield(trial_list(1).presentations(1), 'visual_stim')
    fprintf('  ✓ Trial structure contains both audio and visual fields.\n');
else
    fprintf('  ✗ ERROR: Trial structure is missing audio/visual fields.\n');
    return;
end
fprintf('\n');

%% 3. Test Stimulus Pre-generation
fprintf('STEP 3: Testing pre-generation of audio snippets...\n');
fs = 192000;
unique_audio_stims = containers.Map;
for i = 1:numel(trial_list)
    pres = trial_list(i).presentations(1);
    if isfield(pres, 'audio_stim')
        stim_key = jsonencode(pres.audio_stim);
        if ~isKey(unique_audio_stims, stim_key)
            stim = pres.audio_stim;
            waveform = generate_stimulus(stim.stim_type, stim.params, fs);
            unique_audio_stims(stim_key) = waveform;
            fprintf('  - Generated snippet for: %s\n', stim.stim_type);
        end
    end
end
fprintf('  ✓ Found and generated %d unique audio snippets.\n\n', length(unique_audio_stims));

%% 4. Test Psychtoolbox Initialization (Dry Run)
fprintf('STEP 4: Testing Psychtoolbox screen initialization...\n');
try
    [win, ~] = visual.init_screen();
    fprintf('  ✓ Screen opened successfully.\n');
    visual.close_screen();
    fprintf('  ✓ Screen closed successfully.\n\n');
catch e
    fprintf('  ✗ ERROR: Failed to initialize Psychtoolbox screen.\n');
    fprintf('    Make sure Psychtoolbox is installed and configured correctly.\n');
    rethrow(e);
end

%% Summary
fprintf('═══════════════════════════════════════\n');
fprintf('   ✓ ALL PRE-FLIGHT CHECKS PASSED!\n');
fprintf('═══════════════════════════════════════\n');
fprintf('The audiovisual paradigm is correctly configured.\n');
fprintf('Ready to test with hardware using run_experiment.m\n\n');