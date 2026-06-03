function onClusterSizeChanged(fig)
%ROV.CALLBACKS.ONCLUSTERSIZECHANGED  Cluster size numeric field callback.
%
% PURPOSE
%   Reads the cluster size threshold from the numeric edit field, stores it
%   in s.clusterSize, and triggers a full redraw. Clusters (connected
%   components) smaller than this many voxels are removed from the display.
%
% INPUT
%   fig : main uifigure handle.
%
% NOTES
%   - Value 0 means no cluster filtering (default).
%   - Filtering is performed per 2D slice via bwconncomp.
%
% EXAMPLE
%   Bound to the "Cluster:" numeric edit field ValueChangedFcn
%   in rov.ui.buildLeftPanel DISPLAY RANGE section.

    s = fig.UserData;

    s.clusterSize = s.h.numCluster.Value;
    fig.UserData  = s;

    if s.isDataLoaded
        rov.render.renderPage(fig);
        rov.render.updateLegend(fig);
        rov.render.updateColorbar(fig);
    end
end
