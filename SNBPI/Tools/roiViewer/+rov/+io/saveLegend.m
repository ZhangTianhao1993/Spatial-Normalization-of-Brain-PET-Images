function saveLegend(fig)
%ROV.IO.SAVELEGEND  "Save Legend..." button callback.
%
% PURPOSE
%   Exports the legend at 300 DPI. Because the on-screen legend lives
%   in a scrollable container, we cannot pass it to exportgraphics
%   directly (would only capture the visible viewport). Instead we
%   delegate to rov.io.exportLegendToFile, which builds an off-screen
%   figure with every entry stacked vertically and exports that.
%
% INPUT
%   fig : main uifigure handle.
%
% EXAMPLE
%   Bound to "Save Legend..." button in left panel.

    s = fig.UserData;
    if ~s.isDataLoaded
        rov.util.setStatus(fig, 'No data loaded.');
        return;
    end
    if isempty(s.legendEntries)
        rov.util.setStatus(fig, 'No legend entries to save.');
        return;
    end

    [fname, fpath] = uiputfile( ...
        {'*.tif;*.tiff','TIFF image'; '*.png','PNG image'}, ...
        'Save Legend As');
    rov.util.bringToFront(fig);
    if isequal(fname, 0), return; end

    outFile = fullfile(fpath, fname);
    try
        rov.io.exportLegendToFile(s.legendEntries, outFile, 300);
        rov.util.setStatus(fig, ['Legend saved: ' fname]);
    catch ME
        rov.util.setStatus(fig, ['Save failed: ' ME.message]);
    end
end
