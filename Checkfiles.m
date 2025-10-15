% CHECK_FILES - Verify all core files exist
%
% Run this if you're having installation problems

fprintf('Checking Maestro installation...\n\n');

root = pwd;
fprintf('Current directory: %s\n\n', root);

% List of required files
required_files = {
    '+core/MaestroContext.m'
    '+core/discover_generators.m'
    '+core/discover_builders.m'
    '+core/discover_engines.m'
    '+core/discover_instances.m'
    '+core/discover_experiments.m'
    '+core/load_stimulus_library.m'
    '+core/validate_parameters.m'
    '+core/validate_parameter_value.m'
    '+core/validate_constraints.m'
    '+core/is_randomization_spec.m'
    '+core/validate_randomization_spec.m'
    '+core/resolve_randomization.m'
    '+core/validate_generator_output.m'
    '+core/validate_block_instance.m'
    '+core/validate_trial_list.m'
    '+core/validate_experiment.m'
};

fprintf('Checking core files:\n');
all_present = true;
for i = 1:length(required_files)
    filepath = fullfile(root, required_files{i});
    if exist(filepath, 'file')
        fprintf('  ✓ %s\n', required_files{i});
    else
        fprintf('  ✗ %s MISSING\n', required_files{i});
        all_present = false;
    end
end

fprintf('\n');

if all_present
    fprintf('All files present!\n');
    fprintf('\nNext: run setup_maestro\n');
else
    fprintf('Some files are missing. Please ensure all core files are created.\n');
end