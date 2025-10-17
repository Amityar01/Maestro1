function fix_block_units()
    % Fix ITI units in existing blocks
    
    fprintf('Checking and fixing block ITI units...\n');
    fprintf('════════════════════════════════════════\n\n');
    
    blocks_dir = 'library/blocks';
    files = dir(fullfile(blocks_dir, '*.json'));
    
    fixed_count = 0;
    
    for i = 1:length(files)
        filepath = fullfile(files(i).folder, files(i).name);
        
        try
            % Load block
            block = gui.blocks.block_utils.load_block(filepath);
            
            % Check if it has iti_sec parameter
            if ~isfield(block.parameters, 'iti_sec')
                continue;
            end
            
            iti = block.parameters.iti_sec;
            needs_fix = false;
            
            % Check if ITI seems wrong (>10 seconds is suspicious)
            if isscalar(iti) && iti > 10
                fprintf('Block: %s\n', block.block_id);
                fprintf('  Current ITI: %.1f sec (%.1f min)\n', iti, iti/60);
                fprintf('  Assuming this should be: %.3f sec (was in ms)\n', iti/1000);
                block.parameters.iti_sec = iti / 1000;
                needs_fix = true;
                
            elseif isvector(iti) && length(iti) == 2
                if any(iti > 10)
                    fprintf('Block: %s\n', block.block_id);
                    fprintf('  Current ITI: [%.1f, %.1f] sec\n', iti(1), iti(2));
                    fprintf('  Assuming this should be: [%.3f, %.3f] sec\n', iti(1)/1000, iti(2)/1000);
                    block.parameters.iti_sec = iti / 1000;
                    needs_fix = true;
                end
            end
            
            % Save if fixed
            if needs_fix
                % Backup original
                backup_file = [filepath '.backup'];
                copyfile(filepath, backup_file);
                fprintf('  ✓ Backup saved: %s\n', backup_file);
                
                % Save fixed version
                gui.blocks.block_utils.save_block(block, filepath);
                fprintf('  ✓ Fixed and saved\n\n');
                fixed_count = fixed_count + 1;
            end
            
        catch ME
            fprintf('  ✗ Error processing %s: %s\n\n', files(i).name, ME.message);
        end
    end
    
    fprintf('════════════════════════════════════════\n');
    fprintf('Fixed %d block(s)\n', fixed_count);
    fprintf('Backups saved as *.json.backup\n\n');
end