function saveFull(fig)
%ROV.IO.SAVEFULL  "Save Full Window..." button callback.
%
% PURPOSE
%   Exports a snapshot of the entire viewer window using
%   rov.util.safeExportApp, which falls back to getframe on platforms
%   where exportapp is unavailable or misbehaves.
%
% INPUT
%   fig : main uifigure handle.
%
% EXAMPLE
%   Bound to "Save Full Window..." button in left panel.

    [fname, fpath] = uiputfile( ...
        {'*.png','PNG image'; '*.tif;*.tiff','TIFF image'; '*.jpg','JPEG image'}, ...
        'Save Full Window As');
    rov.util.bringToFront(fig);
    if isequal(fname, 0), return; end

    outFile = fullfile(fpath, fname);
    if rov.util.safeExportApp(fig, outFile)
        rov.util.setStatus(fig, ['Full window saved: ' fname]);
    else
        rov.util.setStatus(fig, ...
            'Save failed: could not export window on this platform.');
    end
end
