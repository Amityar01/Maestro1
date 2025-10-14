% maestro2/+trials/+builders/build_multi_oddball.m
function trial_list = build_multi_oddball(config)
% BUILD_MULTI_ODDBALL - Create trial list with multiple deviant types
%
% config should contain:
%   .n_trials - total number of trials
%   .standard - struct with name, stim_type, params, and optionally probability
%   .deviants - array of structs, each with name, stim_type, params, and optionally probability
%   .order - 'random' or 'predetermined'
%   For predetermined:
%     .sequence - array of numbers [1,1,2,1,3,...] where 1=standard, 2=first deviant, etc.
%     OR
%     .sequence_file - path to text file with sequence

n_trials = config.n_trials;

% Determine trial types based on order mode
if strcmp(config.order, 'predetermined')
    % Load sequence from file or use inline array
    if isfield(config, 'sequence_file')
        sequence = load_sequence_from_file(config.sequence_file);
    elseif isfield(config, 'sequence')
        sequence = config.sequence;
    else
        error('Predetermined order requires either "sequence" or "sequence_file"');
    end
    
    trial_types = build_predetermined_sequence(sequence, config, n_trials);
    
elseif strcmp(config.order, 'random')
    % Use probabilities to randomly assign trial types
    trial_types = build_random_sequence(config, n_trials);
    
else
    error('Unknown order type: %s. Use "random" or "predetermined"', config.order);
end

% Build the trial list
trial_list = struct();

for k = 1:n_trials
    trial_list(k).trial_num = k;
    trial_list(k).block_type = 'multi_oddball';
    trial_list(k).trial_type = trial_types{k};
    
    % Find the stimulus definition for this trial type
    if strcmp(trial_types{k}, config.standard.name)
        % Standard trial
        trial_list(k).presentations(1).stim_type = config.standard.stim_type;
        trial_list(k).presentations(1).params = config.standard.params;
        trial_list(k).metadata.is_deviant = false;
        trial_list(k).metadata.deviant_type = '';
    else
        % Deviant trial - find which one
        dev_idx = find_deviant_by_name(config.deviants, trial_types{k});
        if dev_idx == 0
            error('Trial type "%s" not found in standard or deviants', trial_types{k});
        end
        
        trial_list(k).presentations(1).stim_type = config.deviants(dev_idx).stim_type;
        trial_list(k).presentations(1).params = config.deviants(dev_idx).params;
        trial_list(k).metadata.is_deviant = true;
        trial_list(k).metadata.deviant_type = trial_types{k};
    end
    
    % Presentation timing
    trial_list(k).presentations(1).onset_ms = 0;
end

% Report
n_standard = sum(strcmp(trial_types, config.standard.name));
fprintf('✓ Built multi-oddball block: %d trials\n', n_trials);
fprintf('  - Standard (%s): %d trials (%.1f%%)\n', config.standard.name, ...
    n_standard, 100*n_standard/n_trials);
for i = 1:length(config.deviants)
    n_dev = sum(strcmp(trial_types, config.deviants(i).name));
    fprintf('  - Deviant (%s): %d trials (%.1f%%)\n', config.deviants(i).name, ...
        n_dev, 100*n_dev/n_trials);
end
end

function sequence = load_sequence_from_file(filepath)
% Load sequence from text file
% Supports: one number per line OR comma-separated

fid = fopen(filepath, 'r');
if fid == -1
    error('Could not open sequence file: %s', filepath);
end

content = fread(fid, '*char')';
fclose(fid);

% Try comma-separated first
if contains(content, ',')
    sequence = str2num(content); %#ok<ST2NM>
else
    % One number per line
    lines = strsplit(strtrim(content), {'\n', '\r\n', '\r'});
    sequence = zeros(1, length(lines));
    for i = 1:length(lines)
        if ~isempty(strtrim(lines{i}))
            sequence(i) = str2double(lines{i});
        end
    end
end

fprintf('  ✓ Loaded sequence from file: %s (%d trials)\n', filepath, length(sequence));
end

function trial_types = build_predetermined_sequence(sequence, config, n_trials)
% Convert numeric sequence to trial type names
% 1 = standard, 2 = first deviant, 3 = second deviant, etc.

% Handle length mismatch
if length(sequence) < n_trials
    % Repeat pattern
    n_reps = ceil(n_trials / length(sequence));
    sequence = repmat(sequence(:), n_reps, 1);
    fprintf('  ✓ Sequence pattern repeated to fill %d trials\n', n_trials);
elseif length(sequence) > n_trials
    fprintf('  ✓ Sequence truncated from %d to %d trials\n', length(sequence), n_trials);
end

sequence = sequence(1:n_trials);

% Convert numbers to trial type names
trial_types = cell(n_trials, 1);
for k = 1:n_trials
    num = sequence(k);
    if num == 1
        trial_types{k} = config.standard.name;
    elseif num >= 2 && num <= length(config.deviants) + 1
        trial_types{k} = config.deviants(num-1).name;
    else
        error('Invalid sequence number %d at position %d. Must be 1-%d', ...
            num, k, length(config.deviants)+1);
    end
end
end

function trial_types = build_random_sequence(config, n_trials)
% Use probabilities to randomly assign trials

trial_types = cell(n_trials, 1);

% Calculate number of each type
n_standard = round(config.standard.probability * n_trials);
trial_types(1:n_standard) = {config.standard.name};

idx = n_standard + 1;
for i = 1:length(config.deviants)
    n_dev = round(config.deviants(i).probability * n_trials);
    trial_types(idx:idx+n_dev-1) = {config.deviants(i).name};
    idx = idx + n_dev;
end

% Fill any remaining slots with standard (due to rounding)
for i = idx:n_trials
    trial_types{i} = config.standard.name;
end

% Shuffle
shuffle_idx = randperm(n_trials);
trial_types = trial_types(shuffle_idx);
end

function idx = find_deviant_by_name(deviants, name)
% Find deviant index by name
idx = 0;
for i = 1:length(deviants)
    if strcmp(deviants(i).name, name)
        idx = i;
        return;
    end
end
end