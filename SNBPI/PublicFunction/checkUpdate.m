function checkUpdate(showNoUpdateMsg)
% Check for new version on GitHub
% showNoUpdateMsg - whether to show prompt when no update is available
if nargin < 1
    showNoUpdateMsg = false;
end
url = 'https://raw.githubusercontent.com/ZhangTianhao1993/Spatial-Normalization-of-Brain-PET-Images/main/SNBPI/version.json';
try
    raw = webread(url, weboptions('Timeout', 5));
    remoteInfo = jsondecode(raw);
    remoteVer  = remoteInfo.version;
    localVer   = getLocalVersion();
    if compareVersion(remoteVer, localVer) > 0
        msg = sprintf(['New version v%s is available (current: v%s)\n\n'...
            'What''s new:\n%s\n\n'...
            'Would you like to download it?'], ...
            remoteVer, localVer, remoteInfo.description);
        if remoteInfo.mandatory
            uiwait(msgbox(sprintf('This is a mandatory update. Please download before use.\n\n%s', msg), ...
                'Mandatory Update', 'warn'));
            web(remoteInfo.download_url, '-browser');
            showInstallInstructions();
        else
            choice = questdlg(msg, 'Update Available', 'Download', 'Later', 'Download');
            if strcmp(choice, 'Download')
                web(remoteInfo.download_url, '-browser');
                showInstallInstructions();
            end
        end
    elseif showNoUpdateMsg
        msgbox(sprintf('You are using the latest version v%s.', localVer), 'Check for Updates');
    end
catch
    if showNoUpdateMsg
        warndlg('Unable to connect to the update server. Please check your network connection.', 'Update Check Failed');
    end
end
end

function showInstallInstructions()
% Show manual installation instructions after download
mainApp = which('SNBPI.mlapp');
if isempty(mainApp)
    oldPath = '(SNBPI installation folder not found, please locate it manually)';
else
    oldPath = fileparts(mainApp);
end
instructions = sprintf([...
    'The new version is being downloaded in your browser.\n\n' ...
    'Please follow these steps to install:\n\n' ...
    '1. Extract the downloaded ZIP file to a location of your choice.\n' ...
    '2. Remove the old version from MATLAB:\n' ...
    '      - Go to HOME -> Set Path, remove the old SNBPI folder, and click Save.\n' ...
    '      - Or delete the old folder directly:\n        %s\n' ...
    '3. Add the new SNBPI folder to the MATLAB path\n' ...
    '   (HOME -> Set Path -> Add with Subfolders -> Save).\n' ...
    '4. Restart SNBPI.\n\n' ...
    'Note: Please close SNBPI before deleting the old version.'], oldPath);
uiwait(msgbox(instructions, 'Manual Installation Required', 'help'));
end

function result = compareVersion(v1, v2)
% Compare version strings. Returns 1 if v1>v2, 0 if equal, -1 if v1<v2
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