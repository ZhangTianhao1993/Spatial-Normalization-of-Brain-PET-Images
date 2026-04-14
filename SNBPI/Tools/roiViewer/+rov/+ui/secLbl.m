function h = secLbl(parent, txt, C)
%ROV.UI.SECLBL  Bold section header label used in the left panel.
%
% PURPOSE
%   Consistent "section title" styling across the control panel.
%
% INPUTS
%   parent : parent container (grid/panel)
%   txt    : char vector shown as the header
%   C      : theme struct from rov.ui.uiTheme
%
% OUTPUT
%   h : the created uilabel (mostly ignored)
%
% EXAMPLE
%   rov.ui.secLbl(grid, [C.glyph.bullet '  INPUT FILES'], C);

    h = uilabel(parent, 'Text', txt, ...
        'FontWeight','bold', 'FontColor', C.accent, 'FontSize', 10);
end
