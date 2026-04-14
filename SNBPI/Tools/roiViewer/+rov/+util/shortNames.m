function items = shortNames(paths)
%ROV.UTIL.SHORTNAMES  Convert a cell array of paths to basenames.
%
% PURPOSE
%   Helper for populating the left-panel listboxes with just the file
%   name (plus extension), stripping the directory.
%
% INPUT
%   paths : cell array of char vectors, possibly empty.
%
% OUTPUT
%   items : cell array of char vectors, one per input.
%
% EXAMPLE
%   items = rov.util.shortNames({'/home/me/AAL.nii'});
%   % -> {'AAL.nii'}

    if isempty(paths)
        items = {};
        return;
    end
    items = cell(numel(paths), 1);
    for k = 1:numel(paths)
        [~, n, e] = fileparts(paths{k});
        items{k}  = [n, e];
    end
end
