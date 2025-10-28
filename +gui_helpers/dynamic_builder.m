classdef dynamic_builder
    % dynamic_builder - The core logic for assembling the GUI dynamically.
    methods (Static)
        function templateSelectedCallback(fig, source)
            % This function now has extensive logging to expose hidden errors.
            % (FIXED) It now receives the main figure handle 'fig' directly.
            
            fprintf('\n--- Template Selection Changed ---\n');
            
            try
                % (FIXED) Get handles directly from the figure's UserData.
                handles = fig.UserData;
                
                fprintf('  1. Clearing old UI controls...\n');
                delete(handles.editor_panel.Children);
                
                fprintf('  2. Reading selected template file...\n');
                selected_name = source.Value;
                selected_idx = find(strcmp(source.Items, selected_name));
                if isempty(selected_idx), fprintf('   -> No template selected.\n'); return; end
                template_path = source.UserData.files{selected_idx};
                template_config = jsondecode(fileread(template_path));

                % Store template config in handles for later use by config_manager
                handles.current_template_config = template_config;
                handles.control_map = containers.Map(); % Map from control -> config path
                
                builder_name = template_config.builder;
                fprintf('  3. Finding required builder: "%s"\n', builder_name);
                if ~isKey(handles.builders, builder_name)
                    uialert(handles.fig, ['Builder "' builder_name '" not found.'], 'Error');
                    return;
                end
                builder_meta = handles.builders(builder_name);
                
                fprintf('  4. Building UI for Trial-Level Parameters...\n');
                y_pos = 1000; 

                uilabel(handles.editor_panel, 'Text', 'Trial Parameters', 'Position', [10 y_pos 460 22], 'FontSize', 14, 'FontWeight', 'bold');
                y_pos = y_pos - 30;
                
                param_fields = fields(builder_meta.parameters);
                for i = 1:numel(param_fields)
                    param_name = param_fields{i};
                    fprintf('     -> Creating control for trial param: %s\n', param_name);
                    param_meta = builder_meta.parameters.(param_name);
                    
                    if isfield(template_config.trial_params, param_name)
                        value = template_config.trial_params.(param_name);
                    else
                        value = param_meta.default;
                    end
                    
                    control = gui_helpers.ui_factory.create_control(handles.editor_panel, param_name, param_meta, value, [20 y_pos]);
                    if ~isempty(control)
                        % Store mapping: control -> config path
                        config_path = ['trial_params.' param_name];
                        handles.control_map(num2str(length(handles.control_map)+1)) = struct('control', control, 'path', config_path);
                    end
                    y_pos = y_pos - 35;
                end
                
                y_pos = y_pos - 15;
                
                fprintf('  5. Building UI for Stimulus Slots...\n');
                stim_slots = fields(builder_meta.stimulus_slots);
                for i = 1:numel(stim_slots)
                    slot_name = stim_slots{i};
                    fprintf('     -> Processing slot: %s\n', slot_name);
                    
                    uilabel(handles.editor_panel, 'Text', ['Stimulus: ' slot_name], 'Position', [10 y_pos 460 22], 'FontSize', 14, 'FontWeight', 'bold');
                    y_pos = y_pos - 30;

                    stim_name = template_config.stimuli.(slot_name).name;
                    fprintf('       -> Finding stimulus: "%s"\n', stim_name);
                    
                    if ~isKey(handles.stimuli, stim_name)
                        uialert(handles.fig, ['Stimulus "' stim_name '" not found.'], 'Error');
                        continue;
                    end
                    stim_meta = handles.stimuli(stim_name);
                    
                    stim_param_fields = fields(stim_meta.parameters);
                    for j = 1:numel(stim_param_fields)
                        param_name = stim_param_fields{j};
                        fprintf('         -> Creating control for stim param: %s\n', param_name);
                        param_meta = stim_meta.parameters.(param_name);
                        
                        if isfield(template_config.stimuli.(slot_name).params, param_name)
                            value = template_config.stimuli.(slot_name).params.(param_name);
                        else
                            value = param_meta.default;
                        end
                        
                        control = gui_helpers.ui_factory.create_control(handles.editor_panel, param_name, param_meta, value, [20 y_pos]);
                        if ~isempty(control)
                            % Store mapping: control -> config path
                            config_path = ['stimuli.' slot_name '.params.' param_name];
                            handles.control_map(num2str(length(handles.control_map)+1)) = struct('control', control, 'path', config_path);
                        end
                        y_pos = y_pos - 35;
                    end
                    y_pos = y_pos - 15;
                end

                % Save updated handles back to figure
                fig.UserData = handles;

                fprintf('--- UI Build Complete ---\n');

            catch ME
                fprintf(2, '!!! ERROR BUILDING UI !!!\n');
                fprintf(2, 'Error in ==> %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
                fprintf(2, 'Message: %s\n', ME.message);
                errordlg(['An error occurred while building the editor: ' ME.message], 'UI Build Failed');
            end
        end
    end
end

