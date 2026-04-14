function slice2D = extractSlice(vol, idx, viewDir)
%ROV.COMPUTE.EXTRACTSLICE  Pull a 2D slice from a 3D volume in a given plane.
%
% PURPOSE
%   Factor out the slicing + 90 deg rotation used by both image rendering
%   and overlay masking. Vertical orientation ("anatomical up = top") is
%   handled at the axes level via YDir='reverse', not by flipping the
%   data here.
%
% INPUTS
%   vol     : 3D numeric volume (X Y Z).
%   idx     : integer slice index along the selected axis.
%   viewDir : one of 'Transverse', 'Coronal', 'Sagittal'.
%
% OUTPUT
%   slice2D : 2D numeric slice, rotated 90 deg counter-clockwise for
%             display.
%
% EXAMPLE
%   s = rov.compute.extractSlice(vol, 42, 'Transverse');

    switch viewDir
        case 'Transverse', slice2D = rot90(squeeze(vol(:,:,idx)), 1);
        case 'Coronal',    slice2D = rot90(squeeze(vol(:,idx,:)), 1);
        case 'Sagittal',   slice2D = rot90(squeeze(vol(idx,:,:)), 1);
        otherwise
            error('rov:extractSlice:badDir', ...
                  'Unknown viewDir "%s" (expected Transverse/Coronal/Sagittal)', viewDir);
    end
end
