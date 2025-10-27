classdef RunnerCore < handle
    % HEADLESS orchestrator for running experiments with full logging.
    % prepare() compiles a plan, run() executes via MaestroContext.

    properties
        context            % core.MaestroContext
        hooks              % struct with optional fns: onProgress(payload), onError(ME), onAbort()
        state = 'idle'     % 'idle'|'prepared'|'running'|'completed'|'failed'|'aborted'
        plan               % ExecutionPlan struct (set in prepare)
        sessionDir         % absolute path to the session folder
        abortRequested logical = false
    end

    methods
        function obj = RunnerCore(context, hooks)
            if nargin < 1 || isempty(context)
                obj.context = core.MaestroContext();
            else
                obj.context = context;
            end
            if nargin < 2 || isempty(hooks)
                obj.hooks = struct();
            else
                obj.hooks = hooks;
            end
        end

        function prepare(obj, runTarget, runConfig)
            % Compile an execution plan and write metadata/plan JSONs.
            obj.assertState('idle');

            % --- Validate + defaults
            mustHave(runConfig, 'subject');
            meta = struct();
            meta.subject       = char(runConfig.subject);
            meta.session_num   = getOr(runConfig, 'session_num', 1);
            meta.experimenter  = char(getOr(runConfig, 'experimenter', ''));
            meta.notes         = char(getOr(runConfig, 'notes', ''));
            meta.started_at    = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
            meta.random_seed   = randi(2^31-1); rng(meta.random_seed);
            meta.engine_id     = char(getOr(runConfig, 'engine_id', 'audio_only'));
            meta.logging_level = char(getOr(runConfig, 'logging_level', 'full'));
            meta.versions      = obj.collectVersions();

            % --- Create session directory
            root = obj.maestroRoot();
            subjDir = fullfile(root, 'sessions', meta.subject, datestr(now,'yyyymmdd'));
            if ~exist(subjDir,'dir'), mkdir(subjDir); end
            obj.sessionDir = fullfile(subjDir, sprintf('sess_%02d_%s', meta.session_num, datestr(now,'HHMMSS')));
            if ~exist(obj.sessionDir,'dir'), mkdir(obj.sessionDir); end

            % Persist metadata early
            obj.writeJSON(fullfile(obj.sessionDir,'metadata.json'), meta);

            % --- Build plan from artifact or struct
            plan = struct();
            plan.blocks        = {};
            plan.stimuli       = {};
            plan.engine_id     = meta.engine_id;
            plan.engine_config = obj.coerceScalarStruct(getOr(runConfig,'engine_config',struct()), struct());
            plan.session_dir   = obj.sessionDir;
            plan.meta          = meta;

            if ischar(runTarget) || isstring(runTarget)
                data = jsondecode(fileread(char(runTarget)));
                [plan, plan.type] = obj.planFromArtifact(plan, data);
                plan.source_path  = char(runTarget);
            elseif isstruct(runTarget) && isfield(runTarget,'path')
                data = jsondecode(fileread(char(runTarget.path)));
                [plan, plan.type] = obj.planFromArtifact(plan, data);
                plan.source_path  = char(runTarget.path);
            else
                error('RunnerCore:InvalidRunTarget','runTarget must be a path or struct with .path');
            end

            % --- Preflight: fixups & validation (e.g., ensure parameters.n_trials)
            plan = obj.preflightFixupsAndValidate(plan);

            % Persist execution plan
            obj.plan = plan;
            obj.writeJSON(fullfile(obj.sessionDir,'execution_plan.json'), plan);

            obj.state = 'prepared';
            obj.emit('onProgress', struct('stage','prepared','session_dir',obj.sessionDir));
        end

        function results = run(obj)
            % Execute the prepared plan via MaestroContext.
            obj.assertState('prepared');
            obj.state = 'running';

            experiment = obj.planToExperiment(obj.plan);
            try
                results = obj.context.run_experiment_with_logging( ...
                    experiment, obj.plan.meta.subject, obj.plan.meta.session_num, obj.plan.meta.experimenter);
                obj.writeJSON(fullfile(obj.sessionDir,'run_result.json'), results);
                obj.state = 'completed';
                obj.emit('onProgress', struct('stage','completed'));
            catch ME
                obj.state = 'failed';
                obj.emit('onError', ME);
                rethrow(ME);
            end
        end

        function abort(obj)
            obj.abortRequested = true;
            obj.state = 'aborted';
            obj.emit('onAbort', struct());
        end
    end

    methods (Access=private)
        function [plan, type] = planFromArtifact(obj, plan, data)
            % Accept single-block specs, sequences, and SequenceComposer-style JSON.

            % Merge engine/global settings if present (coerce to scalar struct first)
            if isfield(data,'global_settings') && ~isempty(data.global_settings)
                gs = obj.coerceScalarStruct(data.global_settings, struct());
                if isfield(gs,'engine_type') && ~isempty(gs.engine_type)
                    plan.engine_id = char(gs.engine_type);
                end
                if isfield(gs,'engine_config') && ~isempty(gs.engine_config)
                    ge = obj.coerceScalarStruct(gs.engine_config, struct());
                    plan.engine_config = obj.mergeStructs(plan.engine_config, ge);
                end
                if isfield(gs,'sampling_rate_hz') && ~isfield(plan.engine_config,'sampling_rate_hz')
                    plan.engine_config.sampling_rate_hz = gs.sampling_rate_hz;
                end
            end

            % Normalize any block entry to a block_instance
            function inst = normalizeBlock(item)
                item = obj.coerceScalarStruct(item, struct());
                if isfield(item,'block_instance') && ~isempty(item.block_instance)
                    inst = obj.coerceScalarStruct(item.block_instance, struct());
                    if ~isfield(inst,'builder_type')
                        if isfield(item,'builder_type'), inst.builder_type = char(item.builder_type); end
                        if isfield(item,'type') && ~isfield(inst,'builder_type'), inst.builder_type = char(item.type); end
                    end
                    inst = obj.normalizeBlockInstance(inst);
                    return;
                end
                if isfield(item,'block_file') && ~isempty(item.block_file)
                    inst = obj.loadBlockInstanceFromFile(item.block_file); return;
                end
                if isfield(item,'builder_type') || isfield(item,'type')
                    inst = obj.ensureBlockInstance(item); return;
                end
                error('RunnerCore:InvalidBlockEntry','Block entry missing block_file/block_instance/builder_type.');
            end

            if isfield(data,'blocks')
                b = data.blocks;
                if iscell(b)
                    blocks = cell(1, numel(b));
                    for k = 1:numel(b), blocks{k} = normalizeBlock(b{k}); end
                    plan.blocks = blocks;  type = 'sequence';
                elseif isstruct(b)
                    plan.blocks = { normalizeBlock(b) };  type = 'single_block';
                else
                    error('RunnerCore:UnknownArtifact','"blocks" must be a struct or cell array.');
                end
            elseif isfield(data,'sequence')
                s = data.sequence;
                if iscell(s)
                    blocks = cell(1, numel(s));
                    for k = 1:numel(s), blocks{k} = normalizeBlock(s{k}); end
                    plan.blocks = blocks;  type = 'sequence';
                else
                    plan.blocks = { normalizeBlock(s) };  type = 'single_block';
                end
            elseif isfield(data,'block_instance') || isfield(data,'builder_type') || isfield(data,'type')
                plan.blocks = { obj.ensureBlockInstance(obj.coerceScalarStruct(data, struct())) };  type = 'single_block';
            else
                error('RunnerCore:UnknownArtifact','Unrecognized artifact shape (no block_instance/blocks/sequence).');
            end
        end

       function plan = preflightFixupsAndValidate(obj, plan)
    % Schema-driven normalization: no builder-specific hardcoding here.
    maestroRoot = obj.maestroRoot();
    reg = core.validation.SchemaRegistry(maestroRoot);

    report = struct('blocks', {{}});
    newBlocks = cell(1, numel(plan.blocks));

    for k = 1:numel(plan.blocks)
        inst = obj.coerceScalarStruct(plan.blocks{k}, struct());
        assert(isfield(inst,'builder_type') && ~isempty(inst.builder_type), ...
            'RunnerCore:MissingField','Block %d missing builder_type', k);

        % 1) Load schema for this builder
        schema = reg.get(inst.builder_type);

        % 2) Validate & normalize parameters (aliases, defaults, enums, types)
        [instValidated, rep] = core.validation.SchemaValidator.validate_and_normalize( ...
            schema, inst, obj.context, maestroRoot);

        % 3) Optional builder hook: +builders/+<type>/prepare_instance.m
        hookName = sprintf('builders.%s.prepare_instance', char(inst.builder_type));
        if exist(hookName, 'file') == 2 || exist(hookName, 'builtin') == 5
            hook = str2func(hookName);
            instValidated = hook(instValidated, obj.context);
            % Re-validate after hook (in case hook filled missing fields)
            [instValidated, rep2] = core.validation.SchemaValidator.validate_and_normalize( ...
                schema, instValidated, obj.context, maestroRoot);
            % merge reports
            rep.notes = [rep.notes, rep2.notes];
            rep.applied_aliases = [rep.applied_aliases, rep2.applied_aliases];
            rep.applied_defaults = [rep.applied_defaults, rep2.applied_defaults];
        end

        newBlocks{k} = instValidated;
        report.blocks{end+1} = struct('index',k, 'builder_type',inst.builder_type, ...
                                      'applied_aliases',{rep.applied_aliases}, ...
                                      'applied_defaults',{rep.applied_defaults});
    end

    plan.blocks = newBlocks;
    plan.preflight_report = report;
end


        function [n, why] = inferTrialsCount(~, inst)
            % Try to infer n_trials from various clues. Return NaN if not possible.
            n = NaN; why = '';

            P = struct(); 
            if isfield(inst,'parameters') && isstruct(inst.parameters), P = inst.parameters; end

            % direct aliases
            aliases = {'num_trials','n_total','nTotal','trial_count','trials','N','n'};
            for i = 1:numel(aliases)
                a = aliases{i};
                if isfield(P,a) && ~isempty(P.(a)) && isscalar(P.(a)) && isnumeric(P.(a))
                    n = double(P.(a)); why = ['from parameters.' a]; return;
                end
            end

            % n_standards + n_deviants
            if isfield(P,'n_standards') && isfield(P,'n_deviants') ...
                    && isscalar(P.n_standards) && isscalar(P.n_deviants)
                n = double(P.n_standards) + double(P.n_deviants);
                why = 'from parameters.n_standards + parameters.n_deviants'; 
                return;
            end

            % metadata.is_deviant vector length
            if isfield(inst,'metadata') && isstruct(inst.metadata) && isfield(inst.metadata,'is_deviant')
                v = inst.metadata.is_deviant;
                if isnumeric(v) || islogical(v)
                    n = numel(v); why = 'from metadata.is_deviant length'; return;
                end
            end

            % iti_sec vector length
            if isfield(P,'iti_sec') && ~isempty(P.iti_sec) && (isnumeric(P.iti_sec) || islogical(P.iti_sec))
                n = numel(P.iti_sec); why = 'from parameters.iti_sec length'; return;
            end

            % trial_list length (struct/cell/array)
            for cand = ["trial_list","trials_list","trialSequence","sequence"]
                c = char(cand);
                if isfield(inst,c)
                    v = inst.(c);
                    if iscell(v), n = numel(v); why = ['from ' c ' (cell length)']; return; end
                    if isstruct(v), n = numel(v); why = ['from ' c ' (struct array length)']; return; end
                    if isnumeric(v) || islogical(v), n = numel(v); why = ['from ' c ' (vector length)']; return; end
                end
            end
        end

        function P = normalizeOddballParams(~, P)
            % Light-touch aliasing; do not overwrite existing n_trials.
            if ~isfield(P,'deviant_probability') || isempty(P.deviant_probability)
                for cand = {'p_deviant','dev_frac','deviant_fraction','deviant_prob'}
                    c = cand{1};
                    if isfield(P,c) && ~isempty(P.(c))
                        v = P.(c);
                        if isscalar(v) && isnumeric(v)
                            if v > 1, v = v / 100; end  % allow 20 or 20%
                            P.deviant_probability = v;
                            break;
                        end
                    end
                end
            end
            % order_constraint default to 'none' if missing
            if ~isfield(P,'order_constraint') || isempty(P.order_constraint)
                P.order_constraint = 'none';
            end
        end

        function inst = ensureBlockInstance(obj, spec)
            % Accept block_instance or builder spec. Guarantees scalar struct + builder_type.
            if isfield(spec, 'block_instance') && ~isempty(spec.block_instance)
                inst = obj.coerceScalarStruct(spec.block_instance, struct());
                if ~isfield(inst, 'builder_type')
                    if isfield(spec, 'builder_type'), inst.builder_type = char(spec.builder_type);
                    elseif isfield(spec, 'type'),     inst.builder_type = char(spec.type);
                    else, error('RunnerCore:MissingField','block_instance missing builder_type.');
                    end
                end
                inst = obj.normalizeBlockInstance(inst);
                return;
            end

            % Build from a builder spec
            if isfield(spec,'builder_type'), btype = char(spec.builder_type);
            elseif isfield(spec,'type'),     btype = char(spec.type);
            else, error('RunnerCore:InvalidBlockSpec','Missing builder_type/type');
            end

            fn = str2func(sprintf('builders.%s.build', btype));
            try,    inst = fn(spec);
            catch,  inst = fn(spec, obj.context);
            end

            inst = obj.coerceScalarStruct(inst, struct());
            if ~isfield(inst, 'builder_type') || isempty(inst.builder_type)
                inst.builder_type = btype;
            end
            inst = obj.normalizeBlockInstance(inst);
        end

        function inst = loadBlockInstanceFromFile(obj, blockFile)
            % Resolve a block JSON file to a concrete block_instance, normalizing required fields.
            if isstring(blockFile) || ischar(blockFile)
                bf = char(blockFile);
            else
                error('RunnerCore:InvalidBlockFile','block_file must be a string path.');
            end

            if ~isfile(bf)
                % Try relative to library/blocks
                root = obj.maestroRoot();
                cand = fullfile(root, 'library', 'blocks', bf);
                if isfile(cand)
                    bf = cand;
                else
                    error('RunnerCore:BlockFileNotFound','block_file not found: %s', bf);
                end
            end

            data = jsondecode(fileread(bf));

            if isfield(data,'block_instance') && ~isempty(data.block_instance)
                inst = obj.coerceScalarStruct(data.block_instance, struct());
                if ~isfield(inst,'builder_type')
                    if isfield(data,'builder_type'), inst.builder_type = char(data.builder_type); end
                    if isfield(data,'type')        && ~isfield(inst,'builder_type'), inst.builder_type = char(data.type); end
                end
                inst = obj.normalizeBlockInstance(inst);
            else
                % Treat the whole file as a builder spec
                inst = obj.ensureBlockInstance(obj.coerceScalarStruct(data, struct()));
            end
        end

        function inst = normalizeBlockInstance(~, inst)
            % Minimal required fields and scalar-ness.
            if iscell(inst)
                if isempty(inst), error('RunnerCore:InvalidInstance','block_instance is an empty cell.'); end
                inst = inst{1};
            end
            if ~isstruct(inst)
                error('RunnerCore:InvalidInstance','block_instance must be a struct.');
            end
            if numel(inst) ~= 1
                inst = inst(1); % keep first if array
            end
            if ~isfield(inst,'builder_type') || isempty(inst.builder_type)
                error('RunnerCore:MissingField','block_instance is missing required field "builder_type".');
            end
            if ~isfield(inst,'instance_id') || isempty(inst.instance_id)
                inst.instance_id = char(java.util.UUID.randomUUID());
            end
            if ~isfield(inst,'parameters') || isempty(inst.parameters) || ~isstruct(inst.parameters)
                inst.parameters = struct();
            end
        end

        function experiment = planToExperiment(~, plan)
            % Translate ExecutionPlan into the experiment struct for Context/engine.

            % Ensure a sampling rate exists
            default_sr_hz = 192000;
            ec = plan.engine_config;
            if ~isstruct(ec) || numel(ec) ~= 1
                ec = struct();
            end
            if ~isfield(ec,'sampling_rate_hz') || isempty(ec.sampling_rate_hz)
                ec.sampling_rate_hz = default_sr_hz;
            end

            experiment = struct();
            experiment.experiment_id   = sprintf('run_%s', datestr(now,'yyyymmdd_HHMMSS'));
            experiment.global_settings = struct( ...
                'sampling_rate_hz', ec.sampling_rate_hz, ...
                'engine_type',      plan.engine_id, ...
                'engine_config',    ec);

            % Normalize blocks
            if numel(plan.blocks) == 1
                blk = struct('block_instance', plan.blocks{1});
                experiment.sequence = blk;         % legacy single-block path
                experiment.blocks   = {blk};       % also expose list
            else
                blks = cell(1, numel(plan.blocks));
                for k = 1:numel(plan.blocks)
                    blks{k} = struct('block_instance', plan.blocks{k});
                end
                experiment.blocks   = blks;
                experiment.sequence = blks{1};     % fallback if engine expects single
            end
        end

        function root = maestroRoot(~)
            % Assume we are at <root>/+core/+runner/RunnerCore.m
            here = fileparts(mfilename('fullpath'));
            root = fileparts(fileparts(here));
        end

        function v = collectVersions(~)
            v = struct();
            v.matlab         = version;
            v.matlab_release = version('-release');
        end

        function emit(obj, hookName, payload)
            if isfield(obj.hooks, hookName) && isa(obj.hooks.(hookName), 'function_handle')
                try, obj.hooks.(hookName)(payload); end %#ok<TRYNC>
            end
        end

        function writeJSON(~, path, s)
            fid = fopen(path, 'w');
            if fid == -1, error('RunnerCore:IO','Cannot write %s', path); end
            fwrite(fid, jsonencode(s), 'char'); fclose(fid);
        end

        function assertState(obj, expected)
            if ~strcmp(obj.state, expected)
                error('RunnerCore:State','Expected state %s, got %s', expected, obj.state);
            end
        end

        % ---------- helpers to avoid "Scalar structure required" ----------
        function S = coerceScalarStruct(~, val, defaultStruct)
            if nargin < 3, defaultStruct = struct(); end
            if isempty(val), S = defaultStruct; return; end
            if isstruct(val), S = val( min(1,end) ); return; end
            if iscell(val) && ~isempty(val) && isstruct(val{1}), S = val{1}; return; end
            S = defaultStruct;
        end

        function dest = mergeStructs(~, dest, src)
            if ~isstruct(dest) || numel(dest) ~= 1, dest = struct(); end
            if ~isstruct(src)  || numel(src)  ~= 1,  src = struct();  end
            f = fieldnames(src);
            for i = 1:numel(f), dest.(f{i}) = src.(f{i}); end
        end
    end
end

% ---- local helpers (file scope) -----------------------------------------
function mustHave(S, field)
if ~isfield(S, field) || isempty(S.(field))
    error('RunnerCore:MissingField','Missing required field: %s', field);
end
end

function val = getOr(S, field, default)
if isfield(S, field) && ~isempty(S.(field))
    val = S.(field);
else
    val = default;
end
end
