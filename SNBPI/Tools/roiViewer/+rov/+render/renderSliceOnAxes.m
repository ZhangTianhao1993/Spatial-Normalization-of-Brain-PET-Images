function renderSliceOnAxes(ax, sliceIdx, axLabel, fig)
%ROV.RENDER.RENDERSLICEONAXES  Draw one slice (background + overlay) onto one axes.
%
% PURPOSE
%   Shared rendering routine used by rov.render.renderPage for every
%   slice. Blends the normalised background image with the atlas
%   overlay using s.alpha, in either Continuous or Discrete colour mode.
%
% INPUTS
%   ax       : target uiaxes handle (already cla'd by caller).
%   sliceIdx : integer slice index along s.viewDir.
%   axLabel  : 'x' / 'y' / 'z' for the title.
%   fig      : main uifigure handle (for reading state).
%
% EXAMPLE
%   rov.render.renderSliceOnAxes(ax, 40, 'z', fig);

    s = fig.UserData;

    slice2D  = rov.compute.extractSlice(s.imgNorm, sliceIdx, s.viewDir);
    rgbSlice = repmat(slice2D, [1, 1, 3]);

    isCont = rov.util.isContinuousMode(s);

    if isCont
        atlasSlice = rov.compute.extractSlice(s.atlasVols{1}, sliceIdx, s.viewDir);
        rgbSlice = rov.render.overlayContinuous(rgbSlice, atlasSlice, s);
    else
        hasDispRange = (isfield(s,'dispRangeMin') && isfinite(s.dispRangeMin)) || ...
                       (isfield(s,'dispRangeMax') && isfinite(s.dispRangeMax));
        hasDispAbs   = isfield(s,'dispRangeAbs')  && isfinite(s.dispRangeAbs);
        hasCluster   = isfield(s,'clusterSize')   && isfinite(s.clusterSize) && s.clusterSize > 0;
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
        'XColor','none','YColor','none', 'Color','k', ...
        'YDir','reverse');
    title(ax, sprintf('%s = %d', axLabel, sliceIdx), ...
        'Color',[0.88 0.88 0.88], 'FontSize', 9, 'FontWeight','normal');
end
