function onPageDown(fig)
%ROV.CALLBACKS.ONPAGEDOWN  Scroll down by one full page.
%
% INPUT
%   fig : main uifigure handle.

    s = fig.UserData;
    if s.mipMode, return; end
    pageSize     = s.nRows * s.nCols;
    maxStart     = max(1, numel(s.sliceList) - pageSize + 1);
    s.pageStart  = min(maxStart, s.pageStart + pageSize);
    fig.UserData = s;
    rov.render.renderPage(fig);
end
