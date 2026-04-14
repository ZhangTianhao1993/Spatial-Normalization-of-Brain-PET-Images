function onSpacingChanged(fig)
%ROV.CALLBACKS.ONSPACINGCHANGED  Spacing (mm) edit field callback.
%
% PURPOSE
%   Updates the target inter-slice distance in millimetres, then
%   recomputes the slice list and redraws the page.
%
% INPUT
%   fig : main uifigure handle.
%
% EXAMPLE
%   Bound to the "Spacing (mm)" edit field ValueChangedFcn.

    s = fig.UserData;
    s.spacing    = s.h.numSpacing.Value;
    fig.UserData = s;
    if s.isDataLoaded
        rov.compute.computeSliceList(fig);
        rov.render.renderPage(fig);
    end
end
