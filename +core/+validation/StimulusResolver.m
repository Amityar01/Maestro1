classdef StimulusResolver
    % Resolves "stimulus_spec" values:
    %  - If it's already a struct -> return as-is.
    %  - If it's a string:
    %      * if an existing file -> load JSON and return struct
    %      * else, try library/stimuli/<name>.json
    %      * else, leave as string (up to builder/engine to handle)

    methods (Static)
        function spec = resolve(val, maestroRoot)
            if isstruct(val)
                spec = val; return;
            end
            if isstring(val) || ischar(val)
                s = char(val);
                if isfile(s)
                    spec = jsondecode(fileread(s)); return;
                end
                cand = fullfile(maestroRoot, 'library', 'stimuli', s);
                if isfile(cand)
                    spec = jsondecode(fileread(cand)); return;
                end
                cand2 = fullfile(maestroRoot, 'library', 'stimuli', [s '.json']);
                if isfile(cand2)
                    spec = jsondecode(fileread(cand2)); return;
                end
                % fallback: keep string; builder/engine may accept reference by name
                spec = s; return;
            end
            % unknown type; return as-is
            spec = val;
        end
    end
end
