function IntensityNormalize(imageNames,referenceName,prefix,methodID,d)

% 两种强度标准化方法，均值法和中值法

n = length(imageNames);

imageName1 = imageNames{1};
imageName1(end-1:end) = [];
referenceName = referenceName{1};
referenceName(end-1:end) = [];
referenceMask = deformImgBasedOnOtherImg(referenceName,imageName1);
referenceMask(isnan(referenceMask)) = 0;
referenceMask = referenceMask == 1;

for i=1:n
    imagenamei = imageNames{i};
    imagevi = spm_vol(imagenamei);
    imagei = spm_read_vols(imagevi);
    imagei(isnan(imagei)) =0;
    tImg = imagei(referenceMask);
    if methodID == 1
        imagei = imagei/mean(tImg(:));
    elseif methodID == 2
        imagei = imagei/median(tImg(:));
    end
    filename = imagevi.fname;
    [filepath,name,ext] = fileparts(filename);
    imagevi.fname = [filepath,'\',prefix,name,ext];
    spm_write_vol(spm_create_vol(imagevi),imagei);
    d.Value = i/n;
end
    