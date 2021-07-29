function pImg = preProcessImg(rawImg,x,y,z)
% Preprocess the data

pImg = rawImg;

pImg(isnan(pImg)) = 0; 

xn =x;yn=y;zn=z;
pImg = resize3D(pImg,xn,yn,zn);

pImg = (pImg-mean(pImg(:)))/std(pImg(:));
pImg = pImg(:);

