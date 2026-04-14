function saveColorbar(fig)
%ROV.IO.SAVECOLORBAR  "Save Colorbar..." button callback.
%
% PURPOSE
%   Exports the colorbar axes at 300 DPI. Only permitted in Continuous
%   mode with a single atlas loaded; otherwise the colorbar content is
%   just a placeholder and saving it would mislead the user.
%
% INPUT
%   fig : main uifigure handle.
%
% EXAMPLE
%   Bound to "Save Colorbar..." button in left panel.

    s = fig.UserData;
    if ~rov.util.isContinuousMode(s)
        rov.util.setStatus(fig, ...
            'Colorbar only available in Continuous mode (single atlas).');
        return;
    end
    rov.io.saveAxesHelper(fig, s.h.cbAx, ...
        {'*.tif;*.tiff','TIFF image'; '*.png','PNG image'}, ...
        'Save Colorbar As', [0 0 0]);
end
