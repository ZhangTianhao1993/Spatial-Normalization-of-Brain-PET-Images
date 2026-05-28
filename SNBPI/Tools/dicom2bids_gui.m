function dicom2bids_gui()
% DICOM2BIDS_GUI  SNBPI: DICOM -> BIDS 转换器图形界面
%
% 调用:
%   dicom2bids_gui
%
% 依赖:
%   - dicom2bids_convert (同一文件夹或在 MATLAB path 上)
%   - MATLAB R2021a+ (uifigure / uigridlayout / uitable DoubleClickedFcn)

    %% ---- 状态变量 (闭包共享) -------------------------------------------
    cancelRequested = false;
    isRunning       = false;
    isEvalRunning   = false;
    lastStats       = struct();
    lastLog         = struct();
    lastOutDir      = '';

    PREF_GROUP = 'SNBPI_dicom2bids';

    % 上次路径
    lastDirA   = safeGetPref(PREF_GROUP, 'lastDirA', '');
    lastDirB   = safeGetPref(PREF_GROUP, 'lastDirB', '');
    lastDcmExe = safeGetPref(PREF_GROUP, 'lastDcmExe', '');

    %% ---- 主窗口 ---------------------------------------------------------
    fig = uifigure('Name', 'SNBPI — DICOM to BIDS Converter', ...
                   'Position', [200 120 900 660], ...
                   'CloseRequestFcn', @onClose);

    g = uigridlayout(fig, [8 1]);
    g.RowHeight   = {30, 30, 30, 40, 36, 22, 26, '1x'};
    g.RowSpacing  = 6;
    g.ColumnWidth = {'1x'};
    g.Padding     = [12 12 12 12];

    %% ---- 路径行 1: 源 DICOM --------------------------------------------
    [edtA, btnA] = makePathRow(g, '源 DICOM:', lastDirA);
    btnA.ButtonPushedFcn = @(~,~) onBrowseDir(edtA, '请选择源 DICOM 文件夹');

    %% ---- 路径行 2: 输出 BIDS --------------------------------------------
    [edtB, btnB] = makePathRow(g, '输出 BIDS:', lastDirB);
    btnB.ButtonPushedFcn = @(~,~) onBrowseDir(edtB, '请选择 BIDS 输出文件夹');

    %% ---- 路径行 3: dcm2niix ---------------------------------------------
    row3 = uigridlayout(g, [1 3]);
    row3.ColumnWidth = {110, '1x', 90};
    row3.Padding = [0 0 0 0];
    row3.ColumnSpacing = 8;
    uilabel(row3, 'Text', 'dcm2niix:', 'HorizontalAlignment','right');
    edtX = uieditfield(row3, 'text', 'Value', lastDcmExe, ...
        'Placeholder', '留空 = 自动从 SNBPI/Tools 定位');
    btnX = uibutton(row3, 'Text', '指定...', ...
        'ButtonPushedFcn', @(~,~) onBrowseFile(edtX, ...
            '选择 dcm2niix 可执行文件'));

    %% ---- 选项行 ---------------------------------------------------------
    optPanel = uipanel(g, 'BorderType','line', 'Title','');
    optG = uigridlayout(optPanel, [1 5]);
    optG.ColumnWidth = {130, 70, 70, 70, '1x'};
    optG.Padding = [10 4 10 4];
    optG.ColumnSpacing = 12;
    cbCompress = uicheckbox(optG, 'Text', '压缩 (.nii.gz)', 'Value', false);
    uilabel(optG, 'Text', '模态:', 'HorizontalAlignment','right');
    cbPet = uicheckbox(optG, 'Text', 'PET', 'Value', true);
    cbCt  = uicheckbox(optG, 'Text', 'CT',  'Value', true);
    cbMr  = uicheckbox(optG, 'Text', 'MR',  'Value', true);

    %% ---- 控制行 ---------------------------------------------------------
    ctrlG = uigridlayout(g, [1 7]);
    ctrlG.ColumnWidth = {90, 75, 75, 75, '1x', 200, 90};
    ctrlG.Padding = [0 0 0 0];
    ctrlG.ColumnSpacing = 8;

    btnStart = uibutton(ctrlG, 'Text', '▶ 开始', ...
        'BackgroundColor', [0.18 0.55 0.98], 'FontColor', [1 1 1], ...
        'FontWeight', 'bold', ...
        'ButtonPushedFcn', @onStart);

    btnEval = uibutton(ctrlG, 'Text', '评估预览', ...
        'BackgroundColor', [0.93 0.85 0.65], ...
        'ButtonPushedFcn', @onEval);

    btnCancel = uibutton(ctrlG, 'Text', '■ 停止', 'Enable', 'off', ...
        'ButtonPushedFcn', @onCancel);

    btnOpen = uibutton(ctrlG, 'Text', '打开输出', 'Enable', 'off', ...
        'ButtonPushedFcn', @onOpenOutput);

    uilabel(ctrlG, 'Text', '');  % 占位

    gauge = uigauge(ctrlG, 'linear', 'Limits', [0 100], 'Value', 0, ...
        'ScaleColors', {[0.18 0.55 0.98]}, ...
        'ScaleColorLimits', [0 100], ...
        'MajorTicks', [], 'MinorTicks', []);

    lblProgress = uilabel(ctrlG, 'Text', '0 / 0', ...
        'HorizontalAlignment','right', 'FontColor', [0.4 0.4 0.4]);

    %% ---- 状态行 ---------------------------------------------------------
    lblStatus = uilabel(g, 'Text', '就绪。', ...
        'FontColor', [0.4 0.4 0.4]);

    %% ---- 计数行 ---------------------------------------------------------
    lblCounts = uilabel(g, 'Text', '', ...
        'FontColor', [0.3 0.3 0.3], 'FontWeight', 'bold');

    %% ---- TabGroup -------------------------------------------------------
    tg = uitabgroup(g);

    % 日志 tab
    tabLog = uitab(tg, 'Title', '日志');
    tabLogG = uigridlayout(tabLog, [1 1]);
    tabLogG.Padding = [0 0 0 0];
    txtLog = uitextarea(tabLogG, 'Editable','off', 'Value', {''}, ...
        'FontName', 'Consolas');

    % 失败 tab
    tabFail = uitab(tg, 'Title', '失败 (0)');
    tabFailG = uigridlayout(tabFail, [1 1]);
    tabFailG.Padding = [0 0 0 0];
    tblFail = uitable(tabFailG, ...
        'ColumnName', {'源文件夹', '原因'}, ...
        'ColumnWidth', {320, 'auto'}, ...
        'Data', cell(0,2), ...
        'RowName', '', ...
        'DoubleClickedFcn', @onDoubleClickTable);

    % 跳过 tab
    tabSkip = uitab(tg, 'Title', '跳过 (0)');
    tabSkipG = uigridlayout(tabSkip, [1 1]);
    tabSkipG.Padding = [0 0 0 0];
    tblSkip = uitable(tabSkipG, ...
        'ColumnName', {'源文件夹', '原因'}, ...
        'ColumnWidth', {320, 'auto'}, ...
        'Data', cell(0,2), ...
        'RowName', '', ...
        'DoubleClickedFcn', @onDoubleClickTable);

    % 警告 tab (聚合: PatientName 缺失 / 日期异常 / 头问题 / Tracer 未识别 / Modality 未识别)
    tabWarn = uitab(tg, 'Title', '警告 (0)');
    tabWarnG = uigridlayout(tabWarn, [1 1]);
    tabWarnG.Padding = [0 0 0 0];
    tblWarn = uitable(tabWarnG, ...
        'ColumnName', {'类型', '源文件夹', '详情'}, ...
        'ColumnWidth', {120, 280, 'auto'}, ...
        'Data', cell(0,3), ...
        'RowName', '', ...
        'DoubleClickedFcn', @onDoubleClickTable);

    % 评估结果 tab
    tabEval = uitab(tg, 'Title', '评估结果 (0)');
    tabEvalG = uigridlayout(tabEval, [1 1]);
    tabEvalG.Padding = [0 0 0 0];
    tblEval = uitable(tabEvalG, ...
        'ColumnName', {'源文件夹', '模态', '序列描述', 'sub', 'ses', '示踪剂', '文件数', '状态'}, ...
        'ColumnWidth', {280, 45, 'auto', 70, 60, 65, 45, 55}, ...
        'Data', cell(0,8), ...
        'RowName', '', ...
        'DoubleClickedFcn', @onDoubleClickTable);

    %% =====================================================================
    %% 回调函数 (nested) ---------------------------------------------------
    %% =====================================================================

    function [edt, btn] = makePathRow(parent, labelText, defaultVal)
        rowG = uigridlayout(parent, [1 3]);
        rowG.ColumnWidth = {110, '1x', 90};
        rowG.Padding = [0 0 0 0];
        rowG.ColumnSpacing = 8;
        uilabel(rowG, 'Text', labelText, 'HorizontalAlignment','right');
        edt = uieditfield(rowG, 'text', 'Value', defaultVal);
        btn = uibutton(rowG, 'Text', '浏览...');
    end

    function onBrowseDir(edt, prompt)
        startDir = edt.Value;
        if isempty(startDir) || ~isfolder(startDir), startDir = pwd; end
        d = uigetdir(startDir, prompt);
        figure(fig);  % uigetdir 后把焦点拿回来
        if ~isequal(d, 0), edt.Value = d; end
    end

    function onBrowseFile(edt, prompt)
        startDir = pwd;
        if ~isempty(edt.Value) && isfile(edt.Value)
            startDir = fileparts(edt.Value);
        end
        if ispc, filt = {'*.exe','可执行文件 (*.exe)'; '*.*','所有文件'};
        else,    filt = {'*','所有文件'}; end
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
            uialert(fig, sprintf('源 DICOM 文件夹不存在:\n%s', DirA), '输入错误');
            return;
        end
        if isempty(DirB)
            uialert(fig, '请选择输出 BIDS 文件夹', '输入错误'); return;
        end
        if ~isempty(DcmX) && ~isfile(DcmX) && ~isfolder(DcmX)
            uialert(fig, sprintf('dcm2niix 路径无效:\n%s', DcmX), '输入错误');
            return;
        end

        mods = {};
        if cbPet.Value, mods{end+1} = 'pet'; end
        if cbCt.Value,  mods{end+1} = 'ct';  end
        if cbMr.Value,  mods{end+1} = 'mr';  end
        if isempty(mods)
            uialert(fig, '至少要勾选一种模态', '输入错误'); return;
        end

        % 保存路径偏好
        safeSetPref(PREF_GROUP, 'lastDirA',   DirA);
        safeSetPref(PREF_GROUP, 'lastDirB',   DirB);
        safeSetPref(PREF_GROUP, 'lastDcmExe', DcmX);

        % UI 切到运行态
        cancelRequested = false;
        isRunning = true;
        lastOutDir = DirB;
        setRunningState(true);
        clearResults();
        appendLogLine(sprintf('=== 开始: %s ===', datestr(now,'yyyy-mm-dd HH:MM:SS')));
        appendLogLine(sprintf('  源: %s', DirA));
        appendLogLine(sprintf('  目标: %s', DirB));
        appendLogLine(sprintf('  模态: %s    压缩: %s', ...
                              strjoin(mods,'/'), ternary(cbCompress.Value,'是','否')));

        % 跑
        try
            dicom2bids_convert(DirA, DirB, DcmX, ...
                'Compress',      cbCompress.Value, ...
                'Modalities',    mods, ...
                'ProgressFcn',   @onProgress, ...
                'CancelChecker', @() cancelRequested);
        catch ME
            appendLogLine(sprintf('!!! 错误: %s', ME.message));
            uialert(fig, sprintf('转换出错:\n%s', ME.message), '错误');
        end

        isRunning = false;
        setRunningState(false);
    end

    function onCancel(~, ~)
        if ~isRunning && ~isEvalRunning, return; end
        cancelRequested = true;
        appendLogLine('正在请求取消, 请稍候...');
        btnCancel.Enable = 'off';
        lblStatus.Text = '正在取消...';
    end

    function onEval(~, ~)
        if isRunning || isEvalRunning, return; end

        DirA = strtrim(edtA.Value);
        DirB = strtrim(edtB.Value);
        DcmX = strtrim(edtX.Value);

        if ~isfolder(DirA)
            uialert(fig, sprintf('源 DICOM 文件夹不存在:\n%s', DirA), '输入错误');
            return;
        end
        if isempty(DirB)
            uialert(fig, '请选择输出 BIDS 文件夹', '输入错误'); return;
        end

        safeSetPref(PREF_GROUP, 'lastDirA', DirA);
        safeSetPref(PREF_GROUP, 'lastDirB', DirB);
        safeSetPref(PREF_GROUP, 'lastDcmExe', DcmX);

        % UI 切到评估态
        cancelRequested = false;
        isEvalRunning   = true;
        tblEval.Data = cell(0,8);
        tabEval.Title = '评估结果 (0)';
        btnEval.Enable  = 'off';
        btnStart.Enable = 'off';
        btnCancel.Enable = 'on';
        btnCancel.Text = '停止评估';
        btnOpen.Enable  = 'off';
        lblCounts.Text = '';
        gauge.Value = 0;
        lblProgress.Text = '评估中...';
        lblStatus.Text = '正在评估...';
        drawnow;

        try
            dicom2bids_convert(DirA, DirB, DcmX, ...
                'EvaluateOnly', true, ...
                'Modalities', getSelectedMods(), ...
                'ProgressFcn', @onEvalProgress, ...
                'CancelChecker', @() cancelRequested);
        catch ME
            lblStatus.Text = '评估出错';
            appendLogLine(sprintf('!!! 评估错误: %s', ME.message));
            uialert(fig, sprintf('评估出错:\n%s', ME.message), '错误');
        end

        isEvalRunning = false;
        btnEval.Enable  = 'on';
        btnStart.Enable = 'on';
        btnCancel.Enable = 'off';
        btnCancel.Text = '■ 停止';
        btnOpen.Enable = 'on';
    end

    function onEvalProgress(info)
        switch info.phase
            case 'scan-start'
                lblStatus.Text = info.msg;
                gauge.Value = 0;
                lblProgress.Text = '扫描中...';

            case 'scan-done'
                gauge.Value = 5;

            case 'evaluate-item'
                row = {info.srcFolder, info.modality, info.seriesDescription, ...
                       info.subLabel, info.sesLabel, info.trcLabel, ...
                       info.nDicomFiles, info.statusMsg};
                tblEval.Data = [tblEval.Data; row];
                tabEval.Title = sprintf('评估结果 (%d)', size(tblEval.Data,1));
                lblStatus.Text = sprintf('评估中 [%d/%d]', info.index, info.total);
                lblProgress.Text = sprintf('评估 %d / %d', info.index, info.total);
                gauge.Value = 5 + 85 * info.index / info.total;
                drawnow limitrate;

            case 'evaluate-done'
                lblStatus.Text = sprintf('评估完成: %d 个序列', info.total);
                lblProgress.Text = '';
                lblCounts.Text = sprintf(...
                    '序列: %d  |  正常: %d  已过滤: %d  模态未知: %d  其他(OT): %d  头信息错误: %d', ...
                    info.total, info.ok, info.filtered, info.unknown, info.ot, info.error);
                gauge.Value = 100;
                tabEval.Title = sprintf('评估结果 (%d/%d)', info.ok + info.filtered, info.total);

            case 'cancelled'
                lblStatus.Text = '评估已取消';
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
            uialert(fig, '输出文件夹不存在。', '提示');
            return;
        end
        openInFileManager(lastOutDir);
    end

    function onProgress(info)
        % 关键: 让 Cancel 等 UI 事件能被处理
        switch info.phase
            case 'scan-start'
                lblStatus.Text = info.msg;
                gauge.Value = 0;
                lblProgress.Text = '扫描中...';

            case 'scan-done'
                lblStatus.Text = info.msg;
                lblProgress.Text = sprintf('0 / %d', info.n);
                appendLogLine(info.msg);

            case 'convert'
                if isfield(info,'n') && info.n > 0
                    gauge.Value = round(50 * info.i / info.n);  % 第一遍占 0-50%
                    lblProgress.Text = sprintf('转换 %d / %d', info.i, info.n);
                end
                lblStatus.Text = sprintf('转换中: %s', shortPath(info.srcFolder, 80));
                if strcmpi(getf(info,'level','info'), 'error')
                    appendLogLine(info.msg);
                end

            case 'write'
                if isfield(info,'n') && info.n > 0
                    gauge.Value = round(50 + 50 * info.i / info.n);  % 第二遍 50-100%
                    lblProgress.Text = sprintf('写入 %d / %d', info.i, info.n);
                end
                if isfield(info,'dstFile') && ~isempty(info.dstFile)
                    lblStatus.Text = sprintf('写入: %s', info.dstFile);
                end
                appendLogLine(info.msg);

            case {'done','cancelled'}
                lastStats = info.stats;
                lastLog   = info.log;
                if isfield(info,'outDir'), lastOutDir = info.outDir; end
                gauge.Value = 100;

                if strcmp(info.phase, 'cancelled')
                    lblStatus.Text = '已取消 (部分结果已保留)。';
                    appendLogLine('=== 已取消 ===');
                else
                    lblStatus.Text = '完成。';
                    appendLogLine('=== 完成 ===');
                end

                lblCounts.Text = sprintf( ...
                    '扫描序列文件夹: %d   |   .nii 文件: %d   |   成功: %d   跳过: %d   失败: %d', ...
                    info.stats.folders, info.stats.nii, info.stats.ok, ...
                    info.stats.skipped, info.stats.failed);

                populateResultTables(info.log);

            case 'error'
                appendLogLine(['错误: ' info.msg]);
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

        % 失败/跳过表格: 第 1 列即源文件夹
        % 警告表格:    第 2 列才是源文件夹
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
            uialert(fig, sprintf('找不到文件夹:\n%s', target), '提示');
        end
    end

    function onClose(~, ~)
        if isRunning || isEvalRunning
            sel = uiconfirm(fig, ...
                '操作正在进行中, 确定关闭吗?', '关闭确认', ...
                'Options', {'取消并关闭', '继续运行'}, ...
                'DefaultOption', 2, 'CancelOption', 2);
            if strcmp(sel, '继续运行'), return; end
            cancelRequested = true;
            pause(0.5);
        end
        delete(fig);
    end

    %% ---- 辅助 ----------------------------------------------------------

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
        tabFail.Title = '失败 (0)';
        tabSkip.Title = '跳过 (0)';
        tabWarn.Title = '警告 (0)';
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
            % 防止日志过长拖慢界面
            if numel(cur) > 5000
                cur = [{'... (older lines trimmed) ...'}; cur(end-4000+1:end)];
            end
            txtLog.Value = cur;
        end
        try, scroll(txtLog, 'bottom'); catch, end
    end

    function populateResultTables(L)
        % 失败
        failData = cell(numel(L.failures), 2);
        for i = 1:numel(L.failures)
            x = L.failures{i};
            failData{i,1} = x.src;
            failData{i,2} = oneLine(x.reason);
        end
        tblFail.Data = failData;
        tabFail.Title = sprintf('失败 (%d)', numel(L.failures));

        % 跳过
        skipData = cell(numel(L.skipped), 2);
        for i = 1:numel(L.skipped)
            x = L.skipped{i};
            skipData{i,1} = x.src;
            skipData{i,2} = oneLine(x.reason);
        end
        tblSkip.Data = skipData;
        tabSkip.Title = sprintf('跳过 (%d)', numel(L.skipped));

        % 警告 (聚合 5 类)
        warnRows = {};
        for i = 1:numel(L.patientNameMissing)
            x = L.patientNameMissing{i};
            warnRows(end+1,:) = {'PatientName 缺失', x.src, oneLine(x.fallback)}; %#ok<AGROW>
        end
        for i = 1:numel(L.dateBadFormat)
            x = L.dateBadFormat{i};
            warnRows(end+1,:) = {'日期格式异常', x.src, oneLine(x.fallback)}; %#ok<AGROW>
        end
        for i = 1:numel(L.headerIssues)
            x = L.headerIssues{i};
            warnRows(end+1,:) = {'头信息异常', x.src, oneLine(x.reason)}; %#ok<AGROW>
        end
        for i = 1:numel(L.tracerUnknown)
            x = L.tracerUnknown{i};
            warnRows(end+1,:) = {'Tracer 未识别', x.src, ...
                oneLine(sprintf('SD="%s"  PN="%s"  Rad="%s"', x.sd, x.pn, x.rad))}; %#ok<AGROW>
        end
        for i = 1:numel(L.modalityUnknown)
            x = L.modalityUnknown{i};
            warnRows(end+1,:) = {'Modality 未识别', x.src, ...
                oneLine(sprintf('SD="%s"  PN="%s"', x.sd, x.pn))}; %#ok<AGROW>
        end
        if isempty(warnRows), warnRows = cell(0,3); end
        tblWarn.Data = warnRows;
        tabWarn.Title = sprintf('警告 (%d)', size(warnRows,1));
    end
end


%% ====================================================================
%% ============   独立辅助函数 (无闭包依赖)  ============================
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
