% +hardware/init_daq.m
function dq = init_daq(device_id, fs)
% INIT_DAQ - Initialize NI-DAQ session
%
% dq = init_daq(device_id, fs)

dq = daq("ni");
dq.Rate = fs;

% Add channels as specified in the design
addoutput(dq, device_id, "ao0", "Voltage"); % Audio
addoutput(dq, device_id, "port0/line0", "Digital"); % TTLs
addinput(dq, device_id, "ai0", "Voltage"); % Loopback

fprintf('✓ DAQ session created for %s at %d Hz.\n', device_id, fs);
end