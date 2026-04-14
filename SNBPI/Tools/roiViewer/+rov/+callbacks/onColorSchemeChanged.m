function onColorSchemeChanged(fig)
%ROV.CALLBACKS.ONCOLORSCHEMECHANGED  Colour scheme dropdown callback.
%
% PURPOSE
%   Switching between Continuous and Discrete changes how colours are
%   computed, the legend contents, and the colorbar strip - so all of
%   those are refreshed together.
%
% INPUT
%   fig : main uifigure handle.
%
% EXAMPLE
%   Bound to the "Scheme" dropdown ValueChangedFcn.

    s = fig.UserData;
    s.colorScheme = s.h.ddScheme.Value;
    fig.UserData  = s;

    rov.render.updateColorSchemeUI(fig);
    if s.isDataLoaded
        rov.compute.computeColors(fig);
        rov.render.renderPage(fig);
        rov.render.updateLegend(fig);
        rov.render.updateColorbar(fig);
    end
end
