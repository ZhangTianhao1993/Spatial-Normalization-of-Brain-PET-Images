function s = initState(imgIn, atlasIn, labelsIn)
%ROV.INITSTATE  Return the default UserData struct for the viewer.
%
% PURPOSE
%   Builds the single struct that stores all viewer state (inputs,
%   volumes, view settings, colour state, handle cache). Keeping every
%   piece of mutable state in one struct avoids scattered globals and
%   makes the callbacks easy to reason about.
%
% INPUTS
%   imgIn    : cell array of image file paths (may be empty)
%   atlasIn  : cell array of atlas file paths (may be empty)
%   labelsIn : n x 2 cell {name,value}, or empty
%
% OUTPUT
%   s : struct with fields (all have sensible defaults):
%         imageNames, atlasNames, atlasLabels
%         viewDir ('Transverse'|'Coronal'|'Sagittal'), spacing (mm),
%         nRows, nCols
%         colorScheme ('Continuous'|'Discrete'), colormapName, alpha
%         isDataLoaded, meanVol, imgNorm, atlasHdr, atlasVols, nAtlas,
%         voxSize, worldOriginVox
%         sliceList, pageStart
%         colorEntries, cmap, atlasVmin, atlasVmax,
%         cbUserMin, cbUserMax (NaN = use data range)
%         legendEntries
%         h (struct of handles)
%
% EXAMPLE
%   s = rov.initState({}, {}, {});

    s.imageNames      = imgIn;
    s.atlasNames      = atlasIn;
    s.atlasLabels     = labelsIn;
    s.viewDir         = 'Transverse';
    s.spacing         = 10;
    s.nRows           = 4;
    s.nCols           = 5;
    s.colorScheme     = 'Continuous';
    s.colormapName    = 'parula';
    s.alpha           = 0.52;
    s.isDataLoaded    = false;
    s.meanVol         = [];
    s.imgNorm         = [];
    s.atlasHdr        = [];
    s.atlasVols       = {};
    s.nAtlas          = 0;
    s.voxSize         = [1 1 1];
    s.worldOriginVox  = [1 1 1];
    s.sliceList       = [];
    s.pageStart       = 1;
    s.colorEntries    = [];
    s.cmap            = parula(256);
    s.atlasVmin       = 0;
    s.atlasVmax       = 1;
    s.cbUserMin       = NaN;   % NaN = use data range; set by Min input
    s.cbUserMax       = NaN;   % NaN = use data range; set by Max input
    s.dispRangeMin    = NaN;   % NaN = no lower bound; display range filter
    s.dispRangeMax    = NaN;   % NaN = no upper bound; display range filter
    s.dispRangeAbs    = NaN;   % NaN = no abs threshold; show |value| >= this
    s.clusterSize     = 0;     % 0 = off; remove clusters smaller than this (voxels)
    s.legendEntries   = [];
    s.h               = struct();
end
