function exportLegendToFile(entries, outFile, dpi)
%ROV.IO.EXPORTLEGENDTOFILE  Export an ROI legend to an image file.
%
% PURPOSE
%   The on-screen legend uses scrollable UI components (uilabel /
%   uipanel), which exportgraphics refuses to render ("UI components
%   will not be included in the output"). This helper instead builds a
%   REGULAR off-screen figure with a plain axes, draws each legend row
%   as patch + text (pure graphics objects), exports it with
%   exportgraphics at the requested DPI, and cleans up.
%
% INPUTS
%   entries : struct array with fields .color (1x3) and .name (char).
%   outFile : full path to the output image file (.tif/.tiff/.png).
%   dpi     : resolution for exportgraphics (e.g. 300, 600).
%
% BEHAVIOUR
%   - Returns silently for empty entries.
%   - Disposable figure is created with Visible='off' (the user never
%     sees it flash on-screen).
%   - Always cleans up the figure even on export failure.
%
% EXAMPLE
%   rov.io.exportLegendToFile(s.legendEntries, '/tmp/legend.tiff', 600);

    if isempty(entries)
        return;
    end

    nE       = numel(entries);
    rowH     = 0.6;      % normalised height per row (axes units)
    swatchW  = 0.15;     % swatch width (fraction of axes X)
    textX    = 0.20;     % text left edge
    padY     = 0.3;      % top/bottom padding

    totalH   = nE * rowH + 2 * padY;

    bgColor = [0 0 0];
    fg      = [0.88 0.88 0.88];

    % --- Regular figure (NOT uifigure) so exportgraphics works --------
    %     figW/figH in pixels only affect aspect ratio at export; actual
    %     resolution comes from the dpi parameter.
    figW_px = 360;
    figH_px = max(80, round(22 * nE + 16));

    f = figure('Visible','off', 'Color', bgColor, ...
               'Units','pixels', 'Position',[0 0 figW_px figH_px], ...
               'MenuBar','none', 'ToolBar','none', ...
               'NumberTitle','off', 'Name','legend_export');
    cleaner = onCleanup(@() delete(f));

    ax = axes(f, 'Units','normalized', 'Position',[0 0 1 1], ...
              'Color', bgColor, 'XColor','none', 'YColor','none', ...
              'XLim',[0 1], 'YLim',[0 totalH], ...
              'YDir','reverse', 'Box','off');
    hold(ax, 'on');

    for k = 1:nE
        e  = entries(k);
        y0 = padY + (k - 1) * rowH;

        % Colour swatch (filled rectangle via patch)
        patch(ax, ...
              [0.03, 0.03+swatchW, 0.03+swatchW, 0.03], ...
              [y0+0.08, y0+0.08, y0+rowH-0.08, y0+rowH-0.08], ...
              e.color, 'EdgeColor','none');

        % ROI name
        text(ax, textX, y0 + rowH/2, e.name, ...
             'Color', fg, 'FontSize', 10, ...
             'VerticalAlignment','middle', ...
             'Interpreter','none', 'Clipping','on');
    end
    hold(ax, 'off');

    exportgraphics(ax, outFile, ...
        'Resolution', dpi, 'BackgroundColor', bgColor);
end