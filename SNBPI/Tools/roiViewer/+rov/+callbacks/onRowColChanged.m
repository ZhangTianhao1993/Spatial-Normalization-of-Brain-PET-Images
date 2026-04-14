function onRowColChanged(fig)
%ROV.CALLBACKS.ONROWCOLCHANGED  Rows / Cols edit field callback.
%
% PURPOSE
%   Rebuilds the image axes grid with the new rows/columns, resets the
%   page to the first slice, and repaints.
%
% INPUT
%   fig : main uifigure handle.
%
% EXAMPLE
%   Bound to both "Rows" and "Cols" edit field ValueChangedFcn.

    s = fig.UserData;
    s.nRows      = round(s.h.numRows.Value);
    s.nCols      = round(s.h.numCols.Value);
    s.pageStart  = 1;
    fig.UserData = s;

    rov.ui.recreateImageGrid(fig);
    if s.isDataLoaded
        rov.render.renderPage(fig);
    end
end
