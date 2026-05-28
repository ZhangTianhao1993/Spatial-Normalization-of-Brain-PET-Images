function onDispRangeChanged(fig)
%ROV.CALLBACKS.ONDISPRANGECHANGED  Display range Min / Max text field callback.
%
% PURPOSE
%   Reads the text from the Display Range Min / Max edit fields, parses
%   them to numbers (empty or non-numeric text -> NaN = "no bound"),
%   stores the result in s.dispRangeMin / s.dispRangeMax, and triggers a
%   full redraw.
%
%   Voxels whose ORIGINAL value (from s.meanVol) falls outside
%   [dispRangeMin, dispRangeMax] are rendered as fully transparent.
%
% INPUT
%   fig : main uifigure handle.
%
% NOTES
%   - Empty string -> NaN -> "unbounded" for that side.
%   - Invalid text (e.g. "abc") -> NaN -> same as empty.
%   - Thresholds apply to the raw meanVol values, not the normalised imgNorm.
%
% EXAMPLE
%   Bound to the "Min" / "Max" edit fields ValueChangedFcn
%   in rov.ui.buildLeftPanel DISPLAY RANGE section.

    s = fig.UserData;

    vMin = str2double(strtrim(s.h.txtDispMin.Value));
    vMax = str2double(strtrim(s.h.txtDispMax.Value));

    s.dispRangeMin = vMin;
    s.dispRangeMax = vMax;
    fig.UserData   = s;

    if s.isDataLoaded
        rov.render.renderPage(fig);
        rov.render.updateLegend(fig);
        rov.render.updateColorbar(fig);
    end
end
