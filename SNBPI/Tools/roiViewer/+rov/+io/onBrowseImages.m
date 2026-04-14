function onBrowseImages(fig)
%ROV.IO.ONBROWSEIMAGES  "Select Brain Images..." button callback.
%
% PURPOSE
%   Opens a multi-select native file dialog restricted to NIfTI/Analyze
%   files. Selected paths are stored (as full paths) into
%   fig.UserData.imageNames and the left-panel listbox is refreshed.
%
% INPUT
%   fig : main uifigure handle.
%
% BEHAVIOUR
%   - User cancel: state unchanged.
%   - Single file: wrapped into a 1-cell for consistency.
%   - Calls bringToFront afterwards since the native dialog may leave
%     the uifigure behind other windows.
%
% EXAMPLE
%   Bound to the "Select Brain Images..." button in the left panel.

    [fnames, fpath] = uigetfile( ...
        {'*.nii;*.img','NIfTI / Analyze (*.nii,*.img)'; '*.*','All files'}, ...
        'Select Brain Image(s)', 'MultiSelect','on');
    rov.util.bringToFront(fig);
    if isequal(fnames, 0), return; end
    if ischar(fnames), fnames = {fnames}; end

    s = fig.UserData;
    s.imageNames = cellfun(@(f) fullfile(fpath, f), fnames, ...
                           'UniformOutput', false);
    s.h.listImages.Items = rov.util.shortNames(s.imageNames);
    fig.UserData = s;
end
