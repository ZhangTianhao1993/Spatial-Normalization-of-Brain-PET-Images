function version = getLocalVersion()
% 读取本地版本号
str = which('SNBPI');
[mainfilepath,~,~] = fileparts(str);
versionFile = fullfile(mainfilepath, 'version.json');

fid = fopen(versionFile, 'r');
raw = fread(fid, inf, 'uint8=>char')';
fclose(fid);

info = jsondecode(raw);
version = info.version;
end