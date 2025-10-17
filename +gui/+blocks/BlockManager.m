classdef BlockManager < handle
    % BLOCKMANAGER - GUI for managing block library

    properties
        UIFigure
        GridLayout

        % Left panel - Block list
        BlockListBox
        SearchField

        % Right panel - Details
        DetailsPanel
        BlockIDLabel
        BuilderTypeLabel
        DescriptionLabel
        ParametersText

        % Buttons
        NewButton
        EditButton
        DuplicateButton
        DeleteButton
        RefreshButton

        % Data
        context
        blocks
        selected_block
    end

    methods
        function app = BlockManager()
            % Constructor

            % Create Maestro context
            app.context = core.MaestroContext();

            % Create UI
            app.createComponents();

            % Load blocks
            app.refreshBlockList();
        end

        function createComponents(app)
            % Create UI components

            % Main figure
            app.UIFigure = uifigure('Name', 'Maestro Block Manager');
            app.UIFigure.Position = [100 100 800 600];

            % Main grid layout
            app.GridLayout = uigridlayout(app.UIFigure, [1 2]);
            app.GridLayout.ColumnWidth = {'1x', '2x'};

            % Left panel - Block list
            leftPanel = uipanel(app.GridLayout);
            leftPanel.Layout.Row = 1;
            leftPanel.Layout.Column = 1;
            leftLayout = uigridlayout(leftPanel, [4 1]);
            leftLayout.RowHeight = {30, 30, '1x', 150};

            % Search field
            searchLabel = uilabel(leftLayout, 'Text', 'Search:');
            searchLabel.Layout.Row = 1;
            searchLabel.Layout.Column = 1;

            app.SearchField = uieditfield(leftLayout, 'text');
            app.SearchField.Layout.Row = 2;
            app.SearchField.Layout.Column = 1;
            app.SearchField.ValueChangedFcn = @(src, event) app.filterBlocks();
            app.SearchField.Placeholder = 'Type to filter...';

            % Block list
            app.BlockListBox = uilistbox(leftLayout);
            app.BlockListBox.ValueChangedFcn = @(~,~) app.onBlockSelected();

            % Button panel
            buttonPanel = uipanel(leftLayout);
            buttonLayout = uigridlayout(buttonPanel, [5 1]);
            buttonLayout.RowHeight = {30, 30, 30, 30, 30};

            app.NewButton = uibutton(buttonLayout, 'Text', 'New Block');
            app.NewButton.ButtonPushedFcn = @(~,~) app.onNewBlock();

            app.EditButton = uibutton(buttonLayout, 'Text', 'Edit Block');
            app.EditButton.ButtonPushedFcn = @(~,~) app.onEditBlock();
            app.EditButton.Enable = 'off';

            app.DuplicateButton = uibutton(buttonLayout, 'Text', 'Duplicate');
            app.DuplicateButton.ButtonPushedFcn = @(~,~) app.onDuplicateBlock();
            app.DuplicateButton.Enable = 'off';

            app.DeleteButton = uibutton(buttonLayout, 'Text', 'Delete');
            app.DeleteButton.ButtonPushedFcn = @(~,~) app.onDeleteBlock();
            app.DeleteButton.Enable = 'off';

            app.RefreshButton = uibutton(buttonLayout, 'Text', 'Refresh');
            app.RefreshButton.ButtonPushedFcn = @(~,~) app.refreshBlockList();

            % Right panel - Details
            rightPanel = uipanel(app.GridLayout);
            rightPanel.Layout.Row = 1;
            rightPanel.Layout.Column = 2;
            rightPanel.Title = 'Block Details';
            rightLayout = uigridlayout(rightPanel, [5 1]);
            rightLayout.RowHeight = {30, 30, 60, 30, '1x'};

            app.BlockIDLabel = uilabel(rightLayout, 'Text', 'Block ID: -');
            app.BuilderTypeLabel = uilabel(rightLayout, 'Text', 'Builder: -');
            app.DescriptionLabel = uilabel(rightLayout, 'Text', 'Description: -');
            app.DescriptionLabel.WordWrap = 'on';

            uilabel(rightLayout, 'Text', 'Parameters:');

            app.ParametersText = uitextarea(rightLayout);
            app.ParametersText.Editable = 'off';
        end

        function refreshBlockList(app)
            % Refresh block list from library

            app.blocks = gui.blocks.block_utils.list_blocks();

            if isempty(app.blocks)
                app.BlockListBox.Items = {'(No blocks found)'};
                app.BlockListBox.ItemsData = {};
            else
                items = cell(1, length(app.blocks));
                for i = 1:length(app.blocks)
                    items{i} = sprintf('%s (%s)', ...
                        app.blocks{i}.block_id, ...
                        app.blocks{i}.builder_type);
                end
                app.BlockListBox.Items = items;
                app.BlockListBox.ItemsData = 1:length(app.blocks);
            end

            app.clearDetails();
        end

        function clearDetails(app)
            % Clear details panel

            app.BlockIDLabel.Text = 'Block ID: -';
            app.BuilderTypeLabel.Text = 'Builder: -';
            app.DescriptionLabel.Text = 'Description: -';
            app.ParametersText.Value = '';

            app.EditButton.Enable = 'off';
            app.DuplicateButton.Enable = 'off';
            app.DeleteButton.Enable = 'off';

            app.selected_block = [];
        end

        function filterBlocks(app)
            % Filter blocks based on search text

            search_text = strtrim(lower(app.SearchField.Value));

            fprintf('Search triggered: "%s"\n', search_text);

            % If empty, show all
            if isempty(search_text)
                app.refreshBlockList();
                return;
            end

            % Filter blocks
            filtered_indices = [];
            for i = 1:length(app.blocks)
                block = app.blocks{i};

                % Search in: block_id, builder_type, description
                id_match = contains(lower(block.block_id), search_text);
                builder_match = contains(lower(block.builder_type), search_text);
                desc_match = contains(lower(block.description), search_text);

                if id_match || builder_match || desc_match
                    filtered_indices(end+1) = i;
                    fprintf('  Match: %s (id:%d, builder:%d, desc:%d)\n', ...
                        block.block_id, id_match, builder_match, desc_match);
                end
            end

            fprintf('Found %d matches\n', length(filtered_indices));

            % Update list
            if isempty(filtered_indices)
                app.BlockListBox.Items = {'(No matches)'};
                app.BlockListBox.ItemsData = [];
            else
                items = cell(1, length(filtered_indices));
                for i = 1:length(filtered_indices)
                    idx = filtered_indices(i);
                    items{i} = sprintf('%s (%s)', ...
                        app.blocks{idx}.block_id, ...
                        app.blocks{idx}.builder_type);
                end
                app.BlockListBox.Items = items;
                app.BlockListBox.ItemsData = filtered_indices;
            end

            app.clearDetails();
        end

        function onBlockSelected(app)
            % Handle block selection

            if isempty(app.BlockListBox.Value)
                app.clearDetails();
                return;
            end

            try
                idx = app.BlockListBox.Value;
                app.selected_block = app.blocks{idx};

                % Load block details
                block = gui.blocks.block_utils.load_block(app.selected_block.file);

                % Update details panel
                app.BlockIDLabel.Text = sprintf('Block ID: %s', block.block_id);
                app.BuilderTypeLabel.Text = sprintf('Builder: %s', block.builder_type);

                if isfield(block, 'description')
                    app.DescriptionLabel.Text = sprintf('Description: %s', block.description);
                else
                    app.DescriptionLabel.Text = 'Description: -';
                end

                % Show parameters (formatted)
                param_text = gui.blocks.block_utils.format_parameters(block.parameters);
                app.ParametersText.Value = param_text;

                % Enable buttons
                app.EditButton.Enable = 'on';
                app.DuplicateButton.Enable = 'on';
                app.DeleteButton.Enable = 'on';

            catch ME
                uialert(app.UIFigure, ME.message, 'Error loading block');
            end
        end

        % In Maestro/+gui/+blocks/BlockManager.m

        function onNewBlock(app)
            % Create new block

            % Get available builders
            builder_names = keys(app.context.builders);

            if isempty(builder_names)
                uialert(app.UIFigure, 'No builders available', 'Error');
                return;
            end

            % Select builder type
            [selection, ok] = listdlg('ListString', builder_names, ...
                'SelectionMode', 'single', ...
                'Name', 'Select Builder Type', ...
                'PromptString', 'Choose a builder for the new block:');

            if ~ok
                return;
            end

            builder_type = builder_names{selection};

            % --- START FIX ---
            % Replace the uialert and TODO:
            % uialert(app.UIFigure, 'BlockEditor not yet implemented', 'Coming Soon');
            % TODO: gui.blocks.BlockEditor(app, builder_type, [], app.context);
            
            % Launch the editor you already wrote, passing 'app' as the parent
            gui.blocks.BlockEditor(app, builder_type, [], app.context);
            % --- END FIX ---
        end

        function onEditBlock(app)
            % Edit selected block

            if isempty(app.selected_block)
                return;
            end

            % Load block
            block = gui.blocks.block_utils.load_block(app.selected_block.file);

            % --- START FIX ---
            % Replace the uialert and TODO:
            % uialert(app.UIFigure, 'BlockEditor not yet implemented', 'Coming Soon');
            % TODO: gui.blocks.BlockEditor(app, block.builder_type, block, app.context);
            
            % Launch the editor, passing 'app' as the parent and the loaded block
            gui.blocks.BlockEditor(app, block.builder_type, block, app.context);
            % --- END FIX ---
        end

        function onDuplicateBlock(app)
            % Duplicate selected block

            if isempty(app.selected_block)
                return;
            end

            % Load block
            block = gui.blocks.block_utils.load_block(app.selected_block.file);

            % Prompt for new name
            new_id = inputdlg('Enter new block ID:', 'Duplicate Block', 1, ...
                {[block.block_id '_copy']});

            if isempty(new_id)
                return;
            end

            % Create duplicate
            block.block_id = new_id{1};
            block.created = datestr(now, 'yyyy-mm-ddTHH:MM:SS');

            % Save
            new_file = fullfile('library', 'blocks', [new_id{1} '.json']);
            gui.blocks.block_utils.save_block(block, new_file);

            % Refresh
            app.refreshBlockList();

            uialert(app.UIFigure, sprintf('Block duplicated as "%s"', new_id{1}), 'Success');
        end

        function onDeleteBlock(app)
            % Delete selected block

            if isempty(app.selected_block)
                return;
            end

            % Confirm
            answer = uiconfirm(app.UIFigure, ...
                sprintf('Delete block "%s"?', app.selected_block.block_id), ...
                'Confirm Delete', ...
                'Options', {'Delete', 'Cancel'}, ...
                'DefaultOption', 2);

            if strcmp(answer, 'Delete')
                delete(app.selected_block.file);
                app.refreshBlockList();
                uialert(app.UIFigure, 'Block deleted', 'Success');
            end
        end
    end
end