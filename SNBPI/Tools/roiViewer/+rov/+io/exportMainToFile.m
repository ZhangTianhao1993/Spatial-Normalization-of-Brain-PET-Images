function exportMainToFile(fig, outFile, dpi)
%ROV.IO.EXPORTMAINTOFILE  Export the current page of slices to an image file.
%
% PURPOSE
%   exportgraphics on a uipanel containing uiaxes fails on some MATLAB
%   versions (R2022b and earlier) with "UI components will not be
%   included in the output". This helper instead builds a disposable,
%   off-screen REGULAR figure, re-renders every visible slice onto
%   standard axes, exports with exportgraphics, and deletes the figure.
%
%   The rendering logic mirrors rov.render.renderSliceOnAxes exactly,
%   but targets plain axes objects that exportgraphics can handle.
%
% INPUTS
%   fig     : main uifigure handle (reads state from fig.UserData).
%   outFile : full path to the output image file.
%   dpi     : export resolution (e.g. 300, 600).
%
% EXAMPLE
%   rov.io.exportMainToFile(fig, '/tmp/slices.tiff', 600);

    s = fig.UserData;
    if ~s.isDataLoaded, return; end

    if s.mipMode
        bgColor = [0 0 0];
        f = figure('Visible','off', 'Color', bgColor, ...
                   'Units','pixels', 'Position',[0 0 600 500], ...
                   'MenuBar','none', 'ToolBar','none', ...
                   'NumberTitle','off', 'Name','mip_export', ...
                   'InvertHardcopy','off');
        cleaner = onCleanup(@() delete(f));
        ax = axes(f, 'Units','normalized', ...
                  'Position',[0.05 0.05 0.90 0.90], 'Color','k');
        rov.render.renderMipOnAxes(ax, s);
        exportgraphics(f, outFile, ...
            'Resolution', dpi, 'BackgroundColor', bgColor);
        return;
    end

    if isempty(s.sliceList), return; end

    nR = s.nRows;
    nC = s.nCols;
    nAxes   = nR * nC;
    nSlices = numel(s.sliceList);

    pStart     = max(1, min(s.pageStart, nSlices));
    idxEnd     = min(pStart + nAxes - 1, nSlices);
    pageSlices = s.sliceList(pStart : idxEnd);
    nShow      = numel(pageSlices);

    axLabelMap = struct('Transverse','z','Coronal','y','Sagittal','x');
    lbl        = axLabelMap.(s.viewDir);

    bgColor = [0 0 0];

    % --- Figure sizing: keep similar aspect ratio to the on-screen grid
    tileW = 180;  tileH = 160;
    figW  = nC * tileW;
    figH  = nR * tileH;

    f = figure('Visible','off', 'Color', bgColor, ...
               'Units','pixels', 'Position',[0 0 figW figH], ...
               'MenuBar','none', 'ToolBar','none', ...
               'NumberTitle','off', 'Name','main_export', ...
               'InvertHardcopy','off');    % preserve dark background
    cleaner = onCleanup(@() delete(f));

    % Margins / gaps (normalised) — same as recreateImageGrid
    ML = 0.005;  MR = 0.005;  MT = 0.050;  MB = 0.005;
    GH = 0.005;  GV = 0.030;
    PW = (1 - ML - MR - GH*(nC-1)) / nC;
    PH = (1 - MT - MB - GV*(nR-1)) / nR;

    for k = 1:nAxes
        r  = ceil(k / nC);
        c  = mod(k-1, nC) + 1;
        x0 = ML + (c-1)*(PW + GH);
        y0 = 1  - MT - r*PH - (r-1)*GV;

        ax = axes(f, 'Units','normalized', ...
                  'Position',[x0, y0, PW, PH], ...
                  'Color','k');

        if k <= nShow
            renderOnAxes(ax, pageSlices(k), lbl, s);
        else
            set(ax, 'Color','k', 'XColor','none', 'YColor','none');
        end
    end

    exportgraphics(f, outFile, ...
        'Resolution', dpi, 'BackgroundColor', bgColor);
end


% =========================================================================
%  LOCAL: re-render a single slice on a REGULAR axes (pure graphics).
%  Mirrors the logic in rov.render.renderSliceOnAxes but avoids any
%  dependency on uiaxes or fig.UserData indirection.
% =========================================================================
function renderOnAxes(ax, sliceIdx, axLabel, s)

    slice2D  = rov.compute.extractSlice(s.imgNorm, sliceIdx, s.viewDir);
    rgbSlice = repmat(slice2D, [1, 1, 3]);

    isCont = rov.util.isContinuousMode(s);

    % Resolve display range filter (applies to atlas values, not background)
    hasDispRange = (isfield(s,'dispRangeMin') && isfinite(s.dispRangeMin)) || ...
                   (isfield(s,'dispRangeMax') && isfinite(s.dispRangeMax));
    hasDispAbs   = isfield(s,'dispRangeAbs')  && isfinite(s.dispRangeAbs);
    hasCluster   = isfield(s,'clusterSize')   && isfinite(s.clusterSize) && s.clusterSize > 0;

    if isCont
        atlasSlice = rov.compute.extractSlice(s.atlasVols{1}, sliceIdx, s.viewDir);
        validMask  = isfinite(atlasSlice) & atlasSlice ~= 0;
        if hasDispRange
            if isfield(s,'dispRangeMin') && isfinite(s.dispRangeMin)
                validMask = validMask & (atlasSlice >= s.dispRangeMin);
            end
            if isfield(s,'dispRangeMax') && isfinite(s.dispRangeMax)
                validMask = validMask & (atlasSlice <= s.dispRangeMax);
            end
        end
        if hasDispAbs
            validMask = validMask & (abs(atlasSlice) >= s.dispRangeAbs);
        end
        if hasCluster
            validMask = rov.util.filterByClusterSize(validMask, s.clusterSize);
        end
        nC         = size(s.cmap, 1);

        [vmin, vmax, isDeg] = rov.compute.liveAtlasRange(s);

        if isDeg
            cidx = round(nC/2) * ones(size(atlasSlice));
        else
            wN   = max(0, min(1, (atlasSlice - vmin) / (vmax - vmin)));
            cidx = min(nC, max(1, round(wN*(nC-1)) + 1));
        end

        for ch = 1:3
            chan = rgbSlice(:,:,ch);
            col  = s.cmap(:, ch);
            chan(validMask) = chan(validMask) * (1 - s.alpha) + ...
                              col(cidx(validMask)) * s.alpha;
            rgbSlice(:,:,ch) = chan;
        end
    else
        for e = 1:numel(s.colorEntries)
            en  = s.colorEntries(e);
            asl = rov.compute.extractSlice(s.atlasVols{en.atlasIdx}, sliceIdx, s.viewDir);
            if isnan(en.label)
                mask = isfinite(asl) & asl ~= 0;
            else
                mask = (asl == en.label);
            end
            if hasDispRange
                if isfield(s,'dispRangeMin') && isfinite(s.dispRangeMin)
                    mask = mask & (asl >= s.dispRangeMin);
                end
                if isfield(s,'dispRangeMax') && isfinite(s.dispRangeMax)
                    mask = mask & (asl <= s.dispRangeMax);
                end
            end
            if hasDispAbs
                mask = mask & (abs(asl) >= s.dispRangeAbs);
            end
            if hasCluster
                mask = rov.util.filterByClusterSize(mask, s.clusterSize);
            end
            for ch = 1:3
                chan = rgbSlice(:,:,ch);
                chan(mask) = chan(mask) * (1 - s.alpha) + en.color(ch) * s.alpha;
                rgbSlice(:,:,ch) = chan;
            end
        end
    end

    image(ax, rgbSlice);
    set(ax, ...
        'XTick',[], 'YTick',[], ...
        'DataAspectRatio',[1, 1, 1], ...
        'XColor','none', 'YColor','none', 'Color','k', ...
        'YDir','reverse');
    title(ax, sprintf('%s = %d', axLabel, sliceIdx), ...
        'Color',[0.88 0.88 0.88], 'FontSize', 9, 'FontWeight','normal');
end