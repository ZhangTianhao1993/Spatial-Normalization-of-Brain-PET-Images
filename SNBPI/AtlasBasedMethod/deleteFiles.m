function deleteFiles(imageNamei)
% Delete files
[filepath,name,ext] = fileparts(imageNamei);
cName = fullfile(filepath, ['c', name, '.nii']);
sName = fullfile(filepath, ['s', name, '.nii']);
tempNormName = fullfile(filepath, ['temp', name, ext]);
matfilename = fullfile(filepath, ['c', name, '_seg8.mat']);
delete(cName);
delete(sName);
delete(tempNormName);
delete(matfilename);

