function newImg = resize3D(rawImg,xn,yn,zn)
% 3D matrix zoom

[x,y,z] = size(rawImg);
t1 = (x-1)/(xn-1);
t2 = (y-1)/(yn-1);
t3 = (z-1)/(zn-1);
[Xq,Yq,Zq] = meshgrid((1:t2:y),(1:t1:x),(1:t3:z)); 
[X,Y,Z] = meshgrid(1:y,1:x,1:z);
newImg = interp3(X,Y,Z,rawImg,Xq,Yq,Zq,'cubic');