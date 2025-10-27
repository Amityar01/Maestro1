classdef BlockEditor < handle
    % BLOCKEDITOR - Schema-driven block parameter editor

    properties
        UIFigure
        ParentApp % Keep reference to BlockManager if needed

        % Builder info
        builder_type
        schema
        context

        % Block data
        block
        is_new

        % UI Components
        ScrollPanel
        FieldEdits % Map: param_name -> UI control(s) struct

        % Metadata UI
        BlockIDField
        DescriptionField
        CreatedByField
        TagsField

        % Buttons
        SaveButton
        CancelButton
        ValidateButton
        % --- NEW Preview Button ---
        PreviewButton
    end

    methods
        function app = BlockEditor(parent, builder_type, block, context)
            % CONSTRUCTOR
            app.ParentApp = parent;
            app.builder_type = builder_type;
            app.context = context;
            app.FieldEdits = containers.Map();

            % Load schema using util
            try
                app.schema = gui.blocks.block_utils.load_schema(builder_type, context);
            catch ME
                 gui.common.error_dialog.show_general_error(parent.UIFigure, ME, 'Schema Load Error');
                 delete(app); % Clean up if schema fails
                 return;
            end

            % Handle new vs edit
            if isempty(block)
                app.is_new = true;
                app.block = app.createEmptyBlock();
            else
                app.is_new = false;
                % Load block using util (handles migration)
                try
                    app.block = gui.blocks.block_utils.load_block(block.file);
                catch ME
                     gui.common.error_dialog.show_load_error(parent.UIFigure, ME, block.file);
                     delete(app);
                     return;
                end
            end

            % Create UI
            app.createComponents();
        end

        function block = createEmptyBlock(app)
            % Create empty block structure with defaults and version

            block = struct();
            block.format_version = core.config.BLOCK_FORMAT_VERSION; % Add version
            block.block_id = sprintf('%s_new_%s', ...
                app.builder_type, ...
                datestr(now, 'yyyymmdd_HHMMSS'));
            block.builder_type = app.builder_type;
            block.description = '';
            block.created = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
            block.modified = block.created; % Init modified time

            block.metadata = struct();
            block.metadata.created_by = ''; % Default empty
            block.metadata.tags = {}; % Use empty cell array for tags

            block.parameters = struct();

            % Populate default parameters from schema
             all_param_defs = struct();
             if isfield(app.schema, 'required_inputs')
                 all_param_defs = mergestructs(all_param_defs, app.schema.required_inputs);
             end
             if isfield(app.schema, 'optional_inputs')
                 all_param_defs = mergestructs(all_param_defs, app.schema.optional_inputs);
             end
             param_names = fieldnames(all_param_defs);
             for i = 1:length(param_names)
                 param_name = param_names{i};
                 param_def = all_param_defs.(param_name);
                 if isfield(param_def, 'default')
                     block.parameters.(param_name) = param_def.default;
                 end
             end
        end

        function createComponents(app)
            % Create UI components

            if app.is_new
                title_str = sprintf('New Block: %s', app.builder_type);
            else
                title_str = sprintf('Edit Block: %s', app.block.block_id);
            end

            app.UIFigure = uifigure('Name', title_str, 'Scrollable', 'on'); % Make figure scrollable
            app.UIFigure.Position = [200 100 650 750]; % Slightly wider/taller

            % Overall grid layout (Form + Buttons)
            mainLayout = uigridlayout(app.UIFigure, [2 1]);
            mainLayout.RowHeight = {'1x', 50}; % Form area takes available space

            % Panel to contain the form grid (acts as viewport)
            formPanel = uipanel(mainLayout, 'BorderType', 'none');
            formPanel.Layout.Row = 1;
            formPanel.Layout.Column = 1;
            % The actual grid for form elements, placed inside formPanel
            formLayout = uigridlayout(formPanel);
            formLayout.ColumnWidth = {200, '1x'};
            formLayout.RowHeight = {'fit'}; % Start with fit, will be updated
            formLayout.Scrollable = 'on'; % Make the inner grid scrollable if needed
            app.ScrollPanel = formLayout; % Store handle to the grid

            % Create form elements inside formLayout
            app.createForm(formLayout);

            % Button panel at the bottom
            buttonPanel = uipanel(mainLayout);
            buttonPanel.Layout.Row = 2;
            buttonPanel.Layout.Column = 1;
            buttonLayout = uigridlayout(buttonPanel, [1 5]); % Add Preview button
            buttonLayout.ColumnWidth = {'1x', 100, 100, 100, 100};

            uilabel(buttonLayout); % Spacer

            app.PreviewButton = uibutton(buttonLayout, 'Text', 'Preview...');
            app.PreviewButton.ButtonPushedFcn = @(~,~) app.onPreview();

            app.ValidateButton = uibutton(buttonLayout, 'Text', 'Validate');
            app.ValidateButton.ButtonPushedFcn = @(~,~) app.onValidate();

            app.CancelButton = uibutton(buttonLayout, 'Text', 'Cancel');
            app.CancelButton.ButtonPushedFcn = @(~,~) app.onCancel();

            app.SaveButton = uibutton(buttonLayout, 'Text', 'Save');
            app.SaveButton.ButtonPushedFcn = @(~,~) app.onSave();
            app.SaveButton.BackgroundColor = [0.3 0.7 0.3];
        end


        function createForm(app, formLayout)
             % Combine all parameter definitions
             all_param_defs = struct();
             if isfield(app.schema, 'required_inputs')
                 req_fields = fieldnames(app.schema.required_inputs);
                 for i = 1:length(req_fields)
                     fname = req_fields{i};
                     param_def = app.schema.required_inputs.(fname);
                     param_def.required = true; % Mark as required
                     all_param_defs.(fname) = param_def;
                 end
             end
             if isfield(app.schema, 'optional_inputs')
                 opt_fields = fieldnames(app.schema.optional_inputs);
                 for i = 1:length(opt_fields)
                     fname = opt_fields{i};
                      param_def = app.schema.optional_inputs.(fname);
                      if ~isfield(param_def, 'required') % Ensure required field exists
                          param_def.required = false;
                      end
                      all_param_defs.(fname) = param_def;
                 end
             end
             param_names = fieldnames(all_param_defs);

             % Estimate number of rows needed
             n_meta_rows = 5; % ID, Desc, By, Tags, Separator
             n_param_rows = length(param_names);
             n_rows = n_meta_rows + n_param_rows;
             formLayout.RowHeight = repmat({'fit'}, 1, n_rows); % Adjust grid size

             row = 1;

             % Block ID
             uilabel(formLayout, 'Text', '* Block ID:');
             app.BlockIDField = uieditfield(formLayout, 'text');
             app.BlockIDField.Value = app.block.block_id;
             app.BlockIDField.Layout.Row = row; app.BlockIDField.Layout.Column = 2;
             formLayout.RowHeight{row} = 30; % Fixed height for simple fields
             row = row + 1;

             % Description
             uilabel(formLayout, 'Text', 'Description:');
             app.DescriptionField = uieditfield(formLayout, 'text');
             if isfield(app.block, 'description')
                 app.DescriptionField.Value = app.block.description;
             end
             app.DescriptionField.Layout.Row = row; app.DescriptionField.Layout.Column = 2;
             formLayout.RowHeight{row} = 30;
             row = row + 1;

             % Created By
             uilabel(formLayout, 'Text', 'Created By:');
             app.CreatedByField = uieditfield(formLayout, 'text');
             if isfield(app.block, 'metadata') && isfield(app.block.metadata, 'created_by')
                 app.CreatedByField.Value = app.block.metadata.created_by;
             end
             app.CreatedByField.Layout.Row = row; app.CreatedByField.Layout.Column = 2;
             formLayout.RowHeight{row} = 30;
             row = row + 1;

             % Tags
             uilabel(formLayout, 'Text', 'Tags (comma-sep):');
             app.TagsField = uieditfield(formLayout, 'text');
             if isfield(app.block, 'metadata') && isfield(app.block.metadata, 'tags')
                 if iscell(app.block.metadata.tags)
                     app.TagsField.Value = strjoin(app.block.metadata.tags, ', ');
                 else % Handle older string format if necessary
                     app.TagsField.Value = app.block.metadata.tags;
                 end
             end
             app.TagsField.Layout.Row = row; app.TagsField.Layout.Column = 2;
             formLayout.RowHeight{row} = 30;
             row = row + 1;

             % Parameters Separator
             sepLabel = uilabel(formLayout, 'Text', '─── Parameters ───');
             sepLabel.FontWeight = 'bold';
             sepLabel.Layout.Row = row; sepLabel.Layout.Column = [1 2];
             formLayout.RowHeight{row} = 30;
             row = row + 1;

             % Create field for each parameter
             for i = 1:length(param_names)
                 param_name = param_names{i};
                 param_spec = all_param_defs.(param_name);
                 app.createParameterField(formLayout, param_name, param_spec, row);
                 row = row + 1; % Increment row index for the next parameter
             end
        end

       function createParameterField(app, parentLayout, param_name, param_spec, row)
            % Creates the label and editor controls for a single parameter

            label_text = param_name;
            unit_type = gui.common.unit_converter.get_unit_type(param_spec);

            if isfield(param_spec, 'ui_hints') && isfield(param_spec.ui_hints, 'display_name')
                label_text = param_spec.ui_hints.display_name;
            end
            if param_spec.required
                label_text = ['* ' label_text];
            end

            label = uilabel(parentLayout, 'Text', label_text);
            label.Layout.Row = row;
            label.Layout.Column = 1;
            if isfield(param_spec, 'description')
                label.Tooltip = param_spec.description;
            end

            % Get current value (storage format) from block data or default
            storage_value = [];
            if isfield(app.block.parameters, param_name)
                storage_value = app.block.parameters.(param_name);
            elseif isfield(param_spec, 'default')
                storage_value = param_spec.default;
            end

            % Convert to display format using unit_converter
            current_display_value = gui.common.unit_converter.to_display(storage_value, param_name, unit_type);

            edit_control = []; % Handle for the main UI control
            param_type = param_spec.type;

            if strcmp(param_type, 'stimulus_specification')
                 % Creates dropdown + button, stores handle struct in FieldEdits
                app.createStimulusField(parentLayout, param_name, current_display_value, row);
                return; % createStimulusField handles UI placement and storage

            elseif strcmp(param_type, 'array') && isfield(param_spec, 'element_type') && ...
                   (strcmp(param_spec.element_type, 'float') || strcmp(param_spec.element_type, 'integer'))
                % Smart array editor for numeric arrays
                 edit_control = app.createArrayEditor(parentLayout, current_display_value); % Returns panel

            else % Handle scalar types and simple arrays
                switch param_type
                    case {'integer', 'float'}
                        edit_control = uispinner(parentLayout, 'Limits', [-Inf Inf], 'Step', 0.1);
                        edit_control.Value = 0; % Default init
                        if isfield(param_spec, 'constraints')
                             if isfield(param_spec.constraints, 'min')
                                 min_val = gui.common.unit_converter.to_display(param_spec.constraints.min, param_name, unit_type);
                                 edit_control.Limits(1) = min_val;
                             end
                             if isfield(param_spec.constraints, 'max')
                                  max_val = gui.common.unit_converter.to_display(param_spec.constraints.max, param_name, unit_type);
                                  edit_control.Limits(2) = max_val;
                             end
                        end
                         if strcmp(unit_type, '%')
                            edit_control.Limits = [0 100]; % Display limits for %
                        end
                        % Set value carefully, respecting limits
                        if ~isempty(current_display_value) && isnumeric(current_display_value)
                            bounded_value = max(edit_control.Limits(1), min(edit_control.Limits(2), current_display_value));
                            edit_control.Value = bounded_value;
                        else % Set to min limit if value is invalid/empty
                            edit_control.Value = edit_control.Limits(1);
                        end

                    case 'string'
                        edit_control = uieditfield(parentLayout, 'text');
                         if ~isempty(current_display_value)
                            edit_control.Value = current_display_value;
                        end

                    case 'enum'
                        edit_control = uidropdown(parentLayout, 'Items', param_spec.constraints.options);
                        if ~isempty(current_display_value)
                            edit_control.Value = current_display_value;
                        elseif ~isempty(param_spec.constraints.options) % Set default if value empty
                             edit_control.Value = param_spec.constraints.options{1};
                        end

                    case 'array' % Fallback for non-numeric or complex arrays
                        edit_control = app.createSimpleArrayField(parentLayout, current_display_value);

                    otherwise % Fallback for unknown types
                        edit_control = uieditfield(parentLayout, 'text', 'Value', jsonencode(current_display_value));
                         edit_control.Tooltip = 'Complex type - Edit as JSON string';
                end
            end

            % Place control in grid and store handle
            edit_control.Layout.Row = row;
            edit_control.Layout.Column = 2;
            app.FieldEdits(param_name) = struct('control', edit_control, 'unit_type', unit_type, 'param_type', param_type);
        end

        function edit = createSimpleArrayField(app, parent, value)
            % Fallback for complex arrays: a simple text box (unchanged)
            edit = uieditfield(parent, 'text');
            if ~isempty(value)
                if isnumeric(value)
                    edit.Value = mat2str(value);
                else
                    try edit.Value = jsonencode(value); catch; edit.Value = '[Error encoding]'; end
                end
            else
                edit.Value = '[]';
            end
            edit.Tooltip = 'Enter array as: [val1, val2, ...] or [min, max] or JSON string';
        end

        function panel = createArrayEditor(app, parent, current_value)
            % Creates listbox + buttons for simple numeric arrays (unchanged)
            panel = uipanel(parent, 'BorderType', 'none');
            grid = uigridlayout(panel, [2 1]);
            grid.RowHeight = {'1x', 30}; grid.Padding = [0 0 0 0];
            listbox = uilistbox(grid); listbox.Layout.Row = 1;
            if ~isempty(current_value) && isnumeric(current_value)
                 listbox.Items = cellstr(num2str(current_value(:))); % Ensure column vector
            end
            buttonGrid = uigridlayout(grid, [1 2]); buttonGrid.Layout.Row = 2; buttonGrid.Padding = [0 0 0 0];
            uibutton(buttonGrid, 'Text', 'Add...', 'ButtonPushedFcn', @(src, event) app.onArrayAdd(listbox));
            uibutton(buttonGrid, 'Text', 'Remove', 'ButtonPushedFcn', @(src, event) app.onArrayRemove(listbox));
        end

        function onArrayAdd(app, listbox)
            val_str = inputdlg('Enter a numeric value:', 'Add Array Element', [1 40]);
             if ~isempty(val_str)
                val_num = str2double(val_str{1});
                if ~isnan(val_num)
                     % Add the string representation
                    listbox.Items{end+1} = strtrim(val_str{1});
                else
                     gui.common.error_dialog.show_general_error(app.UIFigure, MException('Input:Error', 'Input must be a valid number.'), 'Input Error');
                end
            end
        end

       function onArrayRemove(app, listbox)
    % Handle both single-select (char/string) and multi-select (cell) cases
    selectedValue = listbox.Value;

    if isempty(selectedValue)
        uialert(app.UIFigure, 'Select an item to remove.', 'Remove Item');
        return;
    end

    % Normalize selection to a single char
    if iscell(selectedValue)
        selectedValue = selectedValue{1};  % take the first selection
    end
    selectedValue = char(string(selectedValue));

    % Normalize Items to cellstr for strcmp
    items = listbox.Items;
    if ~iscell(items)
        items = cellstr(items);  % supports string arrays too
    end

    selectedIndex = find(strcmp(items, selectedValue), 1);

    if ~isempty(selectedIndex)
        listbox.Items(selectedIndex) = [];
        % Clear selection; for single-select it's '', for multi it's {}
        try
            listbox.Value = '';
        catch
            listbox.Value = {};
        end
    else
        gui.common.error_dialog.show_general_error( ...
            app.UIFigure, ...
            MException('App:Error','Selected item not found in list.'), ...
            'Remove Item');
        try, listbox.Value = ''; catch, listbox.Value = {}; end
    end
end

        function createStimulusField(app, parent, param_name, current_value, row)
             % Creates dropdown + button for stimulus spec (unchanged logic, stores struct)
            stimLayout = uigridlayout(parent, [1 2]);
            stimLayout.Layout.Row = row; stimLayout.Layout.Column = 2;
            stimLayout.ColumnWidth = {'1x', 'fit'}; stimLayout.Padding = [0 0 0 0];
            genDropdown = uidropdown(stimLayout);
            genDropdown.Items = keys(app.context.generators);
            editButton = uibutton(stimLayout, 'Text', 'Edit...');
            controlStruct = struct('dropdown', genDropdown, 'button', editButton, 'stimulus_spec', struct()); % Holds dropdown, button, AND the actual spec data

             if isstruct(current_value) && isfield(current_value, 'generator') && ~isempty(current_value.generator)
                 if ismember(current_value.generator, genDropdown.Items)
                    genDropdown.Value = current_value.generator;
                    controlStruct.stimulus_spec = current_value; % Store the whole struct
                 else
                     warning('Block references unknown generator "%s" for parameter "%s". Resetting.', current_value.generator, param_name);
                     genDropdown.Value = genDropdown.Items{1}; % Default to first generator
                     controlStruct.stimulus_spec.generator = genDropdown.Value;
                     controlStruct.stimulus_spec.version = app.context.generators(genDropdown.Value).schema.version;
                     controlStruct.stimulus_spec.parameters = struct();
                 end
             else
                 genDropdown.Value = genDropdown.Items{1};
                 controlStruct.stimulus_spec.generator = genDropdown.Value;
                 controlStruct.stimulus_spec.version = app.context.generators(genDropdown.Value).schema.version;
                 controlStruct.stimulus_spec.parameters = struct();
             end

            editButton.ButtonPushedFcn = @(src, event) app.editStimulusSpec(param_name);
            app.FieldEdits(param_name) = struct('control', controlStruct, 'unit_type', '', 'param_type', 'stimulus_specification'); % Store the struct containing UI handles and data
        end


        function editStimulusSpec(app, param_name)
            % Open StimulusEditor, passing the currently stored spec

            % 1. Get the struct holding the UI elements AND the data
            field_info = app.FieldEdits(param_name);
            controlStruct = field_info.control;

            % 2. Get the *currently selected* generator from the dropdown UI
            selected_generator_in_ui = controlStruct.dropdown.Value;

            % 3. Get the *currently stored* spec data
            stored_spec = controlStruct.stimulus_spec;

            % 4. Check if the UI selection matches the stored generator
            spec_to_edit = stored_spec; % Assume stored spec is current
            if ~isfield(stored_spec, 'generator') || ~strcmp(stored_spec.generator, selected_generator_in_ui)
                 % Dropdown changed! Prepare a new, empty/default spec for the selected generator
                 warning('Generator selection changed for "%s". Opening editor with defaults for "%s".', param_name, selected_generator_in_ui);
                 spec_to_edit = struct();
                 spec_to_edit.generator = selected_generator_in_ui;
                 try
                     spec_to_edit.version = app.context.generators(selected_generator_in_ui).schema.version;
                 catch
                      spec_to_edit.version = 'unknown'; % Fallback
                 end
                 spec_to_edit.parameters = struct(); % Start fresh
            end

            % 5. Open the modal editor
            editor = gui.stimuli.StimulusEditor(app.UIFigure, app.context, spec_to_edit);
            uiwait(editor.UIFigure);

            if editor.WasSaved
                % 6. Update the stored spec data within the controlStruct
                controlStruct.stimulus_spec = editor.OutputSpec;
                % Update the dropdown just in case the editor changed it (though it shouldn't)
                controlStruct.dropdown.Value = editor.OutputSpec.generator;

                % 7. Write the modified controlStruct back into the FieldEdits map
                field_info.control = controlStruct;
                app.FieldEdits(param_name) = field_info; % Update the map entry
                 fprintf('Stimulus spec for "%s" updated.\n', param_name);
            end
        end

        function onValidate(app)
            % Validate current values using block_utils and show dialog

            try
                temp_block = app.readValuesToStruct(); % Read into a temporary struct
                [is_valid, errors] = gui.blocks.block_utils.validate_block(temp_block, app.schema, app.context);
                gui.common.error_dialog.show_validation_errors(app.UIFigure, errors, 'Validation Result');
            catch ME
                 gui.common.error_dialog.show_general_error(app.UIFigure, ME, 'Validation Error');
            end
        end

        function onSave(app)
            % Read values, validate, save using block_utils, show dialog

            try
                % Read values into the app.block property
                app.readValues();

                % Validate before saving
                [is_valid, errors] = gui.blocks.block_utils.validate_block(app.block, app.schema, app.context);
                if ~is_valid
                     gui.common.error_dialog.show_validation_errors(app.UIFigure, errors, 'Cannot Save - Validation Failed');
                    return;
                end

                % Update timestamps
                app.block.modified = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
                 if app.is_new % Update created only if new
                     app.block.created = app.block.modified;
                 end

                % Save to file using config for path
                filename = [app.block.block_id core.config.BLOCK_EXTENSION];
                filepath = core.config.get_block_path(filename);
                gui.blocks.block_utils.save_block(app.block, filepath);

                % Refresh parent BlockManager list
                if ~isempty(app.ParentApp) && isvalid(app.ParentApp) && ismethod(app.ParentApp, 'refreshBlockList')
                    app.ParentApp.refreshBlockList();
                end

                % Success message and close
                uialert(app.UIFigure, sprintf('Block saved:\n%s', filepath), 'Save Successful', 'Icon', 'success', 'Modal', true);
                 drawnow; % Ensure dialog shows before closing
                app.close();

            catch ME
                 gui.common.error_dialog.show_save_error(app.UIFigure, ME);
            end
        end

        function onCancel(app)
            app.close();
        end

        function close(app)
             delete(app.UIFigure);
        end

        function current_block_struct = readValuesToStruct(app)
             % Reads UI values into a temporary struct for validation/preview
             % Does NOT modify app.block directly

             current_block_struct = struct();
             current_block_struct.format_version = core.config.BLOCK_FORMAT_VERSION;
             current_block_struct.block_id = app.BlockIDField.Value;
             current_block_struct.builder_type = app.builder_type; % Fixed for this editor instance
             current_block_struct.description = app.DescriptionField.Value;
             % Timestamps are handled during save, not needed for validation/preview

             current_block_struct.metadata = struct();
             current_block_struct.metadata.created_by = app.CreatedByField.Value;
             tags_str = strtrim(app.TagsField.Value);
             if ~isempty(tags_str)
                 current_block_struct.metadata.tags = strtrim(split(tags_str, ','));
             else
                 current_block_struct.metadata.tags = {};
             end

             current_block_struct.parameters = struct();
             param_names = keys(app.FieldEdits);

             for i = 1:length(param_names)
                 param_name = param_names{i};
                 field_info = app.FieldEdits(param_name);
                 control = field_info.control;
                 unit_type = field_info.unit_type;
                 param_type = field_info.param_type;

                 storage_value = []; % Initialize

                 switch param_type
                     case 'stimulus_specification'
                         % The actual spec is stored in the control struct
                         storage_value = control.stimulus_spec;

                     case 'array'
                          % Check if it's the smart listbox editor (panel) or simple text field
                         if isa(control, 'matlab.ui.container.Panel')
                             listbox = findobj(control, 'Type', 'uilistbox');
                             if ~isempty(listbox)
                                 vals_str = listbox.Items;
                                 if isempty(vals_str)
                                     storage_value = [];
                                 else
                                     display_value = str2double(vals_str); % Values in display units
                                     % Convert array elements using unit_converter
                                     storage_value = gui.common.unit_converter.to_storage(display_value, param_name, unit_type);
                                 end
                             else
                                 storage_value = []; % Error case or empty
                             end
                         else % Simple text field array
                              try storage_value = eval(control.Value); catch; storage_value = control.Value; end % Try eval, fallback to string
                         end

                         % Post-process array format for specific known cases (like iti_sec)
                          if strcmp(param_name, 'iti_sec') || endsWith(param_name, '_sec')
                              if isnumeric(storage_value)
                                  if numel(storage_value) == 1
                                       storage_value = storage_value(1); % Ensure scalar if single value
                                  elseif numel(storage_value) >= 2
                                      % Ensure [min, max] format if 2+ values, store in seconds
                                      storage_value = [min(storage_value), max(storage_value)];
                                  end
                              end
                          end


                     case {'integer', 'float', 'string', 'enum'}
                         display_value = control.Value;
                         storage_value = gui.common.unit_converter.to_storage(display_value, param_name, unit_type);
                         if strcmp(param_type, 'integer') && isnumeric(storage_value)
                             storage_value = round(storage_value); % Ensure integer
                         end
                     otherwise % Fallback
                          try storage_value = jsondecode(control.Value); catch; storage_value = control.Value; end
                 end
                 current_block_struct.parameters.(param_name) = storage_value;
             end
        end

        function readValues(app)
             % Reads values from UI directly into app.block property
             app.block = app.readValuesToStruct();
        end

        % --- PREVIEW FUNCTIONALITY ---
      function onPreview(app)
            % Generates and displays a preview based on the builder's schema template.
            fprintf('Preview button clicked for block: %s\n', app.BlockIDField.Value);
            try
                % 1. Read current UI values into a temporary block struct
                temp_block = app.readValuesToStruct();

                % 2. Validate this temporary block
                [is_valid, errors] = gui.blocks.block_utils.validate_block(temp_block, app.schema, app.context);
                if ~is_valid
                     gui.common.error_dialog.show_validation_errors(app.UIFigure, errors, 'Cannot Preview - Validation Failed');
                    return;
                end

                % 3. Check if the schema has a preview template
                if ~isfield(app.schema, 'preview_template')
                    uialert(app.UIFigure, 'This builder does not have a preview template defined in its schema.', 'Preview Unavailable', 'Icon', 'info');
                    return;
                end
                preview_template = app.schema.preview_template;

                % 4. Get the builder function and prepare a minimal context
                 builder_info = app.context.builders(temp_block.builder_type);
                 build_func = builder_info.build_func;
                 build_context = struct('sampling_rate_hz', core.config.DEFAULT_SAMPLING_RATE, 'generators', app.context.generators, 'rng_seed', randi(1000));

                 % 5. Limit n_trials for a short preview
                 preview_n_trials = 50; % Generate up to 50 trials for stats
                 if isfield(temp_block.parameters, 'n_trials')
                     original_n_trials = temp_block.parameters.n_trials;
                     temp_block.parameters.n_trials = min(original_n_trials, preview_n_trials);
                 end

                 % 6. Call the builder function
                 preview_trials = build_func(temp_block, build_context);
                 if isempty(preview_trials)
                     uialert(app.UIFigure, 'The builder generated an empty trial list for the preview.', 'Preview Empty', 'Icon', 'warning');
                     return;
                 end

                 % 7. Call the generic preview generator utility
                 summary_text = gui.common.preview_generator.generate(preview_trials, temp_block.parameters, preview_template);

                 % 8. Display in a message box
                 msgbox(summary_text, 'Block Preview', 'modal');

            catch ME
                 gui.common.error_dialog.show_general_error(app.UIFigure, ME, 'Preview Error');
                 fprintf('Preview Error: %s\n', ME.message);
                 fprintf('Stack:\n');
                 disp(ME.stack);
            end
        end

        function summary_text = generatePreviewSummary(~, trial_list, block_instance)
             % Generates a text summary from a sample trial list

             if isempty(trial_list)
                 summary_text = 'Builder returned an empty trial list.';
                 return;
             end

             num_trials = length(trial_list);
             summary_lines = {sprintf('Preview Summary (%d trials):', num_trials)};

             % --- Builder-Specific Summary (Example for Oddball) ---
             if strcmp(block_instance.builder_type, 'oddball')
                 try
                     is_deviant = arrayfun(@(t) t.metadata.is_deviant, trial_list);
                     num_deviants = sum(is_deviant);
                     num_standards = num_trials - num_deviants;
                     percent_deviant = 100 * num_deviants / num_trials;
                     summary_lines{end+1} = sprintf('- Standards: %d', num_standards);
                     summary_lines{end+1} = sprintf('- Deviants: %d (%.1f%%)', num_deviants, percent_deviant);

                     % Check for consecutive deviants
                     consecutive = any(is_deviant(1:end-1) & is_deviant(2:end));
                     if consecutive
                          summary_lines{end+1} = '- WARNING: Consecutive deviants found.';
                     end

                     % ITI Summary
                     if isfield(trial_list(1), 'iti_sec')
                         itis = [trial_list.iti_sec];
                         summary_lines{end+1} = sprintf('- ITI Range: %.3f - %.3f sec (Avg: %.3f)', min(itis), max(itis), mean(itis));
                     end

                     % Stimulus Summary
                      if isfield(trial_list(1).presentations(1).stimulus_spec, 'parameters')
                          std_params = block_instance.parameters.standard_stimulus.parameters;
                          dev_params = block_instance.parameters.deviant_stimulus.parameters;
                          % Simple comparison (assumes 'tone' generator)
                          if isfield(std_params, 'freq_hz') && isfield(dev_params, 'freq_hz')
                              summary_lines{end+1} = sprintf('- Std Stim: ~%.0f Hz, %d ms, %d dB', std_params.freq_hz, std_params.dur_ms, std_params.level_db);
                              summary_lines{end+1} = sprintf('- Dev Stim: ~%.0f Hz, %d ms, %d dB', dev_params.freq_hz, dev_params.dur_ms, dev_params.level_db);
                          end
                      end
                 catch ME
                      summary_lines{end+1} = sprintf('- Error generating oddball summary: %s', ME.message);
                 end
             else
                 % Generic Summary for other builders
                 trial_types = unique({trial_list.trial_type});
                 summary_lines{end+1} = sprintf('- Trial Types: %s', strjoin(trial_types, ', '));
                  if isfield(trial_list(1), 'iti_sec')
                     itis = [trial_list.iti_sec];
                     summary_lines{end+1} = sprintf('- ITI Range: %.3f - %.3f sec (Avg: %.3f)', min(itis), max(itis), mean(itis));
                  end
             end

             % --- Sequence Preview ---
             summary_lines{end+1} = ' ';
             summary_lines{end+1} = 'First 10 Trials Sequence:';
             seq_str = '';
             for i = 1:min(num_trials, 10)
                 trial_type_char = 'U'; % Unknown
                 if strcmp(block_instance.builder_type, 'oddball')
                      trial_type_char = ternary(trial_list(i).metadata.is_deviant, 'D', 'S');
                 elseif isfield(trial_list(i), 'trial_type')
                      if ~isempty(trial_list(i).trial_type)
                        trial_type_char = upper(trial_list(i).trial_type(1));
                      end
                 end
                 seq_str = [seq_str trial_type_char ' ']; %#ok<AGROW>
             end
             summary_lines{end+1} = ['[' strtrim(seq_str) ']'];

             summary_text = strjoin(summary_lines, '\n');
        end
    end
end

function result = ternary(condition, true_val, false_val)
    % Helper ternary operator
    if condition
        result = true_val;
    else
        result = false_val;
    end
end

function s = mergestructs(s1, s2)
    % Helper to merge fields from s2 into s1, overwriting s1 fields
    s = s1;
    f = fieldnames(s2);
    for i = 1:length(f)
        s.(f{i}) = s2.(f{i});
    end
end