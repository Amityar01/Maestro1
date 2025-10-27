% DEMO_CONTEXT - Demonstrate MaestroContext usage
%
% This shows how to use the core system

fprintf('\n');
fprintf('Maestro Context Demo\n');
fprintf('════════════════════════════════════════════════\n\n');

% Create context
fprintf('Creating MaestroContext...\n');
ctx = core.MaestroContext();

fprintf('\nCurrent status:\n');
fprintf('  Generators: %d\n', length(ctx.generators));
fprintf('  Builders:   %d\n', length(ctx.builders));
fprintf('  Engines:    %d\n', length(ctx.engines));

% Show what methods are available
fprintf('\nAvailable methods:\n');
methods(ctx)

fprintf('\n');
fprintf('Context is ready! Add some plugins to see them discovered.\n');
fprintf('\n');
