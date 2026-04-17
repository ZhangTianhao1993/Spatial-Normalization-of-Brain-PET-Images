function [vmin, vmax, isDegenerate] = liveAtlasRange(s)
%ROV.COMPUTE.LIVEATLASRANGE  Resolve the active atlas value range from live data.
%
% PURPOSE
%   Single source of truth for the (vmin, vmax) used by both rendering
%   and the colorbar in Continuous mode. Computes the range FRESH from
%   the loaded atlas voxels every call, so the result never depends on
%   whether s.atlasVmin/Vmax happens to be in sync with fig.UserData
%   yet. User-typed Min / Max overrides take precedence (each one
%   independently - one being NaN means "auto for that bound only").
%
% INPUT
%   s : viewer state struct (fig.UserData). Reads s.atlasVols{1},
%       s.cbUserMin, s.cbUserMax. Multi-atlas / no-atlas states return
%       a safe default of [0, 1].
%
% OUTPUTS
%   vmin, vmax   : finite scalars; vmin <= vmax always.
%   isDegenerate : true iff vmin == vmax (e.g. a binary mask). The
%                  renderer should treat this case as "every overlaid
%                  voxel maps to the colormap top colour".
%
% EXAMPLE
%   [lo, hi, deg] = rov.compute.liveAtlasRange(fig.UserData);

    % Defaults (no atlas / weird state)
    vmin = 0;
    vmax = 1;

    if isstruct(s) && isfield(s,'atlasVols') ...
            && iscell(s.atlasVols) && ~isempty(s.atlasVols) ...
            && ~isempty(s.atlasVols{1})
        vol  = s.atlasVols{1};
        vals = vol(isfinite(vol) & vol ~= 0);
        if ~isempty(vals)
            vmin = double(min(vals));
            vmax = double(max(vals));
        end
    end

    % User overrides (each independent)
    if isstruct(s)
        if isfield(s,'cbUserMin') && ~isempty(s.cbUserMin) && isfinite(s.cbUserMin)
            vmin = double(s.cbUserMin);
        end
        if isfield(s,'cbUserMax') && ~isempty(s.cbUserMax) && isfinite(s.cbUserMax)
            vmax = double(s.cbUserMax);
        end
    end

    if vmax < vmin
        t    = vmin;
        vmin = vmax;
        vmax = t;
    end

    isDegenerate = ~(vmax > vmin);
end
