function saveAll(fig)
%ROV.IO.SAVEALL  "Save All [600 DPI]" one-click export.
%
% PURPOSE
%   Single-click export that writes all three artefacts at 600 DPI from
%   one filename prompt:
%     <base><ext>          : main image grid
%     <base>_colorbar.tiff : colorbar (only if Continuous + single atlas)
%     <base>_legend.tiff   : ROI legend
%     <base>_full.tiff     : whole-window snapshot (with getframe fallback)
%
% INPUT
%   fig : main uifigure handle.
%
% BEHAVIOUR
%   - If the user picks 'myplot.png', only the main image respects the
%     picked extension; sidecars are always .tiff (lossless, publication-
%     friendly).
%   - Status label is updated at each step so the user sees progress.
%   - In Discrete / multi-atlas mode the colorbar is skipped.
%
% EXAMPLE
%   Bound to the "Save All [600 DPI]" button in the left panel.

    s = fig.UserData;
    if ~s.isDataLoaded
        rov.util.setStatus(fig, 'No data loaded.');
        return;
    end

    [fname, fpath] = uiputfile( ...
        {'*.tif;*.tiff','TIFF (recommended for 600 DPI)'; '*.png','PNG'}, ...
        'Save All - choose base name (extension reused for main image)');
    rov.util.bringToFront(fig);
    if isequal(fname, 0), return; end

    [~, base, ext] = fileparts(fname);
    if isempty(ext), ext = '.tiff'; end
    res = 600;

    f1 = fullfile(fpath, [base ext]);
    f2 = fullfile(fpath, [base '_colorbar.tiff']);
    f3 = fullfile(fpath, [base '_legend.tiff']);
    f4 = fullfile(fpath, [base '_full.tiff']);

    try
        rov.util.setStatus(fig, 'Saving main images @ 600 DPI...'); drawnow;
        rov.io.exportMainToFile(fig, f1, res);

        savedCb = false;
        if rov.util.isContinuousMode(s)
            rov.util.setStatus(fig, 'Saving colorbar @ 600 DPI...'); drawnow;
            exportgraphics(s.h.cbAx, f2, ...
                'Resolution', res, 'BackgroundColor',[0 0 0]);
            savedCb = true;
        end

        rov.util.setStatus(fig, 'Saving legend @ 600 DPI...'); drawnow;
        rov.io.exportLegendToFile(s.legendEntries, f3, res);

        rov.util.setStatus(fig, 'Saving full window snapshot...'); drawnow;
        rov.util.safeExportApp(fig, f4);

        if savedCb
            rov.util.setStatus(fig, sprintf( ...
                'Save All done: %s, _colorbar, _legend, _full', base));
        else
            rov.util.setStatus(fig, sprintf( ...
                'Save All done: %s, _legend, _full (no colorbar in Discrete)', base));
        end

    catch ME
        rov.util.setStatus(fig, ['Save failed: ' ME.message]);
    end
end