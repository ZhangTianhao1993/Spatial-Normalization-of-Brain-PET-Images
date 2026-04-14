function exportLegendToFile(entries, outFile, dpi)
%ROV.IO.EXPORTLEGENDTOFILE  Export an ROI legend to an image file.
%
% PURPOSE
%   The on-screen legend lives in a SCROLLABLE uigridlayout, and
%   exportgraphics cannot capture content scrolled out of view (and
%   on R2020b/R2021a sometimes refuses to run on a scrollable
%   container at all). This helper instead builds a DISPOSABLE,
%   off-screen plain figure that contains every legend entry stacked
%   vertically (no scrolling), exports it, and deletes it. The result
%   is a single image that always shows ALL ROIs, regardless of how
%   many there are.
%
% INPUTS
%   entries : struct array with fields .color (1x3) and .name (char).
%   outFile : full path to the output image file (.tif/.tiff/.png).
%   dpi     : resolution in DPI for exportgraphics (e.g. 300, 600).
%
% BEHAVIOUR
%   - Returns silently for empty entries (writes nothing).
%   - Disposable figure is created with Visible = 'off' so the user
%     never sees it flash on-screen.
%   - Always cleans up the figure even on export failure.
%
% EXAMPLE
%   rov.io.exportLegendToFile(s.legendEntries, '/tmp/legend.tiff', 600);

    if isempty(entries)
        return;
    end

    nE       = numel(entries);
    rowH_px  = 22;           % matches the on-screen LEGEND_ROW_PX
    swatchPx = 26;           % matches updateLegend swatch column
    padPx    = 8;
    figW_px  = 360;          % wide enough for most ROI names
    figH_px  = 2*padPx + nE*rowH_px + max(0, (nE-1)*2);

    bgColor = [0 0 0];
    fg      = [1 1 1];

    % Disposable hidden figure - use uifigure to keep the same widget
    % family as the live UI (matches font rendering exactly).
    f = uifigure( ...
        'Visible',   'off', ...
        'Units',     'pixels', ...
        'Position',  [0 0 figW_px figH_px], ...
        'Color',     bgColor, ...
        'AutoResizeChildren','off');
    cleaner = onCleanup(@() delete(f));

    grid = uigridlayout(f, [nE, 2], ...
        'ColumnWidth',     {swatchPx, '1x'}, ...
        'RowHeight',       repmat({rowH_px}, 1, nE), ...
        'Padding',         [padPx padPx padPx padPx], ...
        'RowSpacing',      2, ...
        'ColumnSpacing',   6, ...
        'Scrollable',      'off', ...
        'BackgroundColor', bgColor);

    for k = 1:nE
        e = entries(k);

        sw = uipanel(grid, ...
            'BackgroundColor', e.color, ...
            'BorderType','none');
        sw.Layout.Row    = k;
        sw.Layout.Column = 1;

        lbl = uilabel(grid, ...
            'Text',       e.name, ...
            'FontColor',  fg, ...
            'FontSize',   10, ...
            'WordWrap',   'off');
        lbl.Layout.Row    = k;
        lbl.Layout.Column = 2;
    end

    drawnow;            % make sure widgets are realised before export
    exportapp(f, outFile);
end
