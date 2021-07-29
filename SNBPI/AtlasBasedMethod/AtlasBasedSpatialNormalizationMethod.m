function AtlasBasedSpatialNormalizationMethod(PETnames,bbox,voxelsize,normprefix,regularterm,d,saveTPM)
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
    [newTPM,BIClist,maxIndexList] = computeNewTPM(tempImgName,TPM,mask,30,36,30,regularterm);
%     BIClistfilename = [filepath,'\BIClist.mat'];
%     save(BIClistfilename,'BIClist');
%     maxIndexListfilename = [filepath,'\maxIndexList.mat'];
%     save(maxIndexListfilename,'maxIndexList');
    [~,~,~,TPMnum] = size(newTPM);
    finalNormalize(imageNamei,TPMnum,bbox,voxelsize,normprefix);
    deleteFiles(imageNamei);
    d.Value = i/n;
    if saveTPM == 0
        deleteTPMfiles(imageNamei,TPMnum);
    end
end