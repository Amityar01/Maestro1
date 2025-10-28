classdef ui_factory
    % ui_factory - Creates specific UI controls based on parameter metadata.
    methods (Static)
        function control = create_control(parent, param_name, param_meta, value, position)
            % Creates a label and an appropriate input control (e.g., spinner, edit field).
            % Returns the created input control (not the label).

            label_text = param_meta.label;
            if isfield(param_meta, 'units')
                label_text = [label_text ' (' param_meta.units ')'];
            end

            uilabel(parent, 'Text', label_text, 'Position', [position(1), position(2), 200, 22]);

            control_type = param_meta.control;

            switch control_type
                case 'spinner'
                    control = uispinner(parent, ...
                        'Value', value, ...
                        'Position', [position(1) + 210, position(2), 150, 22], ...
                        'Step', param_meta.step, ...
                        'Limits', param_meta.range);
                case 'numeric_edit'
                    control = uieditfield(parent, 'numeric', ...
                        'Value', value, ...
                        'Position', [position(1) + 210, position(2), 150, 22]);
                otherwise
                    control = uieditfield(parent, 'text', ...
                        'Value', num2str(value), ...
                        'Position', [position(1) + 210, position(2), 150, 22]);
            end
            % More control types (dropdown, checkbox, slider) can be added here.
        end
    end
end
