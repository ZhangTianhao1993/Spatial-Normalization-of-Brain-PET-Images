function onRefresh(fig)
%ROV.CALLBACKS.ONREFRESH  "Refresh Display" button callback.
%
% PURPOSE
%   Forces a full reload from disk using the current atlas/image file
%   selections. Useful after the user picks new files or externally
%   modifies a file.
%
% INPUT
%   fig : main uifigure handle.

    s = fig.UserData;
    if isempty(s.atlasNames) || isempty(s.atlasNames{1})
        rov.util.setStatus(fig, 'Please select an atlas file first.');
        return;
    end
    rov.io.loadData(fig);
end
