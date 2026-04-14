function onColormapChanged(fig)
%ROV.CALLBACKS.ONCOLORMAPCHANGED  Colormap dropdown callback.
%
% PURPOSE
%   The colormap only affects Continuous mode. In Discrete mode this
%   callback is a no-op - the dropdown is usually disabled in that
%   case anyway via rov.render.updateColorSchemeUI.
%
% INPUT
%   fig : main uifigure handle.
%
% EXAMPLE
%   Bound to the "Colormap" dropdown ValueChangedFcn.

    s = fig.UserData;
    s.colormapName = s.h.ddCmap.Value;
    fig.UserData   = s;

    if s.isDataLoaded && strcmp(s.colorScheme, 'Continuous')
        rov.compute.computeColors(fig);
        rov.render.renderPage(fig);
        rov.render.updateLegend(fig);
        rov.render.updateColorbar(fig);
    end
end
