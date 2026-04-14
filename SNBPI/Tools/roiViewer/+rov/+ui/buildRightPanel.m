function buildRightPanel(fig)
%ROV.UI.BUILDRIGHTPANEL  Construct the ROI legend column (scrollable).
%
% PURPOSE
%   Builds the rightmost column with a header and a scrollable inner
%   container that hosts one row per ROI. The scrolling itself is done
%   by the inner uigridlayout's Scrollable property (R2020b+) - mouse
%   wheel and the standard vertical scrollbar both work out of the
%   box, no custom slider required.
%
% INPUT
%   fig : main uifigure handle.
%
% SIDE EFFECTS
%   Populates fig.UserData.h:
%     rightGrid     : outer 2-row layout (header + scroll panel)
%     legendPanel   : the uipanel that gets exported in saveLegend
%     legendGrid    : the SCROLLABLE uigridlayout that updateLegend fills
%
% NOTES
%   The scrollable grid is wrapped in a plain uipanel because
%   exportgraphics works much more reliably on a uipanel than on a
%   scrollable uigridlayout directly.
%
% EXAMPLE
%   rov.ui.buildRightPanel(fig);

    s = fig.UserData;
    C = rov.ui.uiTheme();

    g = uigridlayout(s.h.rightPanel, [2,1], ...
        'RowHeight',       {20, '1x'}, ...
        'Padding',         [6 6 6 6], ...
        'RowSpacing',      4, ...
        'BackgroundColor', C.panel);
    s.h.rightGrid = g;

    hLbl = uilabel(g, 'Text','ROI Legend', ...
        'FontWeight','bold', 'FontColor', C.accent, ...
        'HorizontalAlignment','center');
    hLbl.Layout.Row = 1;

    % Wrapper panel - serves as the export target so saveLegend can
    % capture exactly what the user sees (entire scroll container).
    s.h.legendPanel = uipanel(g, ...
        'BackgroundColor', [0.10 0.10 0.13], ...
        'BorderType','none');
    s.h.legendPanel.Layout.Row = 2;

    % The scrollable grid that updateLegend populates dynamically.
    % Row count and heights are reset on every update.
    s.h.legendGrid = uigridlayout(s.h.legendPanel, [1,1], ...
        'RowHeight',       {22}, ...
        'ColumnWidth',     {'1x'}, ...
        'Padding',         [4 4 4 4], ...
        'RowSpacing',      2, ...
        'Scrollable',      'on', ...
        'BackgroundColor', [0.10 0.10 0.13]);

    fig.UserData = s;
end
