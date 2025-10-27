classdef SchemaValidator
    % Applies a builder schema: aliases, defaults, required, enums, types.
    % Stimulus specs are resolved using core.validation.StimulusResolver.

    methods (Static)
        function [instance, report] = validate_and_normalize(schema, instance, context, maestroRoot)
            report = struct('applied_aliases',[], 'applied_defaults',[], 'notes',[]);
            if ~isfield(instance,'parameters') || ~isstruct(instance.parameters) || isempty(instance.parameters)
                instance.parameters = struct();
            end
            P = instance.parameters;

            % ---------- aliases ----------
            if isfield(schema,'parameters') && isfield(schema.parameters,'aliases')
                aliases = schema.parameters.aliases;
                f = fieldnames(aliases);
                for i = 1:numel(f)
                    from = f{i};
                    to   = char(aliases.(from));
                    if ~isfield(P,to) || isempty(P.(to))
                        if isfield(P,from) && ~isempty(P.(from))
                            P.(to) = P.(from);
                            report.applied_aliases{end+1} = sprintf('%s -> %s', from, to); %#ok<AGROW>
                        end
                    end
                end
            end

            % ---------- defaults ----------
            if isfield(schema,'parameters') && isfield(schema.parameters,'defaults')
                defs = schema.parameters.defaults;
                df = fieldnames(defs);
                for i = 1:numel(df)
                    k = df{i};
                    if ~isfield(P,k) || isempty(P.(k))
                        P.(k) = defs.(k);
                        report.applied_defaults{end+1} = k; %#ok<AGROW>
                    end
                end
            end

            % ---------- types ----------
            if isfield(schema,'parameters') && isfield(schema.parameters,'types')
                types = schema.parameters.types;
                tf = fieldnames(types);
                for i = 1:numel(tf)
                    key = tf{i}; want = char(types.(key));
                    if isfield(P,key) && ~isempty(P.(key))
                        switch want
                            case 'scalar_numeric'
                                v = P.(key);
                                assert(isnumeric(v) && isscalar(v), ...
                                    'SchemaValidator:Type','%s must be scalar numeric', key);
                            case 'logical'
                                v = P.(key);
                                assert(islogical(v) && isscalar(v), ...
                                    'SchemaValidator:Type','%s must be scalar logical', key);
                            case 'stimulus_spec'
                                v = P.(key);
                                P.(key) = core.validation.StimulusResolver.resolve(v, maestroRoot);
                            otherwise
                                % extend with more kinds as needed
                        end
                    end
                end
            end

            % ---------- enums ----------
            if isfield(schema,'parameters') && isfield(schema.parameters,'enums')
                enums = schema.parameters.enums;
                ef = fieldnames(enums);
                for i = 1:numel(ef)
                    key = ef{i};
                    if isfield(P,key) && ~isempty(P.(key))
                        allowed = cellfun(@char, cellstr(enums.(key)), 'UniformOutput', false);
                        val = char(P.(key));
                        assert(any(strcmp(val, allowed)), ...
                            'SchemaValidator:Enum','%s must be one of: %s', key, strjoin(allowed, ', '));
                    end
                end
            end

            % ---------- required ----------
            if isfield(schema,'parameters') && isfield(schema.parameters,'required')
                req = schema.parameters.required;
                for i = 1:numel(req)
                    k = char(req{i});
                    assert(isfield(P,k) && ~isempty(P.(k)), ...
                        'SchemaValidator:Required','Missing required parameter "%s"', k);
                end
            end

            % ---------- done ----------
            instance.parameters = P;
        end
    end
end
