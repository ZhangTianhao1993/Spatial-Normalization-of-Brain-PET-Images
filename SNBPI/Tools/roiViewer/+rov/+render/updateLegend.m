function updateLegend(fig)
%ROV.RENDER.UPDATELEGEND  Populate the scrollable ROI legend grid.
%
% PURPOSE
%   Replaces the contents of fig.UserData.h.legendGrid with one row per
%   entry in s.legendEntries. Each row is a tiny 2-column sub-grid
%   holding a colour-swatch panel and an ROI name label. Row height is
%   fixed at LEGEND_ROW_PX so the visual size of each entry never
%   changes - the only thing that grows is the total grid height,
%   which the parent's Scrollable property turns into a scrollbar /
%   wheel-scroll automatically.
%
% INPUT
%   fig : main uifigure handle.
%
% SIDE EFFECTS
%   - Removes all existing children of s.h.legendGrid.
%   - Rebuilds s.h.legendGrid.RowHeight to a fixed-height vector with
%     length == numel(s.legendEntries) (or 1 with a placeholder when
%     empty).
%
% NOTES
%   For very large atlases (e.g. Schaefer-1000), this builds 1000+
%   widgets - takes a fraction of a second on first display, then
%   the user can scroll smoothly through them all.
%
% EXAMPLE
%   rov.render.updateLegend(fig);

    LEGEND_ROW_PX  = 22;
    SWATCH_WIDTH   = 26;

    s       = fig.UserData;
    grid    = s.h.legendGrid;
    entries = s.legendEntries;
    nE      = numel(entries);

    % Clear previous contents
    delete(allchild(grid));

    if nE == 0
        grid.RowHeight = {LEGEND_ROW_PX};
        uilabel(grid, 'Text','(no entries)', ...
            'FontColor',[0.55 0.55 0.60], 'FontSize', 9, ...
            'HorizontalAlignment','center');
        fig.UserData = s;
        return;
    end

    % Reset row template to nE fixed-height rows. Use repmat over a cell
    % to stay compatible with the older uigridlayout API.
    grid.RowHeight = repmat({LEGEND_ROW_PX}, 1, nE);

    for k = 1:nE
        e = entries(k);

        row = uigridlayout(grid, [1, 2], ...
            'ColumnWidth',     {SWATCH_WIDTH, '1x'}, ...
            'Padding',         [0 0 0 0], ...
            'ColumnSpacing',   6, ...
            'BackgroundColor', [0.10 0.10 0.13]);
        row.Layout.Row    = k;
        row.Layout.Column = 1;

        % Colour swatch
        uipanel(row, ...
            'BackgroundColor', e.color, ...
            'BorderType','none');

        % Name (Interpreter is unsupported on uilabel - underscores are
        % displayed verbatim, which is what we want for region names).
        uilabel(row, ...
            'Text',       e.name, ...
            'FontColor',  [0.88 0.88 0.88], ...
            'FontSize',   10, ...
            'WordWrap',   'off', ...
            'Tooltip',    e.name);
    end

    fig.UserData = s;
end
