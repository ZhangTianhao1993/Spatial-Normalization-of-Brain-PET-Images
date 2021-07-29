function ROIvalueCell = makeROIValueCell(imageNames,atlasName,atlasLabels)

filenum = length(imageNames);

PETImages = spm_read_vols(spm_vol(char(string(imageNames))));

imageName1 = imageNames{1};
imageName1(end-1:end) = [];
atlasName = atlasName{1};
atlasName(end-1:end) = [];
atlas = deformImgBasedOnOtherImg(atlasName,imageName1);


[ROIValue,uniAtlas] = computeROIValue(PETImages,atlas);

atlasnum = length(uniAtlas);
ROIvalueCell = cell(filenum+1,atlasnum+1);

ROIvalueCell(2:end,1) = imageNames;
ROIvalueCell(2:end,2:end) = num2cell(ROIValue)';
switch nargin
    case 3
        ROIvalueCell(1,2:end) = atlasLabels(:,1);
    case 2
        ROIvalueCell(1,2:end) = num2cell(uniAtlas);
end

