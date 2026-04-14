function onBrowseAtlas(fig)
%ROV.IO.ONBROWSEATLAS  "Select Atlas File(s)..." button callback.
%
% PURPOSE
%   Opens a multi-select native file dialog for atlas files, stores
%   selection in fig.UserData.atlasNames, refreshes the atlas listbox,
%   and - for single-atlas selections - auto-loads the matching
%   <name>_Labels.mat if present.
%
% INPUT
%   fig : main uifigure handle.
%
% BEHAVIOUR
%   - Cancel -> state unchanged.
%   - >=2 atlases selected -> s.atlasLabels cleared (not meaningful in
%     multi-atlas mode where each atlas gets one colour).
%   - Status label reports whether labels were loaded.
%
% EXAMPLE
%   Bound to the "Select Atlas File(s)..." button in the left panel.

    [fnames, fpath] = uigetfile( ...
        {'*.nii;*.img','NIfTI / Analyze (*.nii,*.img)'; '*.*','All files'}, ...
        'Select Atlas File(s)', 'MultiSelect','on');
    rov.util.bringToFront(fig);
    if isequal(fnames, 0), return; end
    if ischar(fnames), fnames = {fnames}; end

    s = fig.UserData;
    s.atlasNames = cellfun(@(f) fullfile(fpath, f), fnames, ...
                           'UniformOutput', false);
    s.h.listAtlas.Items = rov.util.shortNames(s.atlasNames);

    if isscalar(s.atlasNames)
        labels = rov.io.tryLoadAtlasLabels(s.atlasNames{1});
        if ~isempty(labels)
            s.atlasLabels = labels;
            [~, nm, ~] = fileparts(s.atlasNames{1});
            rov.util.setStatus(fig, sprintf( ...
                'Atlas selected. Loaded %d labels from %s_Labels.mat', ...
                size(labels,1), nm));
        else
            s.atlasLabels = {};
            rov.util.setStatus(fig, ...
                'Atlas selected. (no _Labels.mat found in same folder)');
        end
    else
        s.atlasLabels = {};
    end

    fig.UserData = s;
end
