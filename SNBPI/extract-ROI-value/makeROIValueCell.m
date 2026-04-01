function ROIvalueCell = makeROIValueCell(imageNames,atlasName,extraROIMethod,d,atlasLabels)

filenum = length(imageNames);


%PETImages = spm_read_vols(spm_vol(char(string(imageNames))));
if isscalar(atlasName)
    atlasName = atlasName{1};
    V = spm_vol(atlasName);
    atlasName = V.fname;
    [ROIValue,uniAtlas] = computeROIValue(imageNames,atlasName,extraROIMethod,d);
    
    atlasnum = length(uniAtlas);
    ROIvalueCell = cell(filenum+1,atlasnum+1);
    ROIvalueCell(1,1) = {'ImageFilePath'};
    ROIvalueCell(2:end,1) = imageNames;
    ROIvalueCell(2:end,2:end) = num2cell(ROIValue)';
    switch nargin
        case 5
            if uniAtlas ~=-1
                atlasValues = cell2mat(atlasLabels(:,2));
                [~,I] = sort(atlasValues);
                atlasLabels = atlasLabels(I,:);
                ROIvalueCell(1,2:end) = atlasLabels(:,1);
            else
                ROIvalueCell(1,2) = {'weighted_mean'};
            end

        case 4
            if uniAtlas == -1
                ROIvalueCell(1,2) = {'weighted_mean'};
            else
                ROIvalueCell(1,2:end) = cellstr(num2str(uniAtlas));
            end
    end
else
    atlasnum = length(atlasName);
    atlasshortname = cell(atlasnum,1);
    ROIvalueCell = cell(filenum+1,atlasnum+1);
    for i=1:atlasnum
        atlasNamei = atlasName(i);
        atlasNamei = atlasNamei{1};
        Vi = spm_vol(atlasNamei);
        atlasNamei = Vi.fname;
        [~,name,~] = fileparts(atlasNamei);
        atlasshortname(i) = cellstr(name);
        ROIValue= computeROIValue(imageNames,atlasNamei,extraROIMethod);
        ROIvalueCell(2:end,i+1) = num2cell(ROIValue,1)';
        d.Value = i/atlasnum;
    end
    ROIvalueCell(1,1) = {'ImageFilePath'};
    ROIvalueCell(2:end,1) = imageNames;
    ROIvalueCell(1,2:end) = atlasshortname;
end
end

