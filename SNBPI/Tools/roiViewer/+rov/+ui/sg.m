function g = sg(parent, sz, colW, C)
%ROV.UI.SG  Create a sub-gridlayout with the viewer's background colour.
%
% PURPOSE
%   Shorthand for the many little inline rows (label + control) used in
%   the control panel. Keeps padding/spacing consistent.
%
% INPUTS
%   parent : parent container
%   sz     : [nRows nCols] grid size
%   colW   : cell array of column widths (e.g. {'fit','1x'})
%   C      : theme struct from rov.ui.uiTheme
%
% OUTPUT
%   g : the created uigridlayout
%
% EXAMPLE
%   r = rov.ui.sg(parent, [1,2], {'fit','1x'}, C);

    g = uigridlayout(parent, sz, ...
        'ColumnWidth',     colW, ...
        'RowHeight',       {'1x'}, ...
        'Padding',         [0 0 0 0], ...
        'ColumnSpacing',   5, ...
        'BackgroundColor', C.panel);
end
