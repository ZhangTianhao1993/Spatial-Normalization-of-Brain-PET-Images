function out = normaliseVolume(vol)
%ROV.COMPUTE.NORMALISEVOLUME  Rescale a volume's finite values to [0,1].
%
% PURPOSE
%   Used to turn the mean (or atlas) background into a grayscale image
%   that the overlay colours are then blended onto.
%
% INPUT
%   vol : 3D numeric volume (may contain NaN/Inf).
%
% OUTPUT
%   out : same size as vol, finite values scaled to [0,1]; non-finite
%         values written as 0. If the volume is constant, all zeros
%         are returned.
%
% EXAMPLE
%   g = rov.compute.normaliseVolume(meanVol);

    finite = isfinite(vol);
    out    = zeros(size(vol));
    if ~any(finite,'all'), return; end

    mn = min(vol(finite), [], 'all');
    mx = max(vol(finite), [], 'all');
    if mx > mn
        out(finite) = (vol(finite) - mn) / (mx - mn);
    end
end
