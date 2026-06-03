function mask = filterByClusterSize(mask, minClusterSize)
%ROV.UTIL.FILTERBYCLUSTERSIZE  Remove connected components smaller than threshold.
%
% PURPOSE
%   Performs 2D connected-component labelling on the input binary mask and
%   removes (sets to false) any component whose voxel count is less than
%   minClusterSize. This is used to denoise overlay images by suppressing
%   scattered voxels that do not form meaningful clusters.
%
% INPUTS
%   mask           : 2D logical array.
%   minClusterSize : scalar integer. Components with fewer voxels are
%                    removed. 0 or negative = no filtering.
%
% OUTPUT
%   mask : filtered 2D logical array.
%
% EXAMPLE
%   clean = rov.util.filterByClusterSize(noisyMask, 10);

    if nargin < 2 || minClusterSize <= 0
        return;
    end

    try
        cc = bwconncomp(mask, 8);  % 8-connectivity on 2D slices
        for i = 1:cc.NumObjects
            if numel(cc.PixelIdxList{i}) < minClusterSize
                mask(cc.PixelIdxList{i}) = false;
            end
        end
    catch
        % bwconncomp requires Image Processing Toolbox; silently skip
        % filtering if unavailable
    end
end
