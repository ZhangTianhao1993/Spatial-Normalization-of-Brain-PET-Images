function rgbOut = overlayContinuous(rgbBg, atlas2D, s)
%ROV.RENDER.OVERLAYCONTINUOUS  Blend a 2D atlas slice onto an RGB background using continuous colormap.
%
% PURPOSE
%   Shared continuous-mode overlay logic used by both single-slice rendering
%   (renderSliceOnAxes) and MIP rendering (renderMipOnAxes).
%
% INPUTS
%   rgbBg   : MxNx3 RGB background image (values in [0,1]).
%   atlas2D : MxN atlas data slice or MIP projection.
%   s       : main viewer state struct (fig.UserData).
%
% OUTPUT
%   rgbOut  : MxNx3 RGB image with atlas overlay alpha-blended.

validMask  = isfinite(atlas2D) & atlas2D ~= 0;

hasDispRange = (isfield(s,'dispRangeMin') && isfinite(s.dispRangeMin)) || ...
               (isfield(s,'dispRangeMax') && isfinite(s.dispRangeMax));
hasDispAbs   = isfield(s,'dispRangeAbs')  && isfinite(s.dispRangeAbs);
hasCluster   = isfield(s,'clusterSize')   && isfinite(s.clusterSize) && s.clusterSize > 0;

if hasDispRange
    if isfield(s,'dispRangeMin') && isfinite(s.dispRangeMin)
        validMask = validMask & (atlas2D >= s.dispRangeMin);
    end
    if isfield(s,'dispRangeMax') && isfinite(s.dispRangeMax)
        validMask = validMask & (atlas2D <= s.dispRangeMax);
    end
end
if hasDispAbs
    validMask = validMask & (abs(atlas2D) >= s.dispRangeAbs);
end
if hasCluster
    validMask = rov.util.filterByClusterSize(validMask, s.clusterSize);
end

nC = size(s.cmap, 1);

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
    cidx = (nC/2) * ones(size(atlas2D));
else
    wN   = max(0, min(1, (atlas2D - vmin) / (vmax - vmin)));
    cidx = min(nC, max(1, round(wN*(nC-1)) + 1));
end

rgbOut = rgbBg;
for ch = 1:3
    chan = rgbOut(:,:,ch);
    col  = s.cmap(:, ch);
    chan(validMask) = chan(validMask) * (1 - s.alpha) + ...
                      col(cidx(validMask)) * s.alpha;
    rgbOut(:,:,ch) = chan;
end
end
