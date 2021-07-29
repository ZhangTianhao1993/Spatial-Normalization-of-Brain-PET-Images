function pImg = preProcessImg(rawImg,x,y,z)


% 将数据进行预处理
pImg = rawImg;
%去掉nan
pImg(isnan(pImg)) = 0; 
%平滑

%缩放
xn =x;yn=y;zn=z;
pImg = resize3D(pImg,xn,yn,zn);
%归一化(z变换)
pImg = (pImg-mean(pImg(:)))/std(pImg(:));
pImg = pImg(:);
% 稀疏化
% pImg = pImg.*mask;
% pImg = pImg(:);
% pImg = sparse(pImg);
