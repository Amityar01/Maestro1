classdef StimulusEditor < handle
    % STIMULUSEDITOR - Modal dialog to edit a stimulus specification
    
    properties
        UIFigure
        Context
        ParentFigure % Store parent figure handle

        % UI Components
        GeneratorDropDown
        ParameterGrid % The grid layout *inside* the scroll panel
        ScrollPanel % The scrollable panel containing the grid
        
        % Data
        FieldEdits % Map: param_name -> struct(...)
        GeneratorSchema
        GeneratorPath
        
        % Output
        WasSaved = false
        OutputSpec
    end
    
    methods
        function app = StimulusEditor(parentFigure, context, currentSpec)
            % CONSTRUCTOR
            app.Context = context;
            app.FieldEdits = containers.Map();
            app.ParentFigure = parentFigure;

            % --- All component creation is now inside this constructor ---
            app.UIFigure = uifigure('Name', 'Stimulus Editor', ...
                'WindowStyle', 'modal', ... 
                'Position', [1 1 550 650], ...
                'CloseRequestFcn', @(~,~) app.onCancel, ...
                'Scrollable', 'on');
            
            if ~isempty(app.ParentFigure) && isvalid(app.ParentFigure)
                 centerfig(app.UIFigure, app.ParentFigure);
            end
            
            mainLayout = uigridlayout(app.UIFigure, [4 1]);
            mainLayout.RowHeight = {30, 'fit', '1x', 50};
            
            % 1. Generator Selection
            genPanel = uipanel(mainLayout, 'BorderType', 'none');
            genPanel.Layout.Row = 1; genPanel.Layout.Column = 1;
            genGrid = uigridlayout(genPanel, [1 2]);
            genGrid.ColumnWidth = {100, '1x'}; genGrid.Padding = [0 0 0 0];
            
            % --- FIX: Explicitly assign handle ---
            genLabel = uilabel(genGrid, 'Text', 'Generator:');
            genLabel.Layout.Row = 1; genLabel.Layout.Column = 1;

            app.GeneratorDropDown = uidropdown(genGrid, 'Items', {});
            app.GeneratorDropDown.ValueChangedFcn = @(~,~) app.onGeneratorChanged([]);
            
            % 2. Preset Management
            presetPanel = uipanel(mainLayout);
            presetPanel.Layout.Row = 2; presetPanel.Layout.Column = 1;
            presetGrid = uigridlayout(presetPanel, [1 3]); presetGrid.ColumnWidth = {'1x', '1x', '1x'};
            uibutton(presetGrid, 'Text', 'Load Preset...', 'ButtonPushedFcn', @(~,~) app.onLoadPreset());
            uibutton(presetGrid, 'Text', 'Save Preset...', 'ButtonPushedFcn', @(~,~) app.onSavePreset());
            uibutton(presetGrid, 'Text', 'Delete Preset...', 'ButtonPushedFcn', @(~,~) app.onDeletePreset());
            
            % 3. Parameter Panel (Scrollable)
             app.ScrollPanel = uipanel(mainLayout, 'Title', 'Parameters', 'Scrollable', 'on');
             app.ScrollPanel.Layout.Row = 3; app.ScrollPanel.Layout.Column = 1;
             app.ParameterGrid = uigridlayout(app.ScrollPanel);
             app.ParameterGrid.ColumnWidth = {150, '1x'};
             app.ParameterGrid.RowHeight = {'fit'};
             app.ParameterGrid.Scrollable = 'on';
             
            % 4. Button Panel
            buttonLayout = uigridlayout(mainLayout, [1 3]);
            buttonLayout.Layout.Row = 4; buttonLayout.Layout.Column = 1;
            buttonLayout.ColumnWidth = {'1x', 100, 100}; buttonLayout.Padding = [10 10 10 10];
            
            % --- FIX: Explicitly assign handle for spacer uilabel ---
            spacerLabel = uilabel(buttonLayout); % Spacer
            spacerLabel.Layout.Row = 1; spacerLabel.Layout.Column = 1;

            uibutton(buttonLayout, 'Text', 'Cancel', 'ButtonPushedFcn', @(~,~) app.onCancel);
            uibutton(buttonLayout, 'Text', 'Save', 'BackgroundColor', [0.3 0.7 0.3], 'ButtonPushedFcn', @(~,~) app.onSave);
            
            % Populate and set initial state
            app.populateGeneratorDropdown();
            
            initialSpec = [];
            if isstruct(currentSpec) && isfield(currentSpec, 'generator') && ~isempty(currentSpec.generator)
                 if ismember(currentSpec.generator, app.GeneratorDropDown.Items)
                    app.GeneratorDropDown.Value = currentSpec.generator;
                    initialSpec = currentSpec;
                 else
                     warning('Initial stimulus spec refers to unknown generator "%s". Using default.', currentSpec.generator);
                 end
            end
            
            app.onGeneratorChanged(initialSpec);
        end
        
         function populateGeneratorDropdown(app)
             genKeys = keys(app.Context.generators);
             if isempty(genKeys)
                 app.GeneratorDropDown.Items = {'No generators found'};
                 app.GeneratorDropDown.Enable = 'off';
             else
                 app.GeneratorDropDown.Items = sort(genKeys);
                 app.GeneratorDropDown.Value = app.GeneratorDropDown.Items{1};
                 app.GeneratorDropDown.Enable = 'on';
             end
         end
         
         function onGeneratorChanged(app, currentSpec)
             delete(app.ParameterGrid.Children);
             app.FieldEdits = containers.Map();
             
             genKey = app.GeneratorDropDown.Value;
             if ~isKey(app.Context.generators, genKey)
                  % --- FIX: Explicitly assign handle ---
                  infoLabel = uilabel(app.ParameterGrid, 'Text', 'Select a valid generator.');
                 return;
             end
             
             genInfo = app.Context.generators(genKey);
             app.GeneratorSchema = genInfo.schema;
             app.GeneratorPath = genInfo.path;
             
             if ~isfield(app.GeneratorSchema, 'parameters') || isempty(fieldnames(app.GeneratorSchema.parameters))
                 % --- FIX: Explicitly assign handle ---
                 infoLabel = uilabel(app.ParameterGrid, 'Text', 'This generator has no parameters.');
                 app.ParameterGrid.RowHeight = {'fit'};
                 return;
             end
             
             param_defs = app.GeneratorSchema.parameters;
             param_names = fieldnames(param_defs);
             num_params = length(param_names);
             
             app.ParameterGrid.RowHeight = repmat({'fit'}, 1, num_params);
             
             for i = 1:num_params
                 param_name = param_names{i};
                 param_spec = param_defs.(param_name);
                 
                 storage_value = [];
                  if isstruct(currentSpec) && isfield(currentSpec, 'parameters') && isfield(currentSpec.parameters, param_name)
                     storage_value = currentSpec.parameters.(param_name);
                  elseif isfield(param_spec, 'default')
                     storage_value = param_spec.default;
                  end
                 
                 app.createParameterField(app.ParameterGrid, param_name, param_spec, i, storage_value);
             end
         end
         
        function createParameterField(app, parent, param_name, param_spec, row, storage_value)
            label_text = param_name;
            unit_type = gui.common.unit_converter.get_unit_type(param_spec);
            if isfield(param_spec, 'ui_hints') && isfield(param_spec.ui_hints, 'display_name')
                label_text = param_spec.ui_hints.display_name;
            end
            required = isfield(param_spec, 'required') && param_spec.required;
            if required
                label_text = ['* ' label_text];
            end
            
            label = uilabel(parent, 'Text', label_text);
            label.Layout.Row = row; label.Layout.Column = 1;
            if isfield(param_spec, 'description')
                label.Tooltip = param_spec.description;
            end
            
            current_display_value = gui.common.unit_converter.to_display(storage_value, param_name, unit_type);
            is_random = core.is_randomization_spec(storage_value);
            
            controlPanel = uipanel(parent, 'BorderType', 'none');
            controlPanel.Layout.Row = row; controlPanel.Layout.Column = 2;
            controlGrid = uigridlayout(controlPanel);
            controlGrid.Padding = [0 0 0 0];
            controlGrid.RowHeight = {'fit', 'fit'};
            controlGrid.ColumnWidth = {'1x', 'fit'};
            
            edit = [];
            randCheckbox = [];
            randPanel = [];
            param_type = param_spec.type;
            
            switch param_type
                case {'integer', 'float'}
                    edit = uispinner(controlGrid, 'Limits', [-Inf Inf], 'Step', 0.1);
                     edit.Value = 0;
                    if isfield(param_spec, 'constraints')
                         if isfield(param_spec.constraints, 'min')
                             min_disp = gui.common.unit_converter.to_display(param_spec.constraints.min, param_name, unit_type);
                             edit.Limits(1) = min_disp;
                         end
                         if isfield(param_spec.constraints, 'max')
                              max_disp = gui.common.unit_converter.to_display(param_spec.constraints.max, param_name, unit_type);
                              edit.Limits(2) = max_disp;
                         end
                    end
                     if strcmp(unit_type, '%')
                        edit.Limits = [0 100];
                    end
                    if ~is_random && ~isempty(current_display_value) && isnumeric(current_display_value)
                         bounded_value = max(edit.Limits(1), min(edit.Limits(2), current_display_value));
                         edit.Value = bounded_value;
                    else
                         edit.Value = edit.Limits(1);
                    end
                case 'string'
                    edit = uieditfield(controlGrid, 'text');
                     if ~is_random && ~isempty(current_display_value)
                         edit.Value = current_display_value;
                     end
                case 'enum'
                    edit = uidropdown(controlGrid, 'Items', param_spec.constraints.options);
                     if ~is_random && ~isempty(current_display_value)
                         edit.Value = current_display_value;
                     elseif ~isempty(param_spec.constraints.options)
                          edit.Value = param_spec.constraints.options{1};
                     end
                case 'array'
                     edit = uieditfield(controlGrid, 'text');
                      if ~is_random && ~isempty(current_display_value)
                          if isnumeric(current_display_value)
                               edit.Value = mat2str(current_display_value);
                          else
                              try edit.Value = jsonencode(current_display_value); catch; edit.Value = '[Error]'; end
                          end
                      else
                           edit.Value = '[]';
                      end
                      edit.Tooltip = 'Enter array as [val1, val2] or JSON string';
                 case 'boolean'
                     edit = uicheckbox(controlGrid, 'Text', '');
                     if ~is_random && ~isempty(current_display_value)
                         edit.Value = logical(current_display_value);
                     end
                otherwise
                    edit = uieditfield(controlGrid, 'text', 'Value', jsonencode(current_display_value));
                    edit.Tooltip = 'Complex type - Edit as JSON string';
            end
            
            edit.Layout.Row = 1; edit.Layout.Column = 1;
            
            if isfield(param_spec, 'randomizable') && param_spec.randomizable
                randCheckbox = uicheckbox(controlGrid, 'Text', 'Random');
                randCheckbox.Layout.Row = 1; randCheckbox.Layout.Column = 2;
                randPanel = app.createRandomizationPanel(controlGrid, storage_value);
                randPanel.Layout.Row = 2; randPanel.Layout.Column = [1 2];
                randCheckbox.Value = is_random;
                edit.Enable = ~is_random;
                randPanel.Visible = is_random;
                randCheckbox.ValueChangedFcn = @(src, ~) app.onRandomizeToggled(src, edit, randPanel);
            end
            
            app.FieldEdits(param_name) = struct(...
                'control', edit, 'randCheckbox', randCheckbox, 'randPanel', randPanel, ...
                'unit_type', unit_type, 'param_type', param_type);
        end
        
        function panel = createRandomizationPanel(app, parent, storage_value)
            panel = uipanel(parent, 'BorderType', 'line', 'Visible', 'off');
            grid = uigridlayout(panel, [3 2]);
            grid.ColumnWidth = {100, '1x'}; grid.RowHeight = {30, 30, 30};
            
            typeLabel = uilabel(grid, 'Text', 'Type:');
            typeDropdown = uidropdown(grid, 'Items', {'random_uniform', 'random_gaussian', 'random_choice'});
            
            label1 = uilabel(grid, 'Text', 'Min:');
            editor1 = uispinner(grid, 'Limits', [-Inf Inf]);
            
            label2 = uilabel(grid, 'Text', 'Max:');
            editor2 = uispinner(grid, 'Limits', [-Inf Inf]);
            
            panel.UserData = struct(...
                'typeDropdown', typeDropdown, 'label1', label1, 'editor1', editor1, ...
                'label2', label2, 'editor2', editor2);
            
            if core.is_randomization_spec(storage_value)
                typeDropdown.Value = storage_value.type;
                app.updateRandPanelControls(panel, storage_value);
            else
                app.updateRandPanelControls(panel, []);
            end
            
            typeDropdown.ValueChangedFcn = @(~, ~) app.updateRandPanelControls(panel, []);
        end
        
        function updateRandPanelControls(app, panel, storage_value)
            ud = panel.UserData;
            selected_type = ud.typeDropdown.Value;
            
            % Reset controls to default spinners
            if ~isa(ud.editor1, 'matlab.ui.control.Spinner')
                delete(ud.editor1);
                ud.editor1 = uispinner(panel.Children(1), 'Limits', [-Inf Inf]);
                ud.editor1.Layout.Column = 2; ud.editor1.Layout.Row = 2;
            end
             if ~isa(ud.editor2, 'matlab.ui.control.Spinner')
                 delete(ud.editor2);
                 ud.editor2 = uispinner(panel.Children(1), 'Limits', [-Inf Inf]);
                 ud.editor2.Layout.Column = 2; ud.editor2.Layout.Row = 3;
             end
             ud.label1.Visible = 'on'; ud.editor1.Visible = 'on';
             ud.label2.Visible = 'on'; ud.editor2.Visible = 'on';
             panel.UserData = ud;

            switch selected_type
                case 'random_uniform'
                    ud.label1.Text = 'Min:';
                    ud.label2.Text = 'Max:';
                     if isstruct(storage_value) && isfield(storage_value, 'min'), ud.editor1.Value = storage_value.min; end
                     if isstruct(storage_value) && isfield(storage_value, 'max'), ud.editor2.Value = storage_value.max; end
                case 'random_gaussian'
                    ud.label1.Text = 'Mean:';
                    ud.label2.Text = 'Std:';
                      if isstruct(storage_value) && isfield(storage_value, 'mean'), ud.editor1.Value = storage_value.mean; end
                      if isstruct(storage_value) && isfield(storage_value, 'std'), ud.editor2.Value = storage_value.std; end
                case 'random_choice'
                    ud.label1.Text = 'Options:';
                    ud.label2.Text = '(comma-sep)';
                    delete(ud.editor1);
                    ud.editor1 = uieditfield(panel.Children(1), 'text');
                    ud.editor1.Layout.Column = 2; ud.editor1.Layout.Row = 2;
                    ud.editor2.Visible = 'off';
                     if isstruct(storage_value) && isfield(storage_value, 'options')
                        try
                            opts = storage_value.options;
                            if iscell(opts)
                                opts_str = cellfun(@num2str, opts, 'UniformOutput', false);
                            else
                                opts_str = arrayfun(@num2str, opts, 'UniformOutput', false);
                            end
                            ud.editor1.Value = strjoin(opts_str, ', ');
                        catch
                            ud.editor1.Value = '[Error parsing options]';
                        end
                     else
                          ud.editor1.Value = '';
                     end
            end
            panel.UserData = ud;
        end
        
        function onRandomizeToggled(~, checkbox, fixedEditor, randPanel)
             fixedEditor.Enable = ~checkbox.Value;
             randPanel.Visible = checkbox.Value;
        end
        
         function params = readParametersFromUI(app)
             params = struct();
             param_names = keys(app.FieldEdits);
             for i = 1:length(param_names)
                 param_name = param_names{i};
                 field_info = app.FieldEdits(param_name);
                 control = field_info.control;
                 unit_type = field_info.unit_type;
                 param_type = field_info.param_type;
                 is_random = ~isempty(field_info.randCheckbox) && field_info.randCheckbox.Value;
                 if is_random
                     randPanel = field_info.randPanel;
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
                             vals_str = strsplit(strtrim(ud.editor1.Value), {',', ' '});
                             vals_str = vals_str(~cellfun('isempty', vals_str));
                             vals_num = str2double(vals_str);
                             if any(isnan(vals_num))
                                 rand_spec.options = vals_str;
                             else
                                  rand_spec.options = num2cell(vals_num);
                             end
                     end
                     params.(param_name) = rand_spec;
                 else
                     display_value = [];
                      if strcmp(param_type, 'array')
                          try display_value = eval(control.Value); catch; display_value = control.Value; end
                      elseif strcmp(param_type, 'boolean')
                          display_value = logical(control.Value);
                      else
                           display_value = control.Value;
                      end
                     storage_value = gui.common.unit_converter.to_storage(display_value, param_name, unit_type);
                      if strcmp(param_type, 'integer') && isnumeric(storage_value)
                          storage_value = round(storage_value);
                      end
                     params.(param_name) = storage_value;
                 end
             end
         end
         
         function onSave(app)
             try
                 app.OutputSpec = struct();
                 app.OutputSpec.generator = app.GeneratorDropDown.Value;
                 app.OutputSpec.version = app.GeneratorSchema.version;
                 app.OutputSpec.parameters = app.readParametersFromUI();
                 
                 gen_key = app.OutputSpec.generator;
                 if isKey(app.Context.generators, gen_key)
                     gen_schema = app.Context.generators(gen_key).schema;
                     if isfield(gen_schema, 'parameters')
                        [is_valid, errors] = core.validate_parameters(app.OutputSpec.parameters, gen_schema.parameters);
                        if ~is_valid
                             gui.common.error_dialog.show_validation_errors(app.UIFigure, errors, 'Invalid Parameters');
                             return;
                        end
                     end
                 else
                      uialert(app.UIFigure, sprintf('Selected generator "%s" not found!', gen_key), 'Error', 'Icon', 'error');
                      return;
                 end
                 
                 app.WasSaved = true;
                 delete(app.UIFigure);
             catch ME
                  gui.common.error_dialog.show_general_error(app.UIFigure, ME, 'Save Error');
             end
         end
         
        function onCancel(app)
            app.WasSaved = false;
            delete(app.UIFigure);
        end
        
        function presetPath = getPresetPath(app)
             if isempty(app.GeneratorPath)
                 presetPath = '';
             else
                presetPath = fullfile(app.GeneratorPath, 'presets.json');
             end
        end
        
        function presets = loadPresets(app)
            presets = struct();
            presetFile = app.getPresetPath();
             if isempty(presetFile) || ~exist(presetFile, 'file')
                return;
            end
            try
                presets = jsondecode(fileread(presetFile));
            catch ME
                 gui.common.error_dialog.show_load_error(app.UIFigure, ME, 'presets.json');
            end
        end
        
        function savePresets(app, presets)
            presetFile = app.getPresetPath();
            if isempty(presetFile)
                uialert(app.UIFigure, 'Cannot save preset: Generator path not determined.', 'Save Error');
                return;
            end
            try
                json_text = jsonencode(presets);
                fid = fopen(presetFile, 'w');
                if fid == -1
                    error('Could not open file for writing: %s', presetFile);
                end
                fprintf(fid, '%s', json_text);
                fclose(fid);
            catch ME
                 gui.common.error_dialog.show_save_error(app.UIFigure, ME);
            end
        end
        
        function onLoadPreset(app)
            presets = app.loadPresets();
            presetNames = fieldnames(presets);
            if isempty(presetNames)
                uialert(app.UIFigure, 'No presets found for this generator.', 'Load Preset'); return;
            end
            [idx, ok] = listdlg('ListString', sort(presetNames), 'SelectionMode', 'single', 'Name', 'Load Preset', 'PromptString', 'Select a preset:');
            if ok
                % Need to get the name from the sorted list
                sortedNames = sort(presetNames);
                selectedPresetName = sortedNames{idx};
                presetParams = presets.(selectedPresetName);
                
                tempSpec = struct();
                tempSpec.generator = app.GeneratorDropDown.Value;
                tempSpec.version = app.GeneratorSchema.version;
                tempSpec.parameters = presetParams;
                
                app.onGeneratorChanged(tempSpec);
                 uialert(app.UIFigure, sprintf('Preset "%s" loaded.', selectedPresetName), 'Preset Loaded', 'Icon','success','Modal',false);
            end
        end
        
         function onSavePreset(app)
             presetName = inputdlg('Enter a name for this preset:', 'Save Preset', [1 50]);
             if isempty(presetName) || isempty(presetName{1}); return; end
             
             validPresetName = matlab.lang.makeValidName(presetName{1});
             if ~strcmp(presetName{1}, validPresetName)
                 answer = uiconfirm(app.UIFigure, sprintf('Preset name will be saved as "%s". Continue?', validPresetName), 'Confirm Name');
                 if ~strcmp(answer, 'OK'); return; end
             end
             
             presets = app.loadPresets();
             try
                 currentStorageParams = app.readParametersFromUI();
                 presets.(validPresetName) = currentStorageParams;
                 app.savePresets(presets);
                 uialert(app.UIFigure, sprintf('Preset "%s" saved.', validPresetName), 'Success', 'Icon','success');
             catch ME
                  gui.common.error_dialog.show_general_error(app.UIFigure, ME, 'Save Preset Error');
             end
         end
         
        function onDeletePreset(app)
            presets = app.loadPresets();
            presetNames = fieldnames(presets);
            if isempty(presetNames); uialert(app.UIFigure, 'No presets to delete.', 'Delete Preset'); return; end

            sortedNames = sort(presetNames);
            [idx, ok] = listdlg('ListString', sortedNames, 'SelectionMode', 'single', 'Name', 'Delete Preset', 'PromptString', 'Select preset to delete:');
            if ok
                presetName = sortedNames{idx};
                answer = uiconfirm(app.UIFigure, sprintf('Delete preset "%s"?', presetName), 'Confirm Delete');
                if strcmp(answer, 'OK')
                    presets = rmfield(presets, presetName);
                    app.savePresets(presets);
                    uialert(app.UIFigure, sprintf('Preset "%s" deleted.', presetName), 'Success','Icon','success');
                end
            end
        end
    end
end