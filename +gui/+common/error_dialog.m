classdef error_dialog
    % Utility class for showing consistent error and validation dialogs.

    methods (Static)
        function show_validation_errors(parent_fig, errors, title)
            % Shows validation errors in a formatted dialog.
            % If 'errors' is empty, it shows a success message.

            if nargin < 3
                title = 'Validation Result';
            end

            if isempty(errors)
                 uialert(parent_fig, 'Validation passed!', title, 'Icon', 'success', 'Modal', false);
                return;
            end

            % Format errors nicely
            msg = sprintf('Found %d validation error(s):\n\n', length(errors));
            for i = 1:min(10, length(errors))  % Show max 10
                msg = sprintf('%s• %s\n', msg, errors{i});
            end

            if length(errors) > 10
                msg = sprintf('%s\n... and %d more.', msg, length(errors) - 10);
            end

            uialert(parent_fig, msg, title, 'Icon', 'error');
        end

        function show_save_error(parent_fig, ME)
            % Shows a detailed error dialog for file saving operations.
            msg = sprintf('Failed to save file:\n\n%s\n\n', ME.message);
            msg = [msg, sprintf('Common causes:\n• File is open in another program\n• Insufficient permissions\n• Invalid filename or path')];
            uialert(parent_fig, msg, 'Save Failed', 'Icon', 'error');
        end

        function show_load_error(parent_fig, ME, filename)
            % Shows a detailed error dialog for file loading operations.
            if nargin < 3
                filename = 'the file';
            end
            msg = sprintf('Failed to load %s:\n\n%s', filename, ME.message);
            uialert(parent_fig, msg, 'Load Failed', 'Icon', 'error');
        end

        function show_general_error(parent_fig, ME, title)
            % Shows a generic error dialog for other exceptions.
            if nargin < 3
                title = 'An Error Occurred';
            end
            msg = sprintf('An unexpected error occurred:\n\n%s', ME.message);
            uialert(parent_fig, msg, title, 'Icon', 'error');
        end
    end
end