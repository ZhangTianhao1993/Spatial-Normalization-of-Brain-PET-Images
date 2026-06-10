function renderMipOnAxes(ax, s)
%ROV.RENDER.RENDERMIPONAXES  Render a maximum intensity projection onto one axes.
%
% PURPOSE
%   Computes and displays a MIP through the entire volume along the current
%   view direction, with atlas overlay applied using the shared
%   overlayContinuous function.
%
% INPUTS
%   ax : target axes handle (uiaxes or regular axes, already cla'd by caller).
%   s  : main viewer state struct (fig.UserData).
%
% EXAMPLE
%   rov.render.renderMipOnAxes(ax, fig.UserData);
    switch s.viewDir
        case 'Transverse', projDim = 3;
        case 'Coronal',    projDim = 2;
        case 'Sagittal',   projDim = 1;
        otherwise
            error('rov:renderMipOnAxes:badDir', ...
                  'Unknown viewDir "%s"', s.viewDir);
    end

    % Background MIP — same rotation as extractSlice
    bgMip    = rot90(squeeze(max(s.imgNorm, [], projDim)), 1);
    rgbSlice = repmat(bgMip, [1, 1, 3]);

    isCont = rov.util.isContinuousMode(s);

    if isCont
        atlasMip = rot90(squeeze(max(s.atlasVols{1}, [], projDim)), 1);
        rgbSlice = rov.render.overlayContinuous(rgbSlice, atlasMip, s);
    else
        hasDispRange = (isfield(s,'dispRangeMin') && isfinite(s.dispRangeMin)) || ...
                       (isfield(s,'dispRangeMax') && isfinite(s.dispRangeMax));
        hasDispAbs   = isfield(s,'dispRangeAbs')  && isfinite(s.dispRangeAbs);
        hasCluster   = isfield(s,'clusterSize')   && isfinite(s.clusterSize) && s.clusterSize > 0;
        for e = 1:numel(s.colorEntries)
            en  = s.colorEntries(e);
            vol = s.atlasVols{en.atlasIdx};
            if isnan(en.label)
                mask3D = isfinite(vol) & vol ~= 0;
            else
                mask3D = (vol == en.label);
            end
            % MIP the binary mask — max = logical OR along the ray
            mask = rot90(squeeze(max(double(mask3D), [], projDim)), 1);
            % MIP the atlas values for dispRange / dispAbs filtering
            aslMip = rot90(squeeze(max(vol, [], projDim)), 1);
            if hasDispRange
                if isfield(s,'dispRangeMin') && isfinite(s.dispRangeMin)
                    mask = mask & (aslMip >= s.dispRangeMin);
                end
                if isfield(s,'dispRangeMax') && isfinite(s.dispRangeMax)
                    mask = mask & (aslMip <= s.dispRangeMax);
                end
            end
            if hasDispAbs
                mask = mask & (abs(aslMip) >= s.dispRangeAbs);
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
    title(ax, sprintf('MIP (%s)', s.viewDir), ...
        'Color',[0.88 0.88 0.88], 'FontSize', 9, 'FontWeight','normal');
end
