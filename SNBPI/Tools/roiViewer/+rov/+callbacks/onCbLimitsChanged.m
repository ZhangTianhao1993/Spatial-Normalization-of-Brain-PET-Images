function onCbLimitsChanged(fig)
%ROV.CALLBACKS.ONCBLIMITSCHANGED  Colorbar Min / Max edit field callback.
%
% PURPOSE
%   The colorbar panel exposes two numeric edit fields ("Min" and "Max")
%   that override the auto-derived data range. This callback reads
%   their current values, stores them in the state (NaN means "blank,
%   fall back to data range"), recomputes the legend swatch colours,
%   and repaints the slices, legend, and colorbar.
%
% INPUT
%   fig : main uifigure handle.
%
% NOTES
%   - Empty / NaN entries are treated as "auto"; the field is restored
%     to NaN in state but the visible value is left as the user typed it
%     so they can keep editing.
%   - Reversed limits (Max < Min) are tolerated; the renderer swaps them
%     internally via rov.util.effectiveCbRange.
%
% EXAMPLE
%   Bound to the "Min" / "Max" numeric edit fields ValueChangedFcn
%   in rov.ui.buildColorbarPanel.

    s = fig.UserData;

    vMin = s.h.numCbMin.Value;
    vMax = s.h.numCbMax.Value;

    if isempty(vMin) || ~isfinite(vMin), vMin = NaN; end
    if isempty(vMax) || ~isfinite(vMax), vMax = NaN; end

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
