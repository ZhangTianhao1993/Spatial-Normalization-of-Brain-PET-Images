function onStepDown(fig)
%ROV.CALLBACKS.ONSTEPDOWN  Scroll down by one slice.
%
% PURPOSE
%   Moves page start forward by 1, clamped so at least one tile on
%   the page still shows a real slice.
%
% INPUT
%   fig : main uifigure handle.

    s = fig.UserData;
    maxStart     = max(1, numel(s.sliceList) - s.nRows*s.nCols + 1);
    s.pageStart  = min(maxStart, s.pageStart + 1);
    fig.UserData = s;
    rov.render.renderPage(fig);
end
