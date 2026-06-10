function onPageUp(fig)
%ROV.CALLBACKS.ONPAGEUP  Scroll up by one full page (nRows*nCols slices).
%
% INPUT
%   fig : main uifigure handle.

    s = fig.UserData;
    if s.mipMode, return; end
    s.pageStart  = max(1, s.pageStart - s.nRows*s.nCols);
    fig.UserData = s;
    rov.render.renderPage(fig);
end
