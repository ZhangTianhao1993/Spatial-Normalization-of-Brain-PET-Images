function labels = tryLoadAtlasLabels(atlasPath)
%ROV.IO.TRYLOADATLASLABELS  Load <atlasBase>_Labels.mat next to an atlas file.
%
% PURPOSE
%   Convention: if the user picks e.g. 'AAL.nii', the viewer looks for
%   'AAL_Labels.mat' in the same folder and loads the variable
%   `Labels` (expected to be an n x 2 cell of {name, value}). If no
%   such file is found or the contents are not the expected shape,
%   an empty cell is returned without error.
%
% INPUT
%   atlasPath : char or string, full path to an atlas file.
%
% OUTPUT
%   labels : n x 2 cell {name(char), value(numeric)} on success,
%            {} otherwise.
%
% EXAMPLE
%   L = rov.io.tryLoadAtlasLabels('/data/AAL.nii');

    labels = {};
    if isempty(atlasPath)
        return;
    end
    if ~ischar(atlasPath) && ~isstring(atlasPath)
        return;
    end

    [pth, name, ~] = fileparts(char(atlasPath));
    candidate      = fullfile(pth, [name '_Labels.mat']);
    if exist(candidate, 'file') ~= 2, return; end

    try
        data = load(candidate);
        if isfield(data, 'Labels')
            L = data.Labels;
            if iscell(L) && size(L, 2) >= 2
                for k = 1:size(L, 1)
                    if isstring(L{k,1}), L{k,1} = char(L{k,1}); end
                end
                labels = L;
            end
        end
    catch
        labels = {};
    end
end
