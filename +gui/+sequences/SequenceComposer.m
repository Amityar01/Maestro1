classdef SequenceComposer < handle
    % SEQUENCECOMPOSER - Build experimental sequences from blocks

    properties
        UIFigure

        % Layout
        MainGrid, LeftPanel, CenterPanel, RightPanel, ButtonPanel

        % Left Panel - Block Library
        BlockLibraryList, BlockSearchField, AddBlockButton
        BlockPreviewText % Added for preview

        % Center Panel - Current Sequence
        SequenceList, RemoveButton, MoveUpButton, MoveDownButton, EditTransitionButton

        % Right Panel - Settings
        SequenceIDField, DescriptionField, SamplingRateField, EngineDropdown
        CreatedByField, TagsField % Metadata fields
        EstimatedDurationLabel, BlocksCountLabel, TotalTrialsLabel % Info labels

        % Bottom Buttons
        NewButton, LoadButton, SaveButton, ValidateButton

        % Data
        context
        available_blocks % Full list loaded at start
        current_sequence
        sequence_file % Full path to the currently loaded/saved file
        is_dirty = false % Flag for unsaved changes
    end

    methods
        function app = SequenceComposer()
            % Constructor
            try
                app.context = core.MaestroContext();
            catch ME
                errordlg(sprintf('Failed to create MaestroContext:\n%s\nPlease ensure Maestro is set up correctly.', ME.message), 'Initialization Error');
                delete(app); % Clean up if context fails
                return;
            end

            try
                app.available_blocks = gui.blocks.block_utils.list_blocks(); % Load once
            catch ME
                errordlg(sprintf('Failed to list blocks:\n%s\nPlease check library/blocks directory.', ME.message), 'Initialization Error');
                app.available_blocks = {}; % Initialize as empty
            end

            app.current_sequence = app.createEmptySequence();
            app.sequence_file = '';
            app.createComponents();
            app.refreshBlockLibraryList();
            app.loadSequenceDataIntoUI();
            app.refreshSequenceList();
            app.updateTitle();
            app.UIFigure.CloseRequestFcn = @(~,~) app.onCloseRequest();
        end

        function seq = createEmptySequence(app)
            % Create empty sequence structure with version and metadata
            seq = struct();
            seq.format_version = core.config.SEQUENCE_FORMAT_VERSION;
            seq.sequence_id = sprintf('sequence_%s', datestr(now, 'yyyymmdd_HHMMSS'));
            seq.description = '';
            seq.created = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
            seq.modified = seq.created;
            seq.metadata = struct('created_by', '', 'tags', {{}});
            seq.global_settings = struct();
            seq.global_settings.sampling_rate_hz = core.config.DEFAULT_SAMPLING_RATE;
            
            engine_types = keys(app.context.engines);
            default_engine = core.config.DEFAULT_ENGINE;
            if ~isempty(engine_types)
                if ~ismember(default_engine, engine_types)
                    default_engine = engine_types{1};
                end
            else
                 default_engine = '';
                 warning('No engines found during discovery.');
            end
            seq.global_settings.engine_type = default_engine;
            seq.global_settings.engine_config = struct();
            seq.blocks = [];
        end

        function createComponents(app)
            % Create UI components (USER CORRECTED VERSION)
            app.UIFigure = uifigure('Name', 'Sequence Composer');
            app.UIFigure.Position = [100 100 1200 700];

            % Main grid: 3 columns + button row
            app.MainGrid = uigridlayout(app.UIFigure, [2 3]);
            app.MainGrid.RowHeight = {'1x', 60};
            app.MainGrid.ColumnWidth = {'1x', '1.5x', '1x'};

            % === LEFT PANEL: Block Library ===
            app.LeftPanel = uipanel(app.MainGrid, 'Title', 'Block Library');
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;
            leftGrid = uigridlayout(app.LeftPanel, [5 1]);
            leftGrid.RowHeight = {30, 30, '1x', '1x', 40};

            % --- Search Area ---
            searchGrid = uigridlayout(leftGrid, [1 2]);
            searchGrid.RowHeight = {30};
            searchGrid.ColumnWidth = {'fit', '1x'};
            searchGrid.Padding = [0 0 0 0];
            searchGrid.Layout.Row = 1;
            searchGrid.Layout.Column = 1;

            % Search label - CORRECT SYNTAX
            searchLabel = uilabel(searchGrid, 'Text', 'Search:');
            searchLabel.Layout.Row = 1;
            searchLabel.Layout.Column = 1;

            app.BlockSearchField = uieditfield(searchGrid, 'text', 'Placeholder', 'Filter blocks...');
            app.BlockSearchField.Layout.Row = 1;
            app.BlockSearchField.Layout.Column = 2;
            app.BlockSearchField.ValueChangedFcn = @(src,event) app.onBlockSearch();

            % --- Listbox ---
            app.BlockLibraryList = uilistbox(leftGrid);
            app.BlockLibraryList.Layout.Row = 3;
            app.BlockLibraryList.Multiselect = 'off';
            app.BlockLibraryList.ValueChangedFcn = @(src,event) app.onBlockLibrarySelect();

            % --- Preview Area ---
            app.BlockPreviewText = uitextarea(leftGrid, 'Editable', 'off', 'WordWrap', 'on');
            app.BlockPreviewText.Layout.Row = 4;
            app.BlockPreviewText.Value = {'Select a block to see details...'};

            % --- Add Button ---
            app.AddBlockButton = uibutton(leftGrid, 'Text', 'Add to Sequence →');
            app.AddBlockButton.Layout.Row = 5;
            app.AddBlockButton.ButtonPushedFcn = @(src,event) app.onAddBlock();
            app.AddBlockButton.Enable = 'off';

            % === CENTER PANEL: Current Sequence ===
            app.CenterPanel = uipanel(app.MainGrid, 'Title', 'Current Sequence');
            app.CenterPanel.Layout.Row = 1;
            app.CenterPanel.Layout.Column = 2;
            centerGrid = uigridlayout(app.CenterPanel, [2 1]);
            centerGrid.RowHeight = {'1x', 50};

            app.SequenceList = uilistbox(centerGrid);
            app.SequenceList.Layout.Row = 1;
            app.SequenceList.Multiselect = 'off';
            app.SequenceList.ValueChangedFcn = @(src,event) app.onSequenceSelect();

            buttonGrid = uigridlayout(centerGrid, [1 4]);
            buttonGrid.Layout.Row = 2;
            buttonGrid.ColumnWidth = {'1x', '1x', '1x', '1x'};
            buttonGrid.Padding = [5 5 5 5];

            app.RemoveButton = uibutton(buttonGrid, 'Text', 'Remove', ...
                'ButtonPushedFcn', @(src,event) app.onRemoveBlock(), 'Enable', 'off');
            app.MoveUpButton = uibutton(buttonGrid, 'Text', '▲ Up', ...
                'ButtonPushedFcn', @(src,event) app.onMoveUp(), 'Enable', 'off');
            app.MoveDownButton = uibutton(buttonGrid, 'Text', '▼ Down', ...
                'ButtonPushedFcn', @(src,event) app.onMoveDown(), 'Enable', 'off');
            app.EditTransitionButton = uibutton(buttonGrid, 'Text', 'Edit Transition...', ...
                'ButtonPushedFcn', @(src,event) app.onEditTransition(), 'Enable', 'off');

            % === RIGHT PANEL: Settings ===
            app.RightPanel = uipanel(app.MainGrid, 'Title', 'Sequence Settings & Info');
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 3;
            rightGrid = uigridlayout(app.RightPanel, [11 2]);
            rightGrid.RowHeight = [repmat({30}, 1, 7), 10, 30, 30, 30];
            rightGrid.ColumnWidth = {120, '1x'};

            % Sequence ID
            lbl1 = uilabel(rightGrid, 'Text', '* Sequence ID:');
            lbl1.Layout.Row = 1;
            lbl1.Layout.Column = 1;
            app.SequenceIDField = uieditfield(rightGrid, 'text', ...
                'Value', app.current_sequence.sequence_id);
            app.SequenceIDField.Layout.Row = 1;
            app.SequenceIDField.Layout.Column = 2;
            app.SequenceIDField.ValueChangedFcn = @(src,event) app.markDirty();

            % Description
            lbl2 = uilabel(rightGrid, 'Text', 'Description:');
            lbl2.Layout.Row = 2;
            lbl2.Layout.Column = 1;
            app.DescriptionField = uieditfield(rightGrid, 'text');
            app.DescriptionField.Layout.Row = 2;
            app.DescriptionField.Layout.Column = 2;
            app.DescriptionField.ValueChangedFcn = @(src,event) app.markDirty();

            % Created By
            lbl3 = uilabel(rightGrid, 'Text', 'Created By:');
            lbl3.Layout.Row = 3;
            lbl3.Layout.Column = 1;
            app.CreatedByField = uieditfield(rightGrid, 'text');
            app.CreatedByField.Layout.Row = 3;
            app.CreatedByField.Layout.Column = 2;
            app.CreatedByField.ValueChangedFcn = @(src,event) app.markDirty();

            % Tags
            lbl4 = uilabel(rightGrid, 'Text', 'Tags (comma-sep):');
            lbl4.Layout.Row = 4;
            lbl4.Layout.Column = 1;
            app.TagsField = uieditfield(rightGrid, 'text');
            app.TagsField.Layout.Row = 4;
            app.TagsField.Layout.Column = 2;
            app.TagsField.ValueChangedFcn = @(src,event) app.markDirty();

            % Sampling Rate
            lbl5 = uilabel(rightGrid, 'Text', '* Sampling Rate:');
            lbl5.Layout.Row = 5;
            lbl5.Layout.Column = 1;
            app.SamplingRateField = uispinner(rightGrid, 'Limits', [8000 500000], 'Step', 1000);
            app.SamplingRateField.Layout.Row = 5;
            app.SamplingRateField.Layout.Column = 2;
            app.SamplingRateField.Value = app.current_sequence.global_settings.sampling_rate_hz;
            app.SamplingRateField.ValueChangedFcn = @(src,event) app.markDirty();

            % Engine
            lbl6 = uilabel(rightGrid, 'Text', '* Engine:');
            lbl6.Layout.Row = 6;
            lbl6.Layout.Column = 1;
            app.EngineDropdown = uidropdown(rightGrid);
            app.EngineDropdown.Layout.Row = 6;
            app.EngineDropdown.Layout.Column = 2;
            engine_types = keys(app.context.engines);
            if ~isempty(engine_types)
                app.EngineDropdown.Items = sort(engine_types);
                if isfield(app.current_sequence.global_settings, 'engine_type') && ...
                   ismember(app.current_sequence.global_settings.engine_type, engine_types)
                    app.EngineDropdown.Value = app.current_sequence.global_settings.engine_type;
                else
                    app.EngineDropdown.Value = app.EngineDropdown.Items{1}; % Default
                end
            else
                app.EngineDropdown.Items = {'No Engines Found'};
                app.EngineDropdown.Enable = 'off';
            end
            app.EngineDropdown.ValueChangedFcn = @(src,event) app.markDirty();

            % Separator Label for Info section
            infoLabel = uilabel(rightGrid, 'Text', '─── Sequence Info ───');
            infoLabel.Layout.Row = 8;
            infoLabel.Layout.Column = [1 2];
            infoLabel.FontWeight = 'bold';

            % Blocks Count
            lbl7 = uilabel(rightGrid, 'Text', 'Blocks in Seq:');
            lbl7.Layout.Row = 9;
            lbl7.Layout.Column = 1;
            app.BlocksCountLabel = uilabel(rightGrid, 'Text', '0');
            app.BlocksCountLabel.Layout.Row = 9;
            app.BlocksCountLabel.Layout.Column = 2;

            % Total Trials
            lbl8 = uilabel(rightGrid, 'Text', 'Est. Total Trials:');
            lbl8.Layout.Row = 10;
            lbl8.Layout.Column = 1;
            app.TotalTrialsLabel = uilabel(rightGrid, 'Text', '0');
            app.TotalTrialsLabel.Layout.Row = 10;
            app.TotalTrialsLabel.Layout.Column = 2;

            % Duration
            lbl9 = uilabel(rightGrid, 'Text', 'Est. Duration:');
            lbl9.Layout.Row = 11;
            lbl9.Layout.Column = 1;
            app.EstimatedDurationLabel = uilabel(rightGrid, 'Text', '~0.0 min');
            app.EstimatedDurationLabel.Layout.Row = 11;
            app.EstimatedDurationLabel.Layout.Column = 2;

            % === BOTTOM PANEL: Main Buttons ===
            app.ButtonPanel = uipanel(app.MainGrid);
            app.ButtonPanel.Layout.Row = 2;
            app.ButtonPanel.Layout.Column = [1 3];
            buttonLayout = uigridlayout(app.ButtonPanel, [1 5]);
            buttonLayout.ColumnWidth = {'1x', 100, 100, 100, 100};
            buttonLayout.Padding = [10 10 10 10];

            uilabel(buttonLayout); % Spacer
            app.NewButton = uibutton(buttonLayout, 'Text', 'New', ...
                'ButtonPushedFcn', @(src,event) app.onNew());
            app.LoadButton = uibutton(buttonLayout, 'Text', 'Load...', ...
                'ButtonPushedFcn', @(src,event) app.onLoad());
            app.ValidateButton = uibutton(buttonLayout, 'Text', 'Validate', ...
                'ButtonPushedFcn', @(src,event) app.onValidate());
            app.SaveButton = uibutton(buttonLayout, 'Text', 'Save', ...
                'ButtonPushedFcn', @(src,event) app.onSave(), ...
                'BackgroundColor', [0.3 0.7 0.3]);
        end % End createComponents

        function refreshBlockLibraryList(app, filter_text)
            % Refresh block library list UI, optionally filtering
            if nargin < 2
                filter_text = ''; % Default to no filter
            end
            filter_text = lower(strtrim(filter_text));

            filtered_indices = []; % Indices into app.available_blocks that match filter

            for i = 1:length(app.available_blocks)
                block = app.available_blocks{i};
                % Check if filter text matches any relevant field
                if isempty(filter_text) || ...
                   contains(lower(block.block_id), filter_text) || ...
                   contains(lower(block.builder_type), filter_text) || ...
                   contains(lower(block.description), filter_text) || ...
                   contains(lower(block.metadata_summary), filter_text) % Include metadata summary

                    filtered_indices(end+1) = i; %#ok<AGROW>
                end
            end

            % Update UI listbox items and data
            if isempty(filtered_indices)
                app.BlockLibraryList.Items = {'(No blocks found or match filter)'};
                app.BlockLibraryList.ItemsData = []; % No data if empty
            else
                items = cell(1, length(filtered_indices));
                for i = 1:length(filtered_indices)
                      idx = filtered_indices(i); % Original index
                      block = app.available_blocks{idx};
                      % Format list item string
                      item_str = sprintf('%s (%s)', block.block_id, block.builder_type);
                      if ~isempty(block.metadata_summary)
                          item_str = [item_str ' | ' block.metadata_summary];
                      end
                      items{i} = item_str;
                end
                app.BlockLibraryList.Items = items;
                % Store the original index from app.available_blocks as ItemsData
                app.BlockLibraryList.ItemsData = filtered_indices;
            end
             app.BlockLibraryList.Value = {}; % Clear selection after filtering/refreshing
             app.onBlockLibrarySelect(); % Update preview and button state based on cleared selection
        end


        function refreshSequenceList(app)
            % Refresh sequence list display UI based on app.current_sequence.blocks
            num_blocks = 0;
            % Ensure blocks field exists and is not empty before calculating length
            if isfield(app.current_sequence, 'blocks') && ~isempty(app.current_sequence.blocks)
                 % Check if it's a non-empty struct array or cell array
                 if (isstruct(app.current_sequence.blocks) || iscell(app.current_sequence.blocks))
                     % Handle scalar struct case where length gives 1, but we need to check if it's the placeholder
                     if isscalar(app.current_sequence.blocks) && isstruct(app.current_sequence.blocks) && ~isfield(app.current_sequence.blocks, 'block_file')
                          num_blocks = 0; % It's likely the initial empty struct
                     else
                          num_blocks = length(app.current_sequence.blocks);
                     end
                 end
            end


            if num_blocks == 0
                app.SequenceList.Items = {'(Drag or add blocks from library)'};
                app.SequenceList.ItemsData = []; % No data if empty
                app.current_sequence.blocks = []; % Ensure it's an empty array for consistency
            else
                items = cell(1, num_blocks);
                % Handle scalar struct case explicitly if length somehow returns 1
                 if num_blocks == 1 && isstruct(app.current_sequence.blocks) && isfield(app.current_sequence.blocks,'block_file')
                     block_entry = app.current_sequence.blocks;
                     [~, block_name, ~] = fileparts(block_entry.block_file);
                     trans_str = app.formatTransition(block_entry.transition);
                     items{1} = sprintf('%d. %s  [%s]', 1, block_name, trans_str);
                 else % Handle array of structs
                    for i = 1:num_blocks
                        block_entry = app.current_sequence.blocks(i);
                        [~, block_name, ~] = fileparts(block_entry.block_file); % Get display name from filename
                        trans_str = app.formatTransition(block_entry.transition);
                        items{i} = sprintf('%d. %s  [%s]', i, block_name, trans_str);
                    end
                 end
                app.SequenceList.Items = items;
                % Store the 1-based index within the sequence list as ItemsData
                app.SequenceList.ItemsData = 1:num_blocks;
            end

            app.updateInfo(); % Update duration, block count in the UI
        end


        function str = formatTransition(~, transition)
            % Format transition struct into a human-readable string
             if ~isstruct(transition) || ~isfield(transition, 'type') || strcmp(transition.type,'none')
                str = 'No transition'; return;
            end
            switch transition.type
                case 'delay'
                    dur = 0; if isfield(transition, 'duration_sec') && isnumeric(transition.duration_sec), dur = transition.duration_sec; end
                    str = sprintf('Delay %.1f s', dur);
                case 'button_press'
                    str = 'Button Press'; if isfield(transition, 'message') && ~isempty(transition.message), str = [str ': "' transition.message '"']; end
                otherwise, str = ['Unknown: ' transition.type];
            end
        end

       function updateInfo(app)
             % Update info display (block count, duration, trials) using enhanced estimator
             summary = gui.sequences.sequence_utils.estimate_duration_and_trials(app.current_sequence);
             
             % --- FINAL FIX: Defensive checking based on user feedback ---
             num_blocks = 0;
             if isstruct(summary) && isfield(summary, 'block_details') && ~isempty(summary.block_details)
                 num_blocks = length(summary.block_details);
             end
             
             total_trials = 0;
             if isstruct(summary) && isfield(summary, 'total_trials')
                 total_trials = summary.total_trials;
             end

             total_sec = 0;
             if isstruct(summary) && isfield(summary, 'total_sec')
                 total_sec = summary.total_sec;
             end
             % --- END FINAL FIX ---

             app.BlocksCountLabel.Text = sprintf('%d', num_blocks);
             app.TotalTrialsLabel.Text = sprintf('~%d', total_trials);
             app.EstimatedDurationLabel.Text = sprintf('~%.1f min', total_sec / 60);

             % Handle potential errors from the summary
             if isstruct(summary) && isfield(summary, 'errors') && ~isempty(summary.errors)
                 warning('Duration Estimation Warnings:\n%s', strjoin(summary.errors, '\n'));
                 app.EstimatedDurationLabel.Text = [app.EstimatedDurationLabel.Text ' (?)'];
                 app.TotalTrialsLabel.Text = [app.TotalTrialsLabel.Text ' (?)'];
                 tooltip_text = strjoin(['Estimation may be inaccurate due to errors:'; summary.errors],' ');
                 app.EstimatedDurationLabel.Tooltip = tooltip_text;
                 app.TotalTrialsLabel.Tooltip = tooltip_text;
             else
                  app.EstimatedDurationLabel.Tooltip = '';
                  app.TotalTrialsLabel.Tooltip = '';
             end
        end


         function updateTitle(app)
             % Update figure title with filename and dirty status
             base_title = 'Sequence Composer';
             current_file = '(Untitled)';
             if ~isempty(app.sequence_file)
                 [~, fname, ext] = fileparts(app.sequence_file);
                 current_file = [fname ext];
             end
             dirty_marker = '';
             if app.is_dirty
                 dirty_marker = ' *'; % Add asterisk if dirty
             end
             % Ensure UIFigure is valid before setting Name
             if isvalid(app.UIFigure)
                app.UIFigure.Name = sprintf('%s - %s%s', base_title, current_file, dirty_marker);
             end
         end

         function markDirty(app)
             % Mark sequence as having unsaved changes
             if ~app.is_dirty
                app.is_dirty = true;
                app.updateTitle(); % Update title to show dirty marker
             end
         end

         function markClean(app)
             % Mark sequence as saved (no unsaved changes)
             if app.is_dirty
                app.is_dirty = false;
                app.updateTitle(); % Update title to remove dirty marker
             end
         end

         function proceed = checkForUnsavedChanges(app)
             % Check if dirty, prompt user to save/discard/cancel
             proceed = true; % Default to proceed
             if ~app.is_dirty % If not dirty, just proceed
                 return;
             end

             % Prompt user
             selection = uiconfirm(app.UIFigure, ...
                 'You have unsaved changes. Do you want to save them before continuing?', ...
                 'Unsaved Changes', ...
                 'Options', {'Save', 'Discard', 'Cancel'}, ...
                 'DefaultOption', 'Save', 'CancelOption', 'Cancel', 'Icon', 'warning');

             switch selection
                 case 'Save'
                     proceed = app.onSave(); % Try saving, proceed only if save succeeds
                 case 'Discard'
                     proceed = true; % User chose to discard changes
                 case 'Cancel'
                     proceed = false; % User cancelled the current action (e.g., New, Load, Close)
             end
         end

          function onCloseRequest(app)
              % Handle figure close request, check for unsaved changes
             if app.checkForUnsavedChanges() % Prompt user if dirty
                 delete(app.UIFigure); % Close if saved or discarded
             end
             % Do nothing if user cancelled the save/discard prompt
         end


        % --- UI Callbacks ---
        function onBlockSearch(app)
             % Callback for search field - refresh list with filter
             app.refreshBlockLibraryList(app.BlockSearchField.Value);
        end

        function onBlockLibrarySelect(app)
             % Callback when a block is selected in the library list
             selectedIndexData = app.BlockLibraryList.ItemsData; % Original indices
             selectedValueIndex = app.BlockLibraryList.Value; % Index within currently displayed ItemsData

             if isempty(selectedValueIndex) || isempty(selectedIndexData)
                  app.BlockPreviewText.Value = {'Select a block from the library above.'};
                  app.AddBlockButton.Enable = 'off';
                  return;
             end

              % Ensure selectedValueIndex is within bounds of selectedIndexData
             if selectedValueIndex > length(selectedIndexData)
                 app.BlockPreviewText.Value = {'Selection index error.'};
                 app.AddBlockButton.Enable = 'off';
                 return; % Index mismatch
             end

             % Get the original index into app.available_blocks using ItemsData
             originalIndex = selectedIndexData(selectedValueIndex);

              % Ensure originalIndex is valid for app.available_blocks
             if originalIndex > length(app.available_blocks)
                 app.BlockPreviewText.Value = {'Block data index error.'};
                 app.AddBlockButton.Enable = 'off';
                 return; % Index mismatch
             end

             block_info = app.available_blocks{originalIndex}; % Get info struct

             % Load full block details for preview pane
             try
                 block_data = gui.blocks.block_utils.load_block(block_info.file); % Load from file path

                 % --- Generate Preview Text ---
                 preview_lines = {};
                 preview_lines{end+1} = sprintf('ID: %s', block_data.block_id);
                 preview_lines{end+1} = sprintf('Builder: %s', block_data.builder_type);
                  if isfield(block_data,'description') && ~isempty(block_data.description)
                      preview_lines{end+1} = sprintf('Desc: %s', block_data.description);
                  end
                  % Add Metadata to preview
                  if isfield(block_data, 'metadata')
                     meta_parts = {};
                     if isfield(block_data.metadata, 'created_by') && ~isempty(block_data.metadata.created_by), meta_parts{end+1} = ['By: ' block_data.metadata.created_by]; end
                     if isfield(block_data.metadata, 'tags') && ~isempty(block_data.metadata.tags), meta_parts{end+1} = ['Tags: ' strjoin(block_data.metadata.tags, ', ')]; end
                     if ~isempty(meta_parts), preview_lines{end+1} = ['Meta: ' strjoin(meta_parts, ' | ')]; end
                  end
                  if isfield(block_data, 'created'), preview_lines{end+1} = ['Created: ' block_data.created]; end
                  if isfield(block_data, 'modified'), preview_lines{end+1} = ['Modified: ' block_data.modified]; end

                 preview_lines{end+1} = '--- Parameters ---';
                 param_text = gui.blocks.block_utils.format_parameters(block_data.parameters);
                 
                 % --- FIX ---
                 % The error occurs here. preview_lines is a 1xN row cell array,
                 % but splitlines() returns an Mx1 column cell array.
                 % We must make preview_lines a column vector before concatenating.
                 preview_lines = [preview_lines(:); splitlines(param_text)];
                 % --- END FIX ---

                 app.BlockPreviewText.Value = preview_lines; % Update text area
                 app.AddBlockButton.Enable = 'on'; % Enable Add button

             catch ME
                 app.BlockPreviewText.Value = {'Error loading block preview:', ME.message};
                 app.AddBlockButton.Enable = 'off';
                 % Use the corrected error dialog
                 gui.common.error_dialog.show_load_error(app.UIFigure, ME, block_info.name);
             end
         end


        function onAddBlock(app)
            % Add selected block file to sequence list
            selectedIndexData = app.BlockLibraryList.ItemsData;
            selectedValueIndex = app.BlockLibraryList.Value; % Index within currently displayed items

             if isempty(selectedValueIndex); return; end % Nothing selected

             % Get the original index into app.available_blocks
             originalIndex = selectedIndexData(selectedValueIndex);
             block_info = app.available_blocks{originalIndex}; % Get the info struct

            % Create sequence block entry (store relative filename only)
            seq_block = struct();
            seq_block.block_file = block_info.name; % Just filename.json
            seq_block.transition = struct('type', 'none'); % Default transition

            % Add to sequence array
            % Handle case where blocks might be empty [] or non-existent
             if ~isfield(app.current_sequence, 'blocks') || isempty(app.current_sequence.blocks)
                 app.current_sequence.blocks = seq_block; % Start the array/struct
             else
                 % Ensure it's treated as an array for appending
                 % Handle scalar struct: convert to 1x2 struct array
                 if isstruct(app.current_sequence.blocks) && isscalar(app.current_sequence.blocks) && isfield(app.current_sequence.blocks, 'block_file')
                     app.current_sequence.blocks = [app.current_sequence.blocks, seq_block];
                 else % Already an array or should become one
                      app.current_sequence.blocks(end+1) = seq_block; % Append
                 end
             end


            app.markDirty(); % Mark changes
            app.refreshSequenceList(); % Update UI list

             % Select the newly added item in the sequence list
             new_index = length(app.current_sequence.blocks);
             app.SequenceList.Value = new_index;
             app.updateButtonStates(); % Update enabled state of buttons
        end

        function onRemoveBlock(app)
            % Remove selected block from sequence list UI and data
            selected_idx = app.SequenceList.Value; % Get index from ItemsData (1-based)
            if isempty(selected_idx); return; end

             num_blocks_before_remove = length(app.current_sequence.blocks);
             if selected_idx > num_blocks_before_remove || selected_idx < 1
                 return; % Invalid index
             end

            app.current_sequence.blocks(selected_idx) = []; % Remove from data

             app.markDirty(); % Mark changes
            app.refreshSequenceList(); % Update UI

            % Try to select the previous/next item, or clear selection if list is empty
             num_blocks_after_remove = length(app.current_sequence.blocks);
            if num_blocks_after_remove == 0
                app.SequenceList.Value = {}; % Clear selection
            elseif selected_idx > num_blocks_after_remove
                % If last item was removed, select the new last item
                app.SequenceList.Value = num_blocks_after_remove;
            else
                % Otherwise, select the item now at the deleted index
                app.SequenceList.Value = selected_idx;
            end
            app.updateButtonStates(); % Update buttons
        end

        function onMoveUp(app)
             % Move selected sequence block up one position
             idx = app.SequenceList.Value;
             if isempty(idx) || idx <= 1; return; end % Cannot move up if first or none selected

             % Swap elements in the data array
             app.current_sequence.blocks([idx-1, idx]) = app.current_sequence.blocks([idx, idx-1]);

             app.markDirty(); % Mark changes
             app.refreshSequenceList(); % Update UI list
             app.SequenceList.Value = idx - 1; % Keep selection on the item that moved up
             app.updateButtonStates(); % Update buttons (Move Up might disable)
        end

        function onMoveDown(app)
            % Move selected sequence block down one position
            idx = app.SequenceList.Value;
             num_blocks = 0;
             % Check if blocks exist and is an array before getting length
             if isfield(app.current_sequence, 'blocks') && ~isempty(app.current_sequence.blocks) && (isstruct(app.current_sequence.blocks) || iscell(app.current_sequence.blocks))
                   % Handle scalar struct case explicitly
                   if isscalar(app.current_sequence.blocks) && isstruct(app.current_sequence.blocks) && isfield(app.current_sequence.blocks, 'block_file')
                       num_blocks = 1;
                   else
                       num_blocks = length(app.current_sequence.blocks);
                   end
             end
             % Cannot move down if last or none selected, or if only one block
            if isempty(idx) || idx >= num_blocks || num_blocks <= 1; return; end

            % Swap elements
            app.current_sequence.blocks([idx, idx+1]) = app.current_sequence.blocks([idx+1, idx]);

             app.markDirty(); % Mark changes
            app.refreshSequenceList(); % Update UI
            app.SequenceList.Value = idx + 1; % Keep selection on the item that moved down
            app.updateButtonStates(); % Update buttons (Move Down might disable)
        end


        function onEditTransition(app)
            % Open TransitionEditor for the selected block entry
            idx = app.SequenceList.Value;
            if isempty(idx); return; end % Nothing selected

             num_blocks = length(app.current_sequence.blocks);
             if idx > num_blocks || idx < 1; return; end % Invalid index

            current_transition = app.current_sequence.blocks(idx).transition;

            % Open modal editor dialog
            editor = gui.sequences.TransitionEditor(app.UIFigure, current_transition);
            uiwait(editor.UIFigure); % Wait for editor to close

            if editor.WasSaved % Check if user saved changes
                % Check if the transition actually changed
                if ~isequal(current_transition, editor.OutputTransition)
                    app.current_sequence.blocks(idx).transition = editor.OutputTransition; % Update data
                    app.markDirty(); % Mark changes
                    app.refreshSequenceList(); % Update UI list display
                    app.SequenceList.Value = idx; % Re-select the edited item
                end
            end
        end

        function onSequenceSelect(app)
            % Callback when selection changes in the sequence list
            app.updateButtonStates(); % Update enable state of Up/Down/Remove/Edit buttons
        end

        function updateButtonStates(app)
            % Update enable state of sequence manipulation buttons based on selection
            has_selection = ~isempty(app.SequenceList.Value);
             num_blocks = 0;
              % Check if blocks exist and is an array before getting length
               if isfield(app.current_sequence, 'blocks') && ~isempty(app.current_sequence.blocks)
                   % Handle scalar struct case explicitly
                   if isscalar(app.current_sequence.blocks) && isstruct(app.current_sequence.blocks) && isfield(app.current_sequence.blocks, 'block_file')
                       num_blocks = 1;
                   elseif ~isscalar(app.current_sequence.blocks) % Is an array
                       num_blocks = length(app.current_sequence.blocks);
                   end
               end
            idx = app.SequenceList.Value; % Currently selected index (1-based)

            app.RemoveButton.Enable = has_selection;
            app.EditTransitionButton.Enable = has_selection;
            app.MoveUpButton.Enable = has_selection && (idx > 1);
            app.MoveDownButton.Enable = has_selection && (idx < num_blocks);
        end


        function onNew(app)
            % Action for 'New' button - create an empty sequence
            if ~app.checkForUnsavedChanges(); return; end % Prompt if dirty

            app.current_sequence = app.createEmptySequence(); % Create new struct
            app.sequence_file = ''; % Clear associated file path
            app.loadSequenceDataIntoUI(); % Update settings fields in UI
            app.refreshSequenceList(); % Update sequence list UI (shows empty)
            app.markClean(); % New sequence is not dirty
            app.updateTitle(); % Update figure title
        end

        function onLoad(app)
            % Action for 'Load...' button - load sequence from JSON file
             if ~app.checkForUnsavedChanges(); return; end % Prompt if dirty

            sequences_dir = core.config.get_sequence_path(); % Use config for default dir
            if ~exist(sequences_dir, 'dir')
                try mkdir(sequences_dir); catch ME, gui.common.error_dialog.show_general_error(app.UIFigure, ME, 'Directory Error'); return; end
            end

            [filename, pathname] = uigetfile(['*' core.config.SEQUENCE_EXTENSION], 'Load Sequence', sequences_dir);
            if filename == 0; return; end % User cancelled dialog
            filepath = fullfile(pathname, filename);

            try
                loaded_seq = gui.sequences.sequence_utils.load_sequence(filepath); % Use util to load (handles migration)
                app.current_sequence = loaded_seq; % Update data
                app.sequence_file = filepath; % Store full path of loaded file
                app.loadSequenceDataIntoUI(); % Update settings fields in UI
                app.refreshSequenceList(); % Update sequence list UI
                app.markClean(); % Loaded sequence is initially clean
                app.updateTitle(); % Update figure title with new filename
                uialert(app.UIFigure, sprintf('Loaded: %s', filename), 'Load Successful', 'Icon', 'success','Modal',false);
            catch ME
                 gui.common.error_dialog.show_load_error(app.UIFigure, ME, filename);
                 % Keep existing sequence loaded on error? Or clear? Let's clear for safety.
                 app.current_sequence = app.createEmptySequence();
                 app.sequence_file = '';
                 app.loadSequenceDataIntoUI();
                 app.refreshSequenceList();
                 app.markClean();
                 app.updateTitle();
            end
        end

         function success = onSave(app)
             % Action for 'Save' button - save current sequence to JSON
             % Returns true on success, false otherwise (used by checkForUnsavedChanges)
             success = false; % Default to failure
             try
                 % 1. Read current state from UI into app.current_sequence
                 app.readUIDataIntoSequence();

                 % Make sure sequence_id is not empty and is valid filename component
                 temp_id = strtrim(app.current_sequence.sequence_id);
                 if isempty(temp_id)
                     uialert(app.UIFigure, 'Sequence ID cannot be empty.', 'Save Error', 'Icon', 'error');
                     return; % Stay false
                 end
                 % Attempt to make it a valid variable name (good proxy for filename part)
                 valid_id = matlab.lang.makeValidName(temp_id);
                 if ~strcmp(temp_id, valid_id)
                     answer = uiconfirm(app.UIFigure, sprintf('Sequence ID contains invalid characters for filenames.\nSuggest saving as "%s"?', valid_id),'Invalid ID', 'Options',{'Use Suggestion', 'Cancel'}, 'DefaultOption',1, 'CancelOption', 2);
                      if strcmp(answer, 'Cancel')
                          return; % Stay false
                      end
                      app.current_sequence.sequence_id = valid_id;
                      app.SequenceIDField.Value = valid_id; % Update UI
                 end


                 % 2. Validate the sequence data
                 [is_valid, errors] = gui.sequences.sequence_utils.validate_sequence(app.current_sequence, app.context);
                 if ~is_valid
                      gui.common.error_dialog.show_validation_errors(app.UIFigure, errors, 'Cannot Save - Validation Failed');
                     return; % Stay false, do not proceed with save
                 end

                 % 3. Update modification timestamp
                 app.current_sequence.modified = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
                 % Update created timestamp only if saving for the first time
                 if isempty(app.sequence_file)
                    app.current_sequence.created = app.current_sequence.modified;
                 end

                 % 4. Determine save path
                 filepath = app.sequence_file; % Use existing path if available
                 [~, current_filename_noext, ~] = fileparts(filepath);
                  proposed_filename = [app.current_sequence.sequence_id core.config.SEQUENCE_EXTENSION];

                 % 5. Prompt for "Save As" if:
                 %    - No file path exists yet (app.sequence_file is empty)
                 %    - Or, the sequence_id in the UI differs from the current filename
                  save_as_needed = isempty(filepath) || ~strcmp(current_filename_noext, app.current_sequence.sequence_id);

                  if save_as_needed
                      sequences_dir = core.config.get_sequence_path(); % Default save dir
                      if ~exist(sequences_dir, 'dir'); try mkdir(sequences_dir); catch ME, gui.common.error_dialog.show_general_error(app.UIFigure, ME, 'Directory Error'); return; end; end
                      [filename, pathname] = uiputfile(['*' core.config.SEQUENCE_EXTENSION], ...
                          'Save Sequence As', fullfile(sequences_dir, proposed_filename));
                      if filename == 0; return; end % User cancelled Save As, stay false
                      filepath = fullfile(pathname, filename);

                      % Update sequence_id to match the chosen filename (important!)
                      [~, saved_id, ~] = fileparts(filename);
                       if ~strcmp(saved_id, app.current_sequence.sequence_id)
                           app.current_sequence.sequence_id = saved_id;
                           app.SequenceIDField.Value = saved_id; % Reflect change in UI
                       end
                  end

                 % 6. Save using utility function
                 gui.sequences.sequence_utils.save_sequence(app.current_sequence, filepath);

                 % 7. Update internal state and UI
                 app.sequence_file = filepath; % Store the path where it was saved
                 app.markClean(); % Mark as no longer dirty
                 app.updateTitle(); % Update title (removes asterisk, shows new name if Save As)
                 uialert(app.UIFigure, sprintf('Sequence saved:\n%s', filepath), 'Save Successful', 'Icon', 'success','Modal',false);
                 success = true; % Indicate save was successful

             catch ME
                  gui.common.error_dialog.show_save_error(app.UIFigure, ME);
                 % success remains false
             end
         end


        function onValidate(app)
             % Action for 'Validate' button
             try
                 app.readUIDataIntoSequence(); % Get current state from UI into struct
                 % Use util to validate
                 [is_valid, errors] = gui.sequences.sequence_utils.validate_sequence(app.current_sequence, app.context);
                 % Use common dialog to show results (shows success or errors)
                 gui.common.error_dialog.show_validation_errors(app.UIFigure, errors, 'Validation Result');
                 % Recalculate duration/trials after potential UI changes read
                 app.updateInfo();
             catch ME
                  gui.common.error_dialog.show_general_error(app.UIFigure, ME, 'Validation Error');
             end
        end

        % --- Helper functions to load/read UI data ---
        function loadSequenceDataIntoUI(app)
             % Populates UI fields from app.current_sequence struct
             app.SequenceIDField.Value = app.current_sequence.sequence_id;
             app.DescriptionField.Value = app.current_sequence.description;

             % Metadata
             created_by = ''; tags_str = ''; % Defaults
              if isfield(app.current_sequence, 'metadata') && isstruct(app.current_sequence.metadata)
                  if isfield(app.current_sequence.metadata, 'created_by'), created_by = app.current_sequence.metadata.created_by; end
                  if isfield(app.current_sequence.metadata, 'tags')
                       if iscell(app.current_sequence.metadata.tags), tags_str = strjoin(app.current_sequence.metadata.tags, ', ');
                       else, tags_str = app.current_sequence.metadata.tags; end % Handle old string format
                  end
              end
             app.CreatedByField.Value = created_by;
             app.TagsField.Value = tags_str;

             % Global Settings
             gs = app.current_sequence.global_settings;
             if isfield(gs, 'sampling_rate_hz') && isnumeric(gs.sampling_rate_hz)
                 app.SamplingRateField.Value = gs.sampling_rate_hz;
             else
                  app.SamplingRateField.Value = core.config.DEFAULT_SAMPLING_RATE;
             end
              % Check if engine dropdown is enabled before setting value
              if strcmp(app.EngineDropdown.Enable, 'on')
                  if isfield(gs, 'engine_type') && ismember(gs.engine_type, app.EngineDropdown.Items)
                      app.EngineDropdown.Value = gs.engine_type;
                  elseif ~isempty(app.EngineDropdown.Items) % Default to first if field missing or invalid
                       app.EngineDropdown.Value = app.EngineDropdown.Items{1};
                  end
              end
         end

         function readUIDataIntoSequence(app)
             % Reads UI fields back into app.current_sequence properties
             app.current_sequence.sequence_id = strtrim(app.SequenceIDField.Value);
             app.current_sequence.description = strtrim(app.DescriptionField.Value);

             % Metadata (ensure struct exists)
              if ~isfield(app.current_sequence, 'metadata') || ~isstruct(app.current_sequence.metadata)
                  app.current_sequence.metadata = struct('created_by','','tags',{{}}); % Initialize if missing
              end
             app.current_sequence.metadata.created_by = strtrim(app.CreatedByField.Value);
             tags_str = strtrim(app.TagsField.Value);
             if ~isempty(tags_str)
                  tags_cell = strtrim(split(tags_str, {',',';'})); % Split by comma or semicolon
                  tags_cell = tags_cell(~cellfun('isempty', tags_cell)); % Remove empty elements
                  app.current_sequence.metadata.tags = unique(tags_cell,'stable'); % Store unique tags
             else
                  app.current_sequence.metadata.tags = {}; % Empty cell array if field is empty
             end

             % Global Settings
             app.current_sequence.global_settings.sampling_rate_hz = app.SamplingRateField.Value;
             % Read engine only if dropdown is enabled
             if strcmp(app.EngineDropdown.Enable, 'on')
                app.current_sequence.global_settings.engine_type = app.EngineDropdown.Value;
             elseif ~isfield(app.current_sequence.global_settings, 'engine_type')
                 % If disabled and no engine set, try setting a default if possible
                 if ~isempty(app.EngineDropdown.Items) && ~strcmp(app.EngineDropdown.Items{1}, 'No Engines Found')
                    app.current_sequence.global_settings.engine_type = app.EngineDropdown.Items{1};
                 else
                     app.current_sequence.global_settings.engine_type = ''; % Set empty if none available
                 end
             end
             % Note: engine_config is not edited in this GUI, keep existing value
             if ~isfield(app.current_sequence.global_settings, 'engine_config')
                 app.current_sequence.global_settings.engine_config = struct(); % Ensure it exists
             end
         end
    end % End methods
end % End classdef