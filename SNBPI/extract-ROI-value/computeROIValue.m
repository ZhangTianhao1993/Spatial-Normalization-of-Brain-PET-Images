function [ROIValue,uniAtlas] = computeROIValue(PETImages,atlas)

[~,~,~,tn] = size(PETImages); 
uniAtlas = unique(atlas);
uniAtlas(uniAtlas == 0) = [];
ROInum = length(uniAtlas);
ROIValue = zeros(ROInum,tn);
for i=1:ROInum
    for j=1:tn
        t = PETImages(:,:,:,j);
        ROIValue(i,j) = mean(t(atlas == uniAtlas(i)),'omitnan');
    end
end
