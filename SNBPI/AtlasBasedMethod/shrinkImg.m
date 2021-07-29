function sTPM = shrinkImg(TPM,mask)
% Consider the partial volume effect of PET, and appropriately reduce the 
% atlas
[x,y,z,n] = size(TPM);
sTPM = zeros(x,y,z,n);
se = strel('sphere',1);
maskse = strel('sphere',4);
newmask = imerode(mask,maskse);
ROIVoxelNum = squeeze(sum(sum(sum(TPM))));
for i=1:4
    TPMi = TPM(:,:,:,i);
    ROIiVoxelNum = ROIVoxelNum(i);
    vi = sum(TPMi(:));
    while vi>0.3*ROIiVoxelNum && vi>200
        maski = TPMi>0.3;
        maski = imerode(maski,se);
        TPMi = TPMi.*maski;
        vi = sum(TPMi(:));
    end
    sTPM(:,:,:,i) = TPMi;
end
for i=5:n
    TPMi = TPM(:,:,:,i);
    TPMi(newmask==0) = 0;
    ROIiVoxelNum = ROIVoxelNum(i);
    vi = sum(TPMi(:));
    while vi>0.5*ROIiVoxelNum && vi>300
        maski = TPMi>0.3;
        maski = imerode(maski,se);
        TPMi = TPMi.*maski;
        vi = sum(TPMi(:));
    end
    sTPM(:,:,:,i) = TPMi;
end

    