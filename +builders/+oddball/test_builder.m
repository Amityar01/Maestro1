function test_builder()
% TEST_BUILDER - Test oddball builder
%
% Run this to verify the oddball builder works correctly

    fprintf('Testing oddball builder...\n');
    fprintf('════════════════════════════════════════════════\n\n');
    
    test_basic_building();
    test_deviant_ratio();
    test_trial_structure();
    test_no_consecutive_constraint();
    test_iti_values();
    
    fprintf('\n✓ All oddball builder tests passed!\n\n');
end

function test_basic_building()
    fprintf('1. Testing basic building...\n');
    
    instance = create_test_instance();
    context = struct('sampling_rate_hz', 192000);
    
    trial_list = builders.oddball.build(instance, context);
    
    % Should generate correct number of trials
    assert(length(trial_list) == instance.parameters.n_trials, ...
        'Wrong number of trials');
    
    fprintf('   ✓ Basic building works\n');
end

function test_deviant_ratio()
    fprintf('2. Testing deviant ratio...\n');
    
    instance = create_test_instance();
    instance.parameters.n_trials = 1000;  % Large N for statistical test
    instance.parameters.deviant_probability = 0.2;
    
    context = struct('sampling_rate_hz', 192000);
    trial_list = builders.oddball.build(instance, context);
    
    % Count deviants
    n_deviants = sum([trial_list.metadata.is_deviant]);
    actual_p = n_deviants / length(trial_list);
    
    % Should be close to requested probability (within 5%)
    assert(abs(actual_p - 0.2) < 0.05, ...
        sprintf('Deviant probability %.2f far from requested 0.2', actual_p));
    
    fprintf('   ✓ Deviant ratio correct (%.1f%%)\n', 100*actual_p);
end

function test_trial_structure()
    fprintf('3. Testing trial structure...\n');
    
    instance = create_test_instance();
    context = struct('sampling_rate_hz', 192000);
    trial_list = builders.oddball.build(instance, context);
    
    % Check first trial structure
    trial = trial_list(1);
    
    % Must have required fields
    assert(isfield(trial, 'trial_id'), 'Missing trial_id');
    assert(isfield(trial, 'trial_num'), 'Missing trial_num');
    assert(isfield(trial, 'trial_type'), 'Missing trial_type');
    assert(isfield(trial, 'presentations'), 'Missing presentations');
    assert(isfield(trial, 'iti_sec'), 'Missing iti_sec');
    assert(isfield(trial, 'metadata'), 'Missing metadata');
    
    % Each trial should have 1 presentation
    for i = 1:length(trial_list)
        assert(length(trial_list(i).presentations) == 1, ...
            sprintf('Trial %d should have 1 presentation', i));
    end
    
    % Trial numbers should be sequential
    for i = 1:length(trial_list)
        assert(trial_list(i).trial_num == i, ...
            sprintf('Trial %d has wrong trial_num', i));
    end
    
    fprintf('   ✓ Trial structure correct\n');
end

function test_no_consecutive_constraint()
    fprintf('4. Testing no_consecutive_deviants constraint...\n');
    
    instance = create_test_instance();
    instance.parameters.n_trials = 100;
    instance.parameters.deviant_probability = 0.3;
    instance.parameters.order_constraint = 'no_consecutive_deviants';
    
    context = struct('sampling_rate_hz', 192000, 'rng_seed', 42);
    trial_list = builders.oddball.build(instance, context);
    
    % Check no consecutive deviants
    has_consecutive = false;
    for i = 1:length(trial_list)-1
        if trial_list(i).metadata.is_deviant && ...
           trial_list(i+1).metadata.is_deviant
            has_consecutive = true;
            break;
        end
    end
    
    assert(~has_consecutive, 'Found consecutive deviants');
    
    fprintf('   ✓ No consecutive deviants constraint satisfied\n');
end

function test_iti_values()
    fprintf('5. Testing ITI values...\n');
    
    instance = create_test_instance();
    instance.parameters.iti_min_sec = 1.2;
    instance.parameters.iti_max_sec = 1.8;
    
    context = struct('sampling_rate_hz', 192000);
    trial_list = builders.oddball.build(instance, context);
    
    % Check all ITI values are within bounds
    iti_values = [trial_list.iti_sec];
    
    assert(all(iti_values >= 1.2), 'Some ITI values below minimum');
    assert(all(iti_values <= 1.8), 'Some ITI values above maximum');
    
    fprintf('   ✓ ITI values within bounds [%.1f, %.1f] sec\n', ...
        min(iti_values), max(iti_values));
end

function instance = create_test_instance()
    % Create a test instance for oddball builder
    
    instance = struct();
    instance.instance_id = 'test_oddball';
    instance.builder_type = 'oddball';
    instance.builder_version = '1.0.0';
    
    instance.parameters = struct();
    instance.parameters.n_trials = 50;
    instance.parameters.deviant_probability = 0.15;
    
    instance.parameters.standard_stimulus = struct(...
        'generator', 'tone', ...
        'version', '1.0.0', ...
        'parameters', struct('freq_hz', 1000, 'dur_ms', 50, 'level_db', 60, 'ramp_ms', 5) ...
    );
    
    instance.parameters.deviant_stimulus = struct(...
        'generator', 'tone', ...
        'version', '1.0.0', ...
        'parameters', struct('freq_hz', 2000, 'dur_ms', 50, 'level_db', 60, 'ramp_ms', 5) ...
    );
    
    instance.parameters.order_constraint = 'random';
    instance.parameters.iti_min_sec = 1.0;
    instance.parameters.iti_max_sec = 2.0;
    
    instance.metadata = struct();
end