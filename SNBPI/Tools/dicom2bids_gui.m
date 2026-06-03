function dicom2bids_gui()
% DICOM2BIDS_GUI  SNBPI: DICOM -> BIDS Converter GUI
%
% Call:
%   dicom2bids_gui
%
% Dependencies:
%   - dicom2bids_convert (same folder or on MATLAB path)
%   - MATLAB R2021a+ (uifigure / uigridlayout / uitable DoubleClickedFcn)

    %% ---- State variables (closure-shared) ----------------------------------
    cancelRequested = false;
    isRunning       = false;
    isEvalRunning   = false;
    lastStats       = struct();
    lastLog         = struct();
    lastOutDir      = '';

    PREF_GROUP = 'SNBPI_dicom2bids';

    % Last used paths
    lastDirA   = safeGetPref(PREF_GROUP, 'lastDirA', '');
    lastDirB   = safeGetPref(PREF_GROUP, 'lastDirB', '');
    lastDcmExe = safeGetPref(PREF_GROUP, 'lastDcmExe', '');

    %% ---- Main window -------------------------------------------------------
    fig = uifigure('Name', 'SNBPI — DICOM to BIDS Converter', ...
                   'Position', [200 120 900 660], ...
                   'CloseRequestFcn', @onClose);

    g = uigridlayout(fig, [8 1]);
    g.RowHeight   = {30, 30, 30, 40, 36, 22, 26, '1x'};
    g.RowSpacing  = 6;
    g.ColumnWidth = {'1x'};
    g.Padding     = [12 12 12 12];

    %% ---- Path row 1: Source DICOM ------------------------------------------
    [edtA, btnA] = makePathRow(g, 'Source DICOM:', lastDirA);
    btnA.ButtonPushedFcn = @(~,~) onBrowseDir(edtA, 'Select source DICOM folder');

    %% ---- Path row 2: Output BIDS -------------------------------------------
    [edtB, btnB] = makePathRow(g, 'Output BIDS:', lastDirB);
    btnB.ButtonPushedFcn = @(~,~) onBrowseDir(edtB, 'Select BIDS output folder');

    %% ---- Path row 3: dcm2niix ----------------------------------------------
    row3 = uigridlayout(g, [1 3]);
    row3.ColumnWidth = {110, '1x', 90};
    row3.Padding = [0 0 0 0];
    row3.ColumnSpacing = 8;
    uilabel(row3, 'Text', 'dcm2niix:', 'HorizontalAlignment','right');
    edtX = uieditfield(row3, 'text', 'Value', lastDcmExe, ...
        'Placeholder', 'Leave empty = auto-locate from SNBPI/Tools');
    btnX = uibutton(row3, 'Text', 'Specify...', ...
        'ButtonPushedFcn', @(~,~) onBrowseFile(edtX, ...
            'Select dcm2niix executable'));

    %% ---- Options row -------------------------------------------------------
    optPanel = uipanel(g, 'BorderType','line', 'Title','');
    optG = uigridlayout(optPanel, [1 5]);
    optG.ColumnWidth = {130, 70, 70, 70, '1x'};
    optG.Padding = [10 4 10 4];
    optG.ColumnSpacing = 12;
    cbCompress = uicheckbox(optG, 'Text', 'Compress (.nii.gz)', 'Value', false);
    uilabel(optG, 'Text', 'Modality:', 'HorizontalAlignment','right');
    cbPet = uicheckbox(optG, 'Text', 'PET', 'Value', true);
    cbCt  = uicheckbox(optG, 'Text', 'CT',  'Value', true);
    cbMr  = uicheckbox(optG, 'Text', 'MR',  'Value', true);

    %% ---- Control row -------------------------------------------------------
    ctrlG = uigridlayout(g, [1 7]);
    ctrlG.ColumnWidth = {90, 75, 75, 75, '1x', 200, 90};
    ctrlG.Padding = [0 0 0 0];
    ctrlG.ColumnSpacing = 8;

    btnStart = uibutton(ctrlG, 'Text', '▶ Start', ...
        'BackgroundColor', [0.18 0.55 0.98], 'FontColor', [1 1 1], ...
        'FontWeight', 'bold', ...
        'ButtonPushedFcn', @onStart);

    btnEval = uibutton(ctrlG, 'Text', 'Evaluate Preview', ...
        'BackgroundColor', [0.93 0.85 0.65], ...
        'ButtonPushedFcn', @onEval);

    btnCancel = uibutton(ctrlG, 'Text', '■ Stop', 'Enable', 'off', ...
        'ButtonPushedFcn', @onCancel);

    btnOpen = uibutton(ctrlG, 'Text', 'Open Output', 'Enable', 'off', ...
        'ButtonPushedFcn', @onOpenOutput);

    uilabel(ctrlG, 'Text', '');  % Placeholder

    gauge = uigauge(ctrlG, 'linear', 'Limits', [0 100], 'Value', 0, ...
        'ScaleColors', {[0.18 0.55 0.98]}, ...
        'ScaleColorLimits', [0 100], ...
        'MajorTicks', [], 'MinorTicks', []);

    lblProgress = uilabel(ctrlG, 'Text', '0 / 0', ...
        'HorizontalAlignment','right', 'FontColor', [0.4 0.4 0.4]);

    %% ---- Status row --------------------------------------------------------
    lblStatus = uilabel(g, 'Text', 'Ready.', ...
        'FontColor', [0.4 0.4 0.4]);

    %% ---- Counts row --------------------------------------------------------
    lblCounts = uilabel(g, 'Text', '', ...
        'FontColor', [0.3 0.3 0.3], 'FontWeight', 'bold');

    %% ---- TabGroup ----------------------------------------------------------
    tg = uitabgroup(g);

    % Log tab
    tabLog = uitab(tg, 'Title', 'Log');
    tabLogG = uigridlayout(tabLog, [1 1]);
    tabLogG.Padding = [0 0 0 0];
    txtLog = uitextarea(tabLogG, 'Editable','off', 'Value', {''}, ...
        'FontName', 'Consolas');

    % Failed tab
    tabFail = uitab(tg, 'Title', 'Failed (0)');
    tabFailG = uigridlayout(tabFail, [1 1]);
    tabFailG.Padding = [0 0 0 0];
    tblFail = uitable(tabFailG, ...
        'ColumnName', {'Source Folder', 'Reason'}, ...
        'ColumnWidth', {320, 'auto'}, ...
        'Data', cell(0,2), ...
        'RowName', '', ...
        'DoubleClickedFcn', @onDoubleClickTable);

    % Skipped tab
    tabSkip = uitab(tg, 'Title', 'Skipped (0)');
    tabSkipG = uigridlayout(tabSkip, [1 1]);
    tabSkipG.Padding = [0 0 0 0];
    tblSkip = uitable(tabSkipG, ...
        'ColumnName', {'Source Folder', 'Reason'}, ...
        'ColumnWidth', {320, 'auto'}, ...
        'Data', cell(0,2), ...
        'RowName', '', ...
        'DoubleClickedFcn', @onDoubleClickTable);

    % Warnings tab (aggregated: PatientName missing / date invalid / header issues / Tracer unrecognized / Modality unrecognized)
    tabWarn = uitab(tg, 'Title', 'Warnings (0)');
    tabWarnG = uigridlayout(tabWarn, [1 1]);
    tabWarnG.Padding = [0 0 0 0];
    tblWarn = uitable(tabWarnG, ...
        'ColumnName', {'Type', 'Source Folder', 'Details'}, ...
        'ColumnWidth', {120, 280, 'auto'}, ...
        'Data', cell(0,3), ...
        'RowName', '', ...
        'DoubleClickedFcn', @onDoubleClickTable);

    % Evaluation tab
    tabEval = uitab(tg, 'Title', 'Evaluation (0)');
    tabEvalG = uigridlayout(tabEval, [1 1]);
    tabEvalG.Padding = [0 0 0 0];
    tblEval = uitable(tabEvalG, ...
        'ColumnName', {'Source Folder', 'Modality', 'Series Desc', 'sub', 'ses', 'Tracer', '#Files', 'Status'}, ...
        'ColumnWidth', {280, 45, 'auto', 70, 60, 65, 45, 55}, ...
        'Data', cell(0,8), ...
        'RowName', '', ...
        'DoubleClickedFcn', @onDoubleClickTable);

    %% =====================================================================
    %% Callback functions (nested) -----------------------------------------
    %% =====================================================================

    function [edt, btn] = makePathRow(parent, labelText, defaultVal)
        rowG = uigridlayout(parent, [1 3]);
        rowG.ColumnWidth = {110, '1x', 90};
        rowG.Padding = [0 0 0 0];
        rowG.ColumnSpacing = 8;
        uilabel(rowG, 'Text', labelText, 'HorizontalAlignment','right');
        edt = uieditfield(rowG, 'text', 'Value', defaultVal);
        btn = uibutton(rowG, 'Text', 'Browse...');
    end

    function onBrowseDir(edt, prompt)
        startDir = edt.Value;
        if isempty(startDir) || ~isfolder(startDir), startDir = pwd; end
        d = uigetdir(startDir, prompt);
        figure(fig);  % Bring focus back after uigetdir
        if ~isequal(d, 0), edt.Value = d; end
    end

    function onBrowseFile(edt, prompt)
        startDir = pwd;
        if ~isempty(edt.Value) && isfile(edt.Value)
            startDir = fileparts(edt.Value);
        end
        if ispc, filt = {'*.exe','Executable (*.exe)'; '*.*','All Files'};
        else,    filt = {'*','All Files'}; end
        [f, p] = uigetfile(filt, prompt, startDir);
        figure(fig);
        if ~isequal(f, 0), edt.Value = fullfile(p, f); end
    end

    function onStart(~, ~)
        if isRunning, return; end

        DirA = strtrim(edtA.Value);
        DirB = strtrim(edtB.Value);
        DcmX = strtrim(edtX.Value);

        if ~isfolder(DirA)
            uialert(fig, sprintf('Source DICOM folder does not exist:\n%s', DirA), 'Input Error');
            return;
        end
        if isempty(DirB)
            uialert(fig, 'Please select an output BIDS folder', 'Input Error'); return;
        end
        if ~isempty(DcmX) && ~isfile(DcmX) && ~isfolder(DcmX)
            uialert(fig, sprintf('Invalid dcm2niix path:\n%s', DcmX), 'Input Error');
            return;
        end

        mods = {};
        if cbPet.Value, mods{end+1} = 'pet'; end
        if cbCt.Value,  mods{end+1} = 'ct';  end
        if cbMr.Value,  mods{end+1} = 'mr';  end
        if isempty(mods)
            uialert(fig, 'At least one modality must be selected', 'Input Error'); return;
        end

        % Save path preferences
        safeSetPref(PREF_GROUP, 'lastDirA',   DirA);
        safeSetPref(PREF_GROUP, 'lastDirB',   DirB);
        safeSetPref(PREF_GROUP, 'lastDcmExe', DcmX);

        % Switch UI to running state
        cancelRequested = false;
        isRunning = true;
        lastOutDir = DirB;
        setRunningState(true);
        clearResults();
        appendLogLine(sprintf('=== Start: %s ===', datestr(now,'yyyy-mm-dd HH:MM:SS')));
        appendLogLine(sprintf('  Source: %s', DirA));
        appendLogLine(sprintf('  Target: %s', DirB));
        appendLogLine(sprintf('  Modalities: %s    Compress: %s', ...
                              strjoin(mods,'/'), ternary(cbCompress.Value,'Yes','No')));

        % Run
        try
            dicom2bids_convert(DirA, DirB, DcmX, ...
                'Compress',      cbCompress.Value, ...
                'Modalities',    mods, ...
                'ProgressFcn',   @onProgress, ...
                'CancelChecker', @() cancelRequested);
        catch ME
            appendLogLine(sprintf('!!! Error: %s', ME.message));
            uialert(fig, sprintf('Conversion error:\n%s', ME.message), 'Error');
        end

        isRunning = false;
        setRunningState(false);
    end

    function onCancel(~, ~)
        if ~isRunning && ~isEvalRunning, return; end
        cancelRequested = true;
        appendLogLine('Requesting cancellation, please wait...');
        btnCancel.Enable = 'off';
        lblStatus.Text = 'Cancelling...';
    end

    function onEval(~, ~)
        if isRunning || isEvalRunning, return; end

        DirA = strtrim(edtA.Value);
        DirB = strtrim(edtB.Value);
        DcmX = strtrim(edtX.Value);

        if ~isfolder(DirA)
            uialert(fig, sprintf('Source DICOM folder does not exist:\n%s', DirA), 'Input Error');
            return;
        end
        if isempty(DirB)
            uialert(fig, 'Please select an output BIDS folder', 'Input Error'); return;
        end

        safeSetPref(PREF_GROUP, 'lastDirA', DirA);
        safeSetPref(PREF_GROUP, 'lastDirB', DirB);
        safeSetPref(PREF_GROUP, 'lastDcmExe', DcmX);

        % Switch UI to evaluation state
        cancelRequested = false;
        isEvalRunning   = true;
        tblEval.Data = cell(0,8);
        tabEval.Title = 'Evaluation (0)';
        btnEval.Enable  = 'off';
        btnStart.Enable = 'off';
        btnCancel.Enable = 'on';
        btnCancel.Text = 'Stop Evaluation';
        btnOpen.Enable  = 'off';
        lblCounts.Text = '';
        gauge.Value = 0;
        lblProgress.Text = 'Evaluating...';
        lblStatus.Text = 'Evaluating...';
        drawnow;

        try
            dicom2bids_convert(DirA, DirB, DcmX, ...
                'EvaluateOnly', true, ...
                'Modalities', getSelectedMods(), ...
                'ProgressFcn', @onEvalProgress, ...
                'CancelChecker', @() cancelRequested);
        catch ME
            lblStatus.Text = 'Evaluation error';
            appendLogLine(sprintf('!!! Evaluation error: %s', ME.message));
            uialert(fig, sprintf('Evaluation error:\n%s', ME.message), 'Error');
        end

        isEvalRunning = false;
        btnEval.Enable  = 'on';
        btnStart.Enable = 'on';
        btnCancel.Enable = 'off';
        btnCancel.Text = '■ Stop';
        btnOpen.Enable = 'on';
    end

    function onEvalProgress(info)
        switch info.phase
            case 'scan-start'
                lblStatus.Text = info.msg;
                gauge.Value = 0;
                lblProgress.Text = 'Scanning...';

            case 'scan-done'
                gauge.Value = 5;

            case 'evaluate-item'
                row = {info.srcFolder, info.modality, info.seriesDescription, ...
                       info.subLabel, info.sesLabel, info.trcLabel, ...
                       info.nDicomFiles, info.statusMsg};
                tblEval.Data = [tblEval.Data; row];
                tabEval.Title = sprintf('Evaluation (%d)', size(tblEval.Data,1));
                lblStatus.Text = sprintf('Evaluating [%d/%d]', info.index, info.total);
                lblProgress.Text = sprintf('Evaluating %d / %d', info.index, info.total);
                gauge.Value = 5 + 85 * info.index / info.total;
                drawnow limitrate;

            case 'evaluate-done'
                lblStatus.Text = sprintf('Evaluation complete: %d series', info.total);
                lblProgress.Text = '';
                lblCounts.Text = sprintf(...
                    'Series: %d  |  OK: %d  Filtered: %d  Unknown Modality: %d  Other(OT): %d  Header Error: %d', ...
                    info.total, info.ok, info.filtered, info.unknown, info.ot, info.error);
                gauge.Value = 100;
                tabEval.Title = sprintf('Evaluation (%d/%d)', info.ok + info.filtered, info.total);

            case 'cancelled'
                lblStatus.Text = 'Evaluation cancelled';
                lblProgress.Text = '';
                gauge.Value = 0;
        end
        drawnow limitrate;
    end

    function mods = getSelectedMods()
        mods = {};
        if cbPet.Value, mods{end+1} = 'pet'; end
        if cbCt.Value,  mods{end+1} = 'ct';  end
        if cbMr.Value,  mods{end+1} = 'mr';  end
        if isempty(mods), mods = {'pet','ct','mr'}; end
    end

    function onOpenOutput(~, ~)
        if isempty(lastOutDir) || ~isfolder(lastOutDir)
            uialert(fig, 'Output folder does not exist.', 'Info');
            return;
        end
        openInFileManager(lastOutDir);
    end

    function onProgress(info)
        % Allow UI events (Cancel, etc.) to be processed
        switch info.phase
            case 'scan-start'
                lblStatus.Text = info.msg;
                gauge.Value = 0;
                lblProgress.Text = 'Scanning...';

            case 'scan-done'
                lblStatus.Text = info.msg;
                lblProgress.Text = sprintf('0 / %d', info.n);
                appendLogLine(info.msg);

            case 'convert'
                if isfield(info,'n') && info.n > 0
                    gauge.Value = round(50 * info.i / info.n);  % First pass 0-50%
                    lblProgress.Text = sprintf('Converting %d / %d', info.i, info.n);
                end
                lblStatus.Text = sprintf('Converting: %s', shortPath(info.srcFolder, 80));
                if strcmpi(getf(info,'level','info'), 'error')
                    appendLogLine(info.msg);
                end

            case 'write'
                if isfield(info,'n') && info.n > 0
                    gauge.Value = round(50 + 50 * info.i / info.n);  % Second pass 50-100%
                    lblProgress.Text = sprintf('Writing %d / %d', info.i, info.n);
                end
                if isfield(info,'dstFile') && ~isempty(info.dstFile)
                    lblStatus.Text = sprintf('Writing: %s', info.dstFile);
                end
                appendLogLine(info.msg);

            case {'done','cancelled'}
                lastStats = info.stats;
                lastLog   = info.log;
                if isfield(info,'outDir'), lastOutDir = info.outDir; end
                gauge.Value = 100;

                if strcmp(info.phase, 'cancelled')
                    lblStatus.Text = 'Cancelled (partial results retained).';
                    appendLogLine('=== Cancelled ===');
                else
                    lblStatus.Text = 'Done.';
                    appendLogLine('=== Done ===');
                end

                lblCounts.Text = sprintf( ...
                    'Series folders: %d   |   .nii files: %d   |   OK: %d   Skipped: %d   Failed: %d', ...
                    info.stats.folders, info.stats.nii, info.stats.ok, ...
                    info.stats.skipped, info.stats.failed);

                populateResultTables(info.log);

            case 'error'
                appendLogLine(['Error: ' info.msg]);
        end
        drawnow limitrate;
    end

    function onDoubleClickTable(src, event)
        try
            row = event.InteractionInformation.DisplayRow;
        catch
            row = [];
        end
        if isempty(row) || row < 1, return; end
        d = src.Data;
        if isempty(d) || row > size(d,1), return; end

        % Fail/Skip table: column 1 is the source folder
        % Warnings table:  column 2 is the source folder
        if size(d,2) >= 3
            target = d{row, 2};
        else
            target = d{row, 1};
        end
        if ~ischar(target), target = char(string(target)); end
        if ~isfolder(target) && isfile(target)
            target = fileparts(target);
        end
        if isfolder(target)
            openInFileManager(target);
        else
            uialert(fig, sprintf('Folder not found:\n%s', target), 'Info');
        end
    end

    function onClose(~, ~)
        if isRunning || isEvalRunning
            sel = uiconfirm(fig, ...
                'Operation in progress. Are you sure you want to close?', 'Confirm Close', ...
                'Options', {'Cancel and Close', 'Keep Running'}, ...
                'DefaultOption', 2, 'CancelOption', 2);
            if strcmp(sel, 'Keep Running'), return; end
            cancelRequested = true;
            pause(0.5);
        end
        delete(fig);
    end

    %% ---- Helper functions --------------------------------------------------

    function setRunningState(running)
        btnStart.Enable  = onoff(~running);
        btnEval.Enable   = onoff(~running);
        btnCancel.Enable = onoff( running);
        btnA.Enable      = onoff(~running);
        btnB.Enable      = onoff(~running);
        btnX.Enable      = onoff(~running);
        edtA.Editable    = onoff(~running);
        edtB.Editable    = onoff(~running);
        edtX.Editable    = onoff(~running);
        cbCompress.Enable= onoff(~running);
        cbPet.Enable     = onoff(~running);
        cbCt.Enable      = onoff(~running);
        cbMr.Enable      = onoff(~running);
        btnOpen.Enable   = onoff(~running && ~isempty(lastOutDir) && isfolder(lastOutDir));
        if running, lblCounts.Text = ''; end
    end

    function clearResults()
        txtLog.Value = {''};
        tblFail.Data = cell(0,2);
        tblSkip.Data = cell(0,2);
        tblWarn.Data = cell(0,3);
        tabFail.Title = 'Failed (0)';
        tabSkip.Title = 'Skipped (0)';
        tabWarn.Title = 'Warnings (0)';
        gauge.Value = 0;
        lblProgress.Text = '0 / 0';
        lblCounts.Text = '';
    end

    function appendLogLine(line)
        if isempty(line), return; end
        cur = txtLog.Value;
        if isempty(cur) || (numel(cur) == 1 && isempty(cur{1}))
            txtLog.Value = {line};
        else
            cur{end+1,1} = line;
            % Prevent log from growing too large and slowing down UI
            if numel(cur) > 5000
                cur = [{'... (older lines trimmed) ...'}; cur(end-4000+1:end)];
            end
            txtLog.Value = cur;
        end
        try, scroll(txtLog, 'bottom'); catch, end
    end

    function populateResultTables(L)
        % Failures
        failData = cell(numel(L.failures), 2);
        for i = 1:numel(L.failures)
            x = L.failures{i};
            failData{i,1} = x.src;
            failData{i,2} = oneLine(x.reason);
        end
        tblFail.Data = failData;
        tabFail.Title = sprintf('Failed (%d)', numel(L.failures));

        % Skipped
        skipData = cell(numel(L.skipped), 2);
        for i = 1:numel(L.skipped)
            x = L.skipped{i};
            skipData{i,1} = x.src;
            skipData{i,2} = oneLine(x.reason);
        end
        tblSkip.Data = skipData;
        tabSkip.Title = sprintf('Skipped (%d)', numel(L.skipped));

        % Warnings (aggregated into 5 categories)
        warnRows = {};
        for i = 1:numel(L.patientNameMissing)
            x = L.patientNameMissing{i};
            warnRows(end+1,:) = {'PatientName Missing', x.src, oneLine(x.fallback)}; %#ok<AGROW>
        end
        for i = 1:numel(L.dateBadFormat)
            x = L.dateBadFormat{i};
            warnRows(end+1,:) = {'Date Format Invalid', x.src, oneLine(x.fallback)}; %#ok<AGROW>
        end
        for i = 1:numel(L.headerIssues)
            x = L.headerIssues{i};
            warnRows(end+1,:) = {'Header Issue', x.src, oneLine(x.reason)}; %#ok<AGROW>
        end
        for i = 1:numel(L.tracerUnknown)
            x = L.tracerUnknown{i};
            warnRows(end+1,:) = {'Tracer Unrecognized', x.src, ...
                oneLine(sprintf('SD="%s"  PN="%s"  Rad="%s"', x.sd, x.pn, x.rad))}; %#ok<AGROW>
        end
        for i = 1:numel(L.modalityUnknown)
            x = L.modalityUnknown{i};
            warnRows(end+1,:) = {'Modality Unrecognized', x.src, ...
                oneLine(sprintf('SD="%s"  PN="%s"', x.sd, x.pn))}; %#ok<AGROW>
        end
        if isempty(warnRows), warnRows = cell(0,3); end
        tblWarn.Data = warnRows;
        tabWarn.Title = sprintf('Warnings (%d)', size(warnRows,1));
    end
end


%% ====================================================================
%% ============   Standalone helper functions (no closure deps) ========
%% ====================================================================

function openInFileManager(folder)
    if ispc
        try, winopen(folder); catch, system(['explorer "' folder '" &']); end
    elseif ismac
        system(['open "' folder '" &']);
    else
        system(['xdg-open "' folder '" &']);
    end
end

function s = oneLine(s)
    if isempty(s), s = ''; return; end
    if ~ischar(s), s = char(string(s)); end
    s = regexprep(s, '[\r\n\t]+', ' ');
    if length(s) > 300, s = [s(1:297) '...']; end
end

function v = getf(s, fname, default)
    if isstruct(s) && isfield(s, fname)
        v = s.(fname);
    else
        v = default;
    end
end

function v = safeGetPref(group, name, default)
    try
        if ispref(group, name), v = getpref(group, name); else, v = default; end
    catch
        v = default;
    end
end

function safeSetPref(group, name, value)
    try, setpref(group, name, value); catch, end
end

function s = onoff(tf)
    if tf, s = 'on'; else, s = 'off'; end
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end

function p = shortPath(p, maxLen)
    if length(p) <= maxLen, return; end
    p = ['...' p(end-maxLen+4:end)];
end
