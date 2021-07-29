function filledmask = fillmask(mask)
% 将mask中的空洞补全
[x,y,z] = size(mask);
filledmask = mask;
for i=1:z
    maskxy = mask(:,:,i);
    filledmaskxy = imfill(maskxy,'holes');
    filledmask(:,:,i) = filledmaskxy;
end


