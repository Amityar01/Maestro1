% maestro2/generate_stimulus.m
function s = generate_stimulus(stim_type, params, fs)
% GENERATE_STIMULUS - Route to appropriate stimulus generator
%
% stim_type: string like 'tone', 'noise', 'pip_train', 'fm_sweep', 'looming_sound'
% params: struct with parameters (after resolve_parameters)
% fs: sample rate

% First resolve any randomized parameters
resolved_params = resolve_parameters(params);

% Then generate based on type
switch stim_type
    case 'tone'
        volts = db2volt(resolved_params.level_db);
        s = stim.make_tone(resolved_params.freq_hz, ...
                          resolved_params.dur_ms, ...
                          fs, volts, 5);
    
    case 'noise'
        volts = db2volt(resolved_params.level_db);
        s = stim.make_noise(resolved_params.dur_ms, ...
                           fs, volts, 5, []);
    
    case 'pip_train'
        volts = db2volt(resolved_params.level_db);
        s = stim.make_pip_train(resolved_params.freq_hz, ...
                               resolved_params.n_pips, ...
                               resolved_params.pip_dur_ms, ...
                               resolved_params.gap_ms, ...
                               fs, volts, 5);
    
    case 'fm_sweep'
        volts = db2volt(resolved_params.level_db);
        s = stim.make_fm_sweep(resolved_params.freq_start, ...
                              resolved_params.freq_end, ...
                              resolved_params.dur_ms, ...
                              resolved_params.sweep_type, ...
                              fs, volts, 5);

    case 'looming_sound'
        volts_start = db2volt(resolved_params.level_db_start);
        volts_end   = db2volt(resolved_params.level_db_end);
        
        if isfield(resolved_params, 'seed')
            seed = resolved_params.seed;
        else
            seed = [];
        end
        
        s = stim.make_looming_sound(resolved_params.dur_ms, ...
                                   fs, ...
                                   volts_start, ...
                                   volts_end, ...
                                   resolved_params.freq_min, ...
                                   resolved_params.freq_max, ...
                                   resolved_params.n_tones, ...
                                   5, ...
                                   seed);
    otherwise
        error('Unknown stimulus type: %s', stim_type);
end
end

function volts = db2volt(db_spl)
% DB2VOLT - Convert dB SPL to voltage using a calibrated reference.
% Assumes a reference: 100 dB SPL = 10 Volts (the DAQ's max output).

MAX_VOLTS = 10;
REF_DB = 100;

volts = MAX_VOLTS * 10^((db_spl - REF_DB) / 20);

if volts > MAX_VOLTS
    volts = MAX_VOLTS;
end
end