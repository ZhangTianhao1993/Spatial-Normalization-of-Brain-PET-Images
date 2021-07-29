function newImg = deformImgBasedOnOtherImg(originalImgName,referImgName)

referv = spm_vol(referImgName);
originv = spm_vol(originalImgName);
referImg = spm_read_vols(referv);
originImg = spm_read_vols(originv);

[refer_x,refer_y,refer_z] = size(referImg);
[origin_x,origin_y,origin_z] = size(originImg);

newImg = zeros(refer_x,refer_y,refer_z);

for i=1:refer_x
    for j=1:refer_y
        for k=1:refer_z
            physicalCoor = [i,j,k,1]*(referv.mat)';
            originCoor = physicalCoor/((originv.mat)');
            originCoor = round(originCoor);
            originX = max(min(originCoor(1),origin_x),1);
            originY = max(min(originCoor(2),origin_y),1);
            originZ = max(min(originCoor(3),origin_z),1);
            newImg(i,j,k) = originImg(originX,originY,originZ);
        end
    end
end
end
