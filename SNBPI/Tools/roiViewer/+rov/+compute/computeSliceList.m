function computeSliceList(fig)
%ROV.COMPUTE.COMPUTESLICELIST  Build origin-based slice index list.
%
% PURPOSE
%   Generates the list of slice indices to display, symmetrically spread
%   around the world origin (so the "centre" slice is always the one
%   nearest to MNI origin), with a user-specified spacing in millimetres.
%
% INPUT
%   fig : main uifigure handle. Uses s.viewDir, s.spacing, s.voxSize,
%         s.worldOriginVox, s.atlasHdr.dim.
%
% SIDE EFFECTS
%   Writes s.sliceList (row vector of valid slice indices) and resets
%   s.pageStart to 1.
%
% EXAMPLE
%   rov.compute.computeSliceList(fig);

    s = fig.UserData;
    if ~s.isDataLoaded, return; end

    switch s.viewDir
        case 'Transverse', axIdx = 3;
        case 'Coronal',    axIdx = 2;
        case 'Sagittal',   axIdx = 1;
        otherwise
            error('rov:computeSliceList:badDir', ...
                  'Unknown viewDir "%s"', s.viewDir);
    end

    dim    = s.atlasHdr.dim(axIdx);
    voxSp  = s.spacing / s.voxSize(axIdx);
    center = s.worldOriginVox(axIdx);

    nPos    = floor((dim - center) / voxSp);
    nNeg    = floor((center - 1)   / voxSp);
    rawList = round(center + round((-nNeg:nPos) * voxSp));
    rawList = unique(rawList);
    valid   = rawList >= 1 & rawList <= dim;

    s.sliceList  = rawList(valid);
    s.pageStart  = 1;
    fig.UserData = s;
end
