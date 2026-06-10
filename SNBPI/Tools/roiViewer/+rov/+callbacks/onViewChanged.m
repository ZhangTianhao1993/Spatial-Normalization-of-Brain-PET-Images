function onViewChanged(fig)
%ROV.CALLBACKS.ONVIEWCHANGED  Plane dropdown callback.
%
% PURPOSE
%   When the user switches between Transverse / Coronal / Sagittal, the
%   slice list must be recomputed (different axis, different extent) and
%   the image grid redrawn.
%
% INPUT
%   fig : main uifigure handle.
%
% EXAMPLE
%   Bound to the "Plane" dropdown ValueChangedFcn.

    s = fig.UserData;
    s.viewDir    = s.h.ddView.Value;
    fig.UserData = s;
    if s.isDataLoaded
        if s.mipMode
            rov.render.renderPage(fig);
        else
            rov.compute.computeSliceList(fig);
            rov.render.renderPage(fig);
        end
    end
end
