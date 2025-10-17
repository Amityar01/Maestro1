classdef StimulusEditor < handle
    % STIMULUSEDITOR - Modal dialog to edit a stimulus specification
    %
    % This app is schema-driven. It reads a generator's schema
    % and dynamically builds a parameter-editing form.
    % It also loads and saves user-defined presets.
    
    properties
        UIFigure
        Context
        
        % UI Components
        GeneratorDropDown
        ParameterGrid
        
        % Data
        FieldEdits
        GeneratorSchema
        GeneratorPath
        
        % Output
        WasSaved = false
        OutputSpec
    end
    
    methods
        function app = StimulusEditor(parentFigure, context, currentSpec)
            % CONSTRUCTOR
            %
            % INPUTS:
            %   parentFigure - The calling figure (to make modal)
            %   context - The MaestroContext, for access to generators
            %   currentSpec - The existing stimulus spec struct, or []
            
            app.Context = context;
            app.FieldEdits = containers.Map();
            
            % Create the figure
            app.UIFigure = uifigure('Name', 'Stimulus Editor', ...
                'WindowStyle', 'modal', ... 
                'Position', [1 1 500 600], ...
                'CloseRequestFcn', @(~,~) app.onCancel);
            
            centerfig(app.UIFigure, parentFigure);
            
            % Main layout
            mainLayout = uigridlayout(app.UIFigure, [4 1]);
            mainLayout.RowHeight = {30, 'fit', '1x', 50};
            
            % 1. Generator Selection
            app.GeneratorDropDown = uidropdown(mainLayout, 'Items', {});
            app.GeneratorDropDown.Layout.Row = 1;
            app.GeneratorDropDown.ValueChangedFcn = @(~,~) app.onGeneratorChanged();
            
            % 2. Preset Management
            presetPanel = uipanel(mainLayout);
            presetPanel.Layout.Row = 2;
            presetGrid = uigridlayout(presetPanel, [1 3]);
            
            uibutton(presetGrid, 'Text', 'Load Preset...', 'ButtonPushedFcn', @(~,~) app.onLoadPreset());
            uibutton(presetGrid, 'Text', 'Save as Preset...', 'ButtonPushedFcn', @(~,~) app.onSavePreset());
            uibutton(presetGrid, 'Text', 'Delete Preset...', 'ButtonPushedFcn', @(~,~) app.onDeletePreset());

            % 3. Parameter Panel
            paramPanel = uipanel(mainLayout, 'Title', 'Parameters', 'Scrollable', 'on');
            paramPanel.Layout.Row = 3;
            app.ParameterGrid = uigridlayout(paramPanel);
            app.ParameterGrid.ColumnWidth = {150, '1x'};
            app.ParameterGrid.RowHeight = {'fit'}; % Default
            
            % 4. Button Panel
            buttonLayout = uigridlayout(mainLayout, [1 3]);
            buttonLayout.Layout.Row = 4;
            buttonLayout.ColumnWidth = {'1x', 100, 100};
            
            uilabel(buttonLayout); % Spacer
            uibutton(buttonLayout, 'Text', 'Cancel', 'ButtonPushedFcn', @(~,~) app.onCancel);
            uibutton(buttonLayout, 'Text', 'Save', 'BackgroundColor', [0.3 0.7 0.3], ...
                'ButtonPushedFcn', @(~,~) app.onSave);
            
            % Populate and set initial state
            app.populateGeneratorDropdown();
            
            if isstruct(currentSpec) && isfield(currentSpec, 'generator') && ~isempty(currentSpec.generator)
                app.GeneratorDropDown.Value = currentSpec.generator;
            end
            
            app.onGeneratorChanged(currentSpec);
        end
        
        function populateGeneratorDropdown(app)
            % Fill the dropdown with available generators
            genKeys = keys(app.Context.generators);
            if isempty(genKeys)
                app.GeneratorDropDown.Items = {'No generators found'};
                app.GeneratorDropDown.Enable = 'off';
                return;
            end
            app.GeneratorDropDown.Items = genKeys;
            app.GeneratorDropDown.Value = genKeys{1};
        end
        
        function onGeneratorChanged(app, currentSpec)
            % Fired when user selects a new generator
            % This function REBUILDS the parameter grid
            
            if nargin < 2
                currentSpec = []; % No spec provided, use defaults
            end
            
            % Clear existing fields
            delete(app.ParameterGrid.Children);
            app.FieldEdits = containers.Map();
            
            genKey = app.GeneratorDropDown.Value;
            if ~isKey(app.Context.generators, genKey)
                return;
            end
            
            % Get the schema and path for this generator
            genInfo = app.Context.generators(genKey);
            app.GeneratorSchema = genInfo.schema;
            app.GeneratorPath = genInfo.path;
            
            if ~isfield(app.GeneratorSchema, 'parameters')
                uilabel(app.ParameterGrid, 'Text', 'This generator has no parameters.');
                return;
            end
            
            param_names = fieldnames(app.GeneratorSchema.parameters);
            
            % Set row heights to 'fit' to accommodate dynamic controls
            app.ParameterGrid.RowHeight = repmat({'fit'}, 1, length(param_names));
            
            % Loop and create UI for each parameter
            for i = 1:length(param_names)
                param_name = param_names{i};
                param_spec = app.GeneratorSchema.parameters.(param_name);
                
                % Determine current value
                current_value = [];
                if isstruct(currentSpec) && isfield(currentSpec, 'parameters') && isfield(currentSpec.parameters, param_name)
                    current_value = currentSpec.parameters.(param_name);
                elseif isfield(param_spec, 'default')
                    current_value = param_spec.default;
                end
                
                % Create the field
                app.createParameterField(app.ParameterGrid, param_name, param_spec, i, current_value);
            end
        end
        
        % In Maestro/+gui/+stimuli/StimulusEditor.m
        function createParameterField(app, parent, param_name, param_spec, row, current_value)
            % Creates a single label/editor row in the grid
            
            label_text = param_name;
            unit_type = '';
            
            % Check for UI hints and unit fields
            if isfield(param_spec, 'ui_hints')
                if isfield(param_spec.ui_hints, 'display_name')
                    label_text = param_spec.ui_hints.display_name;
                end
                if isfield(param_spec.ui_hints, 'unit')
                    unit_type = param_spec.ui_hints.unit;
                end
            elseif isfield(param_spec, 'unit') % Fallback to root 'unit'
                unit_type = param_spec.unit;
            end

            if isfield(param_spec, 'required') && param_spec.required
                label_text = ['* ' label_text];
            end
            
            label = uilabel(parent, 'Text', label_text);
            label.Layout.Row = row;
            label.Layout.Column = 1;
            
            if isfield(param_spec, 'description')
                label.Tooltip = param_spec.description;
            end
            
            % Check if value is a randomization spec
            is_random = core.is_randomization_spec(current_value);
            
            % Apply unit conversions for display *if not random*
            if ~isempty(current_value) && ~is_random
                switch unit_type
                    case {'ms', 'milliseconds'}
                        % --- START FIX ---
                        % ONLY convert if the param name *ends in _sec*
                        if endsWith(param_name, '_sec')
                            current_value = current_value * 1000; % sec to ms
                        else
                            % Otherwise, the value is already in ms
                            % (e.g., ramp_ms)
                            % No conversion needed.
                        end
                        % --- END FIX ---
                    case '%'
                        current_value = current_value * 100;  % 0-1 to 0-100
                end
            end
            
            % Create a panel to hold all controls for this parameter
            controlPanel = uipanel(parent, 'BorderType', 'none');
            controlPanel.Layout.Row = row;
            controlPanel.Layout.Column = 2;
            controlGrid = uigridlayout(controlPanel);
            controlGrid.Padding = [0 0 0 0];
            controlGrid.RowHeight = {'fit', 'fit'};
            controlGrid.ColumnWidth = {'1x', 'fit'};
            
            edit = []; % Main editor
            randCheckbox = [];
            randPanel = [];
            
            % Create editor
            switch param_spec.type
                case {'integer', 'float'}
                    edit = uispinner(controlGrid, 'Limits', [-Inf Inf], 'Step', 0.1);
                    if isfield(param_spec, 'constraints')
                        if isfield(param_spec.constraints, 'min')
                            edit.Limits(1) = param_spec.constraints.min;
                        end
                        if isfield(param_spec.constraints, 'max')
                            edit.Limits(2) = param_spec.constraints.max;
                        end
                    end
                    if strcmp(unit_type, '%')
                        edit.Limits = [0 100];
                    end
                    
                    val_to_set = [];
                    if ~is_random && ~isempty(current_value)
                        val_to_set = current_value;
                    elseif isfield(param_spec, 'default')
                        val_to_set = param_spec.default;
                    end
                    
                    if ~isempty(val_to_set) && val_to_set >= edit.Limits(1) && val_to_set <= edit.Limits(2)
                        edit.Value = val_to_set;
                    else
                        edit.Value = edit.Limits(1);
                    end
                    
                case 'string'
                    edit = uieditfield(controlGrid, 'text');
                    if ~is_random && ~isempty(current_value)
                        edit.Value = current_value;
                    end
                    
                case 'enum'
                    edit = uidropdown(controlGrid, 'Items', param_spec.constraints.options);
                    if ~is_random && ~isempty(current_value)
                        edit.Value = current_value;
                    else
                        edit.Value = param_spec.constraints.options{1};
                    end
                    
                case 'array'
                    edit = app.createArrayEditor(controlGrid, current_value);
                
                otherwise
                    edit = uieditfield(controlGrid, 'text', 'Value', jsonencode(current_value));
            end
            
            edit.Layout.Row = 1;
            edit.Layout.Column = 1;
            
            if isfield(param_spec, 'randomizable') && param_spec.randomizable
                randCheckbox = uicheckbox(controlGrid, 'Text', 'Randomize');
                randCheckbox.Layout.Row = 1;
                randCheckbox.Layout.Column = 2;
                
                % Create the randomization panel (initially hidden)
                randPanel = app.createRandomizationPanel(controlGrid, param_spec, current_value);
                randPanel.Layout.Row = 2;
                randPanel.Layout.Column = [1 2];
                
                % Set checkbox state
                randCheckbox.Value = is_random;
                
                % Set visibility
                if is_random
                    edit.Enable = 'off';
                    randPanel.Visible = 'on';
                else
                    edit.Enable = 'on';
                    randPanel.Visible = 'off';
                end
                
                % Add the callback
                randCheckbox.ValueChangedFcn = @(src, event) app.onRandomizeToggled(src, edit, randPanel);
            end
            
            % Store handles and metadata for saving
            app.FieldEdits(param_name) = struct(...
                'editor', edit, ...
                'randCheckbox', randCheckbox, ...
                'randPanel', randPanel, ...
                'unit_type', unit_type, ...
                'param_type', param_spec.type ...
            );
        end
        
        function panel = createArrayEditor(app, parent, current_value)
            % Creates a listbox with add/remove buttons for array editing
            panel = uipanel(parent, 'BorderType', 'none');
            grid = uigridlayout(panel, [1 3]);
            grid.ColumnWidth = {'1x', 40, 40};
            grid.Padding = [0 0 0 0];
            
            listbox = uilistbox(grid);
            listbox.Layout.Column = 1;
            if ~isempty(current_value)
                listbox.Items = cellstr(num2str(current_value(:)));
            end
            
            addButton = uibutton(grid, 'Text', '+', 'ButtonPushedFcn', @(src, event) app.onArrayAdd(listbox));
            addButton.Layout.Column = 2;
            
            removeButton = uibutton(grid, 'Text', '-', 'ButtonPushedFcn', @(src, event) app.onArrayRemove(listbox));
            removeButton.Layout.Column = 3;
            
            % The 'panel' is the main edit control
        end

        function onArrayAdd(app, listbox)
            val_str = inputdlg('Enter a value:', 'Add Array Element', [1 40]);
            if ~isempty(val_str)
                listbox.Items{end+1} = val_str{1};
            end
        end
        
        function onArrayRemove(app, listbox)
            idx = listbox.Value;
            if ~isempty(idx)
                listbox.Items(idx) = [];
            end
        end
        
        function panel = createRandomizationPanel(app, parent, param_spec, current_value)
            % Creates the hidden panel for randomization controls
            
            panel = uipanel(parent, 'BorderType', 'line');
            grid = uigridlayout(panel, [3 2]);
            grid.ColumnWidth = {100, '1x'};
            grid.RowHeight = {30, 30, 30};
            
            % 1. Type dropdown
            uilabel(grid, 'Text', 'Type:');
            typeDropdown = uidropdown(grid, 'Items', {'random_uniform', 'random_gaussian', 'random_choice'});
            
            % 2. Param 1 (Min / Mean / Options)
            label1 = uilabel(grid, 'Text', 'Min:');
            editor1 = uispinner(grid, 'Limits', [-Inf Inf]);
            
            % 3. Param 2 (Max / Std)
            label2 = uilabel(grid, 'Text', 'Max:');
            editor2 = uispinner(grid, 'Limits', [-Inf Inf]);
            
            % Store handles in the panel's UserData
            panel.UserData = struct(...
                'typeDropdown', typeDropdown, ...
                'label1', label1, ...
                'editor1', editor1, ...
                'label2', label2, ...
                'editor2', editor2 ...
            );
            
            % Add callback to dropdown
            typeDropdown.ValueChangedFcn = @(src, event) app.onRandTypeChanged(panel);
            
            % Set initial values
            if core.is_randomization_spec(current_value)
                typeDropdown.Value = current_value.type;
                switch current_value.type
                    case 'random_uniform'
                        editor1.Value = current_value.min;
                        editor2.Value = current_value.max;
                    case 'random_gaussian'
                        editor1.Value = current_value.mean;
                        editor2.Value = current_value.std;
                    case 'random_choice'
                        % For choice, we use a text field
                        delete(editor1);
                        delete(editor2);
                        editor1 = uieditfield(grid, 'text', 'Value', strjoin(cellstr(num2str(current_value.options(:))), ', '));
                        editor1.Layout.Column = 2;
                        label2.Visible = 'off';
                        
                        % Update UserData struct
                        panel.UserData.editor1 = editor1;
                        panel.UserData.editor2 = []; % No second editor
                end
            end
            
            % Trigger update to set labels
            app.onRandTypeChanged(panel);
        end
        
        function onRandTypeChanged(app, panel)
            % Update labels based on randomization type
            ud = panel.UserData;
            
            switch ud.typeDropdown.Value
                case 'random_uniform'
                    ud.label1.Text = 'Min:';
                    ud.label2.Text = 'Max:';
                    ud.label1.Visible = 'on';
                    ud.editor1.Visible = 'on';
                    ud.label2.Visible = 'on';
                    ud.editor2.Visible = 'on';
                case 'random_gaussian'
                    ud.label1.Text = 'Mean:';
                    ud.label2.Text = 'Std:';
                    ud.label1.Visible = 'on';
                    ud.editor1.Visible = 'on';
                    ud.label2.Visible = 'on';
                    ud.editor2.Visible = 'on';
                case 'random_choice'
                    ud.label1.Text = 'Options:';
                    ud.label2.Text = '(comma-sep)';
                    ud.label1.Visible = 'on';
                    ud.label2.Visible = 'on';
                    ud.editor1.Visible = 'on';
                    if ~isempty(ud.editor2)
                        ud.editor2.Visible = 'off'; % Hide spinner
                    end
            end
        end

        function onRandomizeToggled(app, checkbox, fixedEditor, randPanel)
            if checkbox.Value
                % Randomize is ON
                fixedEditor.Enable = 'off';
                randPanel.Visible = 'on';
            else
                % Randomize is OFF
                fixedEditor.Enable = 'on';
                randPanel.Visible = 'off';
            end
        end
        
        function params = readParametersFromUI(app)
            % Gathers the current parameters from the UI
            % This is used by onSave and onSavePreset
            
            params = struct();
            param_names = fieldnames(app.GeneratorSchema.parameters);
            
            for i = 1:length(param_names)
                param_name = param_names{i};
                controls = app.FieldEdits(param_name);
                is_random = ~isempty(controls.randCheckbox) && controls.randCheckbox.Value;
                
                if is_random
                    % Build Randomization Struct
                    randPanel = controls.randPanel;
                    ud = randPanel.UserData;
                    rand_spec = struct();
                    rand_spec.type = ud.typeDropdown.Value;
                    
                    switch rand_spec.type
                        case 'random_uniform'
                            rand_spec.min = ud.editor1.Value;
                            rand_spec.max = ud.editor2.Value;
                        case 'random_gaussian'
                            rand_spec.mean = ud.editor1.Value;
                            rand_spec.std = ud.editor2.Value;
                        case 'random_choice'
                            vals_str = strsplit(ud.editor1.Value, ',');
                            vals_num = str2double(vals_str);
                            rand_spec.options = vals_num;
                    end
                    params.(param_name) = rand_spec;
                    
                else
                    % Build Fixed Value
                    edit = controls.editor;
                    unit_type = controls.unit_type;
                    param_type = controls.param_type;
                    
                    if strcmp(param_type, 'array')
                        listbox = edit.Children(3); % Assumes listbox
                        vals_str = listbox.Items;
                        params.(param_name) = str2double(vals_str);
                    else
                        ui_value = edit.Value;
                        
                        % --- START FIX ---
                        % Apply inverse conversions
                        switch unit_type
                            case {'ms', 'milliseconds'}
                                % ONLY convert to seconds if the param name
                                % *ends in _sec* (like iti_min_sec)
                                if endsWith(param_name, '_sec')
                                    params.(param_name) = ui_value / 1000; % ms to sec
                                else
                                    % Otherwise, the param is stored in ms
                                    % (like ramp_ms)
                                    params.(param_name) = ui_value; 
                                end
                            case '%'
                                params.(param_name) = ui_value / 100;
                            otherwise
                                if strcmp(param_type, 'integer')
                                    params.(param_name) = round(ui_value);
                                else
                                    params.(param_name) = ui_value;
                                end
                        end
                        % --- END FIX ---
                    end
                end
            end
        end
        
        function onSave(app)
            % Read all values, build spec, and close
            
            app.OutputSpec = struct();
            app.OutputSpec.generator = app.GeneratorDropDown.Value;
            app.OutputSpec.version = app.GeneratorSchema.version;
            app.OutputSpec.parameters = app.readParametersFromUI();
            
            app.WasSaved = true;
            delete(app.UIFigure);
        end
        
        function onCancel(app)
            app.WasSaved = false;
            delete(app.UIFigure);
        end
        
        % --- PRESET MANAGEMENT FUNCTIONS ---
        
        function presetPath = getPresetPath(app)
            % Returns the full path to this generator's presets.json
            presetPath = fullfile(app.GeneratorPath, 'presets.json');
        end
        
        function presets = loadPresets(app)
            % Loads presets from the JSON file
            presets = struct();
            presetFile = app.getPresetPath();
            if exist(presetFile, 'file')
                try
                    presets = jsondecode(fileread(presetFile));
                catch ME
                    uialert(app.UIFigure, sprintf('Error reading presets.json:\n%s', ME.message), 'Preset Load Error');
                end
            end
        end
        
        function savePresets(app, presets)
            % Saves the presets struct back to the JSON file
            presetFile = app.getPresetPath();
            try
                json_text = jsonencode(presets);
                fid = fopen(presetFile, 'w');
                fprintf(fid, '%s', json_text);
                fclose(fid);
            catch ME
                uialert(app.UIFigure, sprintf('Error saving presets.json:\n%s', ME.message), 'Preset Save Error');
            end
        end
        
        function onLoadPreset(app)
            % Load all presets and show a list dialog
            presets = app.loadPresets();
            presetNames = fieldnames(presets);
            
            if isempty(presetNames)
                uialert(app.UIFigure, 'No presets found for this generator.', 'Load Preset');
                return;
            end
            
            [idx, ok] = listdlg('ListString', presetNames, 'SelectionMode', 'single', ...
                'Name', 'Load Preset', 'PromptString', 'Select a preset:');
            
            if ok
                % Get the selected preset's parameters
                selectedPreset = presets.(presetNames{idx});
                
                % Create a temporary spec struct to pass to onGeneratorChanged
                % This re-uses all the logic for populating the fields
                tempSpec = struct();
                tempSpec.generator = app.GeneratorDropDown.Value;
                tempSpec.parameters = selectedPreset;
                
                app.onGeneratorChanged(tempSpec);
            end
        end
        
        function onSavePreset(app)
            % Save the current UI state as a new preset
            
            presetName = inputdlg('Enter a name for this preset:', 'Save Preset', [1 50]);
            
            if isempty(presetName) || isempty(presetName{1})
                return; % User cancelled
            end
            
            presetName = matlab.lang.makeValidName(presetName{1});
            
            % Load existing presets
            presets = app.loadPresets();
            
            % Get current parameters from UI
            currentParams = app.readParametersFromUI();
            
            % Add or overwrite
            presets.(presetName) = currentParams;
            
            % Save back to file
            app.savePresets(presets);
            
            uialert(app.UIFigure, sprintf('Preset "%s" saved.', presetName), 'Success');
        end
        
        function onDeletePreset(app)
            % Show a list of presets to delete
            presets = app.loadPresets();
            presetNames = fieldnames(presets);
            
            if isempty(presetNames)
                uialert(app.UIFigure, 'No presets to delete.', 'Delete Preset');
                return;
            end
            
            [idx, ok] = listdlg('ListString', presetNames, 'SelectionMode', 'single', ...
                'Name', 'Delete Preset', 'PromptString', 'Select preset to delete:');
            
            if ok
                presetName = presetNames{idx};
                answer = uiconfirm(app.UIFigure, ...
                    sprintf('Are you sure you want to delete "%s"?', presetName), ...
                    'Confirm Delete');
                
                if strcmp(answer, 'OK')
                    presets = rmfield(presets, presetName);
                    app.savePresets(presets);
                    uialert(app.UIFigure, sprintf('Preset "%s" deleted.', presetName), 'Success');
                end
            end
        end
        
    end
end