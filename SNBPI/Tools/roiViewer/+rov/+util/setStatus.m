function setStatus(fig, msg)
%ROV.UTIL.SETSTATUS  Update the status label at the bottom of the left panel.
%
% PURPOSE
%   Single-line helper so status updates happen in a consistent way and
%   a drawnow call guarantees the user actually sees the message before
%   the next blocking operation begins.
%
% INPUTS
%   fig : main uifigure handle.
%   msg : char vector to show.
%
% EXAMPLE
%   rov.util.setStatus(fig, 'Loading data...');

    if ~isvalid(fig), return; end
    if isfield(fig.UserData,'h') && isfield(fig.UserData.h,'statusLbl') ...
            && isvalid(fig.UserData.h.statusLbl)
        fig.UserData.h.statusLbl.Text = msg;
    end
    drawnow;
end
