function buildColorbarPanel(fig)
%ROV.UI.BUILDCOLORBARPANEL  Construct the colorbar column with custom limits.
%
% PURPOSE
%   Builds the colorbar column that sits between the image grid and the
%   ROI legend. Two TEXT edit fields (Min / Max) let the user override
%   the auto-derived data range. They are only enabled in Continuous +
%   single-atlas mode; otherwise they are visually present but disabled.
%
%   TEXT edit fields are used instead of numeric ones because the
%   numeric AllowEmpty property was not added until R2023b, and this
%   viewer targets R2020b+. An empty text field means "auto (use data
%   range)"; any valid number overrides that bound.
%
% INPUT
%   fig : main uifigure handle.
%
% SIDE EFFECTS
%   Populates fig.UserData.h.cbGrid, lblCbTitle, cbAx, txtCbMax, txtCbMin.
%
% LAYOUT (top to bottom)
%   row 1 : "Colorbar" header label
%   row 2 : "Max" label
%   row 3 : Max text edit field
%   row 4 : the colorbar axes itself (stretches)
%   row 5 : Min text edit field
%   row 6 : "Min" label
%
% EXAMPLE
%   rov.ui.buildColorbarPanel(fig);
%
% See also: rov.callbacks.onCbLimitsChanged

    s = fig.UserData;
    C = rov.ui.uiTheme();

    g = uigridlayout(s.h.cbPanel, [6,1], ...
        'RowHeight',       {20, 14, 24, '1x', 24, 14}, ...
        'Padding',         [6 8 6 8], ...
        'RowSpacing',      3, ...
        'BackgroundColor', [0.10 0.10 0.13]);
    s.h.cbGrid = g;

    s.h.lblCbTitle = uilabel(g, 'Text','Colorbar', ...
        'FontWeight','bold', 'FontColor', C.accent, ...
        'HorizontalAlignment','center');

    uilabel(g, 'Text','Max', ...
        'FontColor', C.muted, 'FontSize', 9, ...
        'HorizontalAlignment','center');

    % TEXT edit field (not numeric) so we can leave it empty on R2020b+.
    % Empty = auto; valid number = user override.
    s.h.txtCbMax = uieditfield(g, 'text', ...
        'Value',              '', ...
        'BackgroundColor',    C.ctrl, ...
        'FontColor',          C.text, ...
        'HorizontalAlignment','center', ...
        'Tooltip',            'Override colorbar max (leave empty for auto)', ...
        'ValueChangedFcn',    @(~,~) rov.callbacks.onCbLimitsChanged(fig));

    s.h.cbAx = uiaxes(g, ...
        'BackgroundColor',[0.10 0.10 0.13], ...
        'XColor','none','YColor',[0.85 0.85 0.85],'Box','on');
    s.h.cbAx.Toolbar.Visible = 'off';
    rov.util.safeDisableInteractivity(s.h.cbAx);

    s.h.txtCbMin = uieditfield(g, 'text', ...
        'Value',              '', ...
        'BackgroundColor',    C.ctrl, ...
        'FontColor',          C.text, ...
        'HorizontalAlignment','center', ...
        'Tooltip',            'Override colorbar min (leave empty for auto)', ...
        'ValueChangedFcn',    @(~,~) rov.callbacks.onCbLimitsChanged(fig));

    uilabel(g, 'Text','Min', ...
        'FontColor', C.muted, 'FontSize', 9, ...
        'HorizontalAlignment','center');

    % Start disabled (enabled only in Continuous mode)
    s.h.txtCbMax.Enable = 'off';
    s.h.txtCbMin.Enable = 'off';

    fig.UserData = s;
end