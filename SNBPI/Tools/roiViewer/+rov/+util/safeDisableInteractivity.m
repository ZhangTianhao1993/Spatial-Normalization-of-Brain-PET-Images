function safeDisableInteractivity(ax)
%ROV.UTIL.SAFEDISABLEINTERACTIVITY  Disable axes interactivity if possible.
%
% PURPOSE
%   The function `disableDefaultInteractivity` is undocumented and not
%   guaranteed to exist on every MATLAB release. Wrapping the call in a
%   try/catch here keeps the viewer working on older versions where the
%   function is missing or differently named.
%
% INPUT
%   ax : axes or uiaxes handle.
%
% EXAMPLE
%   rov.util.safeDisableInteractivity(ax);

    if isempty(ax) || ~isvalid(ax), return; end
    try
        disableDefaultInteractivity(ax);
    catch
        % older MATLAB or restricted environment - ignore
    end
end
