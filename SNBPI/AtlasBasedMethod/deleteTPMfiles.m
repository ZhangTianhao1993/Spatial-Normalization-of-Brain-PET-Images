function deleteTPMfiles(imageNamei,TPMnum)
[filepath,name,~] = fileparts(imageNamei);
for i=1:TPMnum
    TPMnamei = [filepath,'\TPM',num2str(i),name,'.nii'];
    delete(TPMnamei);
end
