function onAlphaChanged(fig, sliderH)
%ROV.CALLBACKS.ONALPHACHANGED  Overlay alpha slider callback.
%
% PURPOSE
%   Sets the blending weight between the grayscale background and the
%   atlas overlay, updates the numeric readout label, and redraws.
%
% INPUTS
%   fig     : main uifigure handle.
%   sliderH : slider object (passed by the UI).
%
% EXAMPLE
%   Bound to the "Alpha" uislider ValueChangedFcn.

    s = fig.UserData;
    s.alpha           = sliderH.Value;
    s.h.lblAlpha.Text = sprintf('%.2f', s.alpha);
    fig.UserData      = s;
    if s.isDataLoaded
        rov.render.renderPage(fig);
    end
end
