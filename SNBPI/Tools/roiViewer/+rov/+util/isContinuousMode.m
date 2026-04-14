function tf = isContinuousMode(s)
%ROV.UTIL.ISCONTINUOUSMODE  True iff the viewer should use a continuous colormap.
%
% PURPOSE
%   The viewer supports Continuous mode only when exactly one atlas is
%   loaded. This predicate centralises the check so every consumer
%   (render/legend/colorbar/save) agrees on what "continuous" means.
%
% INPUT
%   s : viewer state struct (fig.UserData).
%
% OUTPUT
%   tf : logical scalar.
%
% EXAMPLE
%   if rov.util.isContinuousMode(fig.UserData), ... end

    tf = isstruct(s) ...
         && isfield(s,'colorScheme') && strcmp(s.colorScheme,'Continuous') ...
         && isfield(s,'nAtlas')      && s.nAtlas == 1;
end
