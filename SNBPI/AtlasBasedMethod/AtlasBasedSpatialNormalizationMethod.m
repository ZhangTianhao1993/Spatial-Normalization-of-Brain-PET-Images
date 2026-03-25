function AtlasBasedSpatialNormalizationMethod(PETnames,bbox,vx,nf,rt,d,sT,sD)
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

% 创建数据队列，用于 worker → 主线程通信(该功能用于显示进度条)
q = parallel.pool.DataQueue;

% 主线程监听队列，每收到一条消息就更新进度条
count = 0;
afterEach(q, @(~) updateProgress());

d.Value = 0;
parfor i=1:n
    imageNamei = PETnames(i);
    imageNamei = imageNamei{1,1};
    imageNamei(end-1:end) = [];
    cleanImg(imageNamei);
    initialNormalize(imageNamei);
    [filepath,imagename,ext] = fileparts(imageNamei);
    yName = fullfile(filepath, ['y_c', imagename, '.nii']);
    delete(yName);
    matfilename = fullfile(filepath, ['c', imagename, '_seg8.mat']);
    delete(matfilename);
    tempImgName = fullfile(filepath, ['temp', imagename, ext]);
    maskstr = load(fullfile(mainfilepath, 'TPM', 'mask.mat'));
    mask = maskstr.mask;
    TPMstr = load(fullfile(mainfilepath, 'TPM', 'TPM.mat'));
    TPM = TPMstr.TPM;
    [newTPM,~,~] = computeNewTPM(tempImgName,TPM,mask,30,36,30,rt);
    [~,~,~,TPMnum] = size(newTPM);
    finalNormalize(imageNamei,TPMnum,bbox,vx,nf);
    deleteFiles(imageNamei);
    newyName = fullfile(filepath, ['y_', imagename, '.nii']);
    movefile(yName,newyName);
    %d.Value = i/n;
    if sT == 0
        deleteTPMfiles(imageNamei,TPMnum);
    end
    if sD == 0
        delete(newyName);
    end
    send(q,i);
end
d.Value = 1;
    function updateProgress()
        count = count + 1;
        d.Value = count / n;
    end
end