function deleteFiles(imageNamei)
% Delete files
[filepath,name,ext] = fileparts(imageNamei);
cName = [filepath,'\c',name,'.nii'];
sName = [filepath,'\s',name,'.nii'];
yName = [filepath,'\y_c',name,'.nii'];
delete(cName);
delete(sName);
delete(yName);
maskName = [filepath,'\mask.nii'];
delete(maskName);
tempNormName = [filepath,'\temp',name,ext];
delete(tempNormName);
matfilename = [filepath,'\c',name,'_seg8.mat'];
delete(matfilename);

