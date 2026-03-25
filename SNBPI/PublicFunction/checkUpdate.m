function checkUpdate(showNoUpdateMsg)
% 检查 GitHub 上是否有新版本
% showNoUpdateMsg - 是否在没有更新时也弹出提示（手动检查时传 true）

if nargin < 1
    showNoUpdateMsg = false;
end

% GitHub raw 地址，直接访问 version.json 原始内容
url = 'https://raw.githubusercontent.com/ZhangTianhao1993/Spatial-Normalization-of-Brain-PET-Images/main/SNBPI/version.json';

try
    % 下载远程版本信息
    raw = webread(url, weboptions('Timeout', 5));
    remoteInfo = jsondecode(raw);
    remoteVer  = remoteInfo.version;
    localVer   = getLocalVersion();

    if compareVersion(remoteVer, localVer) > 0
        % 有新版本，弹出提示
        msg = sprintf(['发现新版本 v%s（当前 v%s）\n\n'...
                       '更新内容：\n%s\n\n'...
                       '是否前往下载？'], ...
                       remoteVer, localVer, remoteInfo.description);

        if remoteInfo.mandatory
            % 强制更新，不给拒绝选项
            uiwait(msgbox(['此更新为必要更新，请下载后再使用。\n' msg], ...
                '强制更新', 'warn'));
            web(remoteInfo.download_url, '-browser');
        else
            % 可选更新
            choice = questdlg(msg, '发现新版本', '下载更新', '稍后提醒', '跳过此版本', '下载更新');
            switch choice
                case '下载更新'
                    web(remoteInfo.download_url, '-browser');
                case '跳过此版本'
                    saveSkippedVersion(remoteVer);
            end
        end

    elseif showNoUpdateMsg
        msgbox(sprintf('当前已是最新版本 v%s', localVer), '检查更新');
    end

catch e
    if showNoUpdateMsg
        warndlg('无法连接到更新服务器，请检查网络连接。', '检查更新失败');
    end
    % 静默失败，不影响正常使用
end
end


function result = compareVersion(v1, v2)
% 比较版本号，v1>v2 返回1，v1==v2 返回0，v1<v2 返回-1
a = str2double(strsplit(v1, '.'));
b = str2double(strsplit(v2, '.'));
len = max(length(a), length(b));
a(end+1:len) = 0;
b(end+1:len) = 0;
for i = 1:len
    if a(i) > b(i);  result =  1; return; end
    if a(i) < b(i);  result = -1; return; end
end
result = 0;
end


function saveSkippedVersion(version)
% 记录用户选择跳过的版本，下次不再提示
str = which('SNBPI');
[mainfilepath,~,~] = fileparts(str);
skipFile = fullfile(mainfilepath, 'skipped_version.txt');
fid = fopen(skipFile, 'w');
fprintf(fid, '%s', version);
fclose(fid);
end