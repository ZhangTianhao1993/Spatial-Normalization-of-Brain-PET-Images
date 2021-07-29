function filledmask = fillmask(mask)
% Fill the holes in the mask
[x,y,z] = size(mask);
filledmask = mask;
for i=1:z
    maskxy = mask(:,:,i);
    filledmaskxy = imfill(maskxy,'holes');
    filledmask(:,:,i) = filledmaskxy;
end


