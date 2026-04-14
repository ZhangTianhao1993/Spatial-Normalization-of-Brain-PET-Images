function saveAxesHelper(fig, target, filterSpec, dlgTitle, bgColor)
%ROV.IO.SAVEAXESHELPER  Shared "ask for a filename + exportgraphics" worker.
%
% PURPOSE
%   The individual save callbacks (main images, colorbar, legend) used
%   to duplicate the same dialog + error-handling pattern. This helper
%   folds that into one place.
%
% INPUTS
%   fig        : main uifigure handle (for status reporting).
%   target     : handle to export (axes, panel, or figure).
%   filterSpec : uiputfile filter cell, e.g.
%                  {'*.tif;*.tiff','TIFF'; '*.png','PNG'}.
%   dlgTitle   : dialog title.
%   bgColor    : optional [r g b] background colour for exportgraphics.
%                Leave empty to use the target's default.
%
% BEHAVIOUR
%   - Cancel -> silently returns.
%   - Success -> status label shows "<type> saved: <file>".
%   - Failure -> status label shows "Save failed: <msg>".
%
% EXAMPLE
%   rov.io.saveAxesHelper(fig, fig.UserData.h.cbAx, ...
%       {'*.tif;*.tiff','TIFF'}, 'Save Colorbar As', [0.10 0.10 0.13]);

    [fname, fpath] = uiputfile(filterSpec, dlgTitle);
    rov.util.bringToFront(fig);
    if isequal(fname, 0), return; end
    outFile = fullfile(fpath, fname);
    dpi = 600;
    try
        if isempty(bgColor)
            exportgraphics(target, outFile, 'Resolution', dpi);
        else
            exportgraphics(target, outFile, ...
                'Resolution', dpi, 'BackgroundColor', bgColor);
        end
        rov.util.setStatus(fig, ['Saved: ' fname]);
    catch ME
        rov.util.setStatus(fig, ['Save failed: ' ME.message]);
    end
end
