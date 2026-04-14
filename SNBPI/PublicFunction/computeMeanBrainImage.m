function [meanVol, hdr] = computeMeanBrainImage(imageNames, refName)
% COMPUTEMEANBRAINIMAGE  Resample brain images to reference space and compute
%                        a voxel-wise mean (NaN-safe, memory-efficient).
%
%   [meanVol, hdr] = computeMeanBrainImage(imageNames, refName)
%
%   Inputs:
%     imageNames - cell array of brain image file paths
%     refName    - reference image path (typically the first atlas)
%
%   Outputs:
%     meanVol    - 3-D double matrix, nanmean across all images
%     hdr        - SPM volume header of the reference image

hdr   = spm_vol(refName);
sz    = hdr.dim(1:3);
accum = zeros(sz);          % running sum (finite values only)
count = zeros(sz);          % number of finite contributions per voxel

for i = 1:numel(imageNames)
    vol   = resampleImgToRef(imageNames{i}, refName);
    valid = isfinite(vol);
    accum(valid) = accum(valid) + vol(valid);
    count(valid) = count(valid) + 1;
end

meanVol          = NaN(sz);
hasSamples       = count > 0;
meanVol(hasSamples) = accum(hasSamples) ./ count(hasSamples);
end