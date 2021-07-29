function IntensityNormalize(imageNames,referenceName,prefix,d)

n = length(imageNames);

imageName1 = imageNames{1};
imageName1(end-1:end) = [];
referenceName = referenceName{1};
referenceName(end-1:end) = [];
referenceImg = deformImgBasedOnOtherImg(referenceName,imageName1);
referenceImg(isnan(referenceImg)) = 0;

for i=1:n
    imagenamei = imageNames{i};
    imagevi = spm_vol(imagenamei);
    imagei = spm_read_vols(imagevi);
    imagei(isnan(imagei)) =0;
    tImg = imagei.*referenceImg;
    imagei = imagei/(sum(tImg(:))/sum(referenceImg(:)));
    filename = imagevi.fname;
    [filepath,name,ext] = fileparts(filename);
    imagevi.fname = [filepath,'\',prefix,name,ext];
    spm_write_vol(spm_create_vol(imagevi),imagei);
    d.Value = i/n;
end
    