classdef unit_converter
    % Centralized unit conversion for all GUI components
    
    methods (Static)
        function display_value = to_display(storage_value, param_name, unit_type)
            % Convert from storage units to display units
            
            if strcmp(unit_type, 'ms') && endsWith(param_name, '_sec')
                % Storage: seconds, Display: milliseconds
                display_value = storage_value * 1000;
                
            elseif strcmp(unit_type, '%')
                % Storage: 0-1, Display: 0-100
                display_value = storage_value * 100;
                
            else
                % No conversion
                display_value = storage_value;
            end
        end
        
        function storage_value = to_storage(display_value, param_name, unit_type)
            % Convert from display units to storage units
            
            if strcmp(unit_type, 'ms') && endsWith(param_name, '_sec')
                % Display: milliseconds, Storage: seconds
                storage_value = display_value / 1000;
                
            elseif strcmp(unit_type, '%')
                % Display: 0-100, Storage: 0-1
                storage_value = display_value / 100;
                
            else
                % No conversion
                storage_value = display_value;
            end
        end
        
        function unit_type = get_unit_type(param_spec)
            % Extract unit type from parameter spec
            
            unit_type = '';
            
            if isfield(param_spec, 'ui_hints') && isfield(param_spec.ui_hints, 'unit')
                unit_type = param_spec.ui_hints.unit;
            elseif isfield(param_spec, 'unit')
                unit_type = param_spec.unit;
            end
        end
    end
end