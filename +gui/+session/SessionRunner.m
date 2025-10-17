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

        % Mode (future): Exploration | Characterize | Formal
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
            app.UIFigure = uifigure('Name','Session Runner','Position',[100 100 820 600]);

            app.Grid = uigridlayout(app.UIFigure,[7,4]);
            app.Grid.RowHeight   = {28,28,28,28,'1x',34,28};
            app.Grid.ColumnWidth = {120,'1x',120,'1x'};

            % --- Session info ---
            lbl = uilabel(app.Grid,'Text','Subject:');
            lbl.Layout.Row = 1; lbl.Layout.Column = 1;
            app.SubjectField = uieditfield(app.Grid,'text');
            app.SubjectField.Layout.Row = 1; app.SubjectField.Layout.Column = 2;

            lbl = uilabel(app.Grid,'Text','Session #:');
            lbl.Layout.Row = 1; lbl.Layout.Column = 3;
            app.SessionNumField = uieditfield(app.Grid,'numeric','Limits',[1 inf],'RoundFractionalValues','on');
            app.SessionNumField.Layout.Row = 1; app.SessionNumField.Layout.Column = 4; app.SessionNumField.Value = 1;

            lbl = uilabel(app.Grid,'Text','Experimenter:');
            lbl.Layout.Row = 2; lbl.Layout.Column = 1;
            app.ExperimenterField = uieditfield(app.Grid,'text');
            app.ExperimenterField.Layout.Row = 2; app.ExperimenterField.Layout.Column = 2;

            lbl = uilabel(app.Grid,'Text','Notes:');
            lbl.Layout.Row = 3; lbl.Layout.Column = 1;
            app.NotesField = uitextarea(app.Grid);
            app.NotesField.Layout.Row = 3; app.NotesField.Layout.Column = [2 4];

            % --- Mode (placeholder) ---
            lbl = uilabel(app.Grid,'Text','Mode:');
            lbl.Layout.Row = 4; lbl.Layout.Column = 1;
            app.ModeDropdown = uidropdown(app.Grid, 'Items', {'Formal','Characterize','Exploration'}, 'Value','Formal');
            app.ModeDropdown.Layout.Row = 4; app.ModeDropdown.Layout.Column = 2;

            % --- What to run (radiobuttons MUST be direct children of the ButtonGroup) ---
            app.RunTypeGroup = uibuttongroup(app.Grid,'Title','What to run');
            app.RunTypeGroup.Layout.Row = 5; app.RunTypeGroup.Layout.Column = [1 4];

            % Position controls with normalized units inside the ButtonGroup
            app.SavedSequenceRadio = uiradiobutton(app.RunTypeGroup,'Text','Saved Sequence');
            app.SavedSequenceRadio.Units = 'normalized';
            app.SavedSequenceRadio.Position = [0.02 0.62 0.26 0.25];
            app.SavedSequenceRadio.Value = true;

            app.SequenceDropdown = uidropdown(app.RunTypeGroup);
            app.SequenceDropdown.Units = 'normalized';
            app.SequenceDropdown.Position = [0.30 0.62 0.68 0.25];

            app.SingleBlockRadio = uiradiobutton(app.RunTypeGroup,'Text','Single Block');
            app.SingleBlockRadio.Units = 'normalized';
            app.SingleBlockRadio.Position = [0.02 0.12 0.26 0.25];

            app.BlockDropdown = uidropdown(app.RunTypeGroup);
            app.BlockDropdown.Units = 'normalized';
            app.BlockDropdown.Position = [0.30 0.12 0.68 0.25];

            app.RunTypeGroup.SelectionChangedFcn = @(~,~)app.onRunTypeChanged();

            % --- Log + controls ---
            app.LogArea = uitextarea(app.Grid,'Editable','off'); app.LogArea.Value = {'Ready.'};
            app.LogArea.Layout.Row = 6; app.LogArea.Layout.Column = [1 4];

            app.StatusLabel = uilabel(app.Grid,'Text','Idle');
            app.StatusLabel.Layout.Row = 7; app.StatusLabel.Layout.Column = [1 3];

            btnGrid = uigridlayout(app.Grid,[1,2]);
            btnGrid.Layout.Row = 7; btnGrid.Layout.Column = 4;
            btnGrid.ColumnWidth = {'1x','1x'};

            app.AbortButton = uibutton(btnGrid,'Text','Abort','Enable','off', ...
                'ButtonPushedFcn', @(~,~)app.onAbort());
            app.StartButton = uibutton(btnGrid,'Text','Start', ...
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
                app.StartButton.Enable = 'off'; app.AbortButton.Enable = 'on';
                app.StatusLabel.Text = 'Preparing...';
                app.appendLog('Preparing session...');

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

                hooks = struct();
                hooks.onProgress = @(p)app.appendLog(sprintf('> %s', jsonencode(p)));
                hooks.onError    = @(ME)app.appendLog(sprintf('ERROR: %s', ME.message));
                hooks.onAbort    = @(~)app.appendLog('Abort requested.');

                app.runner = core.runner.RunnerCore(app.context, hooks);
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

        function root = maestroRoot(~)
            % Assume we are at <root>/+gui/+session/SessionRunner.m
            here = fileparts(mfilename('fullpath'));
            root = fileparts(fileparts(here));
        end
    end
end
