function [vmin, vmax, isDegenerate] = effectiveCbRange(s)
%ROV.UTIL.EFFECTIVECBRANGE  Resolve the colorbar range actually used.
%
% PURPOSE
%   Returns the [vmin, vmax] range that should be used both for
%   rendering and for drawing colorbar tick labels. The lookup order
%   is:
%     1. User-typed Min / Max (s.cbUserMin / s.cbUserMax). Each side
%        is honoured INDIVIDUALLY - if only one is set, the other
%        falls through to the data range.
%     2. The non-zero, finite voxel min/max of the first atlas
%        (computed FRESH from s.atlasVols{1} every call - we never
%        rely on a possibly-stale s.atlasVmin / s.atlasVmax).
%     3. [0, 1] if no atlas is loaded yet.
%
% INPUT
%   s : viewer state struct (fig.UserData).
%
% OUTPUTS
%   vmin, vmax   : numeric scalars defining the active range. Always
%                  finite. Reversed user limits are swapped silently.
%   isDegenerate : logical, true iff vmax <= vmin. Callers must treat
%                  this as "every overlaid voxel maps to the colormap
%                  top" rather than dividing by zero.
%
% EXAMPLE
%   [vmin, vmax, deg] = rov.util.effectiveCbRange(fig.UserData);

    % Step 1: data-driven defaults from atlas voxels (fresh each call).
    vmin = 0;
    vmax = 1;
    if isstruct(s) && isfield(s,'atlasVols') ...
            && ~isempty(s.atlasVols) && ~isempty(s.atlasVols{1})
        vol  = s.atlasVols{1};
        vals = vol(isfinite(vol) & vol ~= 0);
        if ~isempty(vals)
            vmin = double(min(vals));
            vmax = double(max(vals));
        end
    end

    % Step 2: user override (each side independent).
    if isstruct(s)
        if isfield(s,'cbUserMin') && ~isempty(s.cbUserMin) && isfinite(s.cbUserMin)
            vmin = double(s.cbUserMin);
        end
        if isfield(s,'cbUserMax') && ~isempty(s.cbUserMax) && isfinite(s.cbUserMax)
            vmax = double(s.cbUserMax);
        end
    end

    if vmax < vmin
        tmp  = vmin;
        vmin = vmax;
        vmax = tmp;
    end

    isDegenerate = ~(vmax > vmin);
end
