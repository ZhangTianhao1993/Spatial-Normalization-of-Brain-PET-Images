function saveMain(fig)
%ROV.IO.SAVEMAIN  "Save Main Images..." button callback.
%
% PURPOSE
%   Exports the current image grid (s.h.imagePanel) to a TIFF/PNG/PDF
%   file at 600 DPI using exportgraphics.
%
% INPUT
%   fig : main uifigure handle.
%
% EXAMPLE
%   Bound to "Save Main Images..." button in left panel.

    s = fig.UserData;
    if ~s.isDataLoaded
        rov.util.setStatus(fig, 'No data loaded.');
        return;
    end
    rov.io.saveAxesHelper(fig, s.h.imagePanel, ...
        {'*.tif;*.tiff','TIFF image'; '*.png','PNG image'; '*.pdf','PDF'}, ...
        'Save Main Images As', [0 0 0]);
end
