function cleanImg(imageNamei)
% Remove noise around the brain image
% Input:
% imageNamei - An image name
% Output:
%   A clean imge file. (.nii)
% Author: Zhang Tianhao, 2021/7/29
% =========================================================================
smoothImg(imageNamei);
v = spm_vol(imageNamei);
img = spm_read_vols(v);
[filepath,name,ext] = fileparts(imageNamei);
sImgName = [filepath,'\s',name,ext];
cleanImgName = [filepath,'\c',name,ext];
sImg = spm_read_vols(spm_vol(sImgName));
sImg(isnan(sImg)) = 0;
sImg(sImg<0) = 0;
thresholds = multithresh(sImg,8);
t = thresholds(1)*0.5;
mask = sImg>t;
mask = fillmask(mask);
maskImgName = [filepath,'\mask.nii'];
mv = v;
mv.fname = maskImgName;
spm_write_vol(spm_create_vol(mv),mask);
cImg = img.*mask;
cImg(cImg<0)=0;
cv = v;
cv.fname = cleanImgName;
spm_write_vol(spm_create_vol(cv),cImg);


