function setup_path()
% SETUP_PATH   Add all necessary folders (excluding package folders) to MATLAB path
%   Run this script once to correctly set up the MATLAB search path for the SNBPI program.

% Get the directory where this script is located
scriptPath = fileparts(mfilename('fullpath'));
snbpiPath = fullfile(scriptPath, 'SNBPI');   % Assume SNBPI folder is in the same directory as this script

if ~exist(snbpiPath, 'dir')
    error('SNBPI folder not found. Please ensure this script is placed in the same directory as the SNBPI folder.');
end

% Add the root folder (optional)
addpath(snbpiPath);

% Get all subfolder paths
allSubPaths = strsplit(genpath(snbpiPath), pathsep);

for i = 1:length(allSubPaths)
    p = allSubPaths{i};
    if isempty(p)
        continue;
    end
    % Skip any folder that contains a '+', i.e., package folders and their subfolders
    if contains(p, [filesep '+'])
        continue;
    end
    addpath(p);
end

% Save the path permanently (overwrites previous path settings)
try
    savepath;
    disp('Path setup complete. The path has been saved permanently.');
catch ME
    warning('Path setup complete, but could not save the path permanently. You may need to run "savepath" manually or check file permissions.');
end

end