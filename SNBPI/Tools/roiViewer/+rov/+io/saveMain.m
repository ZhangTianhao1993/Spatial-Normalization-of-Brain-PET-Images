function saveMain(fig)
%ROV.IO.SAVEMAIN  "Save Main Images..." button callback.
%
% PURPOSE
%   Exports the current page of slices to a TIFF/PNG/PDF file. Uses
%   rov.io.exportMainToFile which builds an off-screen regular figure
%   (not uifigure) to avoid the "UI components will not be included
%   in the output" error that exportgraphics raises on uiaxes inside
%   a uipanel in some MATLAB versions (R2022b and earlier).
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

    [fname, fpath] = uiputfile( ...
        {'*.tif;*.tiff','TIFF image'; '*.png','PNG image'; '*.pdf','PDF'}, ...
        'Save Main Images As');
    rov.util.bringToFront(fig);
    if isequal(fname, 0), return; end

    outFile = fullfile(fpath, fname);
    try
        rov.io.exportMainToFile(fig, outFile, 600);
        rov.util.setStatus(fig, ['Images saved: ' fname]);
    catch ME
        rov.util.setStatus(fig, ['Save failed: ' ME.message]);
    end
end