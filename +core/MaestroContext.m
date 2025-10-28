classdef MaestroContext < handle
    % MAESTROCONTEXT - Central registry and runtime context for Maestro
    %
    % This class discovers all available plugins (generators, builders, engines)
    % and provides methods for validation and execution.
    %
    % Usage:
    %   ctx = MaestroContext();  % Discovers all plugins
    %   ctx = MaestroContext('/custom/path');  % Use custom base path
    %
    % Properties:
    %   generators   - Map of available stimulus generators
    %   builders     - Map of available block builders
    %   engines      - Map of available execution engines
    %   stimulus_lib - Map of named stimuli in library
    %   instances    - Map of saved block instances
    %   experiments  - Map of saved experiments

    properties (SetAccess = private)
        generators      % containers.Map: generator_type -> generator_info
        builders        % containers.Map: builder_type -> builder_info
        engines         % containers.Map: engine_type -> engine_info
        stimulus_lib    % containers.Map: stimulus_id -> stimulus_spec
        instances       % containers.Map: instance_id -> block_instance
        experiments     % containers.Map: experiment_id -> experiment_spec
        base_path       % string: root directory for Maestro
    end

    methods
        function obj = MaestroContext(base_path)
            % MAESTROCONTEXT - Initialize and discover all plugins
            %
            % INPUTS:
            %   base_path - string, root directory (default: pwd)

            if nargin < 1 || isempty(base_path)
                base_path = pwd;
            end

            obj.base_path = base_path;
            obj.discover_all();
        end

        function discover_all(obj)
            % DISCOVER_ALL - Discover all available plugins and content

            fprintf('Maestro: Discovering plugins...\n');

            % Discover plugins using unified discovery system
            obj.generators = core.discovery.PluginDiscovery.discover_generators(...
                fullfile(obj.base_path, '+generators'));
            fprintf('  Found %d generators\n', length(obj.generators));

            obj.builders = core.discovery.PluginDiscovery.discover_builders(...
                fullfile(obj.base_path, '+builders'));
            fprintf('  Found %d builders\n', length(obj.builders));

            obj.engines = core.discovery.PluginDiscovery.discover_engines(...
                fullfile(obj.base_path, '+engines'));
            fprintf('  Found %d engines\n', length(obj.engines));

            % Discover user content
            obj.stimulus_lib = core.load_stimulus_library(...
                fullfile(obj.base_path, 'stimuli'));
            fprintf('  Found %d stimuli in library\n', length(obj.stimulus_lib));

            obj.instances = core.discover_instances(...
                fullfile(obj.base_path, 'instances'));
            fprintf('  Found %d block instances\n', length(obj.instances));

            obj.experiments = core.discover_experiments(...
                fullfile(obj.base_path, 'experiments'));
            fprintf('  Found %d experiments\n', length(obj.experiments));

            fprintf('✓ Maestro Context initialized\n\n');
        end

        function [is_valid, errors] = validate_generator_params(obj, generator_type, params)
            % VALIDATE_GENERATOR_PARAMS - Validate parameters against generator schema
            %
            % INPUTS:
            %   generator_type - string, type of generator
            %   params         - struct, parameters to validate
            %
            % OUTPUTS:
            %   is_valid - boolean, true if valid
            %   errors   - cell array of error messages

            if ~isKey(obj.generators, generator_type)
                is_valid = false;
                errors = {sprintf('Unknown generator type: %s', generator_type)};
                return;
            end

            gen_info = obj.generators(generator_type);
            [is_valid, errors] = core.validate_parameters(params, ...
                gen_info.schema.parameters);
        end

        function output_spec = generate_stimulus(obj, stim_spec, context)
            % GENERATE_STIMULUS - Generate a stimulus from specification
            %
            % INPUTS:
            %   stim_spec - struct, stimulus specification with:
            %               .generator - string, generator type
            %               .parameters - struct, generator parameters
            %   context   - struct, runtime context (must have .sampling_rate_hz)
            %
            % OUTPUTS:
            %   output_spec - struct, generated stimulus output

            % Validate stimulus spec structure
            if ~isstruct(stim_spec) || ~isfield(stim_spec, 'generator') || ...
                    ~isfield(stim_spec, 'parameters')
                error('Maestro:InvalidStimSpec', ...
                    'Stimulus spec must have "generator" and "parameters" fields');
            end

            % Get generator
            generator_type = stim_spec.generator;
            if ~isKey(obj.generators, generator_type)
                error('Maestro:UnknownGenerator', ...
                    'Unknown generator type: %s', generator_type);
            end

            gen_info = obj.generators(generator_type);

            % Validate parameters
            [is_valid, errors] = obj.validate_generator_params(...
                generator_type, stim_spec.parameters);

            if ~is_valid
                error('Maestro:InvalidParameters', ...
                    'Invalid parameters for generator "%s":\n%s', ...
                    generator_type, strjoin(errors, '\n'));
            end

            % Resolve any randomization
            resolved_params = core.resolve_randomization(...
                stim_spec.parameters, context);

            % Call generator
            output_spec = gen_info.generate_func(resolved_params, context);

            % Validate output
            [is_valid, errors] = core.validate_generator_output(...
                output_spec, gen_info.schema);

            if ~is_valid
                error('Maestro:InvalidGeneratorOutput', ...
                    'Generator "%s" produced invalid output:\n%s', ...
                    generator_type, strjoin(errors, '\n'));
            end
        end

        function trial_list = build_block(obj, instance, context)
            % BUILD_BLOCK - Build trial list from block instance
            %
            % INPUTS:
            %   instance - struct, block instance specification with:
            %              .builder_type - string
            %              .parameters - struct
            %   context  - struct, runtime context
            %
            % OUTPUTS:
            %   trial_list - array of trial structs

            % Validate instance structure
            if ~isstruct(instance) || ~isfield(instance, 'builder_type') || ...
                    ~isfield(instance, 'parameters')
                error('Maestro:InvalidInstance', ...
                    'Instance must have "builder_type" and "parameters" fields');
            end

            % Get builder
            builder_type = instance.builder_type;
            if ~isKey(obj.builders, builder_type)
                error('Maestro:UnknownBuilder', ...
                    'Unknown builder type: %s', builder_type);
            end

            builder_info = obj.builders(builder_type);

            % Validate instance
            [is_valid, errors] = core.validate_block_instance(...
                instance, builder_info.schema);

            if ~is_valid
                error('Maestro:InvalidInstance', ...
                    'Invalid block instance:\n%s', strjoin(errors, '\n'));
            end

            % Add context info
            context.generators = obj.generators;

            % Call builder
            trial_list = builder_info.build_func(instance, context);

            % Validate trial list
            [is_valid, errors] = core.validate_trial_list(...
                trial_list, builder_info.schema);

            if ~is_valid
                error('Maestro:InvalidTrialList', ...
                    'Builder produced invalid trial list:\n%s', ...
                    strjoin(errors, '\n'));
            end
        end

        function results = run_experiment(obj, experiment_spec, context)
            % RUN_EXPERIMENT - Execute a complete experiment
            %
            % INPUTS:
            %   experiment_spec - struct, experiment specification
            %   context         - struct, runtime context (optional)
            %
            % OUTPUTS:
            %   results - struct, execution results

            % Prepare context
            if nargin < 3
                context = struct();
            end
            context.generators = obj.generators;
            context.builders = obj.builders;
            context.instances = obj.instances;

            % Get engine
            if ~isfield(experiment_spec, 'global_settings') || ...
                    ~isfield(experiment_spec.global_settings, 'engine_type')
                error('Maestro:MissingEngine', ...
                    'Experiment must specify engine_type in global_settings');
            end

            engine_type = experiment_spec.global_settings.engine_type;
            if ~isKey(obj.engines, engine_type)
                error('Maestro:UnknownEngine', ...
                    'Unknown engine type: %s', engine_type);
            end

            engine_info = obj.engines(engine_type);

            % Validate experiment
            [is_valid, errors] = core.validate_experiment(...
                experiment_spec, obj);

            if ~is_valid
                error('Maestro:InvalidExperiment', ...
                    'Invalid experiment specification:\n%s', ...
                    strjoin(errors, '\n'));
            end

            % Call engine
            results = engine_info.execute_func(experiment_spec, context);
        end
        function results = run_experiment_with_logging(obj, experiment, subject_id, session_number, experimenter)
            % RUN_EXPERIMENT_WITH_LOGGING - Run experiment with session logging
            %
            % INPUTS:
            %   experiment - experiment specification struct
            %   subject_id - subject identifier (e.g., 'S001')
            %   session_number - session number (integer)
            %   experimenter - experimenter name
            %
            % OUTPUTS:
            %   results - minimal struct with session info

            % Create session logger
            session_logger = core.logging.SessionLogger(subject_id, session_number, ...
                experimenter, experiment);

            try
                % Get engine
                engine_type = experiment.global_settings.engine_type;

                if ~isKey(obj.engines, engine_type)
                    error('Unknown engine type: %s', engine_type);
                end

                engine_info = obj.engines(engine_type);

                % Build context for engine
                context = struct();
                context.generators = obj.generators;
                context.builders = obj.builders;

                % Execute with logging
                results = engine_info.execute_func(experiment, context, session_logger);

                % Finalize session
                session_logger.finalize('completed');

            catch ME
                % Log error and finalize
                session_logger.log_event('ERROR', ME.message);
                session_logger.finalize('error');
                rethrow(ME);
            end
        end

        function list_generators(obj)
            % LIST_GENERATORS - Display all available generators

            if isempty(obj.generators)
                fprintf('No generators found.\n');
                return;
            end

            fprintf('\nAvailable Generators:\n');
            fprintf('═══════════════════════════════════════════════\n');

            gen_types = keys(obj.generators);
            for i = 1:length(gen_types)
                gen_type = gen_types{i};
                gen_info = obj.generators(gen_type);
                fprintf('  %s (v%s)\n', gen_type, gen_info.schema.version);
                fprintf('    %s\n', gen_info.schema.description);
                fprintf('    Modality: %s, Type: %s\n', ...
                    gen_info.schema.modality, gen_info.schema.render_type);
            end
            fprintf('\n');
        end

        function list_builders(obj)
            % LIST_BUILDERS - Display all available builders

            if isempty(obj.builders)
                fprintf('No builders found.\n');
                return;
            end

            fprintf('\nAvailable Builders:\n');
            fprintf('═══════════════════════════════════════════════\n');

            builder_types = keys(obj.builders);
            for i = 1:length(builder_types)
                builder_type = builder_types{i};
                builder_info = obj.builders(builder_type);
                fprintf('  %s (v%s)\n', builder_type, builder_info.schema.version);
                fprintf('    %s\n', builder_info.schema.description);
            end
            fprintf('\n');
        end

        function list_engines(obj)
            % LIST_ENGINES - Display all available engines

            if isempty(obj.engines)
                fprintf('No engines found.\n');
                return;
            end

            fprintf('\nAvailable Engines:\n');
            fprintf('═══════════════════════════════════════════════\n');

            engine_types = keys(obj.engines);
            for i = 1:length(engine_types)
                engine_type = engine_types{i};
                engine_info = obj.engines(engine_type);
                fprintf('  %s (v%s)\n', engine_type, engine_info.schema.version);
                fprintf('    %s\n', engine_info.schema.description);
                fprintf('    Modalities: %s\n', strjoin(engine_info.schema.supported_modalities, ', '));
            end
            fprintf('\n');
        end
    end
end