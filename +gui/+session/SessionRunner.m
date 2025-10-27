classdef SessionRunner < handle
    % gui.session.SessionRunner - UI wrapper around core.runner.RunnerCore

    properties
        UIFigure
        Grid
        % Session info
        SubjectField
        SessionNumField
        ExperimenterField
        NotesField

        % Mode: Exploration | Characterize | Formal
        ModeDropdown

        % What to run
        RunTypeGroup
        SavedSequenceRadio
        SingleBlockRadio
        SequenceDropdown
        BlockDropdown

        % Controls
        StartButton
        AbortButton
        StatusLabel
        LogArea

        % Core
        context     % core.MaestroContext
        runner      % core.runner.RunnerCore
    end

    methods
        function app = SessionRunner(context)
            if nargin < 1 || isempty(context)
                app.context = core.MaestroContext();
            else
                app.context = context;
            end
            app.buildUI();
            app.refreshArtifacts();
        end

        function buildUI(app)
            app.UIFigure = uifigure('Name','Session Runner','Position',[100 100 860 640]);

            app.Grid = uigridlayout(app.UIFigure,[7,4]);
            app.Grid.RowHeight   = {28,28,28,28,'1x',34,56};   % taller bottom row
            app.Grid.ColumnWidth = {120,'1x',120,'1x'};

            % --- Session info ---
            lbl = uilabel(app.Grid,'Text','Subject:');
            lbl.Layout.Row = 1; lbl.Layout.Column = 1;
            app.SubjectField = uieditfield(app.Grid,'text');
            app.SubjectField.Layout.Row = 1; app.SubjectField.Layout.Column = 2;

            lbl = uilabel(app.Grid,'Text','Session #:');
            lbl.Layout.Row = 1; lbl.Layout.Column = 3;
            app.SessionNumField = uieditfield(app.Grid,'numeric','Limits',[1 inf],'RoundFractionalValues','on');
            app.SessionNumField.Layout.Row = 1; app.SessionNumField.Layout.Column = 4; 
            app.SessionNumField.Value = 1;

            lbl = uilabel(app.Grid,'Text','Experimenter:');
            lbl.Layout.Row = 2; lbl.Layout.Column = 1;
            app.ExperimenterField = uieditfield(app.Grid,'text');
            app.ExperimenterField.Layout.Row = 2; app.ExperimenterField.Layout.Column = 2;

            lbl = uilabel(app.Grid,'Text','Notes:');
            lbl.Layout.Row = 3; lbl.Layout.Column = 1;
            app.NotesField = uitextarea(app.Grid);
            app.NotesField.Layout.Row = 3; app.NotesField.Layout.Column = [2 4];

            % --- Mode ---
            lbl = uilabel(app.Grid,'Text','Mode:');
            lbl.Layout.Row = 4; lbl.Layout.Column = 1;
            app.ModeDropdown = uidropdown(app.Grid,'Items',{'Formal','Characterize','Exploration'},'Value','Formal');
            app.ModeDropdown.Layout.Row = 4; app.ModeDropdown.Layout.Column = 2;

            % --- What to run (RadioButtons MUST be direct children of the ButtonGroup) ---
            app.RunTypeGroup = uibuttongroup(app.Grid,'Title','What to run');
            app.RunTypeGroup.Layout.Row = 5; app.RunTypeGroup.Layout.Column = [1 4];

            % Children of the ButtonGroup
            app.SavedSequenceRadio = uiradiobutton(app.RunTypeGroup, 'Text','Saved Sequence');
            app.SequenceDropdown   = uidropdown(app.RunTypeGroup);
            app.SingleBlockRadio   = uiradiobutton(app.RunTypeGroup, 'Text','Single Block');
            app.BlockDropdown      = uidropdown(app.RunTypeGroup);

            % Defaults
            app.SavedSequenceRadio.Value = true;

            % Size-aware layout inside the group (pixel positions)
            app.RunTypeGroup.SizeChangedFcn = @(~,~)app.layoutRunTypeControls();
            drawnow;  % ensure a first valid size
            app.layoutRunTypeControls();

            % Selection change
            app.RunTypeGroup.SelectionChangedFcn = @(~,~)app.onRunTypeChanged();

            % --- Log + controls ---
            app.LogArea = uitextarea(app.Grid,'Editable','off'); 
            app.LogArea.Value = {'Ready.'};
            app.LogArea.Layout.Row = 6; 
            app.LogArea.Layout.Column = [1 4];

            app.StatusLabel = uilabel(app.Grid,'Text','Idle');
            app.StatusLabel.Layout.Row = 7; app.StatusLabel.Layout.Column = [1 2];

            btnGrid = uigridlayout(app.Grid,[1,2]);
            btnGrid.Layout.Row = 7; btnGrid.Layout.Column = [3 4];
            btnGrid.RowHeight   = {56};
            btnGrid.ColumnWidth = {'fit','fit'};

            app.AbortButton = uibutton(btnGrid,'Text','Abort','Enable','off','FontSize',14, ...
                'ButtonPushedFcn', @(~,~)app.onAbort());
            app.StartButton = uibutton(btnGrid,'Text','Start','FontSize',14, ...
                'ButtonPushedFcn', @(~,~)app.onStart());
        end

        function refreshArtifacts(app)
            root = app.maestroRoot();
            seqDir = fullfile(root,'library','sequences');
            blkDir = fullfile(root,'library','blocks');

            seq = dir(fullfile(seqDir,'*.json')); seqNames = {seq.name};
            blk = dir(fullfile(blkDir,'*.json')); blkNames = {blk.name};

            app.SequenceDropdown.Items = cellfun(@(s) fullfile(seqDir,s), seqNames, 'UniformOutput', false);
            if isempty(app.SequenceDropdown.Items), app.SequenceDropdown.Items = {''}; end

            app.BlockDropdown.Items = cellfun(@(s) fullfile(blkDir,s), blkNames, 'UniformOutput', false);
            if isempty(app.BlockDropdown.Items), app.BlockDropdown.Items = {''}; end

            app.onRunTypeChanged();
        end

        function onRunTypeChanged(app)
            if app.SavedSequenceRadio.Value
                app.SequenceDropdown.Enable = 'on';
                app.BlockDropdown.Enable    = 'off';
            else
                app.SequenceDropdown.Enable = 'off';
                app.BlockDropdown.Enable    = 'on';
            end
        end

function onStart(app)
    try
        % --- Preflight: make sure RunnerCore is actually loadable
        app.assertRunnerCorePresent();

        app.StartButton.Enable = 'off'; app.AbortButton.Enable = 'on';
        app.StatusLabel.Text = 'Preparing...';
        app.appendLog('Preparing session...');

        % What to run
        runTarget = struct();
        if app.SavedSequenceRadio.Value
            runTarget.type = 'sequence';
            runTarget.path = char(app.SequenceDropdown.Value);
            if ~isfile(runTarget.path), error('Select a saved sequence JSON.'); end
        else
            runTarget.type = 'single_block';
            runTarget.path = char(app.BlockDropdown.Value);
            if ~isfile(runTarget.path), error('Select a block JSON.'); end
        end

        % Run config
        runConfig = struct();
        runConfig.subject       = char(app.SubjectField.Value);
        runConfig.session_num   = app.SessionNumField.Value;
        runConfig.experimenter  = char(app.ExperimenterField.Value);
        runConfig.notes         = char(join(app.NotesField.Value, newline));
        runConfig.engine_id     = 'audio_only';
        runConfig.engine_config = struct();   % TODO: device selection UI
        switch app.ModeDropdown.Value
            case 'Formal',        runConfig.logging_level = 'full';
            case 'Characterize',  runConfig.logging_level = 'light';
            otherwise,            runConfig.logging_level = 'none';
        end
        if isempty(runConfig.subject)
            error('Subject is required.');
        end

        % Hooks for progress
        hooks = struct();
        hooks.onProgress = @(p)app.appendLog(sprintf('> %s', jsonencode(p)));
        hooks.onError    = @(ME)app.appendLog(sprintf('ERROR: %s', ME.message));
        hooks.onAbort    = @(~)app.appendLog('Abort requested.');

        % Construct RunnerCore (now that we know it's visible)
        app.runner = core.runner.RunnerCore(app.context, hooks);

        % Prepare + run
        app.runner.prepare(runTarget, runConfig);
        app.StatusLabel.Text = 'Running...'; app.appendLog('Starting engine...');
        app.runner.run();
        app.StatusLabel.Text = 'Complete'; app.appendLog('Session complete.');

    catch ME
        app.StatusLabel.Text = 'Error';
        app.appendLog(['ERROR: ' ME.message]);
        try
            gui.common.error_dialog.show_general_error(app.UIFigure, ME, 'Session Error');
        catch
            uialert(app.UIFigure, ME.message, 'Session Error', 'Icon','error');
        end
    end

    app.StartButton.Enable = 'on'; app.AbortButton.Enable = 'off';
end
function assertRunnerCorePresent(app)
    % Assert that core.runner.RunnerCore is resolvable, and give a precise
    % message with the expected on-disk location if not.

    % If MATLAB can already see the class, we're done.
    if exist('core.runner.RunnerCore','class') == 8
        return;
    end

    % Compute expected file path from Maestro root (based on where MaestroContext lives)
    ctx_path = which('core.MaestroContext');
    if isempty(ctx_path)
        error(['MaestroContext not found on path. Make sure Maestro root is on the MATLAB path.\n' ...
               'Try: run(fullfile(<MaestroRoot>,''setup_maestro.m''));']);
    end
    root = fileparts(fileparts(ctx_path));  % strip .../+core/MaestroContext.m -> Maestro root
    expected = fullfile(root, '+core', '+runner', 'RunnerCore.m');

    % Does the file exist at that location?
    fileExists = exist(expected,'file') == 2;

    % Build a concrete, helpful error
    if ~fileExists
        error(['Unable to resolve class core.runner.RunnerCore.\n' ...
               'Expected file was not found at:\n  %s\n\n' ...
               'Fix:\n  - Ensure the file is saved exactly at +core/+runner/RunnerCore.m (note the + folders)\n' ...
               '  - Class header must be:  classdef RunnerCore < handle\n' ...
               '  - Then run: clear classes; rehash toolboxcache;\n' ...
               '  - Ensure Maestro root is on path (setup_maestro.m).'], expected);
    else
        % File is there but class still not visible -> likely classdef or cache issue
        % Try to read the first line to check classdef
        try
            txt = fileread(expected);
        catch
            txt = '';
        end

        hasClassdef = contains(txt, 'classdef RunnerCore < handle');

        if ~hasClassdef
            error(['RunnerCore.m is present but the class header is incorrect.\n' ...
                   'File: %s\n' ...
                   'Fix:\n  - The first classdef line must be exactly:\n' ...
                   '      classdef RunnerCore < handle\n' ...
                   '  - No package name in the classdef; the +core/+runner folders provide the namespace.\n' ...
                   '  - After fixing, run: clear classes; rehash toolboxcache;'], expected);
        else
            error(['MATLAB cannot resolve core.runner.RunnerCore even though the file exists and classdef looks correct.\n' ...
                   'Likely cause: MATLAB class cache not refreshed or path shadowing.\n' ...
                   'Try, in this order:\n' ...
                   '  clear classes; clear functions; rehash toolboxcache;\n' ...
                   '  run(fullfile(''%s'',''setup_maestro.m''));\n' ...
                   '  which -all core.runner.RunnerCore  %% should list the file above\n' ...
                   'If it still fails, check for another folder named ''core'' without the + prefix that could be shadowing.'], root);
        end
    end
end

        function onAbort(app)
            if ~isempty(app.runner)
                app.runner.abort();
                app.StatusLabel.Text = 'Aborted';
            end
        end

        function appendLog(app, msg)
            lines = app.LogArea.Value;
            lines{end+1} = sprintf('[%s] %s', datestr(now,'HH:MM:SS'), msg);
            app.LogArea.Value = lines;
            drawnow;
        end

        function layoutRunTypeControls(app)
            % Responsive layout inside RunTypeGroup using pixel positions.
            if isempty(app.RunTypeGroup) || ~isvalid(app.RunTypeGroup), return; end
            gp = app.RunTypeGroup.InnerPosition;  % [x y w h]
            if isempty(gp) || any(gp(3:4) <= 0), return; end

            pad  = 10; rowH = 24; gap = 10;
            y1 = gp(4) - pad - rowH;         % Saved Sequence row
            y2 = y1 - gap - rowH;            % Single Block row
            labelW = 140;                    % space for radio label
            dropX  = pad + labelW;
            dropW  = max(80, gp(3) - dropX - pad);

            app.SavedSequenceRadio.Position = [pad, y1, labelW-20, rowH];
            app.SequenceDropdown.Position   = [dropX, y1, dropW,   rowH];
            app.SingleBlockRadio.Position   = [pad, y2, labelW-20, rowH];
            app.BlockDropdown.Position      = [dropX, y2, dropW,   rowH];
        end

        function root = maestroRoot(~)
            % Assume we are at <root>/+gui/+session/SessionRunner.m
            here = fileparts(mfilename('fullpath'));
            root = fileparts(fileparts(here));
        end
    end
end
