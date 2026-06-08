function dicom2bids_convert(DirA, DirB, dcm2niixPath, varargin)
% DICOM2BIDS_CONVERT  Convert a source directory containing DICOM files to a BIDS-style PET/CT/MR dataset.
%
% Usage:
%   dicom2bids_convert()
%   dicom2bids_convert(DirA, DirB)
%   dicom2bids_convert(DirA, DirB, dcm2niixPath)
%   dicom2bids_convert(DirA, DirB, dcm2niixPath, 'Name', Value, ...)
%
% Optional name-value:
%   'Compress'       (false)  Whether to output .nii.gz (-z y) instead of .nii (-z n)
%   'Modalities'     ({'pet','ct','mr'})  Only convert these modalities; others are logged as skipped
%   'ProgressFcn'    ([])    function_handle, called once for each key event
%                            Parameter is a struct with fields:
%                              .phase  'scan-start' / 'scan-done' /
%                                      'convert' / 'write' /
%                                      'done' / 'cancelled' / 'error'
%                              .i, .n   current progress
%                              .srcFolder, .dstFile, .msg, .level
%                              .stats   struct (done phase only)
%                              .log     struct (done phase only, includes failures etc.)
%   'CancelChecker'  ([])    function_handle, returns true to stop at the next loop boundary
%
% dcm2niix resolution order (when dcm2niixPath is empty):
%   1. Same directory as this .m file (SNBPI/Tools/dcm2niix.exe)
%   2. Tools/ directory one level above this .m file
%   3. System PATH
%
% Dependencies:
%   - dcm2niix (distributed with SNBPI toolbox, in the Tools folder)
%   - MATLAB Image Processing Toolbox (dicominfo)
%   - MATLAB R2021a+

    %% --- 0a. Input Processing --------------------------------------------------
    if nargin < 1 || isempty(DirA)
        DirA = uigetdir(pwd, 'Select the source DICOM folder DirA');
        if isequal(DirA, 0), disp('Cancelled.'); return; end
    end
    if nargin < 2 || isempty(DirB)
        DirB = uigetdir(pwd, 'Select the BIDS output folder DirB');
        if isequal(DirB, 0), disp('Cancelled.'); return; end
    end
    if nargin < 3, dcm2niixPath = ''; end

    if ~isfolder(DirA), error('Source folder does not exist: %s', DirA); end
    if ~isfolder(DirB), mkdir(DirB); end

    %% --- 0b. Name-Value Options ------------------------------------------------
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

    %% --- 1. Check dcm2niix and IPT --------------------------------------------
    if opts.EvaluateOnly
        dcm2niixCmd = '';
        dcm2niixVer = '';
    else
        dcm2niixCmd = resolveDcm2niix(dcm2niixPath);
        [status, verOut] = system(sprintf('"%s" -h', dcm2niixCmd));
        if status ~= 0 && ~contains(lower(verOut), 'dcm2niix')
            error('Failed to call dcm2niix (cmd=%s)\nOutput:\n%s', dcm2niixCmd, verOut);
        end
        dcm2niixVer = extractDcm2niixVersion(verOut);
        fprintf('Using dcm2niix: %s  (%s)\n', dcm2niixCmd, dcm2niixVer);
    end

    if ~(license('test','image_toolbox') && exist('dicominfo','file')==2)
        error('Image Processing Toolbox is required (for dicominfo).');
    end

    %% --- 2. Prepare Log -------------------------------------------------------
    logPath = fullfile(DirB, 'conversion_log.txt');
    log = struct('failures',{{}}, 'skipped',{{}}, 'headerIssues',{{}}, ...
                 'tracerUnknown',{{}}, 'modalityUnknown',{{}}, ...
                 'patientNameMissing',{{}}, 'dateBadFormat',{{}});

    %% --- 3. Scan All Subfolders Containing DICOM ------------------------------
    callProgress(opts, struct('phase','scan-start', 'msg', ...
                              sprintf('Scanning %s ...', DirA), 'level','info'));
    fprintf('Scanning %s ...\n', DirA);
    dicomFolders = findDicomFolders(DirA);
    nTotal = numel(dicomFolders);
    if nTotal == 0
        callProgress(opts, struct('phase','done', 'level','warn', ...
            'msg','No DICOM files found', ...
            'stats', struct('folders',0,'nii',0,'ok',0,'skipped',0,'failed',0), ...
            'log', log, 'cancelled', false));
        fprintf('No DICOM files found.\n'); return;
    end
    callProgress(opts, struct('phase','scan-done', 'n', nTotal, ...
        'msg', sprintf('Found %d DICOM sequence folders', nTotal), 'level','info'));
    fprintf('Found %d DICOM sequence folders.\n\n', nTotal);

    %% --- 3.5 Evaluation Mode: No Conversion, Only Scan Header Info -------------
    if opts.EvaluateOnly
        runEvaluation(dicomFolders, nTotal, opts);
        return;
    end

    %% --- 4. First Pass: Convert Each DICOM Folder to Temp, Collect Plans -------
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
        % --- Soft cancel check ---
        if isCancelled(opts), cancelled = true; break; end

        srcFolder = dicomFolders{fi};

        callProgress(opts, struct('phase','convert', 'i', fi, 'n', nTotal, ...
            'srcFolder', srcFolder, ...
            'msg', sprintf('[%d/%d] Converting: %s', fi, nTotal, srcFolder), ...
            'level','info'));

        if mod(fi, 25) == 0 || fi == 1 || fi == nTotal
            fprintf('[%d/%d] Converting: %s\n', fi, nTotal, srcFolder);
        end

        tmpDir = fullfile(tempRoot, sprintf('s%05d', fi));
        mkdir(tmpDir);

        nameFmt = '%p_%s_%r';
        baseCmd = sprintf('"%s" -z %s -b y -ba n -w 2 -f "%s" -o "%s" "%s"', ...
                          dcm2niixCmd, zFlag, nameFmt, tmpDir, srcFolder);
        [status, cmdOut] = system(baseCmd);
        niiList = dir(fullfile(tmpDir, ['*' niiExt]));

        % --- Dynamic series fallback: when merging fails by default or naming
        %     conflicts exceed 26 (a-z), dcm2niix reports "Too many NIFTI images
        %     with the name" and fails. Retry once with -m y to merge frames into
        %     a single 4D file. ---
        if (status ~= 0 || isempty(niiList)) && ...
                contains(cmdOut, 'Too many NIFTI images')
            cleanDir(tmpDir);                 % Clear partial output from first attempt
            mergeCmd = sprintf('"%s" -z %s -b y -ba n -m y -w 2 -f "%s" -o "%s" "%s"', ...
                               dcm2niixCmd, zFlag, nameFmt, tmpDir, srcFolder);
            callProgress(opts, struct('phase','convert', 'i', fi, 'n', nTotal, ...
                'srcFolder', srcFolder, 'level','warn', ...
                'msg', '  ! Detected multi-frame naming conflict, retrying with -m y to merge into 4D'));
            [status, cmdOut] = system(mergeCmd);
            niiList = dir(fullfile(tmpDir, ['*' niiExt]));
        end

        if status ~= 0 || isempty(niiList)
            log.failures{end+1, 1} = struct('src', srcFolder, ...
                                             'reason', strtrim(cmdOut));
            failedCount = failedCount + 1;
            callProgress(opts, struct('phase','convert', 'i', fi, 'n', nTotal, ...
                'srcFolder', srcFolder, 'level','error', ...
                'msg', sprintf('  X dcm2niix failed: %s', firstLine(cmdOut))));
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
                        'reason', sprintf('JSON decode failed (%s): %s', ...
                                          srcJson, ME.message));
                end
            end

            [fullData, sampleDicomPath] = readFirstDicomHeader(srcFolder);

            % Determine modality: OT checked before isempty
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

            % Modality whitelist filter
            if ~ismember(bidsModality, opts.Modalities)
                log.skipped{end+1,1} = struct('src', srcFolder, ...
                    'reason', sprintf('Modality filtered out (Modalities option does not include %s)', ...
                                      bidsModality));
                skippedCount = skippedCount + 1;
                continue;
            end

            % --- Derive sub ---
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
                issues{end+1} = sprintf('PatientName/ID both missing, sub=%s', subLabel); %#ok<AGROW>
            end

            % --- Derive ses ---
            [sesLabel, sesSourceUsed, dateOk] = deriveSes(bidsData, fullData);
            if ~dateOk
                log.dateBadFormat{end+1,1} = struct('src', srcFolder, ...
                    'fallback', sprintf('ses=%s (from %s)', sesLabel, sesSourceUsed));
            end

            % --- Derive trc ---
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
                        'reason', sprintf('Unknown modality value: %s', bidsModality));
                    skippedCount = skippedCount + 1;
                    continue;
            end

            % --- Derive sort key for run ordering ----------------------------
            % Primary: InstanceNumber extracted from dcm2niix filename (_\d+$).
            % This is a DICOM-standard globally unique incrementing counter
            % and is numerically reliable for frame ordering.
            % Fallback: SeriesNumber from JSON, then fi*1000+ni as last resort.
            tok = regexp(base, '_(\d+)$', 'tokens', 'once');
            if ~isempty(tok)
                sNum = str2double(tok{1});
            else
                sNum = getNum(bidsData, 'SeriesNumber');
                if isnan(sNum), sNum = fi*1000 + ni; end
            end

            % Secondary: AcquisitionTime parsed to total seconds for
            % cross-checking against InstanceNumber order.
            acqTimeSec = parseAcquisitionTime(getStr(bidsData, 'AcquisitionTime'));

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
            plan.acqTimeSec   = acqTimeSec;
            plan.issues       = issues;
            plan.fullData     = fullData;
            plans{end+1, 1} = plan; %#ok<AGROW>
        end
    end

    %% --- 5. Compute Run Numbers (By Group) -------------------------------------
    if ~isempty(plans)
        groupKeys = cellfun(@(p) sprintf('%s|%s|%s|%s|%s|%s', ...
                                         p.sub, p.ses, p.modality, ...
                                         p.trc, p.acq, p.suffix), ...
                            plans, 'UniformOutput', false);
        [uKeys, ~, gIdx] = unique(groupKeys);
        for k = 1:numel(uKeys)
            inds = find(gIdx == k);
            if numel(inds) >= 2
                % Primary sort: InstanceNumber (from filename _\d+, numeric)
                sNums = cellfun(@(p) p.seriesNumber, plans(inds));
                [~, order] = sort(sNums);
                for r = 1:numel(inds)
                    plans{inds(order(r))}.run = r;
                end

                % Cross-check against AcquisitionTime order (parsed seconds).
                % Warn when the two orderings disagree — indicates unusual DICOM.
                acqSecs = cellfun(@(p) p.acqTimeSec, plans(inds));
                if all(isfinite(acqSecs))
                    [~, orderAcq] = sort(acqSecs);
                    if ~isequal(order, orderAcq)
                        log.headerIssues{end+1,1} = struct( ...
                            'src', plans{inds(1)}.srcFolder, ...
                            'reason', sprintf( ...
                                ['Run order mismatch: InstanceNumber order differs from ' ...
                                 'AcquisitionTime order. Used InstanceNumber. ' ...
                                 'InstanceNumber ranks: [%s]  AcqTime ranks: [%s]'], ...
                                num2str(order(:)'), num2str(orderAcq(:)')));
                        fprintf(['  WARNING: run order mismatch (InstanceNumber vs ' ...
                                 'AcquisitionTime) in %s\n'], plans{inds(1)}.srcFolder);
                    end
                end
            else
                plans{inds}.run = 0;
            end
        end
    end

    %% --- 6. Second Pass: Write Each Plan to BIDS Location ----------------------
    fprintf('\nOrganizing into BIDS structure...\n');
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
                'reason', sprintf('File move failed: %s', ME.message));
            failedCount = failedCount + 1;
            callProgress(opts, struct('phase','write', 'i', pi, ...
                'n', numel(plans), 'srcFolder', p.srcFolder, ...
                'level','error', ...
                'msg', sprintf('  X Move failed: %s', ME.message)));
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
            'msg', sprintf('  -> %s', [baseName niiExt])));
    end

    %% --- 7. Write dataset_description.json ------------------------------------
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

    %% --- 8. participants.tsv -----------------------------------------------
    writeParticipantsTsv(fullfile(DirB,'participants.tsv'), participantsMap);

    %% --- 9. Append Log --------------------------------------------------------
    appendLog(logPath, DirA, DirB, dcm2niixCmd, dcm2niixVer, ...
              nTotal, niiTotal, successCount, skippedCount, failedCount, ...
              cancelled, log);

    fprintf('\n=========================================\n');
    if cancelled, fprintf('Cancelled (written files are kept).\n'); end
    fprintf('Scanned sequence folders: %d\n', nTotal);
    fprintf('Generated .nii files: %d (Success: %d  Skipped: %d  Failed: %d)\n', ...
            niiTotal, successCount, skippedCount, failedCount);
    fprintf('Log: %s\n', logPath);

    %% --- 10. Notify GUI Completion --------------------------------------------
    finalPhase = 'done';
    if cancelled, finalPhase = 'cancelled'; end
    callProgress(opts, struct( ...
        'phase',     finalPhase, ...
        'level',     'info', ...
        'msg',       'Conversion complete', ...
        'stats',     struct('folders',nTotal, 'nii',niiTotal, ...
                            'ok',successCount, 'skipped',skippedCount, ...
                            'failed',failedCount), ...
        'log',       log, ...
        'cancelled', cancelled, ...
        'logPath',   logPath, ...
        'outDir',    DirB));
end


%% ====================================================================
%% ============   Helper Subfunctions Below   ==========================
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
            if ~isfile(cand), error('dcm2niix not found in %s.', userPath); end
            cmd = cand;
        elseif isfile(userPath)
            cmd = userPath;
        else
            error('dcm2niixPath is neither a folder nor a file: %s', userPath);
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
    nBase = n(1:end-length(niiExt));  % Compatible with .nii.gz
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
    if fid < 0, warning('writeFullHeaderJson: unable to write %s', path); return; end
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
    if fid < 0, warning('writeJsonPretty: unable to write %s', path); return; end
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
    if fid < 0, warning('writeParticipantsTsv: unable to write %s', path); return; end
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

function sec = parseAcquisitionTime(t)
% Parse DICOM AcquisitionTime string (HH:MM:SS.ffffff or HHMMSS.ffffff)
% to total seconds. Returns NaN on failure.
    sec = NaN;
    if isempty(t), return; end
    t = strtrim(t);
    % Handle both "HH:MM:SS.fff" and "HHMMSS.fff" formats
    tok = regexp(t, '^(\d{2}):(\d{2}):(\d{2}(?:\.\d*)?)$', 'tokens', 'once');
    if isempty(tok)
        tok = regexp(t, '^(\d{2})(\d{2})(\d{2}(?:\.\d*)?)$', 'tokens', 'once');
    end
    if isempty(tok), return; end
    h = str2double(tok{1});
    m = str2double(tok{2});
    s = str2double(tok{3});
    if any(isnan([h m s])), return; end
    sec = h*3600 + m*60 + s;
end

function appendLog(path, srcRoot, dstRoot, dcmCmd, dcmVer, ...
                   nFolders, nNii, nOk, nSkip, nFail, cancelled, log)
    fid = fopen(path, 'a', 'n', 'UTF-8');
    if fid < 0, warning('appendLog: unable to write %s', path); return; end
    fprintf(fid, '\n=== Run %s ===\n', datestr(now,'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, 'Source:   %s\n', srcRoot);
    fprintf(fid, 'Dest:     %s\n', dstRoot);
    fprintf(fid, 'dcm2niix: %s (%s)\n', dcmCmd, dcmVer);
    if cancelled, fprintf(fid, '*** Run cancelled by user ***\n'); end
    fprintf(fid, '\n');
    fprintf(fid, '== Summary ==\n');
    fprintf(fid, 'Scanned sequence folders: %d\n', nFolders);
    fprintf(fid, 'Generated .nii files: %d\n', nNii);
    fprintf(fid, '  Written successfully:     %d\n', nOk);
    fprintf(fid, '  Skipped:         %d\n', nSkip);
    fprintf(fid, '  Failed:         %d\n', nFail);
    fprintf(fid, 'Warnings (total): patientNameMissing=%d dateBadFormat=%d headerIssues=%d tracerUnknown=%d modalityUnknown=%d\n\n', ...
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

function cleanDir(p)
% Delete all files under directory p (keep the directory itself), used to clean up partial output before retry.
    if ~isfolder(p), return; end
    items = dir(p);
    for i = 1:numel(items)
        if items(i).isdir, continue; end
        try, delete(fullfile(p, items(i).name)); catch, end
    end
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
                'status', 'error', 'statusMsg', 'Failed to read header info'));
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
            status = 'ot'; statusMsg = 'Other (OT)'; nOt = nOt + 1;
        elseif isempty(bidsModality)
            status = 'unknown_modality'; statusMsg = 'Unknown modality'; nUnknown = nUnknown + 1;
        elseif ~ismember(bidsModality, opts.Modalities)
            status = 'filtered'; statusMsg = sprintf('Filtered out (not selected: %s)', upper(bidsModality));
            nFiltered = nFiltered + 1;
        else
            status = 'ok'; statusMsg = 'Normal'; nOk = nOk + 1;
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
