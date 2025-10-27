function test_logging()
% TEST_LOGGING - Test the logging system
%
% Creates a minimal session and verifies all files are created correctly

    fprintf('Testing Maestro Logging System\n');
    fprintf('═══════════════════════════════════════════════\n\n');
    
    % Create test session
    fprintf('Creating session logger...\n');
    
    test_experiment = struct();
    test_experiment.experiment_id = 'test_001';
    test_experiment.global_settings = struct('sampling_rate_hz', 192000);
    test_experiment.sequence = struct('block_id', 'test_block');
    
    session_logger = core.logging.SessionLogger('TEST', 1, 'Test User', test_experiment);
    fprintf('  ✓ Session created: %s\n', session_logger.session_id);
    fprintf('  ✓ Directory: %s\n', session_logger.session_dir);
    fprintf('\n');
    
    % Test block logging
    fprintf('Testing block logger...\n');
    
    block_config = struct();
    block_config.builder_type = 'test';
    block_config.n_trials = 5;
    
    block_logger = session_logger.start_block(1, block_config);
    fprintf('  ✓ Block 1 started\n');
    
    % Log some test trials
    for i = 1:5
        trial_data = struct();
        trial_data.trial_index = i;
        trial_data.block_index = 1;
        trial_data.trial_type = 'test';
        trial_data.freq_hz = 1000;
        trial_data.dur_ms = 50;
        trial_data.level_db = 60;
        trial_data.onset_time_sec = (i-1) * 1.5;
        trial_data.trigger_sent_sec = (i-1) * 1.5 + 0.001;
        trial_data.iti_sec = 1.0;
        
        block_logger.log_trial(trial_data);
    end
    fprintf('  ✓ Logged 5 trials\n');
    
    session_logger.end_block(block_logger, 5);
    fprintf('  ✓ Block 1 ended\n');
    fprintf('\n');
    
    % Test notes
    fprintf('Testing notes...\n');
    session_logger.add_note('This is a test note');
    fprintf('  ✓ Note added\n');
    fprintf('\n');
    
    % Finalize
    fprintf('Finalizing session...\n');
    session_logger.finalize('completed');
    fprintf('  ✓ Session finalized\n');
    fprintf('\n');
    
    % Verify files
    fprintf('Verifying files...\n');
    
    session_dir = session_logger.session_dir;
    
    files_to_check = {
        'metadata.json',
        'sequence.json',
        'events.log',
        'notes.txt',
        fullfile('block_001', 'block_config.json'),
        fullfile('block_001', 'stimuli.csv')
    };
    
    all_ok = true;
    for i = 1:length(files_to_check)
        file_path = fullfile(session_dir, files_to_check{i});
        if exist(file_path, 'file')
            fprintf('  ✓ %s\n', files_to_check{i});
        else
            fprintf('  ✗ %s MISSING\n', files_to_check{i});
            all_ok = false;
        end
    end
    
    fprintf('\n');
    
    if all_ok
        fprintf('═══════════════════════════════════════════════\n');
        fprintf('✓ All tests passed!\n');
        fprintf('═══════════════════════════════════════════════\n');
        fprintf('\nSession directory: %s\n', session_dir);
        
        % Show sample of stimuli.csv
        fprintf('\nSample from stimuli.csv:\n');
        stimuli_file = fullfile(session_dir, 'block_001', 'stimuli.csv');
        data = readtable(stimuli_file);
        disp(data);
    else
        fprintf('✗ Some tests failed\n');
    end
end