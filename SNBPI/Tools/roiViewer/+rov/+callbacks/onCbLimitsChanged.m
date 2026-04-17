function onCbLimitsChanged(fig)
%ROV.CALLBACKS.ONCBLIMITSCHANGED  Colorbar Min / Max text field callback.
%
% PURPOSE
%   Reads the text from the Min / Max edit fields, parses them to
%   numbers (empty or non-numeric text → NaN = "auto"), stores the
%   result in s.cbUserMin / s.cbUserMax, and triggers a full redraw
%   of slices + legend + colorbar.
%
% INPUT
%   fig : main uifigure handle.
%
% NOTES
%   - Empty string → NaN → "use data range" for that bound.
%   - Invalid text (e.g. "abc") → NaN → same as empty.
%   - Each bound is independent: the user can override just one.
%
% EXAMPLE
%   Bound to the "Min" / "Max" text edit fields ValueChangedFcn
%   in rov.ui.buildColorbarPanel.

    s = fig.UserData;

    vMin = str2double(strtrim(s.h.txtCbMin.Value));
    vMax = str2double(strtrim(s.h.txtCbMax.Value));
    % str2double returns NaN for empty or non-numeric strings, which is
    % exactly what we want ("auto").

    s.cbUserMin  = vMin;
    s.cbUserMax  = vMax;
    fig.UserData = s;

    if s.isDataLoaded && rov.util.isContinuousMode(s)
        rov.compute.computeColors(fig);
        rov.render.renderPage(fig);
        rov.render.updateLegend(fig);
        rov.render.updateColorbar(fig);
    end
end