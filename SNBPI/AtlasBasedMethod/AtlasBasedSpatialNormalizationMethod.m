function AtlasBasedSpatialNormalizationMethod(PETnames,bbox,vx,nf,rt,d,s)
% The main function for atlas based method
% PETnames - The names of the PET images
% bbox     - Bounding box, a 2* 3 matrix which determine the min and max X,
%            Y, and Z.
% vx       - Voxel size, a 1*3 vecotr of voxel dimensions (mm).
% nf       - The prefix for normalized image, a char.
% rt       - Regular term, a real number.
% d        - a progress bar object
% s        - a logic variable which indicate whether save the TPM for 
%           spatial normalization
% Author: Zhang Tianhao 2021/7/29
% =========================================================================

n = length(PETnames);
str = which('SNBPI');
[mainfilepath,~,~] = fileparts(str);
for i=1:n
    imageNamei = PETnames(i);
    imageNamei = imageNamei{1,1};
    imageNamei(end-1:end) = [];
    cleanImg(imageNamei);
    initialNormalize(imageNamei);
    [filepath,imagename,ext] = fileparts(imageNamei);
    tempImgName = [filepath,'\temp',imagename,ext];
    maskstr = load([mainfilepath,'\TPM\mask.mat']);
    mask = maskstr.mask;
    TPMstr = load([mainfilepath,'\TPM\TPM.mat']);
    TPM = TPMstr.TPM;
    [newTPM,~,~] = computeNewTPM(tempImgName,TPM,mask,30,36,30,rt);
    [~,~,~,TPMnum] = size(newTPM);
    finalNormalize(imageNamei,TPMnum,bbox,vx,nf);
    deleteFiles(imageNamei);
    d.Value = i/n;
    if s == 0
        deleteTPMfiles(imageNamei,TPMnum);
    end
end