classdef TransitionEditor < handle
    % TRANSITIONEDITOR - Modal dialog to edit block transitions
    %
    % Usage:
    %   editor = gui.sequences.TransitionEditor(parentFigure, currentTransition);
    %   uiwait(editor.UIFigure);
    %   if editor.WasSaved
    %       transition = editor.OutputTransition;
    %   end
    
    properties
        UIFigure
        
        % UI Components
        TypeDropdown
        DurationField
        MessageField
        DurationLabel
        MessageLabel
        
        % Output
        WasSaved = false
        OutputTransition
    end
    
    methods
        function app = TransitionEditor(parentFigure, currentTransition)
            % Constructor
            
            % Create figure
            app.UIFigure = uifigure('Name', 'Transition Editor', ...
                'WindowStyle', 'modal', ...
                'Position', [100 100 400 250]);
            
            % Center on parent
            if nargin >= 1 && ~isempty(parentFigure)
                centerfig(app.UIFigure, parentFigure);
            end
            
            % Create UI
            app.createComponents(currentTransition);
        end
        
function createComponents(app, currentTransition)
            % Create UI components
            
            mainGrid = uigridlayout(app.UIFigure, [5 2]);
            mainGrid.RowHeight = {30, 40, 40, '1x', 50};
            mainGrid.ColumnWidth = {120, '1x'};
            
            % --- FIX: Explicitly assign all uilabel handles ---
            % Type
            typeLabel = uilabel(mainGrid, 'Text', 'Transition Type:');
            app.TypeDropdown = uidropdown(mainGrid);
            app.TypeDropdown.Items = {'None', 'Delay', 'Button Press'};
            app.TypeDropdown.ItemsData = {'none', 'delay', 'button_press'};
            app.TypeDropdown.ValueChangedFcn = @(~,~) app.onTypeChanged();
            
            % Duration (for delay)
            app.DurationLabel = uilabel(mainGrid, 'Text', 'Duration (sec):');
            app.DurationField = uispinner(mainGrid);
            app.DurationField.Limits = [0 3600];
            app.DurationField.Value = 30;
            app.DurationField.Step = 5;
            
            % Message (for button press)
            app.MessageLabel = uilabel(mainGrid, 'Text', 'Message:');
            app.MessageField = uieditfield(mainGrid, 'text');
            app.MessageField.Value = 'Press ENTER to continue';
            
            % Spacer
            spacer1 = uilabel(mainGrid, 'Text', '');
            spacer2 = uilabel(mainGrid, 'Text', '');
            
            % Buttons
            buttonPanel = uipanel(mainGrid);
            buttonPanel.Layout.Column = [1 2];
            buttonGrid = uigridlayout(buttonPanel, [1 3]);
            buttonGrid.ColumnWidth = {'1x', 100, 100};
            
            spacer3 = uilabel(buttonGrid);
            
            uibutton(buttonGrid, 'Text', 'Cancel', ...
                'ButtonPushedFcn', @(~,~) app.onCancel());
            
            uibutton(buttonGrid, 'Text', 'OK', ...
                'ButtonPushedFcn', @(~,~) app.onOK(), ...
                'BackgroundColor', [0.3 0.7 0.3]);
            
            % Set initial values
            if nargin >= 2 && ~isempty(currentTransition)
                if isfield(currentTransition, 'type')
                    app.TypeDropdown.Value = currentTransition.type;
                    
                    switch currentTransition.type
                        case 'delay'
                            if isfield(currentTransition, 'duration_sec')
                                app.DurationField.Value = currentTransition.duration_sec;
                            end
                        case 'button_press'
                            if isfield(currentTransition, 'message')
                                app.MessageField.Value = currentTransition.message;
                            end
                    end
                end
            end
            
            % Update visibility
            app.onTypeChanged();
end

        function onTypeChanged(app)
            % Update field visibility based on type
            
            switch app.TypeDropdown.Value
                case 'none'
                    app.DurationLabel.Visible = 'off';
                    app.DurationField.Visible = 'off';
                    app.MessageLabel.Visible = 'off';
                    app.MessageField.Visible = 'off';
                    
                case 'delay'
                    app.DurationLabel.Visible = 'on';
                    app.DurationField.Visible = 'on';
                    app.MessageLabel.Visible = 'off';
                    app.MessageField.Visible = 'off';
                    
                case 'button_press'
                    app.DurationLabel.Visible = 'off';
                    app.DurationField.Visible = 'off';
                    app.MessageLabel.Visible = 'on';
                    app.MessageField.Visible = 'on';
            end
        end
        
        function onOK(app)
            % Save and close
            
            app.OutputTransition = struct();
            app.OutputTransition.type = app.TypeDropdown.Value;
            
            switch app.TypeDropdown.Value
                case 'delay'
                    app.OutputTransition.duration_sec = app.DurationField.Value;
                case 'button_press'
                    app.OutputTransition.message = app.MessageField.Value;
            end
            
            app.WasSaved = true;
            delete(app.UIFigure);
        end
        
        function onCancel(app)
            % Cancel and close
            app.WasSaved = false;
            delete(app.UIFigure);
        end
    end
end