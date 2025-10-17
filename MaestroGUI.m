classdef MaestroGUI < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        TabGroup                   matlab.ui.container.TabGroup
        
        % Setup Tab
        SetupTab                   matlab.ui.container.Tab
        SetupGrid                  matlab.ui.container.GridLayout
        ExperimentIDField          matlab.ui.control.EditField
        ExperimentIDLabel          matlab.ui.control.Label
        SamplingRateField          matlab.ui.control.NumericEditField
        SamplingRateLabel          matlab.ui.control.Label
        EngineDropDown             matlab.ui.control.DropDown
        EngineLabel                matlab.ui.control.Label
        DAQVendorField             matlab.ui.control.EditField
        DAQVendorLabel             matlab.ui.control.Label
        DAQDeviceField             matlab.ui.control.EditField
        DAQDeviceLabel             matlab.ui.control.Label
        RefreshButton              matlab.ui.control.Button
        
        % Generators Tab
        GeneratorsTab              matlab.ui.container.Tab
        GeneratorsGrid             matlab.ui.container.GridLayout
        GeneratorsList             matlab.ui.control.ListBox
        GeneratorsLabel            matlab.ui.control.Label
        GeneratorInfoText          matlab.ui.control.TextArea
        
        % Builders Tab
        BuildersTab                matlab.ui.container.Tab
        BuildersGrid               matlab.ui.container.GridLayout
        BuildersList               matlab.ui.control.ListBox
        BuildersLabel              matlab.ui.control.Label
        BuilderInfoText            matlab.ui.control.TextArea
        
        % Block Tab
        BlockTab                   matlab.ui.container.Tab
        BlockGrid                  matlab.ui.container.GridLayout
        BlockBuilderDropDown       matlab.ui.control.DropDown
        BlockBuilderLabel          matlab.ui.control.Label
        TrialsField                matlab.ui.control.NumericEditField
        TrialsLabel                matlab.ui.control.Label
        DeviантProbField           matlab.ui.control.NumericEditField
        DeviантProbLabel           matlab.ui.control.Label
        ConstraintDropDown         matlab.ui.control.DropDown
        ConstraintLabel            matlab.ui.control.Label
        ITIMinField                matlab.ui.control.NumericEditField
        ITIMinLabel                matlab.ui.control.Label
        ITIMaxField                matlab.ui.control.NumericEditField
        ITIMaxLabel                matlab.ui.control.Label
        StandardPanel              matlab.ui.container.Panel
        StandardFreqField          matlab.ui.control.NumericEditField
        StandardFreqLabel          matlab.ui.control.Label
        StandardDurField           matlab.ui.control.NumericEditField
        StandardDurLabel           matlab.ui.control.Label
        StandardLevelField         matlab.ui.control.NumericEditField
        StandardLevelLabel         matlab.ui.control.Label
        DeviantPanel               matlab.ui.container.Panel
        DeviantFreqField           matlab.ui.control.NumericEditField
        DeviantFreqLabel           matlab.ui.control.Label
        DeviantDurField            matlab.ui.control.NumericEditField
        DeviantDurLabel            matlab.ui.control.Label
        DeviantLevelField          matlab.ui.control.NumericEditField
        DeviantLevelLabel          matlab.ui.control.Label
        ValidateButton             matlab.ui.control.Button
        ValidationText             matlab.ui.control.TextArea
        
        % Run Tab
        RunTab                     matlab.ui.container.Tab
        RunGrid                    matlab.ui.container.GridLayout
        RunButton                  matlab.ui.control.StateButton
        RunStatusLabel             matlab.ui.control.Label
        ProgressGauge              matlab.ui.control.LinearGauge
        TrialCounterLabel          matlab.ui.control.Label
        ElapsedTimeLabel           matlab.ui.control.Label
        
        % Results Tab
        ResultsTab                 matlab.ui.container.Tab
        ResultsGrid                matlab.ui.container.GridLayout
        ResultsAxes                matlab.ui.control.UIAxes
        ResultsSummaryText         matlab.ui.control.TextArea
        LoadResultsButton          matlab.ui.control.Button
        
        % Menu
        FileMenu                   matlab.ui.container.Menu
        LoadConfigMenu             matlab.ui.container.Menu
        SaveConfigMenu             matlab.ui.container.Menu
        ExitMenu                   matlab.ui.container.Menu
    end

    properties (Access = private)
        ctx                        % MaestroContext
        current_experiment         % Current experiment configuration
        current_results            % Results from last run
        run_timer                  % Timer for updating progress
        experiment_start_time      % Start time of experiment
    end

    methods (Access = private)

        function startupFcn(app)
            % Initialize Maestro context
            app.ctx = core.MaestroContext();
            app.refreshComponents();
            app.updateStatus('Ready');
        end
        
        function refreshComponents(app)
            % Update dropdowns with available components
            
            % Engines
            if isempty(app.ctx.engines)
                app.EngineDropDown.Items = {'No engines found'};
            else
                engine_names = keys(app.ctx.engines);
                app.EngineDropDown.Items = engine_names;
                if ~isempty(engine_names)
                    app.EngineDropDown.Value = engine_names{1};
                end
            end
            
            % Generators
            if isempty(app.ctx.generators)
                app.GeneratorsList.Items = {'No generators found'};
            else
                app.GeneratorsList.Items = keys(app.ctx.generators);
            end
            
            % Builders
            if isempty(app.ctx.builders)
                app.BuildersList.Items = {'No builders found'};
                app.BlockBuilderDropDown.Items = {'No builders found'};
            else
                builder_names = keys(app.ctx.builders);
                app.BuildersList.Items = builder_names;
                app.BlockBuilderDropDown.Items = builder_names;
                if ~isempty(builder_names)
                    app.BlockBuilderDropDown.Value = builder_names{1};
                end
            end
        end
        
        function showGeneratorInfo(app, event)
            % Display generator information
            gen_name = app.GeneratorsList.Value;
            if isempty(gen_name) || strcmp(gen_name, 'No generators found')
                return;
            end
            
            gen_info = app.ctx.generators(gen_name);
            info_text = sprintf('Generator: %s\n', gen_name);
            info_text = [info_text sprintf('Version: %s\n', gen_info.schema.version)];
            info_text = [info_text sprintf('Description: %s\n\n', gen_info.schema.description)];
            info_text = [info_text sprintf('Modality: %s\n', gen_info.schema.modality)];
            info_text = [info_text sprintf('Render Type: %s\n\n', gen_info.schema.render_type)];
            
            % List parameters
            if isfield(gen_info.schema, 'parameters')
                info_text = [info_text sprintf('Parameters:\n')];
                param_names = fieldnames(gen_info.schema.parameters);
                for i = 1:length(param_names)
                    pname = param_names{i};
                    pinfo = gen_info.schema.parameters.(pname);
                    info_text = [info_text sprintf('  - %s: %s\n', pname, pinfo.description)];
                end
            end
            
            app.GeneratorInfoText.Value = info_text;
        end
        
        function showBuilderInfo(app, event)
            % Display builder information
            builder_name = app.BuildersList.Value;
            if isempty(builder_name) || strcmp(builder_name, 'No builders found')
                return;
            end
            
            builder_info = app.ctx.builders(builder_name);
            info_text = sprintf('Builder: %s\n', builder_name);
            info_text = [info_text sprintf('Version: %s\n', builder_info.schema.version)];
            info_text = [info_text sprintf('Description: %s\n', builder_info.schema.description)];
            
            app.BuilderInfoText.Value = info_text;
        end
        
        function validateExperiment(app, event)
            % Validate current configuration
            try
                experiment = app.buildExperimentStruct();
                [is_valid, errors] = core.validate_experiment(experiment, app.ctx);
                
                if is_valid
                    app.ValidationText.Value = '✓ Experiment configuration is valid!';
                    app.ValidationText.FontColor = [0 0.5 0];
                else
                    error_text = '✗ Validation errors:\n';
                    for i = 1:length(errors)
                        error_text = [error_text sprintf('  - %s\n', errors{i})];
                    end
                    app.ValidationText.Value = error_text;
                    app.ValidationText.FontColor = [0.8 0 0];
                end
            catch ME
                app.ValidationText.Value = sprintf('✗ Error: %s', ME.message);
                app.ValidationText.FontColor = [0.8 0 0];
            end
        end
        
        function experiment = buildExperimentStruct(app)
            % Build experiment structure from GUI inputs
            
            experiment = struct();
            experiment.experiment_id = app.ExperimentIDField.Value;
            
            % Global settings
            experiment.global_settings = struct();
            experiment.global_settings.sampling_rate_hz = app.SamplingRateField.Value;
            experiment.global_settings.engine_type = app.EngineDropDown.Value;
            
            % Engine config
            experiment.global_settings.engine_config = struct();
            experiment.global_settings.engine_config.vendor = app.DAQVendorField.Value;
            experiment.global_settings.engine_config.device_id = app.DAQDeviceField.Value;
            experiment.global_settings.engine_config.audio_channels = {'ao0', 'ao1'};
            
            % Build block
            block = struct();
            block.block_instance = struct();
            block.block_instance.instance_id = sprintf('%s_block1', experiment.experiment_id);
            block.block_instance.builder_type = app.BlockBuilderDropDown.Value;
            
            % Block parameters
            block.block_instance.parameters = struct();
            block.block_instance.parameters.n_trials = app.TrialsField.Value;
            block.block_instance.parameters.deviant_probability = app.DeviантProbField.Value;
            block.block_instance.parameters.order_constraint = lower(app.ConstraintDropDown.Value);
            block.block_instance.parameters.iti_sec = [app.ITIMinField.Value, app.ITIMaxField.Value];
            
            % Standard stimulus
            block.block_instance.parameters.standard_stimulus = struct(...
                'generator', 'tone', ...
                'version', '1.0.0', ...
                'parameters', struct(...
                    'freq_hz', app.StandardFreqField.Value, ...
                    'dur_ms', app.StandardDurField.Value, ...
                    'level_db', app.StandardLevelField.Value, ...
                    'ramp_ms', 5 ...
                ) ...
            );
            
            % Deviant stimulus
            block.block_instance.parameters.deviant_stimulus = struct(...
                'generator', 'tone', ...
                'version', '1.0.0', ...
                'parameters', struct(...
                    'freq_hz', app.DeviantFreqField.Value, ...
                    'dur_ms', app.DeviantDurField.Value, ...
                    'level_db', app.DeviantLevelField.Value, ...
                    'ramp_ms', 5 ...
                ) ...
            );
            
            experiment.sequence = block;
        end
        
        function runExperiment(app, event)
            % Run or stop experiment
            
            if strcmp(app.RunButton.Value, 'on')
                % Start experiment
                try
                    app.RunButton.Text = 'Stop';
                    app.updateStatus('Running...');
                    drawnow;
                    
                    % Build experiment
                    experiment = app.buildExperimentStruct();
                    
                    % Store start time
                    app.experiment_start_time = tic;
                    
                    % Run in background (would need different approach for real async)
                    app.current_results = app.ctx.run_experiment(experiment);
                    
                    % Update results
                    app.displayResults();
                    app.updateStatus('Completed successfully!');
                    
                catch ME
                    app.updateStatus(sprintf('Error: %s', ME.message));
                    app.RunButton.Value = 'off';
                    app.RunButton.Text = 'Run Experiment';
                end
                
                app.RunButton.Value = 'off';
                app.RunButton.Text = 'Run Experiment';
            else
                % Stop experiment (would need proper implementation)
                app.updateStatus('Stopped by user');
            end
        end
        
        function updateStatus(app, message)
            % Update status label
            app.RunStatusLabel.Text = message;
            drawnow;
        end
        
        function displayResults(app)
            % Display experiment results
            
            if isempty(app.current_results)
                return;
            end
            
            % Switch to results tab
            app.TabGroup.SelectedTab = app.ResultsTab;
            
            % Summary text
            summary = sprintf('Experiment: %s\n', app.current_results.experiment_id);
            summary = [summary sprintf('Completed: %s\n', mat2str(app.current_results.completed))];
            summary = [summary sprintf('Duration: %.1f sec\n', app.current_results.duration_sec)];
            summary = [summary sprintf('Blocks: %d\n', length(app.current_results.blocks))];
            summary = [summary sprintf('Trials: %d\n\n', app.current_results.summary.total_trials)];
            
            if ~isempty(app.current_results.blocks)
                trials = app.current_results.blocks(1).trials;
                n_dev = 0;
                for i = 1:length(trials)
                    if trials(i).metadata.is_deviant
                        n_dev = n_dev + 1;
                    end
                end
                summary = [summary sprintf('Standards: %d (%.1f%%)\n', ...
                    length(trials)-n_dev, 100*(length(trials)-n_dev)/length(trials))];
                summary = [summary sprintf('Deviants: %d (%.1f%%)\n', ...
                    n_dev, 100*n_dev/length(trials))];
            end
            
            app.ResultsSummaryText.Value = summary;
            
            % Plot trial sequence
            if ~isempty(app.current_results.blocks)
                trials = app.current_results.blocks(1).trials;
                trial_types = zeros(length(trials), 1);
                for i = 1:length(trials)
                    trial_types(i) = trials(i).metadata.is_deviant;
                end
                
                cla(app.ResultsAxes);
                stem(app.ResultsAxes, 1:length(trials), trial_types, 'Marker', 'none', 'LineWidth', 2);
                ylim(app.ResultsAxes, [-0.1 1.1]);
                app.ResultsAxes.YTick = [0 1];
                app.ResultsAxes.YTickLabel = {'Standard', 'Deviant'};
                xlabel(app.ResultsAxes, 'Trial Number');
                title(app.ResultsAxes, 'Trial Sequence');
                grid(app.ResultsAxes, 'on');
            end
        end
        
        function loadConfiguration(app, event)
            % Load experiment configuration from file
            [file, path] = uigetfile('*.json', 'Load Experiment Configuration');
            if file == 0
                return;
            end
            
            try
                config = jsondecode(fileread(fullfile(path, file)));
                app.loadConfigIntoGUI(config);
                app.updateStatus(sprintf('Loaded: %s', file));
            catch ME
                uialert(app.UIFigure, ME.message, 'Load Error');
            end
        end
        
        function saveConfiguration(app, event)
            % Save experiment configuration to file
            [file, path] = uiputfile('*.json', 'Save Experiment Configuration');
            if file == 0
                return;
            end
            
            try
                experiment = app.buildExperimentStruct();
                json_text = jsonencode(experiment);
                fid = fopen(fullfile(path, file), 'w');
                fprintf(fid, '%s', json_text);
                fclose(fid);
                app.updateStatus(sprintf('Saved: %s', file));
            catch ME
                uialert(app.UIFigure, ME.message, 'Save Error');
            end
        end
        
        function loadConfigIntoGUI(app, config)
            % Load configuration into GUI fields
            if isfield(config, 'experiment_id')
                app.ExperimentIDField.Value = config.experiment_id;
            end
            
            if isfield(config, 'global_settings')
                gs = config.global_settings;
                if isfield(gs, 'sampling_rate_hz')
                    app.SamplingRateField.Value = gs.sampling_rate_hz;
                end
                if isfield(gs, 'engine_type')
                    app.EngineDropDown.Value = gs.engine_type;
                end
                if isfield(gs, 'engine_config')
                    ec = gs.engine_config;
                    if isfield(ec, 'vendor')
                        app.DAQVendorField.Value = ec.vendor;
                    end
                    if isfield(ec, 'device_id')
                        app.DAQDeviceField.Value = ec.device_id;
                    end
                end
            end
            
            % Load block parameters if present
            if isfield(config, 'sequence') && ~isempty(config.sequence)
                block = config.sequence(1);
                if isfield(block, 'block_instance')
                    inst = block.block_instance;
                    if isfield(inst, 'parameters')
                        p = inst.parameters;
                        if isfield(p, 'n_trials')
                            app.TrialsField.Value = p.n_trials;
                        end
                        % ... load other parameters
                    end
                end
            end
        end
    end

    % Component initialization
    methods (Access = private)

        function createComponents(app)
            % Create UIFigure and components
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 900 600];
            app.UIFigure.Name = 'Maestro v2.0';
            
            % Create menus
            app.FileMenu = uimenu(app.UIFigure, 'Text', 'File');
            app.LoadConfigMenu = uimenu(app.FileMenu, 'Text', 'Load Configuration...', ...
                'MenuSelectedFcn', createCallbackFcn(app, @loadConfiguration, true));
            app.SaveConfigMenu = uimenu(app.FileMenu, 'Text', 'Save Configuration...', ...
                'MenuSelectedFcn', createCallbackFcn(app, @saveConfiguration, true));
            app.ExitMenu = uimenu(app.FileMenu, 'Text', 'Exit', ...
                'MenuSelectedFcn', @(~,~) delete(app));
            
            % Create TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [10 10 880 580];
            
            % Create tabs
            app.createSetupTab();
            app.createGeneratorsTab();
            app.createBuildersTab();
            app.createBlockTab();
            app.createRunTab();
            app.createResultsTab();
            
            % Show figure
            app.UIFigure.Visible = 'on';
        end
        
        function createSetupTab(app)
            app.SetupTab = uitab(app.TabGroup, 'Title', 'Setup');
            app.SetupGrid = uigridlayout(app.SetupTab, [10 2]);
            app.SetupGrid.RowHeight = repmat({30}, 1, 10);
            
            % Experiment ID
            app.ExperimentIDLabel = uilabel(app.SetupGrid, 'Text', 'Experiment ID:');
            app.ExperimentIDLabel.Layout.Row = 1;
            app.ExperimentIDLabel.Layout.Column = 1;
            app.ExperimentIDField = uieditfield(app.SetupGrid, 'text');
            app.ExperimentIDField.Layout.Row = 1;
            app.ExperimentIDField.Layout.Column = 2;
            app.ExperimentIDField.Value = 'experiment_001';
            
            % Sampling Rate
            app.SamplingRateLabel = uilabel(app.SetupGrid, 'Text', 'Sampling Rate (Hz):');
            app.SamplingRateLabel.Layout.Row = 2;
            app.SamplingRateLabel.Layout.Column = 1;
            app.SamplingRateField = uieditfield(app.SetupGrid, 'numeric');
            app.SamplingRateField.Layout.Row = 2;
            app.SamplingRateField.Layout.Column = 2;
            app.SamplingRateField.Value = 192000;
            app.SamplingRateField.Limits = [8000 500000];
            
            % Engine
            app.EngineLabel = uilabel(app.SetupGrid, 'Text', 'Engine:');
            app.EngineLabel.Layout.Row = 3;
            app.EngineLabel.Layout.Column = 1;
            app.EngineDropDown = uidropdown(app.SetupGrid);
            app.EngineDropDown.Layout.Row = 3;
            app.EngineDropDown.Layout.Column = 2;
            
            % DAQ Vendor
            app.DAQVendorLabel = uilabel(app.SetupGrid, 'Text', 'DAQ Vendor:');
            app.DAQVendorLabel.Layout.Row = 4;
            app.DAQVendorLabel.Layout.Column = 1;
            app.DAQVendorField = uieditfield(app.SetupGrid, 'text');
            app.DAQVendorField.Layout.Row = 4;
            app.DAQVendorField.Layout.Column = 2;
            app.DAQVendorField.Value = 'ni';
            
            % DAQ Device
            app.DAQDeviceLabel = uilabel(app.SetupGrid, 'Text', 'DAQ Device:');
            app.DAQDeviceLabel.Layout.Row = 5;
            app.DAQDeviceLabel.Layout.Column = 1;
            app.DAQDeviceField = uieditfield(app.SetupGrid, 'text');
            app.DAQDeviceField.Layout.Row = 5;
            app.DAQDeviceField.Layout.Column = 2;
            app.DAQDeviceField.Value = 'Dev1';
            
            % Refresh button
            app.RefreshButton = uibutton(app.SetupGrid, 'Text', 'Refresh Components');
            app.RefreshButton.Layout.Row = 6;
            app.RefreshButton.Layout.Column = [1 2];
            app.RefreshButton.ButtonPushedFcn = createCallbackFcn(app, @(~,~) app.refreshComponents(), true);
        end
        
        function createGeneratorsTab(app)
            app.GeneratorsTab = uitab(app.TabGroup, 'Title', 'Generators');
            app.GeneratorsGrid = uigridlayout(app.GeneratorsTab, [2 2]);
            app.GeneratorsGrid.RowHeight = {'1x', '2x'};
            app.GeneratorsGrid.ColumnWidth = {'1x', '2x'};
            
            % List
            app.GeneratorsLabel = uilabel(app.GeneratorsGrid, 'Text', 'Available Generators:');
            app.GeneratorsLabel.Layout.Row = 1;
            app.GeneratorsLabel.Layout.Column = 1;
            
            app.GeneratorsList = uilistbox(app.GeneratorsGrid);
            app.GeneratorsList.Layout.Row = 2;
            app.GeneratorsList.Layout.Column = 1;
            app.GeneratorsList.ValueChangedFcn = createCallbackFcn(app, @showGeneratorInfo, true);
            
            % Info
            app.GeneratorInfoText = uitextarea(app.GeneratorsGrid);
            app.GeneratorInfoText.Layout.Row = [1 2];
            app.GeneratorInfoText.Layout.Column = 2;
            app.GeneratorInfoText.Editable = 'off';
        end
        
        function createBuildersTab(app)
            app.BuildersTab = uitab(app.TabGroup, 'Title', 'Builders');
            app.BuildersGrid = uigridlayout(app.BuildersTab, [2 2]);
            app.BuildersGrid.RowHeight = {'1x', '2x'};
            app.BuildersGrid.ColumnWidth = {'1x', '2x'};
            
            % List
            app.BuildersLabel = uilabel(app.BuildersGrid, 'Text', 'Available Builders:');
            app.BuildersLabel.Layout.Row = 1;
            app.BuildersLabel.Layout.Column = 1;
            
            app.BuildersList = uilistbox(app.BuildersGrid);
            app.BuildersList.Layout.Row = 2;
            app.BuildersList.Layout.Column = 1;
            app.BuildersList.ValueChangedFcn = createCallbackFcn(app, @showBuilderInfo, true);
            
            % Info
            app.BuilderInfoText = uitextarea(app.BuildersGrid);
            app.BuilderInfoText.Layout.Row = [1 2];
            app.BuilderInfoText.Layout.Column = 2;
            app.BuilderInfoText.Editable = 'off';
        end
        
        function createBlockTab(app)
            app.BlockTab = uitab(app.TabGroup, 'Title', 'Block Configuration');
            app.BlockGrid = uigridlayout(app.BlockTab, [15 4]);
            app.BlockGrid.RowHeight = repmat({30}, 1, 15);
            
            % Builder selection
            app.BlockBuilderLabel = uilabel(app.BlockGrid, 'Text', 'Builder:');
            app.BlockBuilderLabel.Layout.Row = 1;
            app.BlockBuilderLabel.Layout.Column = 1;
            app.BlockBuilderDropDown = uidropdown(app.BlockGrid);
            app.BlockBuilderDropDown.Layout.Row = 1;
            app.BlockBuilderDropDown.Layout.Column = [2 4];
            
            % Number of trials
            app.TrialsLabel = uilabel(app.BlockGrid, 'Text', 'Number of Trials:');
            app.TrialsLabel.Layout.Row = 2;
            app.TrialsLabel.Layout.Column = 1;
            app.TrialsField = uieditfield(app.BlockGrid, 'numeric');
            app.TrialsField.Layout.Row = 2;
            app.TrialsField.Layout.Column = 2;
            app.TrialsField.Value = 100;
            app.TrialsField.Limits = [1 10000];
            
            % Deviant probability
            app.DeviантProbLabel = uilabel(app.BlockGrid, 'Text', 'Deviant Probability:');
            app.DeviантProbLabel.Layout.Row = 3;
            app.DeviантProbLabel.Layout.Column = 1;
            app.DeviантProbField = uieditfield(app.BlockGrid, 'numeric');
            app.DeviантProbField.Layout.Row = 3;
            app.DeviантProbField.Layout.Column = 2;
            app.DeviантProbField.Value = 0.15;
            app.DeviантProbField.Limits = [0 1];
            
            % Order constraint
            app.ConstraintLabel = uilabel(app.BlockGrid, 'Text', 'Order Constraint:');
            app.ConstraintLabel.Layout.Row = 4;
            app.ConstraintLabel.Layout.Column = 1;
            app.ConstraintDropDown = uidropdown(app.BlockGrid);
            app.ConstraintDropDown.Layout.Row = 4;
            app.ConstraintDropDown.Layout.Column = 2;
            app.ConstraintDropDown.Items = {'None', 'No_Consecutive_Deviants'};
            app.ConstraintDropDown.Value = 'No_Consecutive_Deviants';
            
            % ITI
            app.ITIMinLabel = uilabel(app.BlockGrid, 'Text', 'ITI Min (sec):');
            app.ITIMinLabel.Layout.Row = 5;
            app.ITIMinLabel.Layout.Column = 1;
            app.ITIMinField = uieditfield(app.BlockGrid, 'numeric');
            app.ITIMinField.Layout.Row = 5;
            app.ITIMinField.Layout.Column = 2;
            app.ITIMinField.Value = 1.0;
            
            app.ITIMaxLabel = uilabel(app.BlockGrid, 'Text', 'ITI Max (sec):');
            app.ITIMaxLabel.Layout.Row = 5;
            app.ITIMaxLabel.Layout.Column = 3;
            app.ITIMaxField = uieditfield(app.BlockGrid, 'numeric');
            app.ITIMaxField.Layout.Row = 5;
            app.ITIMaxField.Layout.Column = 4;
            app.ITIMaxField.Value = 2.0;
            
            % Standard stimulus panel
            app.StandardPanel = uipanel(app.BlockGrid, 'Title', 'Standard Stimulus');
            app.StandardPanel.Layout.Row = [6 8];
            app.StandardPanel.Layout.Column = [1 4];
            
            standardGrid = uigridlayout(app.StandardPanel, [3 4]);
            standardGrid.RowHeight = {30, 30, 30};
            
            app.StandardFreqLabel = uilabel(standardGrid, 'Text', 'Frequency (Hz):');
            app.StandardFreqLabel.Layout.Row = 1;
            app.StandardFreqLabel.Layout.Column = 1;
            app.StandardFreqField = uieditfield(standardGrid, 'numeric');
            app.StandardFreqField.Layout.Row = 1;
            app.StandardFreqField.Layout.Column = 2;
            app.StandardFreqField.Value = 1000;
            
            app.StandardDurLabel = uilabel(standardGrid, 'Text', 'Duration (ms):');
            app.StandardDurLabel.Layout.Row = 2;
            app.StandardDurLabel.Layout.Column = 1;
            app.StandardDurField = uieditfield(standardGrid, 'numeric');
            app.StandardDurField.Layout.Row = 2;
            app.StandardDurField.Layout.Column = 2;
            app.StandardDurField.Value = 50;
            
            app.StandardLevelLabel = uilabel(standardGrid, 'Text', 'Level (dB SPL):');
            app.StandardLevelLabel.Layout.Row = 3;
            app.StandardLevelLabel.Layout.Column = 1;
            app.StandardLevelField = uieditfield(standardGrid, 'numeric');
            app.StandardLevelField.Layout.Row = 3;
            app.StandardLevelField.Layout.Column = 2;
            app.StandardLevelField.Value = 60;
            
            % Deviant stimulus panel
            app.DeviantPanel = uipanel(app.BlockGrid, 'Title', 'Deviant Stimulus');
            app.DeviantPanel.Layout.Row = [9 11];
            app.DeviantPanel.Layout.Column = [1 4];
            
            deviantGrid = uigridlayout(app.DeviantPanel, [3 4]);
            deviantGrid.RowHeight = {30, 30, 30};
            
            app.DeviantFreqLabel = uilabel(deviantGrid, 'Text', 'Frequency (Hz):');
            app.DeviantFreqLabel.Layout.Row = 1;
            app.DeviantFreqLabel.Layout.Column = 1;
            app.DeviantFreqField = uieditfield(deviantGrid, 'numeric');
            app.DeviantFreqField.Layout.Row = 1;
            app.DeviantFreqField.Layout.Column = 2;
            app.DeviantFreqField.Value = 2000;
            
            app.DeviantDurLabel = uilabel(deviantGrid, 'Text', 'Duration (ms):');
            app.DeviantDurLabel.Layout.Row = 2;
            app.DeviantDurLabel.Layout.Column = 1;
            app.DeviantDurField = uieditfield(deviantGrid, 'numeric');
            app.DeviantDurField.Layout.Row = 2;
            app.DeviantDurField.Layout.Column = 2;
            app.DeviantDurField.Value = 50;
            
            app.DeviantLevelLabel = uilabel(deviantGrid, 'Text', 'Level (dB SPL):');
            app.DeviantLevelLabel.Layout.Row = 3;
            app.DeviantLevelLabel.Layout.Column = 1;
            app.DeviantLevelField = uieditfield(deviantGrid, 'numeric');
            app.DeviantLevelField.Layout.Row = 3;
            app.DeviantLevelField.Layout.Column = 2;
            app.DeviantLevelField.Value = 60;
            
            % Validate button
            app.ValidateButton = uibutton(app.BlockGrid, 'Text', 'Validate Configuration');
            app.ValidateButton.Layout.Row = 12;
            app.ValidateButton.Layout.Column = [1 4];
            app.ValidateButton.ButtonPushedFcn = createCallbackFcn(app, @validateExperiment, true);
            
            % Validation text
            app.ValidationText = uitextarea(app.BlockGrid);
            app.ValidationText.Layout.Row = [13 15];
            app.ValidationText.Layout.Column = [1 4];
            app.ValidationText.Editable = 'off';
            app.ValidationText.Value = 'Configure your experiment and click "Validate Configuration"';
        end
        
        function createRunTab(app)
            app.RunTab = uitab(app.TabGroup, 'Title', 'Run');
            app.RunGrid = uigridlayout(app.RunTab, [6 1]);
            app.RunGrid.RowHeight = {50, 30, 30, 30, 30, '1x'};
            
            % Run button
            app.RunButton = uibutton(app.RunGrid, 'state', 'Text', 'Run Experiment');
            app.RunButton.Layout.Row = 1;
            app.RunButton.Layout.Column = 1;
            app.RunButton.FontSize = 16;
            app.RunButton.FontWeight = 'bold';
            app.RunButton.ValueChangedFcn = createCallbackFcn(app, @runExperiment, true);
            
            % Status
            app.RunStatusLabel = uilabel(app.RunGrid, 'Text', 'Ready');
            app.RunStatusLabel.Layout.Row = 2;
            app.RunStatusLabel.Layout.Column = 1;
            app.RunStatusLabel.FontSize = 14;
            
            % Progress gauge
            app.ProgressGauge = uigauge(app.RunGrid, 'linear');
            app.ProgressGauge.Layout.Row = 3;
            app.ProgressGauge.Layout.Column = 1;
            
            % Trial counter
            app.TrialCounterLabel = uilabel(app.RunGrid, 'Text', 'Trial: 0 / 0');
            app.TrialCounterLabel.Layout.Row = 4;
            app.TrialCounterLabel.Layout.Column = 1;
            
            % Elapsed time
            app.ElapsedTimeLabel = uilabel(app.RunGrid, 'Text', 'Elapsed: 0 sec');
            app.ElapsedTimeLabel.Layout.Row = 5;
            app.ElapsedTimeLabel.Layout.Column = 1;
        end
        
        function createResultsTab(app)
            app.ResultsTab = uitab(app.TabGroup, 'Title', 'Results');
            app.ResultsGrid = uigridlayout(app.ResultsTab, [3 2]);
            app.ResultsGrid.RowHeight = {30, '2x', '1x'};
            app.ResultsGrid.ColumnWidth = {'2x', '1x'};
            
            % Load button
            app.LoadResultsButton = uibutton(app.ResultsGrid, 'Text', 'Load Results...');
            app.LoadResultsButton.Layout.Row = 1;
            app.LoadResultsButton.Layout.Column = 1;
            
            % Plot
            app.ResultsAxes = uiaxes(app.ResultsGrid);
            app.ResultsAxes.Layout.Row = [2 3];
            app.ResultsAxes.Layout.Column = 1;
            title(app.ResultsAxes, 'Trial Sequence');
            
            % Summary
            app.ResultsSummaryText = uitextarea(app.ResultsGrid);
            app.ResultsSummaryText.Layout.Row = [2 3];
            app.ResultsSummaryText.Layout.Column = 2;
            app.ResultsSummaryText.Editable = 'off';
            app.ResultsSummaryText.Value = 'No results loaded';
        end
    end

    % App creation and deletion
    methods (Access = public)

        function app = MaestroGUI

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end