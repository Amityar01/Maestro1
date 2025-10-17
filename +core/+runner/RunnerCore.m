classdef RunnerCore < handle
    % HEADLESS orchestrator for running experiments with full logging.
    % prepare() compiles a plan, run() executes via MaestroContext.
    %
    % Usage:
    %   ctx   = core.MaestroContext();
    %   hooks = struct('onProgress', @(p)disp(p), 'onError', @(e)disp(e.message));
    %   rc    = core.runner.RunnerCore(ctx, hooks);
    %   rc.prepare(struct('type','sequence','path','library/sequences/your_seq.json'), ...
    %              struct('subject','R042','session_num',1,'experimenter','Amit'));
    %   rc.run();

    properties
        context            % core.MaestroContext
        hooks              % struct with optional fns: onProgress(payload), onError(ME), onAbort()
        state = 'idle'     % 'idle' | 'prepared' | 'running' | 'completed' | 'failed' | 'aborted'
        plan               % ExecutionPlan struct (see prepare)
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
            % Compile an execution plan and write metadata/plan JSONs to the session folder.
            % runTarget: path string to JSON, or struct with fields:
            %   .type: 'sequence'|'single_block'
            %   .path: path to JSON
            % runConfig: struct with fields:
            %   subject (char), session_num (double), experimenter (char), notes (char)
            %   Optional: engine_id (char, default 'audio_only'), engine_config (struct),
            %             logging_level (char: 'full'|'light'|'none')

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
            plan.blocks       = {};
            plan.stimuli      = {};               % reserved; engines may do on-the-fly generation
            plan.engine_id    = meta.engine_id;
            plan.engine_config= getOr(runConfig, 'engine_config', struct());
            plan.session_dir  = obj.sessionDir;
            plan.meta         = meta;

            if ischar(runTarget) || isstring(runTarget)
                data = jsondecode(fileread(char(runTarget)));
                [plan, plan.type] = obj.planFromArtifact(plan, data);
                plan.source_path  = char(runTarget);
            elseif isstruct(runTarget)
                if isfield(runTarget, 'path')
                    data = jsondecode(fileread(char(runTarget.path)));
                    [plan, plan.type] = obj.planFromArtifact(plan, data);
                    plan.source_path  = char(runTarget.path);
                else
                    error('RunnerCore:InvalidRunTarget', 'Struct runTarget must include a .path to JSON.');
                end
            else
                error('RunnerCore:InvalidRunTarget', 'runTarget must be a path or struct with .path');
            end

            % Persist execution plan
            obj.plan = plan;
            obj.writeJSON(fullfile(obj.sessionDir,'execution_plan.json'), plan);

            obj.state = 'prepared';
            obj.emit('onProgress', struct('stage','prepared','session_dir',obj.sessionDir));
        end

        function results = run(obj)
            % Execute the prepared plan via MaestroContext's headless runner.
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
            % NOTE: add engine-level abort propagation if/when supported.
        end
    end

    methods (Access=private)
        function [plan, type] = planFromArtifact(obj, plan, data)
            % Accepts either a single block JSON or a sequence JSON; normalizes to plan.blocks{...}.block_instance
            type = 'single_block';
            if isfield(data, 'block_instance') || isfield(data, 'builder_type')
                inst = obj.ensureBlockInstance(data);
                plan.blocks = {inst};
                type = 'single_block';
            elseif isfield(data, 'blocks') && iscell(data.blocks)
                blocks = cell(1, numel(data.blocks));
                for k = 1:numel(data.blocks)
                    blocks{k} = obj.ensureBlockInstance(data.blocks{k});
                end
                plan.blocks = blocks;
                type = 'sequence';
            elseif isfield(data, 'sequence')
                blocks = {};
                seq = data.sequence;
                if iscell(seq)
                    for k = 1:numel(seq)
                        blocks{end+1} = obj.ensureBlockInstance(seq{k}); %#ok<AGROW>
                    end
                    type = 'sequence';
                else
                    blocks{1} = obj.ensureBlockInstance(seq);
                    type = 'single_block';
                end
                plan.blocks = blocks;
            else
                error('RunnerCore:UnknownArtifact', ...
                      'Unrecognized artifact shape (no block_instance/blocks/sequence).');
            end
        end

        function inst = ensureBlockInstance(obj, spec)
            % Accept both block_instance (already resolved) and builder specs.
            if isfield(spec, 'block_instance')
                inst = spec.block_instance; return;
            end
            % Build instance from a builder spec
            if isfield(spec,'builder_type')
                btype = char(spec.builder_type);
            elseif isfield(spec,'type')
                btype = char(spec.type);
            else
                error('RunnerCore:InvalidBlockSpec','Missing builder_type/type');
            end
            fn = str2func(sprintf('builders.%s.build', btype));
            try
                inst = fn(spec);                 % (spec)
            catch
                inst = fn(spec, obj.context);    % (spec, context) fallback
            end
        end

        function experiment = planToExperiment(~, plan)
            % Translate ExecutionPlan into the experiment struct consumed by Context/engine.
            experiment = struct();
            experiment.experiment_id   = sprintf('run_%s', datestr(now,'yyyymmdd_HHMMSS'));
            experiment.global_settings = struct( ...
                'engine_type',   plan.engine_id, ...
                'engine_config', plan.engine_config);

            % Normalize blocks
            if numel(plan.blocks) == 1
                blk = struct('block_instance', plan.blocks{1});
                experiment.sequence = blk;   % legacy single-block path
                experiment.blocks   = {blk}; % also expose list for future engines
            else
                blks = cell(1, numel(plan.blocks));
                for k = 1:numel(plan.blocks)
                    blks{k} = struct('block_instance', plan.blocks{k});
                end
                experiment.blocks   = blks;
                experiment.sequence = blks{1}; % fallback if engine expects single
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
            % TODO: attach toolbox versions, git hash if available
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
    end
end

% ---- local helpers -------------------------------------------------------
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
