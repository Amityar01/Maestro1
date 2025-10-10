% +hardware/play_block.m
function loopback_data = play_block(dq, ao_data, do_data)
% PLAY_BLOCK - Write and read data simultaneously using readwrite
%
% loopback_data = play_block(dq, ao_data, do_data)

fprintf('Starting hardware-timed playback and recording...\n');

% The 'readwrite' function is the standard way to perform a simultaneous,
% hardware-timed read and write. It is blocking, meaning it will wait
% until all data is played and recorded before returning.
% We provide the output data as a matrix [audio, ttl].
output_data = [ao_data, do_data];
[loopback_data, ~] = readwrite(dq, output_data);

fprintf('✓ Playback and recording complete.\n');
end