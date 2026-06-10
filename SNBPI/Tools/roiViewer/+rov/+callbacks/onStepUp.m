function onStepUp(fig)
%ROV.CALLBACKS.ONSTEPUP  Scroll up by one slice.
%
% PURPOSE
%   Moves the page start back by 1 (clamped to >=1) and redraws.
%
% INPUT
%   fig : main uifigure handle.

    s = fig.UserData;
    if s.mipMode, return; end
    s.pageStart  = max(1, s.pageStart - 1);
    fig.UserData = s;
    rov.render.renderPage(fig);
end
