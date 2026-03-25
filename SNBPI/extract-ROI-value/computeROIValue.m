function [ROIValue,uniAtlas] = computeROIValue(imgNames,atlasName,extraROIMethod,d)

Imgnum = length(imgNames);
atlas = spm_read_vols(spm_vol(atlasName));
% fprintf('Convert image size to atlas size and use 4th degree B-spline interpolation\n');
% for i=1:Imgnum
%     imgNamei = imgNames{i};
%     imgNamei(end-1:end) = [];
%     deformImgBasedOnAtlas(imgNamei,atlasName);
%     [filepath,name,ext] = fileparts(imgNamei);
%     eimgNames(i) = {fullfile(filepath,['e',name,ext])};
% end

if strcmp(extraROIMethod,'weight')
    uniAtlas = -1;
    ROIValue = NaN(1,Imgnum);
    for i=1:Imgnum
        %t = spm_read_vols(spm_vol(imgNames{i}));
        t = deformImgBasedOnAtlas(imgNames{i},atlasName);
        ROIValue(1,i) = sum(t.*atlas,'all','omitnan')/sum(atlas,'all','omitnan');
        switch nargin
            case 4
                d.Value = i/Imgnum;
        end
    end
else
    uniAtlas = unique(atlas);
    uniAtlas(uniAtlas == 0) = [];
    ROInum = length(uniAtlas);
    ROIValue = NaN(ROInum,Imgnum);
    if strcmp(extraROIMethod,'mean')
        for i=1:Imgnum
            %t = spm_read_vols(spm_vol(eimgNames{i}));
            t = deformImgBasedOnAtlas(imgNames{i},atlasName);
            for j=1:ROInum
                ROIValue(j,i) = mean(t(atlas == uniAtlas(j)),'omitnan');
            end
            switch nargin
                case 4
                    d.Value = i/Imgnum;
            end
        end
    elseif strcmp(extraROIMethod,'median')
        for i=1:Imgnum
            %t = spm_read_vols(spm_vol(eimgNames{i}));
            t = deformImgBasedOnAtlas(imgNames{i},atlasName);
            for j=1:ROInum
                ROIValue(j,i) = median(t(atlas == uniAtlas(j)),'omitnan');
            end
            switch nargin
                case 4
                    d.Value = i/Imgnum;
            end
        end 
    end
end
end