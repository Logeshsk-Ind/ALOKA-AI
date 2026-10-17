function setupALOKAPath()
% Automatically adds all ALOKA-AI integration folders.
root = fileparts(mfilename('fullpath'));
addpath(genpath(root));
fprintf('ALOKA-AI integration path loaded.\n');
end
