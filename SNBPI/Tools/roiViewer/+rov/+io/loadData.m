function loadData(fig)
%ROV.IO.LOADDATA  Load atlas(es) + compute mean brain image; refresh display.
%
% PURPOSE
%   Core data-loading pipeline. Reads the first atlas header for world
%   geometry, reads all atlas volumes, computes (or reuses) a mean brain
%   image as the background, normalises the background to [0,1], then
%   kicks off slice-list computation, colour computation, and rendering.
%
% INPUT
%   fig : main uifigure handle. Uses s.atlasNames, s.imageNames.
%
% SIDE EFFECTS
%   Populates s.atlasHdr, voxSize, worldOriginVox, atlasVols, nAtlas,
%   meanVol, imgNorm, isDataLoaded. Triggers full redraw and status
%   updates. On error, the error is re-thrown after being shown in the
%   status label.
%
% EXAMPLE
%   rov.io.loadData(fig);
%
% See also: rov.compute.computeSliceList, rov.compute.computeColors,
%           rov.render.renderPage

    s = fig.UserData;
    rov.util.setStatus(fig, 'Loading data...');
    drawnow;

    try
        % Drop any empty atlas entries defensively
        s.atlasNames = s.atlasNames( ...
            ~cellfun(@(x) isempty(strtrim(x)), s.atlasNames));
        s.nAtlas     = numel(s.atlasNames);
        if s.nAtlas == 0
            rov.util.setStatus(fig, 'ERROR: No atlas file selected.');
            return;
        end

        % --- geometry from first atlas -------------------------------
        V0         = spm_vol(s.atlasNames{1});
        s.atlasHdr = V0;
        s.voxSize  = sqrt(sum(V0.mat(1:3,1:3).^2, 1));

        originH          = V0.mat \ [0; 0; 0; 1];
        s.worldOriginVox = originH(1:3)';

        % --- read all atlas volumes ----------------------------------
        s.atlasVols = cell(s.nAtlas, 1);
        for i = 1:s.nAtlas
            Vi             = spm_vol(s.atlasNames{i});
            s.atlasVols{i} = spm_read_vols(Vi);
        end

        % Auto-load labels for single atlas if user did not supply any
        if s.nAtlas == 1 && isempty(s.atlasLabels)
            lbls = rov.io.tryLoadAtlasLabels(s.atlasNames{1});
            if ~isempty(lbls), s.atlasLabels = lbls; end
        end

        % --- background image ---------------------------------------
        if ~isempty(s.imageNames)
            rov.util.setStatus(fig, sprintf( ...
                'Computing mean over %d image(s)...', numel(s.imageNames)));
            drawnow;
            s.meanVol = computeMeanBrainImage(s.imageNames, s.atlasNames{1});
        else
            s.meanVol = s.atlasVols{1};
        end
        s.imgNorm      = rov.compute.normaliseVolume(s.meanVol);
        s.isDataLoaded = true;
        fig.UserData   = s;

        % --- refresh -------------------------------------------------
        rov.render.updateColorSchemeUI(fig);
        rov.compute.computeSliceList(fig);
        rov.compute.computeColors(fig);
        rov.render.renderPage(fig);
        rov.render.updateLegend(fig);
        rov.render.updateColorbar(fig);

        s = fig.UserData;
        rov.util.setStatus(fig, sprintf( ...
            'Loaded. %d slice(s) with atlas coverage.', numel(s.sliceList)));

    catch ME
        rov.util.setStatus(fig, ['ERROR: ' ME.message]);
        rethrow(ME);
    end
end
