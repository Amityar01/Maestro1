% Quick debug script to test validation
config = struct();
config.symbols = {
    struct('symbol', 'A', 'stimulus_ref', 'tone1')
};
config.patterns = {
    struct('name', 'AAAB', 'probability', 1.0, 'elements', {...
        struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'A'), struct('symbol', 'B')})
};

fprintf('Symbols: ');
disp(config.symbols);
fprintf('Patterns: ');
disp(config.patterns);
% Use getfield to avoid comma-separated list expansion
temp_elems = getfield(config.patterns{1}, 'elements');
fprintf('Pattern elements type: %s\n', class(temp_elems));
fprintf('Pattern elements length: %d\n', length(temp_elems));
fprintf('First element: ');
disp(temp_elems{1});
fprintf('Last element (should have symbol B): ');
disp(temp_elems{4});

[valid, errors] = v1.validation.CustomValidators.validate_local_global_config(config);
fprintf('Valid: %d\n', valid);
fprintf('Number of errors: %d\n', length(errors));
if ~isempty(errors)
    fprintf('Error message: %s\n', errors{1}.message);
end
