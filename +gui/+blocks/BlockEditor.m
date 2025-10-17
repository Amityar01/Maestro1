classdef BlockEditor < handle
    % BLOCKEDITOR - Schema-driven block parameter editor
    %
    % Usage:
    %   editor = BlockEditor(parent, builder_type, block, context);
    
    properties
        UIFigure
        ParentApp
        
        % Builder info
        builder_type
        schema
        context
        
        % Block data
        block
        is_new
        
        % UI Components
        ScrollPanel
        FieldEdits          % Map of parameter name -> edit field
        
        % --- NEW METADATA PROPERTIES ---
        CreatedByField
        TagsField
        % --- END ---

        % Buttons
        SaveButton
        CancelButton
        ValidateButton
    end
    
    methods
        function app = BlockEditor(parent, builder_type, block, context)
            % CONSTRUCTOR
            app.ParentApp = parent;
            app.builder_type = builder_type;
            app.context = context;
            app.FieldEdits = containers.Map();
            
            % Load schema
            app.schema = gui.blocks.block_utils.load_schema(builder_type, context);
            
            % Check if new or edit
            if isempty(block)
                app.is_new = true;
                app.block = app.createEmptyBlock();
            else
                app.is_new = false;
                app.block = block;
            end
            
            % Create UI
            app.createComponents();
        end
        
        function block = createEmptyBlock(app)
            % Create empty block with default structure
            
            block = struct();
            block.block_id = sprintf('%s_new_%s', ...
                app.builder_type, ...
                datestr(now, 'yyyymmdd_HHMMSS'));
            block.builder_type = app.builder_type;
            block.description = '';
            block.created = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
            
            % --- NEW METADATA ---
            block.metadata = struct();
            block.metadata.created_by = '';
            block.metadata.tags = '';
            % --- END ---
            
            block.parameters = struct();
        end
        
        function createComponents(app)
            % Create UI components
            
            % Main figure
            if app.is_new
                title_str = sprintf('New Block: %s', app.builder_type);
            else
                title_str = sprintf('Edit Block: %s', app.block.block_id);
            end
            
            app.UIFigure = uifigure('Name', title_str);
            app.UIFigure.Position = [200 100 600 700];
            
            % Main layout
            mainLayout = uigridlayout(app.UIFigure, [3 1]);
            mainLayout.RowHeight = {'1x', 60, 50};
            
            % Scrollable panel for parameters
            app.ScrollPanel = uipanel(mainLayout);
            app.ScrollPanel.Layout.Row = 1;
    
            app.ScrollPanel.Layout.Column = 1;
            app.ScrollPanel.Scrollable = 'on';
            
            % Create form
            app.createForm();
            
            % Info panel
            infoPanel = uipanel(mainLayout);
            infoPanel.Layout.Row = 2;
            infoPanel.Layout.Column = 1;
            infoLayout = uigridlayout(infoPanel, [2 2]);
            infoLayout.ColumnWidth = {100, '1x'};
            
            uilabel(infoLayout, 'Text', 'Builder:');
            uilabel(infoLayout, 'Text', app.builder_type);
            
            uilabel(infoLayout, 'Text', 'Version:');
            uilabel(infoLayout, 'Text', app.schema.version);
            
            % Button panel
            buttonPanel = uipanel(mainLayout);
            buttonPanel.Layout.Row = 3;
            buttonPanel.Layout.Column = 1;
            buttonLayout = uigridlayout(buttonPanel, [1 4]);
            buttonLayout.ColumnWidth = {'1x', 100, 100, 100};
            
            uilabel(buttonLayout);  % Spacer
            
            app.ValidateButton = uibutton(buttonLayout, 'Text', 'Validate');
            app.ValidateButton.ButtonPushedFcn = @(~,~) app.onValidate();
            
            app.CancelButton = uibutton(buttonLayout, 'Text', 'Cancel');
            app.CancelButton.ButtonPushedFcn = @(~,~) app.onCancel();
            
            app.SaveButton = uibutton(buttonLayout, 'Text', 'Save');
            app.SaveButton.ButtonPushedFcn = @(~,~) app.onSave();
            app.SaveButton.BackgroundColor = [0.3 0.7 0.3];
        end
        
        function createForm(app)
            % Create form based on schema
            
            % Combine required_inputs and optional_inputs into one struct
            all_parameters = struct();
            
            if isfield(app.schema, 'required_inputs')
                req_fields = fieldnames(app.schema.required_inputs);
                for i = 1:length(req_fields)
                    fname = req_fields{i};
                    all_parameters.(fname) = app.schema.required_inputs.(fname);
                    all_parameters.(fname).required = true; 
                end
            end
            
            if isfield(app.schema, 'optional_inputs')
                opt_fields = fieldnames(app.schema.optional_inputs);
                for i = 1:length(opt_fields)
                    fname = opt_fields{i};
                    all_parameters.(fname) = app.schema.optional_inputs.(fname);
                    if ~isfield(all_parameters.(fname), 'required')
                        all_parameters.(fname).required = false;
                    end
                end
            end

            param_names = fieldnames(all_parameters);
            
            % +5 for (Block ID, Desc, CreatedBy, Tags, Separator)
            n_rows = length(param_names) + 5;
            
            formLayout = uigridlayout(app.ScrollPanel, [n_rows 2]);
            
            % --- Row Height set to 'fit' for dynamic components ---
            formLayout.RowHeight = repmat({'fit'}, 1, n_rows);
            formLayout.ColumnWidth = {200, '1x'};
            
            row = 1;
            
            % Block ID
            uilabel(formLayout, 'Text', '* Block ID:');
            idEdit = uieditfield(formLayout, 'text');
            idEdit.Value = app.block.block_id;
            app.FieldEdits('block_id') = idEdit;
            idEdit.UserData = struct('unit_type', ''); % Init UserData
            formLayout.RowHeight{row} = 30;
            row = row + 1;
            
            % Description
            uilabel(formLayout, 'Text', 'Description:');
            descEdit = uieditfield(formLayout, 'text');
            if isfield(app.block, 'description')
                descEdit.Value = app.block.description;
            end
            app.FieldEdits('description') = descEdit;
            descEdit.UserData = struct('unit_type', ''); % Init UserData
            formLayout.RowHeight{row} = 30;
            row = row + 1;
            
            % --- NEW METADATA FIELDS ---
            uilabel(formLayout, 'Text', 'Created By:');
            app.CreatedByField = uieditfield(formLayout, 'text');
            if isfield(app.block, 'metadata') && isfield(app.block.metadata, 'created_by')
                app.CreatedByField.Value = app.block.metadata.created_by;
            end
            app.CreatedByField.Layout.Row = row;
            app.CreatedByField.Layout.Column = 2;
            formLayout.RowHeight{row} = 30;
            row = row + 1;

            uilabel(formLayout, 'Text', 'Tags:');
            app.TagsField = uieditfield(formLayout, 'text', 'Placeholder', 'comma, separated, tags');
            if isfield(app.block, 'metadata') && isfield(app.block.metadata, 'tags')
                if iscell(app.block.metadata.tags)
                    app.TagsField.Value = strjoin(app.block.metadata.tags, ', ');
                else
                    app.TagsField.Value = app.block.metadata.tags;
                end
            end
            app.TagsField.Layout.Row = row;
            app.TagsField.Layout.Column = 2;
            formLayout.RowHeight{row} = 30;
            row = row + 1;
            % --- END NEW METADATA FIELDS ---

            % Separator
            sepLabel = uilabel(formLayout, 'Text', '─── Parameters ───');
            sepLabel.FontWeight = 'bold';
            sepLabel.Layout.Column = [1 2];
            formLayout.RowHeight{row} = 30;
            row = row + 1;
            
            % Create field for all other parameters
            for i = 1:length(param_names)
                param_name = param_names{i};
                param_spec = all_parameters.(param_name);
                
                app.createParameterField(formLayout, param_name, param_spec, row);
                row = row + 1;
            end
        end
        
        function createParameterField(app, parent, param_name, param_spec, row)
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

            if param_spec.required
                label_text = ['* ' label_text];
            end
            
            label = uilabel(parent, 'Text', label_text);
            label.Layout.Row = row;
            label.Layout.Column = 1;
            
            if isfield(param_spec, 'description')
                label.Tooltip = param_spec.description;
            end
            
            % Get current value
            if isfield(app.block.parameters, param_name)
                current_value = app.block.parameters.(param_name);
            elseif isfield(param_spec, 'default')
                current_value = param_spec.default;
            else
                current_value = [];
            end
            
            % Apply unit conversions for display
            if ~isempty(current_value) && ~core.is_randomization_spec(current_value)
                switch unit_type
                    case {'ms', 'milliseconds'}
                        if endsWith(param_name, '_sec')
                            current_value = current_value * 1000;
                        end
                    case '%'
                        current_value = current_value * 100;
                end
            end
            
            % Create editor
            param_type = param_spec.type;
            
            if strcmp(param_type, 'stimulus_specification')
                app.createStimulusField(parent, param_name, current_value, row);
                return; % This function creates its own components
            end
            
            % --- START NEW ARRAY LOGIC ---
            if strcmp(param_type, 'array')
                % Check for our new 'element_type' field
                if isfield(param_spec, 'element_type') && ...
                   (strcmp(param_spec.element_type, 'float') || strcmp(param_spec.element_type, 'integer'))
                    
                    % Use the new "smart" array editor
                    edit = app.createArrayEditor(parent, current_value);
                else
                    % Use the old "dumb" text box for complex/undefined arrays
                    edit = app.createSimpleArrayField(parent, current_value);
                end
            % --- END NEW ARRAY LOGIC ---
            
            else
                % Handle all other types
                switch param_type
                    case {'integer', 'float'}
                        edit = uispinner(parent, 'Limits', [-Inf Inf], 'Step', 0.1);
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
                        if ~isempty(current_value)
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
                        edit = uieditfield(parent, 'text');
                        if ~isempty(current_value)
                            edit.Value = current_value;
                        end
                    case 'enum'
                        edit = uidropdown(parent, 'Items', param_spec.constraints.options);
                        if ~isempty(current_value)
                            edit.Value = current_value;
                        else
                            edit.Value = param_spec.constraints.options{1};
                        end
                    otherwise
                        edit = uieditfield(parent, 'text', 'Value', jsonencode(current_value));
                end
            end
            
            edit.Layout.Row = row;
            edit.Layout.Column = 2;
            
            % Store handle and metadata for saving
            app.FieldEdits(param_name) = edit;
            if ~isstruct(edit.UserData)
                edit.UserData = struct();
            end
            edit.UserData.unit_type = unit_type;
        end
        
        function edit = createSimpleArrayField(app, parent, value)
            % Fallback for complex arrays: a simple text box
            edit = uieditfield(parent, 'text');
            if ~isempty(value)
                if isnumeric(value)
                    edit.Value = mat2str(value);
                else
                    edit.Value = jsonencode(value);
                end
            else
                edit.Value = '[]';
            end
            edit.Tooltip = 'Enter as: [val1, val2, ...] or [min, max]';
        end
        
        function panel = createArrayEditor(app, parent, current_value)
            % Creates a listbox with add/remove buttons for simple numeric array editing
            
            panel = uipanel(parent, 'BorderType', 'none');
            grid = uigridlayout(panel, [2 1]);
            grid.RowHeight = {'1x', 30};
            grid.Padding = [0 0 0 0];
            
            listbox = uilistbox(grid);
            listbox.Layout.Row = 1;
            if ~isempty(current_value)
                listbox.Items = cellstr(num2str(current_value(:)));
            end
            
            buttonGrid = uigridlayout(grid, [1 2]);
            buttonGrid.Layout.Row = 2;
            buttonGrid.Padding = [0 0 0 0];
            
            addButton = uibutton(buttonGrid, 'Text', 'Add...', 'ButtonPushedFcn', @(src, event) app.onArrayAdd(listbox));
            removeButton = uibutton(buttonGrid, 'Text', 'Remove', 'ButtonPushedFcn', @(src, event) app.onArrayRemove(listbox));
            
            % The 'panel' is the main edit control
        end

        function onArrayAdd(app, listbox)
            val_str = inputdlg('Enter a value:', 'Add Array Element', [1 40]);
            if ~isempty(val_str)
                % Check if numeric
                val_num = str2double(val_str{1});
                if ~isnan(val_num)
                    listbox.Items{end+1} = val_str{1};
                else
                    uialert(app.UIFigure, 'Input must be a valid number.', 'Input Error');
                end
            end
        end
        % In Maestro/+gui/+blocks/BlockEditor.m
        function onArrayRemove(app, listbox)
            
            selectedValue = listbox.Value; % This is the *string* of the selected item
            
            % Check if anything is selected
            if isempty(selectedValue)
                uialert(app.UIFigure, 'Select an item to remove.', 'Remove Item');
                return;
            end
            
            % --- START FIX ---
            
            % 1. Find the numeric index of the selected string
            % We must do this because listbox.Value gives the *text*, not the *index*.
            selectedIndex = find(strcmp(listbox.Items, selectedValue), 1);
            
            if isempty(selectedIndex)
                % This should not happen if Value is set, but just in case
                uialert(app.UIFigure, 'Selection mismatch error.', 'Error');
                listbox.Value = {}; % Clear the bad selection
                return;
            end

            % 2. Remove the item by its numeric index
            listbox.Items(selectedIndex) = [];
            
            % 3. Clear the selection after removing
            % The error "Value' must be a... string scalar or an empty cell array"
            % means we must use {} instead of [].
            listbox.Value = {}; 
            % --- END FIX ---
        end

        function createStimulusField(app, parent, param_name, current_value, row)
            % Creates a dropdown + button for a stimulus parameter
            
            % Create a new grid to hold the dropdown and button
            stimLayout = uigridlayout(parent, [1 2]);
            stimLayout.Layout.Row = row;
            stimLayout.Layout.Column = 2;
            stimLayout.ColumnWidth = {'1x', 'fit'};
            stimLayout.Padding = [0 0 0 0];
            
            % Generator Dropdown
            genDropdown = uidropdown(stimLayout);
            genDropdown.Items = keys(app.context.generators);
            
            % Edit Button
            editButton = uibutton(stimLayout, 'Text', 'Edit...');
            
            % Store handles in a struct
            controlStruct = struct(...
                'dropdown', genDropdown, ...
                'button', editButton, ...
                'stimulus_spec', struct() ... % This will hold the saved data
            );
            
            % Set initial values
            if isstruct(current_value) && isfield(current_value, 'generator') && ~isempty(current_value.generator)
                genDropdown.Value = current_value.generator;
                controlStruct.stimulus_spec = current_value;
            else
                % Set to first generator by default
                genDropdown.Value = genDropdown.Items{1};
                % Create an empty spec
                controlStruct.stimulus_spec.generator = genDropdown.Value;
                controlStruct.stimulus_spec.version = app.context.generators(genDropdown.Value).schema.version;
                controlStruct.stimulus_spec.parameters = struct();
            end
            
            % Set the button callback
            editButton.ButtonPushedFcn = @(src, event) app.editStimulusSpec(param_name);
            
            % Store the control struct in FieldEdits
            app.FieldEdits(param_name) = controlStruct;
        end

        function editStimulusSpec(app, param_name)
            % Open the StimulusEditor for the selected generator
            
            % 1. READ the control struct from the map
            controlStruct = app.FieldEdits(param_name);
            
            % Get the *currently selected* generator from the dropdown
            selected_generator = controlStruct.dropdown.Value;
            
            % Get the *currently stored* spec
            current_spec = controlStruct.stimulus_spec;
            
            % If the user changed the dropdown, the stored spec is invalid
            % We must pass the correct spec or an empty one
            if ~isfield(current_spec, 'generator') || ~strcmp(current_spec.generator, selected_generator)
                % Generator changed! Create a new, empty spec
                current_spec = struct();
                current_spec.generator = selected_generator;
                current_spec.version = app.context.generators(selected_generator).schema.version;
                current_spec.parameters = struct();
            end
            
            % Open the modal editor, passing the correct spec
            editor = gui.stimuli.StimulusEditor(app.UIFigure, app.context, current_spec);
            
            % Wait for it to close
            uiwait(editor.UIFigure);
            
            if editor.WasSaved
                % Get the output struct
                new_value = editor.OutputSpec;
                
                % 2. MODIFY the temporary struct
                controlStruct.stimulus_spec = new_value;
                
                % 3. WRITE the entire struct back into the map
                app.FieldEdits(param_name) = controlStruct;
            end
        end
        
        function onValidate(app)
            % Validate current values
            
            try
                % Read values from form into app.block
                app.readValues();
                
                % Validate against schema
                [is_valid, errors] = gui.blocks.block_utils.validate_block(app.block, app.schema, app.context);
                
                if is_valid
                    uialert(app.UIFigure, 'Block is valid!', 'Validation Success', 'Icon', 'success');
                else
                    error_msg = sprintf('Validation errors:\n%s', strjoin(errors, '\n'));
                    uialert(app.UIFigure, error_msg, 'Validation Failed', 'Icon', 'error');
                end
            catch ME
                uialert(app.UIFigure, ME.message, 'Validation Error', 'Icon', 'error');
            end
        end
        
        function onSave(app)
            % Save block
            
            try
                % Read values from form
                app.readValues();
                
                % Validate
                [is_valid, errors] = gui.blocks.block_utils.validate_block(app.block, app.schema, app.context);
                if ~is_valid
                    error_msg = sprintf('Validation errors:\n%s', strjoin(errors, '\n'));
                    uialert(app.UIFigure, 'Cannot Save');
                    return;
                end
                
                % Update timestamps
                if app.is_new
                    app.block.created = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
                else
                    app.block.modified = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
                end
                
                % Save to file
                filename = [app.block.block_id '.json'];
                filepath = fullfile('library', 'blocks', filename);
                gui.blocks.block_utils.save_block(app.block, filepath);
                
                % Refresh parent
                if ~isempty(app.ParentApp)
                    app.ParentApp.refreshBlockList();
                end
                
                % Close
                uialert(app.UIFigure, sprintf('Block saved: %s', filename), 'Success', 'Icon', 'success');
                delete(app.UIFigure); % Use delete
                
            catch ME
                uialert(app.UIFigure, ME.message, 'Save Failed');
            end
        end
        
        function onCancel(app)
            % Cancel editing
            delete(app.UIFigure); % Use delete
        end
        
   % In Maestro/+gui/+blocks/BlockEditor.m
        function readValues(app)
            % Read values from form into block struct
            
            % Block metadata
            app.block.block_id = app.FieldEdits('block_id').Value;
            app.block.description = app.FieldEdits('description').Value;
            
            app.block.metadata = struct();
            app.block.metadata.created_by = app.CreatedByField.Value;
            tags_str = app.TagsField.Value;
            if ~isempty(tags_str)
                app.block.metadata.tags = strtrim(split(tags_str, ','));
            else
                app.block.metadata.tags = {};
            end

            % Combine all param definitions
            all_parameters = struct();
            if isfield(app.schema, 'required_inputs')
                req_names = fieldnames(app.schema.required_inputs);
                for i = 1:length(req_names)
                    fname = req_names{i};
                    all_parameters.(fname) = app.schema.required_inputs.(fname);
                end
            end
            if isfield(app.schema, 'optional_inputs')
                opt_names = fieldnames(app.schema.optional_inputs);
                 for i = 1:length(opt_names)
                    fname = opt_names{i};
                    all_parameters.(fname) = app.schema.optional_inputs.(fname);
                end
            end
            
            param_names = fieldnames(all_parameters);
            for i = 1:length(param_names)
                param_name = param_names{i};
                param_spec = all_parameters.(param_name);
                
                edit = app.FieldEdits(param_name);
                
                % --- START UPDATED READ LOGIC ---
                if strcmp(param_spec.type, 'stimulus_specification')
                    % This is a stimulus control struct
                    app.block.parameters.(param_name) = edit.stimulus_spec;
                
                elseif strcmp(param_spec.type, 'array')
                    % --- START FIX for ITI ---
                    if strcmp(param_name, 'iti_sec')
                        % Read from smart editor (iti_sec is special)
                        listbox = findobj(edit, 'Type', 'uilistbox');
                        vals_str = listbox.Items;
                        app.block.parameters.(param_name) = str2double(vals_str);
                        
                        % Apply unit conversion (ms to sec)
                        app.block.parameters.(param_name) = app.block.parameters.(param_name) / 1000;
                        
                        % Ensure it's a row vector [min max] or scalar
                        if numel(app.block.parameters.(param_name)) > 1
                             app.block.parameters.(param_name) = [min(app.block.parameters.(param_name)), max(app.block.parameters.(param_name))];
                        elseif numel(app.block.parameters.(param_name)) == 1
                             % Convert single value to scalar for builder
                             app.block.parameters.(param_name) = app.block.parameters.(param_name)(1);
                        else % Empty list
                            app.block.parameters.(param_name) = []; % Or handle error
                        end

                    % --- END FIX for ITI ---
                    
                    elseif isfield(param_spec, 'element_type') && ...
                           (strcmp(param_spec.element_type, 'float') || strcmp(param_spec.element_type, 'integer'))
                        % Read from smart editor (other numeric arrays)
                        listbox = findobj(edit, 'Type', 'uilistbox');
                        vals_str = listbox.Items;
                        app.block.parameters.(param_name) = str2double(vals_str);
                        
                        % Apply unit conversion if needed (rare for arrays?)
                        unit_type = '';
                        if isstruct(edit.UserData) && isfield(edit.UserData, 'unit_type')
                            unit_type = edit.UserData.unit_type;
                        end
                        if strcmp(unit_type, 'ms') && endsWith(param_name, '_sec')
                            app.block.parameters.(param_name) = app.block.parameters.(param_name) / 1000;
                        end
                    else
                        % Read from dumb editor
                        app.block.parameters.(param_name) = eval(edit.Value);
                    end
                
                else
                    % This is a standard control (spinner, dropdown, etc.)
                    unit_type = '';
                    if isstruct(edit.UserData) && isfield(edit.UserData, 'unit_type')
                        unit_type = edit.UserData.unit_type;
                    end
                    
                    ui_value = edit.Value;
                    
                    % Apply inverse conversions
                    switch unit_type
                        case 'ms'
                            if endsWith(param_name, '_sec')
                                app.block.parameters.(param_name) = ui_value / 1000;
                            else
                                app.block.parameters.(param_name) = ui_value;
                            end
                        case '%'
                            app.block.parameters.(param_name) = ui_value / 100;
                        otherwise
                            switch param_spec.type
                                case {'integer', 'float', 'string', 'enum'}
                                    app.block.parameters.(param_name) = ui_value;
                            end
                    end
                end
                % --- END UPDATED READ LOGIC ---
            end
        end
        
    end
end