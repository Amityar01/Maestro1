classdef BlockManager < handle
    % BLOCKMANAGER - GUI for managing the block library.

    properties
        UIFigure
        GridLayout
        
        % Left Panel
        BlockListBox
        SearchField
        
        % Right Panel
        DetailsPanel
        BlockIDLabel
        BuilderTypeLabel
        DescriptionLabel
        MetadataLabel
        ParametersText
        
        % Buttons
        NewButton
        EditButton
        DuplicateButton
        DeleteButton
        RefreshButton

        % Data
        context
        all_blocks          % Cell array of structs from block_utils.list_blocks
        selected_block_info % The info struct for the currently selected block
    end

    methods
        function app = BlockManager(parentContext)
            % CONSTRUCTOR
            if nargin < 1 || isempty(parentContext)
                 app.context = core.MaestroContext();
            else
                 app.context = parentContext; % Allow passing in an existing context
            end
            
            app.all_blocks = {}; % Initialize as an empty cell
            
            % Create UI and then load data
            app.createComponents();
            app.refreshBlockList(); % Initial load
        end

  function createComponents(app)
            % Create UI components
            app.UIFigure = uifigure('Name', 'Maestro Block Manager', 'Position', [100 100 900 600]); % Increased width slightly
            app.GridLayout = uigridlayout(app.UIFigure, [1 2]);
            app.GridLayout.ColumnWidth = {'1x', '2x'};

            % --- Left Panel (List & Buttons) ---
            leftPanel = uipanel(app.GridLayout);
            leftPanel.Layout.Column = 1;
            leftLayout = uigridlayout(leftPanel, [3 1]);
            leftLayout.RowHeight = {30, '1x', 'fit'}; % Fit button panel height

            % Search Area
            searchGrid = uigridlayout(leftLayout, [1 2]);
            searchGrid.ColumnWidth = {'fit', '1x'};
            searchGrid.Padding = [0 0 0 0];

            searchLabel = uilabel(searchGrid, 'Text', 'Search:');
            searchLabel.Layout.Row = 1; searchLabel.Layout.Column = 1;

            app.SearchField = uieditfield(searchGrid, 'text', 'Placeholder', 'Filter by ID, builder, desc, tags...');
            app.SearchField.ValueChangedFcn = @(~,~) app.filterBlocks();
            app.SearchField.Layout.Row = 1; app.SearchField.Layout.Column = 2;

            % Block List
            app.BlockListBox = uilistbox(leftLayout);
            app.BlockListBox.Layout.Row = 2;
            app.BlockListBox.ValueChangedFcn = @(~,~) app.onBlockSelected();

            % Button Panel
            buttonPanel = uipanel(leftLayout);
            buttonPanel.Layout.Row = 3;
            buttonLayout = uigridlayout(buttonPanel, [5 1]); % 5 rows, 1 column

            % --- FIX: Change RowHeight from {30} to 'fit' ---
            buttonLayout.RowHeight = {'fit'}; % Auto-adjust row height based on button content
            % --- END FIX ---

            app.NewButton = uibutton(buttonLayout, 'Text', 'New Block...', 'ButtonPushedFcn', @(~,~) app.onNewBlock());
            app.EditButton = uibutton(buttonLayout, 'Text', 'Edit Block...', 'ButtonPushedFcn', @(~,~) app.onEditBlock(), 'Enable', 'off');
            app.DuplicateButton = uibutton(buttonLayout, 'Text', 'Duplicate...', 'ButtonPushedFcn', @(~,~) app.onDuplicateBlock(), 'Enable', 'off');
            app.DeleteButton = uibutton(buttonLayout, 'Text', 'Delete', 'ButtonPushedFcn', @(~,~) app.onDeleteBlock(), 'Enable', 'off');
            app.RefreshButton = uibutton(buttonLayout, 'Text', 'Refresh List', 'ButtonPushedFcn', @(~,~) app.refreshBlockList());

            % --- Right Panel (Details) ---
            app.DetailsPanel = uipanel(app.GridLayout, 'Title', 'Block Details');
            app.DetailsPanel.Layout.Column = 2;
            rightLayout = uigridlayout(app.DetailsPanel, [6 1]);
            rightLayout.RowHeight = {30, 30, 'fit', 'fit', 30, '1x'};

            app.BlockIDLabel = uilabel(rightLayout, 'Text', 'Block ID: -', 'FontWeight', 'bold');
            app.BuilderTypeLabel = uilabel(rightLayout, 'Text', 'Builder: -');
            app.DescriptionLabel = uilabel(rightLayout, 'Text', 'Description: -', 'WordWrap', 'on');

            app.MetadataLabel = uilabel(rightLayout, 'Text', 'Metadata: -', 'WordWrap', 'on');
            app.MetadataLabel.Layout.Row = 4;

            paramsLabel = uilabel(rightLayout, 'Text', 'Parameters:', 'FontWeight', 'bold');
            paramsLabel.Layout.Row = 5;

            app.ParametersText = uitextarea(rightLayout, 'Editable', 'off', 'WordWrap', 'on');
            app.ParametersText.Layout.Row = 6;
        end

        function refreshBlockList(app)
            % Reloads the complete list of blocks from the library directory.
            try
                app.all_blocks = gui.blocks.block_utils.list_blocks();
                app.filterBlocks(); % This will update the UI listbox
                app.clearDetails();
            catch ME
                 gui.common.error_dialog.show_general_error(app.UIFigure, ME, 'Error Listing Blocks');
            end
        end

        function filterBlocks(app)
            % Filters the UI listbox based on search text, without re-reading from disk.
            search_text = lower(strtrim(app.SearchField.Value));
            filtered_indices = []; % Indices into app.all_blocks

            for i = 1:length(app.all_blocks)
                block = app.all_blocks{i};
                if isempty(search_text) || ...
                   contains(lower(block.block_id), search_text) || ...
                   contains(lower(block.builder_type), search_text) || ...
                   contains(lower(block.description), search_text) || ...
                   contains(lower(block.metadata_summary), search_text)
                    filtered_indices(end+1) = i;
                end
            end

            if isempty(filtered_indices)
                app.BlockListBox.Items = {'(No blocks found or match filter)'};
                app.BlockListBox.ItemsData = [];
            else
                items = cell(1, length(filtered_indices));
                for i = 1:length(filtered_indices)
                      idx = filtered_indices(i);
                      block = app.all_blocks{idx};
                      items{i} = sprintf('%s (%s)', block.block_id, block.builder_type);
                      if ~isempty(block.metadata_summary)
                          items{i} = [items{i} ' | ' block.metadata_summary];
                      end
                end
                app.BlockListBox.Items = items;
                app.BlockListBox.ItemsData = filtered_indices;
            end
             app.BlockListBox.Value = {}; % Clear selection
             app.clearDetails();
        end

        function clearDetails(app)
            % Clears the details panel and disables action buttons.
            app.BlockIDLabel.Text = 'Block ID: -';
            app.BuilderTypeLabel.Text = 'Builder: -';
            app.DescriptionLabel.Text = 'Description: -';
            app.MetadataLabel.Text = 'Metadata: -';
            app.ParametersText.Value = '';
            app.EditButton.Enable = 'off';
            app.DuplicateButton.Enable = 'off';
            app.DeleteButton.Enable = 'off';
            app.selected_block_info = [];
        end

        function onBlockSelected(app)
            % Handles selection change in the block listbox.
            if isempty(app.BlockListBox.ItemsData) || isempty(app.BlockListBox.Value)
                app.clearDetails();
                return;
            end

            try
                % The Value of the listbox is the index into its ItemsData array
                selectedIndex = app.BlockListBox.Value;
                originalIndex = app.BlockListBox.ItemsData(selectedIndex);
                app.selected_block_info = app.all_blocks{originalIndex};

                full_block_data = gui.blocks.block_utils.load_block(app.selected_block_info.file);

                % Update details panel UI
                app.BlockIDLabel.Text = sprintf('Block ID: %s', full_block_data.block_id);
                app.BuilderTypeLabel.Text = sprintf('Builder: %s', full_block_data.builder_type);
                desc = '-';
                if isfield(full_block_data, 'description') && ~isempty(full_block_data.description)
                    desc = full_block_data.description;
                end
                app.DescriptionLabel.Text = sprintf('Description: %s', desc);

                 meta_parts = {};
                 if isfield(full_block_data, 'metadata')
                     if isfield(full_block_data.metadata, 'created_by') && ~isempty(full_block_data.metadata.created_by)
                         meta_parts{end+1} = ['Created By: ' full_block_data.metadata.created_by];
                     end
                      if isfield(full_block_data.metadata, 'tags') && ~isempty(full_block_data.metadata.tags)
                         meta_parts{end+1} = ['Tags: ' strjoin(full_block_data.metadata.tags, ', ')];
                     end
                 end
                  if isfield(full_block_data, 'created'), meta_parts{end+1} = ['Created: ' full_block_data.created]; end
                  if isfield(full_block_data, 'modified'), meta_parts{end+1} = ['Modified: ' full_block_data.modified]; end
                 if isempty(meta_parts)
                      app.MetadataLabel.Text = 'Metadata: -';
                 else
                     app.MetadataLabel.Text = ['Metadata: ' strjoin(meta_parts, ' | ')];
                 end

                param_text = gui.blocks.block_utils.format_parameters(full_block_data.parameters);
                app.ParametersText.Value = param_text;

                app.EditButton.Enable = 'on';
                app.DuplicateButton.Enable = 'on';
                app.DeleteButton.Enable = 'on';
            catch ME
                 gui.common.error_dialog.show_load_error(app.UIFigure, ME, app.selected_block_info.name);
                 app.clearDetails();
            end
        end

        function onNewBlock(app)
            % Opens the BlockEditor for a new block.
            builder_names = keys(app.context.builders);
            if isempty(builder_names)
                uialert(app.UIFigure, 'No builders available to create a new block.', 'Error'); return;
            end
            
            [selectionIdx, ok] = listdlg('ListString', sort(builder_names), 'SelectionMode', 'single', ...
                'Name', 'Select Builder Type', 'PromptString', 'Choose a builder:');
            if ~ok; return; end

            sorted_names = sort(builder_names);
            builder_type = sorted_names{selectionIdx};
            
            gui.blocks.BlockEditor(app, builder_type, [], app.context);
        end

        function onEditBlock(app)
            % Opens the BlockEditor for the selected block.
            if isempty(app.selected_block_info); return; end
            gui.blocks.BlockEditor(app, app.selected_block_info.builder_type, app.selected_block_info, app.context);
        end

         function onDuplicateBlock(app)
             % Duplicates the selected block under a new name.
             if isempty(app.selected_block_info); return; end

             try
                 original_block = gui.blocks.block_utils.load_block(app.selected_block_info.file);

                 new_id_base = [original_block.block_id '_copy'];
                 new_id = inputdlg('Enter new unique block ID:', 'Duplicate Block', [1 60], {new_id_base});
                 if isempty(new_id) || isempty(new_id{1}); return; end
                 
                 new_id = matlab.lang.makeValidName(strtrim(new_id{1}));
                 
                 new_filename = [new_id core.config.BLOCK_EXTENSION];
                 new_filepath = core.config.get_block_path(new_filename);
                 if exist(new_filepath, 'file')
                      uialert(app.UIFigure, sprintf('A block with ID "%s" already exists. Choose a different ID.', new_id), 'Duplicate Failed'); return;
                 end

                 duplicated_block = original_block;
                 duplicated_block.block_id = new_id;
                 duplicated_block.created = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
                 duplicated_block.modified = duplicated_block.created;
                 duplicated_block.metadata.created_by = ''; % Clear creator

                 gui.blocks.block_utils.save_block(duplicated_block, new_filepath);
                 app.refreshBlockList();
                 uialert(app.UIFigure, sprintf('Block duplicated as "%s"', new_id), 'Success', 'Icon','success');

             catch ME
                  gui.common.error_dialog.show_general_error(app.UIFigure, ME, 'Duplicate Error');
             end
         end

        function onDeleteBlock(app)
            % Deletes the selected block after confirmation.
            if isempty(app.selected_block_info); return; end

            answer = uiconfirm(app.UIFigure, ...
                sprintf('Permanently delete block "%s"?\n(%s)', app.selected_block_info.block_id, app.selected_block_info.name), ...
                'Confirm Delete', ...
                'Options', {'Delete', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');

            if strcmp(answer, 'Delete')
                try
                     filepath_to_delete = app.selected_block_info.file;
                     if exist(filepath_to_delete, 'file')
                        delete(filepath_to_delete);
                        app.refreshBlockList();
                        uialert(app.UIFigure, sprintf('Block "%s" deleted.', app.selected_block_info.block_id), 'Delete Successful','Icon','success');
                     else
                          uialert(app.UIFigure, 'File not found. Already deleted?', 'Delete Error', 'Icon', 'warning');
                          app.refreshBlockList();
                     end
                catch ME
                     gui.common.error_dialog.show_general_error(app.UIFigure, ME, 'Delete Error');
                end
            end
        end
    end
end