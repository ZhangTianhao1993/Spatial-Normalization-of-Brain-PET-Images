function dicom2bids_convert(DirA, DirB, dcm2niixPath, varargin)
% DICOM2BIDS_CONVERT  把含 DICOM 的源目录转换为 BIDS 风格的 PET/CT/MR 数据集.
%
% 用法:
%   dicom2bids_convert()
%   dicom2bids_convert(DirA, DirB)
%   dicom2bids_convert(DirA, DirB, dcm2niixPath)
%   dicom2bids_convert(DirA, DirB, dcm2niixPath, 'Name', Value, ...)
%
% 可选 name-value:
%   'Compress'       (false) 是否输出 .nii.gz (-z y) 而非 .nii (-z n)
%   'Modalities'     ({'pet','ct','mr'})  仅转换这些模态, 其他记入 skipped
%   'ProgressFcn'    ([])    function_handle, 每个关键事件回调一次
%                            参数为 struct, 字段包括:
%                              .phase  'scan-start' / 'scan-done' /
%                                      'convert' / 'write' /
%                                      'done' / 'cancelled' / 'error'
%                              .i, .n   当前进度
%                              .srcFolder, .dstFile, .msg, .level
%                              .stats   struct (仅 done 阶段)
%                              .log     struct (仅 done 阶段, 含 failures 等)
%   'CancelChecker'  ([])    function_handle, 返回 true 即在下次循环边界停止
%
% dcm2niix 定位顺序 (dcm2niixPath 为空时):
%   1. 与本 .m 同目录 (SNBPI/Tools/dcm2niix.exe)
%   2. 本 .m 文件上一级 Tools/
%   3. 系统 PATH
%
% 依赖:
%   - dcm2niix (随 SNBPI 工具包分发, 在 Tools 文件夹)
%   - MATLAB Image Processing Toolbox (dicominfo)
%   - MATLAB R2021a+

    %% --- 0a. 输入处理 -----------------------------------------------------
    if nargin < 1 || isempty(DirA)
        DirA = uigetdir(pwd, '请选择源 DICOM 文件夹 DirA');
        if isequal(DirA, 0), disp('已取消。'); return; end
    end
    if nargin < 2 || isempty(DirB)
        DirB = uigetdir(pwd, '请选择 BIDS 输出文件夹 DirB');
        if isequal(DirB, 0), disp('已取消。'); return; end
    end
    if nargin < 3, dcm2niixPath = ''; end

    if ~isfolder(DirA), error('源文件夹不存在: %s', DirA); end
    if ~isfolder(DirB), mkdir(DirB); end

    %% --- 0b. name-value 选项 ---------------------------------------------
    ip = inputParser;
    ip.addParameter('Compress', false, @(x) islogical(x) && isscalar(x));
    ip.addParameter('Modalities', {'pet','ct','mr'}, ...
        @(x) iscellstr(x) || isstring(x));   %#ok<ISCLSTR>
    ip.addParameter('ProgressFcn',   [], @(x) isempty(x) || isa(x,'function_handle'));
    ip.addParameter('CancelChecker', [], @(x) isempty(x) || isa(x,'function_handle'));
    ip.addParameter('EvaluateOnly', false, @(x) islogical(x) && isscalar(x));
    ip.parse(varargin{:});
    opts = ip.Results;
    opts.Modalities = lower(cellstr(opts.Modalities));

    if opts.Compress
        niiExt = '.nii.gz'; zFlag = 'y';
    else
        niiExt = '.nii';    zFlag = 'n';
    end

    %% --- 1. 检查 dcm2niix 与 IPT -----------------------------------------
    if opts.EvaluateOnly
        dcm2niixCmd = '';
        dcm2niixVer = '';
    else
        dcm2niixCmd = resolveDcm2niix(dcm2niixPath);
        [status, verOut] = system(sprintf('"%s" -h', dcm2niixCmd));
        if status ~= 0 && ~contains(lower(verOut), 'dcm2niix')
            error('调用 dcm2niix 失败 (cmd=%s)\n输出:\n%s', dcm2niixCmd, verOut);
        end
        dcm2niixVer = extractDcm2niixVersion(verOut);
        fprintf('使用 dcm2niix: %s  (%s)\n', dcm2niixCmd, dcm2niixVer);
    end

    if ~(license('test','image_toolbox') && exist('dicominfo','file')==2)
        error('需要 Image Processing Toolbox (用于 dicominfo)。');
    end

    %% --- 2. 准备日志 ------------------------------------------------------
    logPath = fullfile(DirB, 'conversion_log.txt');
    log = struct('failures',{{}}, 'skipped',{{}}, 'headerIssues',{{}}, ...
                 'tracerUnknown',{{}}, 'modalityUnknown',{{}}, ...
                 'patientNameMissing',{{}}, 'dateBadFormat',{{}});

    %% --- 3. 扫描所有含 DICOM 的子文件夹 ----------------------------------
    callProgress(opts, struct('phase','scan-start', 'msg', ...
                              sprintf('扫描 %s ...', DirA), 'level','info'));
    fprintf('正在扫描 %s ...\n', DirA);
    dicomFolders = findDicomFolders(DirA);
    nTotal = numel(dicomFolders);
    if nTotal == 0
        callProgress(opts, struct('phase','done', 'level','warn', ...
            'msg','未找到任何 DICOM 文件', ...
            'stats', struct('folders',0,'nii',0,'ok',0,'skipped',0,'failed',0), ...
            'log', log, 'cancelled', false));
        fprintf('未找到任何 DICOM 文件。\n'); return;
    end
    callProgress(opts, struct('phase','scan-done', 'n', nTotal, ...
        'msg', sprintf('扫描到 %d 个 DICOM 序列文件夹', nTotal), 'level','info'));
    fprintf('共找到 %d 个 DICOM 序列文件夹。\n\n', nTotal);

    %% --- 3.5 评估模式: 不转换, 只扫描头信息 ---------------------------
    if opts.EvaluateOnly
        runEvaluation(dicomFolders, nTotal, opts);
        return;
    end

    %% --- 4. 第一遍: 转换每个 DICOM 文件夹到临时目录, 收集计划项 ----------
    plans = {};

    tempRoot = fullfile(tempdir, ...
        sprintf('snbpi_dcm2niix_%s', datestr(now,'yyyymmdd_HHMMSSFFF')));
    if isfolder(tempRoot), rmdir(tempRoot, 's'); end
    mkdir(tempRoot);
    cleanupTemp = onCleanup(@() safeRmdir(tempRoot)); %#ok<NASGU>

    successCount = 0; skippedCount = 0; failedCount = 0;
    niiTotal = 0;
    unknownPatientCounter = 0;
    unknownSubMap = containers.Map('KeyType','char','ValueType','char');
    cancelled = false;

    for fi = 1:nTotal
        % --- 软取消检查 ---
        if isCancelled(opts), cancelled = true; break; end

        srcFolder = dicomFolders{fi};

        callProgress(opts, struct('phase','convert', 'i', fi, 'n', nTotal, ...
            'srcFolder', srcFolder, ...
            'msg', sprintf('[%d/%d] 转换中: %s', fi, nTotal, srcFolder), ...
            'level','info'));

        if mod(fi, 25) == 0 || fi == 1 || fi == nTotal
            fprintf('[%d/%d] 转换中: %s\n', fi, nTotal, srcFolder);
        end

        tmpDir = fullfile(tempRoot, sprintf('s%05d', fi));
        mkdir(tmpDir);

        cmd = sprintf('"%s" -z %s -b y -ba n -w 2 -f "%%p_%%s" -o "%s" "%s"', ...
                      dcm2niixCmd, zFlag, tmpDir, srcFolder);
        [status, cmdOut] = system(cmd);

        niiList = dir(fullfile(tmpDir, ['*' niiExt]));
        if status ~= 0 || isempty(niiList)
            log.failures{end+1, 1} = struct('src', srcFolder, ...
                                             'reason', strtrim(cmdOut));
            failedCount = failedCount + 1;
            callProgress(opts, struct('phase','convert', 'i', fi, 'n', nTotal, ...
                'srcFolder', srcFolder, 'level','error', ...
                'msg', sprintf('  ✗ dcm2niix 失败: %s', firstLine(cmdOut))));
            continue;
        end

        for ni = 1:numel(niiList)
            niiTotal = niiTotal + 1;
            niiName = niiList(ni).name;
            base    = niiName(1:end-length(niiExt));
            srcNii  = fullfile(tmpDir, [base niiExt]);
            srcJson = fullfile(tmpDir, [base '.json']);
            if ~isfile(srcJson), srcJson = ''; end

            bidsData = struct();
            if ~isempty(srcJson)
                try
                    bidsData = jsondecode(fileread(srcJson));
                catch ME
                    log.headerIssues{end+1,1} = struct('src', srcFolder, ...
                        'reason', sprintf('JSON 解码失败 (%s): %s', ...
                                          srcJson, ME.message));
                end
            end

            [fullData, sampleDicomPath] = readFirstDicomHeader(srcFolder);

            % 决定模态: OT 先于 isempty
            [bidsModality, modSrc] = decideModality(bidsData, fullData);
            if strcmpi(modSrc, 'OT')
                log.skipped{end+1,1} = struct('src', srcFolder, ...
                    'reason', sprintf('Modality = OT (%s)', ...
                                      getStr(bidsData,'SeriesDescription')));
                skippedCount = skippedCount + 1;
                continue;
            end
            if isempty(bidsModality)
                log.modalityUnknown{end+1,1} = struct('src', srcFolder, ...
                    'sd', getStr(bidsData,'SeriesDescription'), ...
                    'pn', getStr(bidsData,'ProtocolName'));
                skippedCount = skippedCount + 1;
                continue;
            end

            % 模态白名单过滤
            if ~ismember(bidsModality, opts.Modalities)
                log.skipped{end+1,1} = struct('src', srcFolder, ...
                    'reason', sprintf('模态被过滤 (Modalities 选项不含 %s)', ...
                                      bidsModality));
                skippedCount = skippedCount + 1;
                continue;
            end

            % --- 派生 sub ---
            issues = {};
            [subLabel, subSourceUsed, hadName] = deriveSub(bidsData, fullData, srcFolder);
            if ~hadName
                log.patientNameMissing{end+1,1} = struct('src', srcFolder, ...
                    'fallback', sprintf('sub=%s (from %s)', subLabel, subSourceUsed));
            end
            if startsWith(subSourceUsed, 'unknown')
                if ~isKey(unknownSubMap, srcFolder)
                    unknownPatientCounter = unknownPatientCounter + 1;
                    unknownSubMap(srcFolder) = ...
                        sprintf('unknown%03d', unknownPatientCounter);
                end
                subLabel = unknownSubMap(srcFolder);
                issues{end+1} = sprintf('PatientName/ID 都缺失, sub=%s', subLabel); %#ok<AGROW>
            end

            % --- 派生 ses ---
            [sesLabel, sesSourceUsed, dateOk] = deriveSes(bidsData, fullData);
            if ~dateOk
                log.dateBadFormat{end+1,1} = struct('src', srcFolder, ...
                    'fallback', sprintf('ses=%s (from %s)', sesLabel, sesSourceUsed));
            end

            % --- 派生 trc ---
            trcLabel = deriveTracer(bidsData, fullData);
            if isempty(trcLabel) && strcmp(bidsModality, 'pet')
                log.tracerUnknown{end+1,1} = struct('src', srcFolder, ...
                    'sd', getStr(bidsData,'SeriesDescription'), ...
                    'pn', getStr(bidsData,'ProtocolName'), ...
                    'sd2', getStr(bidsData,'StudyDescription'), ...
                    'rad', getStr(bidsData,'Radiopharmaceutical'));
            end

            acqLabel = '';
            if strcmp(bidsModality, 'pet')
                acqLabel = derivePetAcq(bidsData);
            end

            switch bidsModality
                case 'pet', suffix = 'pet';
                case 'ct',  suffix = 'ct';
                case 'mr',  suffix = deriveMrSuffix(bidsData);
                otherwise
                    log.skipped{end+1,1} = struct('src', srcFolder, ...
                        'reason', sprintf('未知模态值: %s', bidsModality));
                    skippedCount = skippedCount + 1;
                    continue;
            end

            sNum = getNum(bidsData, 'SeriesNumber');
            if isnan(sNum), sNum = fi*1000 + ni; end

            plan = struct();
            plan.srcFolder    = srcFolder;
            plan.srcNii       = srcNii;
            plan.srcJson      = srcJson;
            plan.sampleDicom  = sampleDicomPath;
            plan.modality     = bidsModality;
            plan.sub          = subLabel;
            plan.ses          = sesLabel;
            plan.trc          = trcLabel;
            plan.acq          = acqLabel;
            plan.suffix       = suffix;
            plan.seriesNumber = sNum;
            plan.issues       = issues;
            plan.fullData     = fullData;
            plans{end+1, 1} = plan; %#ok<AGROW>
        end
    end

    %% --- 5. 计算 run 编号 (按分组) ----------------------------------------
    if ~isempty(plans)
        groupKeys = cellfun(@(p) sprintf('%s|%s|%s|%s|%s|%s', ...
                                         p.sub, p.ses, p.modality, ...
                                         p.trc, p.acq, p.suffix), ...
                            plans, 'UniformOutput', false);
        [uKeys, ~, gIdx] = unique(groupKeys);
        for k = 1:numel(uKeys)
            inds = find(gIdx == k);
            if numel(inds) >= 2
                sNums = cellfun(@(p) p.seriesNumber, plans(inds));
                [~, order] = sort(sNums);
                for r = 1:numel(inds)
                    plans{inds(order(r))}.run = r;
                end
            else
                plans{inds}.run = 0;
            end
        end
    end

    %% --- 6. 第二遍: 把每个 plan 写到 BIDS 位置 ---------------------------
    fprintf('\n开始组织到 BIDS 结构...\n');
    participantsMap = containers.Map('KeyType','char','ValueType','any');

    for pi = 1:numel(plans)
        if isCancelled(opts), cancelled = true; break; end
        p = plans{pi};

        modDir = fullfile(DirB, ['sub-' p.sub], ['ses-' p.ses], p.modality);
        if ~isfolder(modDir), mkdir(modDir); end

        baseName = buildBidsName(p);
        dstNii  = fullfile(modDir, [baseName niiExt]);
        dstJson = fullfile(modDir, [baseName '.json']);
        dstFull = fullfile(modDir, [baseName '_fullheader.json']);

        [dstNii, dstJson, dstFull] = ensureUniquePaths(dstNii, dstJson, dstFull, niiExt);

        try
            movefile(p.srcNii, dstNii, 'f');
            if ~isempty(p.srcJson) && isfile(p.srcJson)
                movefile(p.srcJson, dstJson, 'f');
            end
        catch ME
            log.failures{end+1,1} = struct('src', p.srcFolder, ...
                'reason', sprintf('移动文件失败: %s', ME.message));
            failedCount = failedCount + 1;
            callProgress(opts, struct('phase','write', 'i', pi, ...
                'n', numel(plans), 'srcFolder', p.srcFolder, ...
                'level','error', ...
                'msg', sprintf('  ✗ 移动失败: %s', ME.message)));
            continue;
        end

        writeFullHeaderJson(dstFull, p.fullData);

        if ~isKey(participantsMap, p.sub)
            participantsMap(p.sub) = struct( ...
                'patient_name', getStr(getJson(dstJson),'PatientName'), ...
                'patient_id',   getStr(getJson(dstJson),'PatientID'), ...
                'patient_sex',  getStr(getJson(dstJson),'PatientSex'), ...
                'patient_age',  getNumStr(getJson(dstJson),'PatientAge'), ...
                'patient_birth_date', getStr(getJson(dstJson),'PatientBirthDate'), ...
                'sessions', {{p.ses}});
        else
            v = participantsMap(p.sub);
            if ~ismember(p.ses, v.sessions)
                v.sessions{end+1} = p.ses;
                participantsMap(p.sub) = v;
            end
        end

        successCount = successCount + 1;
        callProgress(opts, struct('phase','write', 'i', pi, ...
            'n', numel(plans), 'srcFolder', p.srcFolder, ...
            'dstFile', [baseName niiExt], 'level','info', ...
            'msg', sprintf('  → %s', [baseName niiExt])));
    end

    %% --- 7. 写 dataset_description.json ----------------------------------
    ddPath = fullfile(DirB, 'dataset_description.json');
    if ~isfile(ddPath)
        dd = struct();
        dd.Name = 'PET-CT BIDS dataset (auto-generated)';
        dd.BIDSVersion = '1.8.0';
        dd.DatasetType = 'raw';
        dd.GeneratedBy = {struct('Name','dicom2bids_convert.m + dcm2niix',...
                                  'Version', dcm2niixVer)};
        writeJsonPretty(ddPath, dd);
    end

    %% --- 8. participants.tsv --------------------------------------------
    writeParticipantsTsv(fullfile(DirB,'participants.tsv'), participantsMap);

    %% --- 9. 追加日志 -----------------------------------------------------
    appendLog(logPath, DirA, DirB, dcm2niixCmd, dcm2niixVer, ...
              nTotal, niiTotal, successCount, skippedCount, failedCount, ...
              cancelled, log);

    fprintf('\n=========================================\n');
    if cancelled, fprintf('已取消 (但已写出的文件保留)。\n'); end
    fprintf('扫描序列文件夹: %d\n', nTotal);
    fprintf('产生 .nii 文件: %d (成功: %d  跳过: %d  失败: %d)\n', ...
            niiTotal, successCount, skippedCount, failedCount);
    fprintf('日志: %s\n', logPath);

    %% --- 10. 通知 GUI 完成 ----------------------------------------------
    finalPhase = 'done';
    if cancelled, finalPhase = 'cancelled'; end
    callProgress(opts, struct( ...
        'phase',     finalPhase, ...
        'level',     'info', ...
        'msg',       '转换完成', ...
        'stats',     struct('folders',nTotal, 'nii',niiTotal, ...
                            'ok',successCount, 'skipped',skippedCount, ...
                            'failed',failedCount), ...
        'log',       log, ...
        'cancelled', cancelled, ...
        'logPath',   logPath, ...
        'outDir',    DirB));
end


%% ====================================================================
%% ============   以下为辅助子函数   ====================================
%% ====================================================================

function callProgress(opts, info)
    if ~isempty(opts.ProgressFcn)
        try
            opts.ProgressFcn(info);
        catch ME
            warning(ME.identifier, '%s', ME.message)
        end
    end
end

function tf = isCancelled(opts)
    tf = false;
    if ~isempty(opts.CancelChecker)
        try, tf = logical(opts.CancelChecker()); catch, tf = false; end
    end
end

function s = firstLine(s)
    if isempty(s), return; end
    nl = find(s == newline | s == char(13), 1, 'first');
    if ~isempty(nl), s = s(1:nl-1); end
    s = strtrim(s);
end

function cmd = resolveDcm2niix(userPath)
    if ~isempty(userPath)
        if isfolder(userPath)
            if ispc, cand = fullfile(userPath, 'dcm2niix.exe');
            else,    cand = fullfile(userPath, 'dcm2niix'); end
            if ~isfile(cand), error('在 %s 中未找到 dcm2niix。', userPath); end
            cmd = cand;
        elseif isfile(userPath)
            cmd = userPath;
        else
            error('dcm2niixPath 既不是文件夹也不是文件: %s', userPath);
        end
        return;
    end
    if ispc, exeName = 'dcm2niix.exe'; else, exeName = 'dcm2niix'; end
    thisDir = fileparts(mfilename('fullpath'));
    cand = fullfile(thisDir, exeName);
    if isfile(cand), cmd = cand; return; end
    cand = fullfile(thisDir, '..', 'Tools', exeName);
    if isfile(cand), cmd = cand; return; end
    cmd = exeName;
end

function v = extractDcm2niixVersion(out)
    tok = regexp(out, 'version\s+(v[\d\.]+\w*)', 'tokens', 'once');
    if isempty(tok), v = 'unknown'; else, v = tok{1}; end
end

function folders = findDicomFolders(rootDir)
    folders = {};
    folders = scanFolderRec(rootDir, folders);
end

function folders = scanFolderRec(currentDir, folders)
    items = dir(currentDir);
    hasDicom = false;
    for i = 1:numel(items)
        nm = items(i).name;
        if isequal(nm,'.') || isequal(nm,'..'), continue; end
        fullP = fullfile(currentDir, nm);
        if items(i).isdir
            folders = scanFolderRec(fullP, folders);
        elseif ~hasDicom && isDicomFile(fullP)
            hasDicom = true;
        end
    end
    if hasDicom, folders{end+1,1} = currentDir; end
end

function tf = isDicomFile(filePath)
    tf = false;
    fid = fopen(filePath, 'r');
    if fid < 0, return; end
    cu = onCleanup(@() fclose(fid)); %#ok<NASGU>
    try
        fseek(fid, 128, 'bof');
        magic = fread(fid, 4, 'uint8=>char')';
        if numel(magic) == 4 && strcmp(magic,'DICM'), tf = true; end
    catch, tf = false; end
end

function [info, sampleFile] = readFirstDicomHeader(folder)
    info = struct(); sampleFile = '';
    items = dir(folder);
    for i = 1:numel(items)
        if items(i).isdir, continue; end
        fp = fullfile(folder, items(i).name);
        if ~isDicomFile(fp), continue; end
        try
            info = dicominfo(fp);
            sampleFile = fp;
            return;
        catch, continue; end
    end
end

function [mod, modSrc] = decideModality(bids, full)
    mod = ''; modSrc = '';
    candidates = {getStr(bids,'Modality'), getStr(full,'Modality')};
    for i = 1:numel(candidates)
        v = upper(candidates{i});
        if isempty(v), continue; end
        modSrc = v;
        switch v
            case 'PT', mod = 'pet'; return;
            case 'CT', mod = 'ct';  return;
            case 'MR', mod = 'mr';  return;
            case 'OT', return;
        end
    end
    txt = lower([getStr(bids,'SeriesDescription') ' ' getStr(bids,'ProtocolName')]);
    if contains(txt, 'pet'), mod = 'pet'; modSrc = 'PT';
    elseif contains(txt, 'ct'), mod = 'ct'; modSrc = 'CT';
    elseif any(cellfun(@(k) contains(txt,k), ...
              {'bravo','propeller','flair','t1','t2','asl','mprage'}))
        mod = 'mr'; modSrc = 'MR';
    end
end

function [sub, source, hadName] = deriveSub(bids, full, srcFolder)
    hadName = false;
    candidates = {};
    s = getStr(bids,'PatientName');
    candidates{end+1} = struct('val',s,'src','PatientName_bids');
    if ~isempty(s), hadName = true; end
    candidates{end+1} = struct('val', getNestedFamilyName(full,'PatientName'), ...
                                'src','PatientName_full');
    candidates{end+1} = struct('val', getStr(bids,'PatientID'), 'src','PatientID_bids');
    candidates{end+1} = struct('val', getStr(full,'PatientID'), 'src','PatientID_full');
    [~, folderName] = fileparts(srcFolder);
    candidates{end+1} = struct('val', folderName, 'src','folderName');
    for i = 1:numel(candidates)
        cleaned = sanitizeLabel(candidates{i}.val);
        if ~isempty(cleaned)
            sub = upper(cleaned);
            source = candidates{i}.src;
            return;
        end
    end
    sub = 'UNKNOWN'; source = 'unknown';
end

function s = getNestedFamilyName(data, fname)
    s = '';
    if ~isstruct(data) || ~isfield(data, fname), return; end
    v = data.(fname);
    if ischar(v) || (isstring(v) && isscalar(v))
        s = char(v);
    elseif isstruct(v) && isfield(v,'FamilyName')
        s = char(v.FamilyName);
    end
end

function [ses, source, dateOk] = deriveSes(bids, full)
    ses = ''; source = ''; dateOk = false;
    dt = getStr(bids, 'AcquisitionDateTime');
    if length(dt) >= 10
        cand = regexprep(dt(1:10), '-', '');
        if length(cand) == 8 && all(isstrprop(cand,'digit'))
            ses = cand; source = 'AcquisitionDateTime'; dateOk = true; return;
        end
    end
    for fname = {'StudyDate','SeriesDate','AcquisitionDate'}
        v = getStr(full, fname{1});
        if length(v) == 8 && all(isstrprop(v,'digit'))
            ses = v; source = fname{1}; dateOk = true; return;
        end
    end
    for fname = {'StudyDate','SeriesDate'}
        v = getStr(bids, fname{1});
        if length(v) == 8 && all(isstrprop(v,'digit'))
            ses = v; source = ['bids_' fname{1}]; dateOk = true; return;
        end
    end
    ses = 'nodate'; source = 'fallback'; dateOk = false;
end

function trc = deriveTracer(bids, full)
    parts = {getStr(bids,'Radiopharmaceutical'), ...
             getStr(bids,'TracerName'), ...
             getStr(bids,'StudyDescription'), ...
             getStr(bids,'ProtocolName'), ...
             getStr(bids,'ProcedureStepDescription'), ...
             getStr(full,'Radiopharmaceutical'), ...
             getStr(full,'StudyDescription'), ...
             getStr(full,'ProtocolName'), ...
             getStr(full,'PerformedProcedureStepDescription')};
    txt = lower(strjoin(parts, ' '));
    rules = {
        {'av1451','av-1451'},                     'AV1451';
        {'apn-1607','apn1607'},                   'APN1607';
        {'av45','av-45'},                          'AV45';
        {'florbetaben'},                           'FBB';
        {'pib','pittsburgh'},                      'PIB';
        {'carfentanil'},                           'Carfentanil';
        {'cft'},                                   'CFT';
        {'fdg','fluorodeoxy'},                     'FDG';
        {'av1'},                                   'FBB';
    };
    for i = 1:size(rules,1)
        kws = rules{i,1};
        for k = 1:numel(kws)
            if contains(txt, kws{k}), trc = rules{i,2}; return; end
        end
    end
    trc = '';
end

function acq = derivePetAcq(bids)
    sd = lower(getStr(bids,'SeriesDescription'));
    if isempty(sd), acq = 'unknown'; return; end
    if contains(sd,'mac'), acq = 'MAC';
    elseif contains(sd,'nac'), acq = 'NAC';
    elseif contains(sd,'20min'), acq = '20min';
    elseif contains(sd,'4x5') || contains(sd,'4 x 5'), acq = 'dyn4x5';
    elseif contains(sd,'static'), acq = 'static';
    else, acq = 'unknown';
    end
end

function suffix = deriveMrSuffix(bids)
    sd = lower(getStr(bids,'SeriesDescription'));
    if isempty(sd), sd = lower(getStr(bids,'ProtocolName')); end
    if contains(sd,'flair') || contains(sd,'t2flair'), suffix = 'FLAIR';
    elseif contains(sd,'bravo') || contains(sd,'mprage') || ...
           (contains(sd,'t1') && ~contains(sd,'flair'))
        suffix = 'T1w';
    elseif contains(sd,'propeller') || contains(sd,'t2'), suffix = 'T2w';
    elseif contains(sd,'asl'), suffix = 'asl';
    else, suffix = 'mr';
    end
end

function name = buildBidsName(p)
    parts = {sprintf('sub-%s', p.sub), sprintf('ses-%s', p.ses)};
    if ~isempty(p.trc), parts{end+1} = sprintf('trc-%s', p.trc); end
    if ~isempty(p.acq), parts{end+1} = sprintf('acq-%s', p.acq); end
    if isfield(p,'run') && p.run >= 1
        parts{end+1} = sprintf('run-%d', p.run);
    end
    parts{end+1} = p.suffix;
    name = strjoin(parts, '_');
end

function [n, j, f] = ensureUniquePaths(n, j, f, niiExt)
    if ~isfile(n), return; end
    nBase = n(1:end-length(niiExt));  % 兼容 .nii.gz
    [dj, bj, ej] = fileparts(j);
    [df, bf, ef] = fileparts(f);
    k = 1;
    while true
        nn = sprintf('%s_dup%d%s', nBase, k, niiExt);
        if ~isfile(nn)
            n = nn;
            j = fullfile(dj, sprintf('%s_dup%d%s', bj, k, ej));
            f = fullfile(df, sprintf('%s_dup%d%s', bf, k, ef));
            return;
        end
        k = k + 1;
    end
end

function writeFullHeaderJson(path, info)
    if isempty(fieldnames(info)), return; end
    cleanInfo = sanitizeForJson(info);
    try
        s = jsonencode(cleanInfo, 'PrettyPrint', true);
    catch
        s = jsonencode(cleanInfo);
    end
    fid = fopen(path, 'w', 'n', 'UTF-8');
    if fid < 0, warning('writeFullHeaderJson: 无法写入 %s', path); return; end
    fprintf(fid, '%s', s); fclose(fid);
end

function out = sanitizeForJson(s)
    if isstruct(s)
        out = struct();
        f = fieldnames(s);
        for i = 1:numel(f)
            v = s.(f{i});
            if isnumeric(v) && (isa(v,'uint8')||isa(v,'int8')) && numel(v) > 256
                out.(f{i}) = sprintf('<binary, %d bytes>', numel(v));
            elseif isstruct(v)
                out.(f{i}) = arrayfun(@sanitizeForJson, v);
            elseif iscell(v)
                out.(f{i}) = cellfun(@sanitizeForJson, v, 'UniformOutput', false);
            else
                out.(f{i}) = v;
            end
        end
    elseif iscell(s)
        out = cellfun(@sanitizeForJson, s, 'UniformOutput', false);
    else
        out = s;
    end
end

function s = sanitizeLabel(s)
    if isempty(s), s = ''; return; end
    if ~ischar(s), s = char(s); end
    s = regexprep(s, '[^A-Za-z0-9]', '');
end

function s = getStr(data, fname)
    s = '';
    if ~isstruct(data) || ~isfield(data, fname), return; end
    v = data.(fname);
    if ischar(v) || (isstring(v) && isscalar(v))
        s = char(v);
    elseif isnumeric(v) && isscalar(v)
        s = num2str(v);
    end
end

function n = getNum(data, fname)
    n = NaN;
    if ~isstruct(data) || ~isfield(data, fname), return; end
    v = data.(fname);
    if isnumeric(v) && isscalar(v), n = double(v); end
end

function s = getNumStr(data, fname)
    n = getNum(data, fname);
    if isnan(n), s = getStr(data, fname); else, s = num2str(n); end
    if isempty(s), s = 'n/a'; end
end

function j = getJson(path)
    j = struct();
    if isfile(path)
        try, j = jsondecode(fileread(path)); catch, end
    end
end

function writeJsonPretty(path, data)
    try, s = jsonencode(data, 'PrettyPrint', true);
    catch, s = jsonencode(data); end
    fid = fopen(path, 'w', 'n', 'UTF-8');
    if fid < 0, warning('writeJsonPretty: 无法写入 %s', path); return; end
    fprintf(fid, '%s', s); fclose(fid);
end

function writeParticipantsTsv(path, newMap)
    existing = struct();
    if isfile(path)
        try
            T = readtable(path, 'FileType','text', 'Delimiter','\t');
            for i = 1:height(T)
                pid = T.participant_id{i};
                if startsWith(pid,'sub-'), pid = pid(5:end); end
                existing.(matlab.lang.makeValidName(['s_' pid])) = T(i,:);
            end
        catch, end
    end
    fid = fopen(path, 'w', 'n', 'UTF-8');
    if fid < 0, warning('writeParticipantsTsv: 无法写入 %s', path); return; end
    fprintf(fid, 'participant_id\tpatient_name\tpatient_id\tpatient_sex\tpatient_age\tpatient_birth_date\tn_sessions\n');
    keysAll = {};
    if ~isempty(fieldnames(existing)), keysAll = fieldnames(existing); end
    newKeys = newMap.keys;
    for i = 1:numel(newKeys)
        k = matlab.lang.makeValidName(['s_' newKeys{i}]);
        if ~ismember(k, keysAll), keysAll{end+1} = k; end %#ok<AGROW>
    end
    for i = 1:numel(keysAll)
        k = keysAll{i};
        sub = k(3:end);
        if newMap.isKey(sub)
            v = newMap(sub);
            row = {sub, nz(v.patient_name), nz(v.patient_id), ...
                   nz(v.patient_sex), nz(v.patient_age), ...
                   nz(v.patient_birth_date), num2str(numel(v.sessions))};
        else
            T = existing.(k);
            row = {sub, char(T.patient_name), char(T.patient_id), ...
                   char(T.patient_sex), char(T.patient_age), ...
                   char(T.patient_birth_date), num2str(T.n_sessions)};
        end
        fprintf(fid, 'sub-%s\t%s\t%s\t%s\t%s\t%s\t%s\n', row{:});
    end
    fclose(fid);
end

function s = nz(s), if isempty(s), s = 'n/a'; end, end

function appendLog(path, srcRoot, dstRoot, dcmCmd, dcmVer, ...
                   nFolders, nNii, nOk, nSkip, nFail, cancelled, log)
    fid = fopen(path, 'a', 'n', 'UTF-8');
    if fid < 0, warning('appendLog: 无法写入 %s', path); return; end
    fprintf(fid, '\n=== 运行 %s ===\n', datestr(now,'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '源:       %s\n', srcRoot);
    fprintf(fid, '目标:     %s\n', dstRoot);
    fprintf(fid, 'dcm2niix: %s (%s)\n', dcmCmd, dcmVer);
    if cancelled, fprintf(fid, '*** 运行被用户取消 ***\n'); end
    fprintf(fid, '\n');
    fprintf(fid, '== Summary ==\n');
    fprintf(fid, '扫描序列文件夹: %d\n', nFolders);
    fprintf(fid, '产生 .nii 文件: %d\n', nNii);
    fprintf(fid, '  成功写出:     %d\n', nOk);
    fprintf(fid, '  跳过:         %d\n', nSkip);
    fprintf(fid, '  失败:         %d\n', nFail);
    fprintf(fid, '警告(总): PatientName缺失=%d, 日期格式异常=%d, 头不全=%d, 示踪剂未识别=%d, 模态未识别=%d\n\n', ...
        numel(log.patientNameMissing), numel(log.dateBadFormat), ...
        numel(log.headerIssues), numel(log.tracerUnknown), numel(log.modalityUnknown));
    writeLogSection(fid, '== Failures ==', log.failures, ...
        @(x) sprintf('    Reason: %s', x.reason));
    writeLogSection(fid, '== Skipped ==', log.skipped, ...
        @(x) sprintf('    Reason: %s', x.reason));
    writeLogSection(fid, '== PatientName Missing ==', log.patientNameMissing, ...
        @(x) sprintf('    Fallback: %s', x.fallback));
    writeLogSection(fid, '== Date Format Issues ==', log.dateBadFormat, ...
        @(x) sprintf('    Fallback: %s', x.fallback));
    writeLogSection(fid, '== Header Issues ==', log.headerIssues, ...
        @(x) sprintf('    %s', x.reason));
    writeLogSection(fid, '== Tracer Unknown (PET) ==', log.tracerUnknown, ...
        @(x) sprintf(['    SeriesDescription: %s\n' ...
                      '    ProtocolName:      %s\n' ...
                      '    StudyDescription:  %s\n' ...
                      '    Radiopharmaceutical: %s'], ...
                     x.sd, x.pn, x.sd2, x.rad));
    writeLogSection(fid, '== Modality Unknown ==', log.modalityUnknown, ...
        @(x) sprintf(['    SeriesDescription: %s\n' ...
                      '    ProtocolName:      %s'], x.sd, x.pn));
    fclose(fid);
end

function writeLogSection(fid, title, items, formatter)
    if isempty(items), return; end
    fprintf(fid, '%s\n', title);
    for i = 1:numel(items)
        x = items{i};
        fprintf(fid, '[%d] %s\n', i, x.src);
        fprintf(fid, '%s\n', formatter(x));
    end
    fprintf(fid, '\n');
end

function safeRmdir(p)
    if isfolder(p), try, rmdir(p, 's'); catch, end, end
end

function runEvaluation(dicomFolders, nTotal, opts)
% Run in evaluation mode: scan DICOM headers, report metadata, no file conversion.
    nOk = 0; nFiltered = 0; nUnknown = 0; nOt = 0; nError = 0;

    for fi = 1:nTotal
        if isCancelled(opts), break; end
        srcFolder = dicomFolders{fi};

        % Read first DICOM header
        [fullData, ~] = readFirstDicomHeader(srcFolder);

        % Handle header read failure
        if isempty(fieldnames(fullData))
            callProgress(opts, struct(...
                'phase', 'evaluate-item', ...
                'index', fi, 'total', nTotal, ...
                'srcFolder', srcFolder, ...
                'modality', '', 'seriesDescription', '', ...
                'protocolName', '', ...
                'subLabel', '?', 'sesLabel', '?', 'trcLabel', '', ...
                'acqLabel', '', 'suffix', '', ...
                'nDicomFiles', countDicomFiles(srcFolder), ...
                'status', 'error', 'statusMsg', '头信息读取失败'));
            nError = nError + 1;
            continue;
        end

        nDicomFiles = countDicomFiles(srcFolder);
        sd = getStr(fullData, 'SeriesDescription');
        pn = getStr(fullData, 'ProtocolName');

        % Determine modality
        [bidsModality, modSrc] = decideModality(fullData, fullData);

        % Classify status
        if strcmp(modSrc, 'OT')
            status = 'ot'; statusMsg = '其他(OT)'; nOt = nOt + 1;
        elseif isempty(bidsModality)
            status = 'unknown_modality'; statusMsg = '模态未知'; nUnknown = nUnknown + 1;
        elseif ~ismember(bidsModality, opts.Modalities)
            status = 'filtered'; statusMsg = sprintf('已过滤(未勾选%s)', upper(bidsModality));
            nFiltered = nFiltered + 1;
        else
            status = 'ok'; statusMsg = '正常'; nOk = nOk + 1;
        end

        % Derive BIDS labels (for identifiable modalities)
        subLabel = ''; sesLabel = ''; trcLabel = ''; acqLabel = ''; suffix = '';
        if ~isempty(bidsModality) && ~strcmp(modSrc, 'OT')
            [subLabel, ~, ~] = deriveSub(fullData, fullData, srcFolder);
            [sesLabel, ~, ~] = deriveSes(fullData, fullData);
            trcLabel = deriveTracer(fullData, fullData);
            if strcmp(bidsModality, 'pet')
                acqLabel = derivePetAcq(fullData);
            end
            switch bidsModality
                case 'pet', suffix = 'pet';
                case 'ct',  suffix = 'ct';
                case 'mr',  suffix = deriveMrSuffix(fullData);
            end
        end

        callProgress(opts, struct(...
            'phase', 'evaluate-item', ...
            'index', fi, 'total', nTotal, ...
            'srcFolder', srcFolder, ...
            'modality', upper(bidsModality), ...
            'seriesDescription', sd, 'protocolName', pn, ...
            'subLabel', subLabel, 'sesLabel', sesLabel, ...
            'trcLabel', trcLabel, 'acqLabel', acqLabel, ...
            'suffix', suffix, ...
            'nDicomFiles', nDicomFiles, ...
            'status', status, 'statusMsg', statusMsg));
    end

    callProgress(opts, struct(...
        'phase', 'evaluate-done', ...
        'total', nTotal, ...
        'ok', nOk, 'filtered', nFiltered, ...
        'unknown', nUnknown, 'ot', nOt, 'error', nError));
end

function n = countDicomFiles(folder)
    n = 0;
    items = dir(folder);
    for i = 1:numel(items)
        if items(i).isdir, continue; end
        if isDicomFile(fullfile(folder, items(i).name))
            n = n + 1;
        end
    end
end
