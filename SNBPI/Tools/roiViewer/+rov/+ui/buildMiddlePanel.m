function buildMiddlePanel(fig)
%ROV.UI.BUILDMIDDLEPANEL  Construct the central image grid + scroll bar.
%
% PURPOSE
%   Creates the uipanel that holds the image axes grid and the bottom
%   row of paging buttons (Page Up / Step Up / slice info / Step Down
%   / Page Down). Calls rov.ui.recreateImageGrid to lay out the actual
%   axes, so that grid can be rebuilt independently when Rows/Cols
%   change.
%
% INPUT
%   fig : main uifigure handle.
%
% SIDE EFFECTS
%   Populates fig.UserData.h.imagePanel, sliceInfoLbl, imageAxesCell.
%
% EXAMPLE
%   rov.ui.buildMiddlePanel(fig);
%
% See also: rov.ui.recreateImageGrid, rov.render.renderPage

    s = fig.UserData;
    C = rov.ui.uiTheme();

    mg = uigridlayout(s.h.midPanel, [2,1], ...
        'RowHeight',       {'1x', 44}, ...
        'Padding',         [4 4 4 4], ...
        'RowSpacing',      4, ...
        'BackgroundColor', [0.07 0.07 0.07]);

    s.h.imagePanel = uipanel(mg, 'BackgroundColor','k', 'BorderType','none');
    s.h.imagePanel.Layout.Row = 1;

    bg = uigridlayout(mg, [1,6], ...
        'ColumnWidth',     {90,80,'1x',80,90,80}, ...
        'Padding',         [0 4 0 4], ...
        'ColumnSpacing',   6, ...
        'BackgroundColor', [0.07 0.07 0.07]);
    bg.Layout.Row = 2;

    uibutton(bg, 'push', 'Text', [C.glyph.pageUp ' Page Up'], ...
        'BackgroundColor', C.scrollbtn, 'FontColor', C.text, ...
        'ButtonPushedFcn', @(~,~) rov.callbacks.onPageUp(fig));
    uibutton(bg, 'push', 'Text', [C.glyph.stepUp ' Step Up'], ...
        'BackgroundColor', C.scrollbtn, 'FontColor', C.text, ...
        'ButtonPushedFcn', @(~,~) rov.callbacks.onStepUp(fig));

    s.h.sliceInfoLbl = uilabel(bg, 'Text','', ...
        'FontColor', C.muted, 'FontSize', 9, ...
        'HorizontalAlignment','center');

    uibutton(bg, 'push', 'Text', [C.glyph.stepDown ' Step Down'], ...
        'BackgroundColor', C.scrollbtn, 'FontColor', C.text, ...
        'ButtonPushedFcn', @(~,~) rov.callbacks.onStepDown(fig));
    uibutton(bg, 'push', 'Text', [C.glyph.pageDown ' Page Down'], ...
        'BackgroundColor', C.scrollbtn, 'FontColor', C.text, ...
        'ButtonPushedFcn', @(~,~) rov.callbacks.onPageDown(fig));

    uilabel(bg, 'Text','');   % right spacer

    s.h.imageAxesCell = {};
    fig.UserData = s;

    rov.ui.recreateImageGrid(fig);
end
