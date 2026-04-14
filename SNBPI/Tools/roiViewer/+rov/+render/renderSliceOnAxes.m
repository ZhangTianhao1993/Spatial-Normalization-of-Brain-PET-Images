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
        validMask  = isfinite(atlasSlice) & atlasSlice ~= 0;
        nC         = size(s.cmap, 1);

        % Compute the active range fresh so rendering NEVER depends on
        % whether s.atlasVmin/Vmax was already synced into fig.UserData.
        % For a binary mask (only value = 1) this gives vmin == vmax == 1
        % and we map every voxel to the colormap top - the bug fix.
        if isfield(s,'cbUserMin') && isfinite(s.cbUserMin) && ...
           isfield(s,'cbUserMax') && isfinite(s.cbUserMax)
            vmin = double(s.cbUserMin);
            vmax = double(s.cbUserMax);
            if vmax < vmin, t = vmin; vmin = vmax; vmax = t; end
        else
            vol3d = s.atlasVols{1};
            vals  = vol3d(isfinite(vol3d) & vol3d ~= 0);
            if isempty(vals)
                vmin = 0;  vmax = 1;
            else
                vmin = double(min(vals));
                vmax = double(max(vals));
            end
            % User may have set ONE of the two; honour that
            if isfield(s,'cbUserMin') && isfinite(s.cbUserMin)
                vmin = double(s.cbUserMin);
            end
            if isfield(s,'cbUserMax') && isfinite(s.cbUserMax)
                vmax = double(s.cbUserMax);
            end
            if vmax < vmin, t = vmin; vmin = vmax; vmax = t; end
        end
        isDeg = ~(vmax > vmin);

        if isDeg
            cidx = (nC/2) * ones(size(atlasSlice));
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
