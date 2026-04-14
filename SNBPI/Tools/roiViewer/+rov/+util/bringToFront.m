function bringToFront(fig)
%ROV.UTIL.BRINGTOFRONT  Restore focus to a uifigure after a native dialog.
%
% PURPOSE
%   On Windows a native file dialog (uigetfile/uiputfile) can push the
%   parent uifigure behind other windows. On some Linux window managers
%   the behaviour is similar. This helper drags the window back to the
%   front using the safest methods available.
%
% INPUT
%   fig : uifigure handle.
%
% BEHAVIOUR
%   - No-op if fig is invalid.
%   - Calls drawnow, then tries figure(fig) (works on uifigure in
%     R2020a+); falls back to a Visible off/on toggle if that fails.
%
% EXAMPLE
%   [f,p] = uigetfile(...); rov.util.bringToFront(fig);

    if isempty(fig) || ~isvalid(fig), return; end
    drawnow;
    try
        figure(fig);
    catch
        try
            fig.Visible = 'off';
            fig.Visible = 'on';
        catch
            % best effort only
        end
    end
    drawnow;
end
