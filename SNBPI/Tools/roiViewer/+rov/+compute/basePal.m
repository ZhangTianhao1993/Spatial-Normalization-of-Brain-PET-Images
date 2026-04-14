function palette = basePal()
%ROV.COMPUTE.BASEPAL  Return the default 12-colour palette for multi-atlas mode.
%
% PURPOSE
%   When multiple atlas files are overlaid, each atlas gets one colour
%   from this cyclic palette, picked by atlas index.
%
% OUTPUT
%   palette : 12 x 3 RGB matrix in [0,1].
%
% EXAMPLE
%   p = rov.compute.basePal();
%   colorForAtlas3 = p(mod(3-1, size(p,1)) + 1, :);

    palette = [0.929 0.169 0.169; 0.204 0.596 0.859; 0.180 0.800 0.443;
               0.953 0.612 0.071; 0.608 0.239 0.851; 0.071 0.714 0.765;
               0.949 0.408 0.149; 0.894 0.235 0.655; 0.553 0.827 0.078;
               0.200 0.286 0.929; 0.969 0.929 0.173; 0.161 0.624 0.475];
end
