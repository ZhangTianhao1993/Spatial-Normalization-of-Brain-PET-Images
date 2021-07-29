function [newTPM,BIClist,maxIndexList] = computeNewTPM(tempImgName,TPM,...
    mask,x,y,z,regularterm)
% Generating Adaptive Brain Probabilistic Atlas

fprintf('Generating Adaptive Brain Probabilistic Atlas...\n');
v = spm_vol(tempImgName);
wImg = spm_read_vols(v);
pwImg = preProcessImg(wImg,x,y,z);
sTPM = shrinkImg(TPM,mask);
psTPM = preProcessTPM(sTPM,x,y,z);
[BIClist,maxIndexList] = computeMinBIC(pwImg,psTPM,regularterm);
newTPM = mergeTPM(TPM,maxIndexList,BIClist); 
[~,~,~,TPMnum] = size(newTPM);
[filepath,name,~] = fileparts(v.fname);
name(1:4) = [];
for i=1:TPMnum
    TPMvi = v;
    TPMvi.dt = [16 0];
    TPMvi.fname = [filepath,'\TPM',num2str(i),name,'.nii'];
    spm_write_vol(spm_create_vol(TPMvi),newTPM(:,:,:,i));
end
