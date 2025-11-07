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
% Use cell array wrapper to capture all elements
pattern = config.patterns{1};
temp_elems_cell = {pattern.elements};
fprintf('Captured %d items in cell wrapper\n', length(temp_elems_cell));

if length(temp_elems_cell) > 1
    temp_elems = temp_elems_cell;
else
    temp_elems = temp_elems_cell{1};
end

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
