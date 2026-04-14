function h = spacer(parent)
%ROV.UI.SPACER  Empty label used as a vertical spacer row.
%
% PURPOSE
%   In a uigridlayout, the cleanest way to leave a blank row of a
%   specified height is to place an empty label in it. This helper
%   just creates such a label.
%
% INPUT
%   parent : parent container (usually a uigridlayout)
%
% OUTPUT
%   h : the created uilabel handle
%
% EXAMPLE
%   rov.ui.spacer(grid);

    h = uilabel(parent, 'Text', '');
end
