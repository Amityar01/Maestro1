classdef CompilerCore < handle
    % CompilerCore - Compiles element tables into SequenceFiles
    %
    % The compiler is the final stage of the compilation pipeline.
    % It converts element tables (from PatternBuilderCore) into
    % executable SequenceFiles ready for DAQ playback.
    %
    % Pipeline:
    %   element_table → audio generation → TTL injection → packaging → SequenceFile
    %
    % Contract:
    %   - Input: element_table, stimulus_library, fs_hz, context
    %   - Output: SequenceFile struct (audio, ttl, events, metadata)
    %   - Deterministic: same inputs → same audio
    %   - Provenance: full hash and metadata tracking
    %
    % Example:
    %   compiler = v1.compilation.CompilerCore();
    %   seq_file = compiler.compile(element_table, stimulus_library, 48000, context);

    properties (Constant)
        TTL_PULSE_SAMPLES = 10;  % TTL pulse width in samples
        MIN_BUFFER_MS = 1000;     % Minimum buffer size (1 second)
    end

    methods
        function seq_file = compile(obj, element_table, stimulus_library, fs_hz, context)
            % Compile element table into SequenceFile
            %
            % Args:
            %   element_table: Element table from PatternBuilderCore
            %   stimulus_library: Map of stimulus_ref → stimulus definition
            %   fs_hz: Sampling rate in Hz
            %   context: GeneratorContext with RNG, sampler, etc.
            %
            % Returns:
            %   seq_file: SequenceFile struct with fields:
            %     - audio: Audio buffer [samples × channels] (float32)
            %     - ttl: TTL code buffer [samples × 1] (uint8)
            %     - events: Events table with sample_index, time_ms, codes
            %     - trial_table: Trial-level metadata
            %     - element_table: Element-level metadata
            %     - manifest: Provenance and metadata

            fprintf('Compiling element table → SequenceFile...\n');

            % Compute buffer size
            buffer_samples = obj.compute_buffer_size(element_table, fs_hz);
            fprintf('  Buffer size: %d samples (%.2f s)\n', buffer_samples, buffer_samples/fs_hz);

            % Determine number of channels (from first stimulus)
            n_channels = obj.determine_n_channels(element_table, stimulus_library);
            fprintf('  Channels: %d\n', n_channels);

            % Initialize audio and TTL buffers
            audio = zeros(buffer_samples, n_channels, 'single');
            ttl = zeros(buffer_samples, 1, 'uint8');

            % Generate audio and inject TTL codes
            events_data = cell(height(element_table), 5);  % Pre-allocate events

            fprintf('  Generating audio for %d elements...\n', height(element_table));

            for i = 1:height(element_table)
                element = element_table(i, :);

                % Get stimulus definition
                stimulus_ref = element.stimulus_ref{1};
                if ~isKey(stimulus_library, stimulus_ref)
                    error('CompilerCore:UnknownStimulus', ...
                        'Stimulus not found in library: %s', stimulus_ref);
                end
                stimulus_def = stimulus_library(stimulus_ref);

                % Generate audio for this element
                [element_audio, ~] = obj.generate_element_audio(stimulus_def, context);

                % Compute sample index for placement
                onset_sample = round(element.absolute_onset_ms / 1000 * fs_hz) + 1;

                % Place audio in buffer
                element_samples = size(element_audio, 1);
                end_sample = onset_sample + element_samples - 1;

                if end_sample <= buffer_samples
                    audio(onset_sample:end_sample, :) = audio(onset_sample:end_sample, :) + element_audio;
                else
                    warning('CompilerCore:ElementTruncated', ...
                        'Element %d extends beyond buffer, truncating', i);
                    available_samples = buffer_samples - onset_sample + 1;
                    audio(onset_sample:buffer_samples, :) = audio(onset_sample:buffer_samples, :) + ...
                        element_audio(1:available_samples, :);
                end

                % Inject TTL code
                if ismember('ttl_code', element_table.Properties.VariableNames)
                    ttl_code = element.ttl_code;
                else
                    ttl_code = i;  % Default: element index
                end

                pulse_end = min(onset_sample + obj.TTL_PULSE_SAMPLES - 1, buffer_samples);
                ttl(onset_sample:pulse_end) = ttl_code;

                % Record event
                events_data{i, 1} = onset_sample;
                events_data{i, 2} = element.absolute_onset_ms;
                events_data{i, 3} = element.trial_index;
                events_data{i, 4} = element.element_index;
                events_data{i, 5} = ttl_code;
            end

            fprintf('  Audio generation complete.\n');

            % Build events table
            events = table(...
                cell2mat(events_data(:, 1)), ...
                cell2mat(events_data(:, 2)), ...
                cell2mat(events_data(:, 3)), ...
                cell2mat(events_data(:, 4)), ...
                cell2mat(events_data(:, 5)), ...
                'VariableNames', {'sample_index', 'time_ms', 'trial_index', ...
                                 'element_index', 'code'});

            % Build trial table
            trial_table = obj.build_trial_table(element_table);

            % Compute audio hash for provenance
            audio_hash = obj.compute_audio_hash(audio);

            % Build manifest
            manifest = struct();
            manifest.version = 'v1.0';
            manifest.fs_hz = fs_hz;
            manifest.n_channels = n_channels;
            manifest.n_trials = height(trial_table);
            manifest.n_elements = height(element_table);
            manifest.duration_samples = buffer_samples;
            manifest.duration_ms = buffer_samples / fs_hz * 1000;
            manifest.compiled_at = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            manifest.audio_hash = audio_hash;

            % Package SequenceFile
            seq_file = struct();
            seq_file.audio = audio;
            seq_file.ttl = ttl;
            seq_file.events = events;
            seq_file.trial_table = trial_table;
            seq_file.element_table = element_table;
            seq_file.manifest = manifest;

            fprintf('Compilation complete. Duration: %.2f s\n', manifest.duration_ms / 1000);
        end

        function buffer_samples = compute_buffer_size(obj, element_table, fs_hz)
            % Compute required buffer size in samples
            %
            % Args:
            %   element_table: Element table
            %   fs_hz: Sampling rate
            %
            % Returns:
            %   buffer_samples: Buffer size in samples

            if isempty(element_table)
                % Empty table: use minimum buffer
                buffer_samples = round(obj.MIN_BUFFER_MS / 1000 * fs_hz);
                return;
            end

            % Find last element end time
            last_onset = max(element_table.absolute_onset_ms);
            last_duration = element_table.duration_ms(element_table.absolute_onset_ms == last_onset);
            last_duration = last_duration(1);  % In case of ties

            total_duration_ms = last_onset + last_duration + 100;  % Add 100ms padding

            % Ensure minimum buffer size
            total_duration_ms = max(total_duration_ms, obj.MIN_BUFFER_MS);

            % Convert to samples
            buffer_samples = ceil(total_duration_ms / 1000 * fs_hz);
        end

        function n_channels = determine_n_channels(obj, element_table, stimulus_library)
            % Determine number of output channels
            %
            % Args:
            %   element_table: Element table
            %   stimulus_library: Stimulus library
            %
            % Returns:
            %   n_channels: Number of channels

            if isempty(element_table)
                n_channels = 2;  % Default stereo
                return;
            end

            % Get first stimulus
            first_stimulus_ref = element_table.stimulus_ref{1};
            if ~isKey(stimulus_library, first_stimulus_ref)
                n_channels = 2;  % Default
                return;
            end

            stimulus_def = stimulus_library(first_stimulus_ref);

            % Get channels from routing
            if isfield(stimulus_def, 'routing') && isfield(stimulus_def.routing, 'channels')
                channels = stimulus_def.routing.channels;
                n_channels = max(channels) + 1;  % 0-indexed
            else
                n_channels = 2;  % Default stereo
            end
        end

        function [audio, metadata] = generate_element_audio(obj, stimulus_def, context)
            % Generate audio for a single element
            %
            % Args:
            %   stimulus_def: Stimulus definition struct
            %   context: GeneratorContext
            %
            % Returns:
            %   audio: Audio buffer [samples × channels]
            %   metadata: Generation metadata

            % Dispatch to appropriate generator based on stimulus type
            switch stimulus_def.type
                case 'tone.simple'
                    generator = v1.generators.ToneSimpleGenerator();
                    [audio, metadata] = generator.generate(stimulus_def, context);

                case 'noise.bandpass'
                    generator = v1.generators.NoiseBandpassGenerator();
                    [audio, metadata] = generator.generate(stimulus_def, context);

                case 'click.train.fixed'
                    generator = v1.generators.ClickTrainFixedGenerator();
                    [audio, metadata] = generator.generate(stimulus_def, context);

                case 'silence'
                    generator = v1.generators.SilenceGenerator();
                    [audio, metadata] = generator.generate(stimulus_def, context);

                otherwise
                    error('CompilerCore:UnsupportedStimulus', ...
                        'Unsupported stimulus type: %s', stimulus_def.type);
            end
        end

        function trial_table = build_trial_table(obj, element_table)
            % Build trial table from element table
            %
            % Args:
            %   element_table: Element table
            %
            % Returns:
            %   trial_table: Trial-level metadata table

            if isempty(element_table)
                % Empty trial table with proper column structure
                trial_table = table([], {}, [], ...
                    'VariableNames', {'trial_index', 'label', 'n_elements'});
                return;
            end

            % Get unique trials
            [unique_trials, ~, trial_groups] = unique(element_table.trial_index);
            n_trials = length(unique_trials);

            trial_indices = unique_trials;
            labels = cell(n_trials, 1);
            n_elements = zeros(n_trials, 1);

            for i = 1:n_trials
                trial_elements = element_table(trial_groups == i, :);
                labels{i} = trial_elements.label{1};  % First element's label
                n_elements(i) = height(trial_elements);
            end

            trial_table = table(trial_indices, labels, n_elements, ...
                               'VariableNames', {'trial_index', 'label', 'n_elements'});
        end

        function hash_str = compute_audio_hash(obj, audio)
            % Compute SHA-256 hash of audio buffer
            %
            % Args:
            %   audio: Audio buffer
            %
            % Returns:
            %   hash_str: SHA-256 hash as hex string

            % Convert audio to bytes
            audio_bytes = typecast(audio(:), 'uint8');

            % Compute SHA-256 hash
            hash_obj = java.security.MessageDigest.getInstance('SHA-256');
            hash_obj.update(audio_bytes);
            hash_bytes = hash_obj.digest();

            % Convert to hex string
            hash_str = '';
            for i = 1:length(hash_bytes)
                hash_str = [hash_str, sprintf('%02x', typecast(hash_bytes(i), 'uint8'))];
            end
        end

        function write_hdf5(obj, seq_file, filepath)
            % Write SequenceFile to HDF5 file
            %
            % Args:
            %   seq_file: SequenceFile struct
            %   filepath: Output HDF5 file path

            fprintf('Writing SequenceFile to HDF5: %s\n', filepath);

            % Delete existing file
            if exist(filepath, 'file')
                delete(filepath);
            end

            % Write audio dataset
            h5create(filepath, '/audio', size(seq_file.audio), 'Datatype', 'single');
            h5write(filepath, '/audio', seq_file.audio);

            % Write TTL dataset
            h5create(filepath, '/ttl', size(seq_file.ttl), 'Datatype', 'uint8');
            h5write(filepath, '/ttl', seq_file.ttl);

            % Write manifest as attributes
            h5writeatt(filepath, '/', 'version', seq_file.manifest.version);
            h5writeatt(filepath, '/', 'fs_hz', seq_file.manifest.fs_hz);
            h5writeatt(filepath, '/', 'n_channels', seq_file.manifest.n_channels);
            h5writeatt(filepath, '/', 'n_trials', seq_file.manifest.n_trials);
            h5writeatt(filepath, '/', 'n_elements', seq_file.manifest.n_elements);
            h5writeatt(filepath, '/', 'duration_samples', seq_file.manifest.duration_samples);
            h5writeatt(filepath, '/', 'duration_ms', seq_file.manifest.duration_ms);
            h5writeatt(filepath, '/', 'compiled_at', seq_file.manifest.compiled_at);
            h5writeatt(filepath, '/', 'audio_hash', seq_file.manifest.audio_hash);

            % Write events table (as separate datasets)
            h5create(filepath, '/events/sample_index', size(seq_file.events.sample_index), 'Datatype', 'int64');
            h5write(filepath, '/events/sample_index', seq_file.events.sample_index);

            h5create(filepath, '/events/time_ms', size(seq_file.events.time_ms), 'Datatype', 'double');
            h5write(filepath, '/events/time_ms', seq_file.events.time_ms);

            h5create(filepath, '/events/trial_index', size(seq_file.events.trial_index), 'Datatype', 'int64');
            h5write(filepath, '/events/trial_index', seq_file.events.trial_index);

            h5create(filepath, '/events/element_index', size(seq_file.events.element_index), 'Datatype', 'int64');
            h5write(filepath, '/events/element_index', seq_file.events.element_index);

            h5create(filepath, '/events/code', size(seq_file.events.code), 'Datatype', 'uint8');
            h5write(filepath, '/events/code', seq_file.events.code);

            fprintf('SequenceFile written successfully.\n');
        end

        function seq_file = read_hdf5(obj, filepath)
            % Read SequenceFile from HDF5 file
            %
            % Args:
            %   filepath: HDF5 file path
            %
            % Returns:
            %   seq_file: SequenceFile struct

            fprintf('Reading SequenceFile from HDF5: %s\n', filepath);

            % Read audio
            audio = h5read(filepath, '/audio');

            % Read TTL
            ttl = h5read(filepath, '/ttl');

            % Read manifest
            manifest = struct();
            manifest.version = h5readatt(filepath, '/', 'version');
            manifest.fs_hz = h5readatt(filepath, '/', 'fs_hz');
            manifest.n_channels = h5readatt(filepath, '/', 'n_channels');
            manifest.n_trials = h5readatt(filepath, '/', 'n_trials');
            manifest.n_elements = h5readatt(filepath, '/', 'n_elements');
            manifest.duration_samples = h5readatt(filepath, '/', 'duration_samples');
            manifest.duration_ms = h5readatt(filepath, '/', 'duration_ms');
            manifest.compiled_at = h5readatt(filepath, '/', 'compiled_at');
            manifest.audio_hash = h5readatt(filepath, '/', 'audio_hash');

            % Read events
            events = table();
            events.sample_index = h5read(filepath, '/events/sample_index');
            events.time_ms = h5read(filepath, '/events/time_ms');
            events.trial_index = h5read(filepath, '/events/trial_index');
            events.element_index = h5read(filepath, '/events/element_index');
            events.code = h5read(filepath, '/events/code');

            % Package
            seq_file = struct();
            seq_file.audio = audio;
            seq_file.ttl = ttl;
            seq_file.events = events;
            seq_file.manifest = manifest;

            fprintf('SequenceFile loaded successfully.\n');
        end
    end
end
