function [meanImg,referenceMask] = ...
    IntensityNormalize(imageNames,referenceName,prefix,methodID,d)

% Two intensity standardization methods: mean method and median method.

n = length(imageNames);

imageName1 = imageNames{1};
Vimg = spm_vol(imageName1);
imageName1 = Vimg.fname;
referenceName = referenceName{1};
Vref = spm_vol(referenceName);
referenceName = Vref.fname;
referenceMask = resampleImgToRef(referenceName,imageName1,'nearest');
referenceMask(isnan(referenceMask)) = 0;
referenceMask = referenceMask > 0.9;
v1 = spm_vol(imageName1);
meanImg = zeros(v1.dim);
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
    %imagevi.fname = [filepath,'\',prefix,name,ext];
    imagevi.fname = fullfile(filepath,[prefix,name,ext]);
    imagevi.dt = [16,0];
    spm_write_vol(spm_create_vol(imagevi),imagei);
    meanImg = meanImg + imagei/n;
    d.Value = i/n;
end
    