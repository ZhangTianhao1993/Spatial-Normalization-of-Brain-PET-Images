function AtlasMergerTool()
% AtlasMergerTool - 交互式脑区Atlas合并工具
%
% 功能:
%   1. 加载 NIfTI 格式的 Atlas 图像及对应的 _Labels.mat 标签文件
%   2. 以四列交互界面显示图像、ROI列表、合并操作和合并结果
%   3. 勾选ROI后在图像上高亮对应脑区
%   4. 将选定的多个ROI合并为新ROI，输出新Atlas文件
%
% 依赖:
%   SPM12 (需已添加至 MATLAB 路径)
%
% 使用方法:
%   AtlasMergerTool()

%% ================================================================
%% 状态变量 (所有嵌套函数共享)
%% ================================================================
S.atlasFile    = '';
S.atlasVol     = [];       % SPM vol 结构体
S.atlasData    = [];       % 3D double 数组
S.Labels       = {};       % n×2 cell: {ROI名称(str), Index(double)}
S.nROI         = 0;
S.selected     = logical([]);  % n×1 logical，是否被勾选
S.disabled     = logical([]);  % n×1 logical，合并后禁用
S.mergedList   = {};       % 已合并ROI的cell数组（struct）
S.orientation  = 'axial';
S.currentSlice = 1;
S.nSlices      = 1;

%% ================================================================
%% 界面布局常量
%% ================================================================
FW   = 1600;   % 窗口宽度
FH   = 900;    % 窗口高度
colW = 378;    % 每列宽度
gap  = 8;      % 列间距
lm   = 5;      % 左边距
panH = FH - 92;  % 面板高度
panY = 45;        % 面板底部Y坐标
cX   = @(c) lm + (c-1)*(colW+gap);  % 第c列的X坐标

%% ================================================================
%% 创建主窗口
%% ================================================================
% 注意：CloseRequestFcn 须在 fig 赋值后再设置，
% 否则匿名函数捕获的是未赋值的 fig（MATLAB 经典陷阱）
fig = figure( ...
    'Name',        'Atlas ROI 合并工具 | AtlasMergerTool', ...
    'NumberTitle', 'off', ...
    'Position',    [20 30 FW FH], ...
    'MenuBar',     'none', ...
    'ToolBar',     'none', ...
    'Color',       [0.15 0.17 0.22], ...
    'Resize',      'off');
set(fig, 'CloseRequestFcn', @cb_close);

%% ================================================================
%% 顶部工具栏
%% ================================================================
% 选择文件按钮
uicontrol(fig, 'Style', 'pushbutton', ...
    'String',          '📂  选择 Atlas (.nii)', ...
    'Position',        [8 FH-42 175 33], ...
    'FontSize',        10, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.20 0.55 0.95], ...
    'ForegroundColor', 'white', ...
    'Callback',        @cb_selectAtlas);

hFileLbl = uicontrol(fig, 'Style', 'text', ...
    'String',           '← 请先选择 Atlas NIfTI 文件 (.nii)', ...
    'Position',         [192 FH-40 FW-400 26], ...
    'HorizontalAlignment', 'left', ...
    'FontSize',         9, ...
    'BackgroundColor',  [0.15 0.17 0.22], ...
    'ForegroundColor',  [0.65 0.75 0.85]);

%% ================================================================
%% 创建四个面板
%% ================================================================
panelColor = [0.18 0.20 0.26];
titleColor = [0.22 0.24 0.32];

p1 = makepanel(' ① 原始 Atlas 图像',      cX(1), panY, colW, panH);
p2 = makepanel(' ② ROI 列表（勾选高亮）', cX(2), panY, colW, panH);
p3 = makepanel(' ③ 合并操作',             cX(3), panY, colW, panH);
p4 = makepanel(' ④ 已合并 ROI 列表',      cX(4), panY, colW, panH);

    function p = makepanel(title_, x, y, w, h)
        p = uipanel(fig, ...
            'Units',           'pixels', ...     % 必须指定，默认是 normalized！
            'Title',           title_, ...
            'Position',        [x y w h], ...
            'FontSize',        10, 'FontWeight', 'bold', ...
            'ForegroundColor', [0.55 0.75 0.95], ...
            'BackgroundColor', panelColor, ...
            'BorderType',      'line', ...
            'HighlightColor',  [0.30 0.35 0.45]);
    end

%% ================================================================
%% 面板1: 图像显示
%% ================================================================
hAx = axes('Parent', p1, 'Units', 'pixels', ...
    'Position', [8 58 colW-16 panH-95]);
set(hAx, 'Color', 'k', 'XColor', 'none', 'YColor', 'none');
axis(hAx, 'image', 'off');

% 切片滑块
uicontrol(p1, 'Style', 'text', 'String', '切片:', ...
    'Position', [8 35 38 18], 'FontSize', 9, ...
    'BackgroundColor', panelColor, 'ForegroundColor', [0.75 0.85 0.95]);
hSlider = uicontrol(p1, 'Style', 'slider', ...
    'Position', [50 33 colW-108 22], 'Min', 1, 'Max', 2, 'Value', 1, ...
    'SliderStep', [1 1], 'Callback', @cb_slider, ...
    'BackgroundColor', [0.28 0.32 0.42]);
hSliceLbl = uicontrol(p1, 'Style', 'text', 'String', '-/-', ...
    'Position', [colW-54 33 50 20], 'FontSize', 9, ...
    'BackgroundColor', [0.10 0.12 0.16], 'ForegroundColor', [0.9 0.95 1.0], ...
    'HorizontalAlignment', 'center');

% 方向选择
hOrBG = uibuttongroup(p1, ...
    'Units',               'pixels', ...    % 必须指定，默认是 normalized！
    'Position',            [8 10 colW-16 22], ...
    'BorderType',          'none', ...
    'BackgroundColor',     panelColor, ...
    'SelectionChangedFcn', @cb_orientation);
hOrAx = makeRadio(hOrBG, 'Axial',    0,   1);
hOrCo = makeRadio(hOrBG, 'Coronal',  80,  0);
hOrSa = makeRadio(hOrBG, 'Sagittal', 165, 0);

    function rb = makeRadio(parent, str, x, val)
        rb = uicontrol(parent, 'Style', 'radiobutton', 'String', str, ...
            'Position', [x 2 80 18], 'Value', val, 'FontSize', 9, ...
            'BackgroundColor', panelColor, 'ForegroundColor', [0.80 0.90 1.0]);
    end

%% ================================================================
%% 面板2: ROI 列表（uitable）
%% ================================================================
hROITable = uitable(p2, ...
    'Position',    [5 5 colW-10 panH-32], ...
    'ColumnName',  {'ROI 名称', 'Index', '选择', '状态'}, ...
    'ColumnWidth', {152, 52, 45, 88}, ...
    'ColumnEditable', [false false true false], ...
    'ColumnFormat', {'char', 'numeric', 'logical', 'char'}, ...
    'RowName',     [], ...
    'Data',        {}, ...
    'FontSize',    9, ...
    'CellEditCallback', @cb_roiSelect);

%% ================================================================
%% 面板3: 合并操作
%% ================================================================
innerH = panH - 28;  % 面板内可用高度（减去标题栏）

% 已选ROI预览标签
uicontrol(p3, 'Style', 'text', 'String', '已勾选的 ROI（待合并）:', ...
    'Position', [8 innerH-28 220 20], 'FontSize', 9, ...
    'HorizontalAlignment', 'left', ...
    'BackgroundColor', panelColor, 'ForegroundColor', [0.65 0.80 0.95]);

% 已选ROI预览列表框
hPreview = uicontrol(p3, 'Style', 'listbox', ...
    'Position', [8 innerH-148 colW-16 118], ...
    'String', {}, 'FontSize', 9, 'Enable', 'inactive', ...
    'BackgroundColor', [0.10 0.12 0.18], ...
    'ForegroundColor', [0.85 0.95 0.75]);

% 分隔线（用文本模拟）
uicontrol(p3, 'Style', 'text', 'String', repmat('─', 1, 48), ...
    'Position', [8 innerH-158 colW-16 12], 'FontSize', 7, ...
    'BackgroundColor', panelColor, 'ForegroundColor', [0.35 0.40 0.55]);

% 合并后名称输入
uicontrol(p3, 'Style', 'text', 'String', '合并后 ROI 名称:', ...
    'Position', [8 innerH-180 160 18], 'FontSize', 9, ...
    'HorizontalAlignment', 'left', ...
    'BackgroundColor', panelColor, 'ForegroundColor', [0.75 0.85 0.95]);
hMergeName = uicontrol(p3, 'Style', 'edit', ...
    'Position', [8 innerH-206 colW-16 24], 'FontSize', 10, ...
    'BackgroundColor', [0.10 0.12 0.18], 'ForegroundColor', [0.95 0.98 1.0], ...
    'HorizontalAlignment', 'left');

% 合并后Index输入
uicontrol(p3, 'Style', 'text', 'String', '合并后 ROI Index（整数）:', ...
    'Position', [8 innerH-232 210 18], 'FontSize', 9, ...
    'HorizontalAlignment', 'left', ...
    'BackgroundColor', panelColor, 'ForegroundColor', [0.75 0.85 0.95]);
hMergeIdx = uicontrol(p3, 'Style', 'edit', ...
    'Position', [8 innerH-258 colW-16 24], 'FontSize', 10, ...
    'BackgroundColor', [0.10 0.12 0.18], 'ForegroundColor', [0.95 0.98 1.0], ...
    'HorizontalAlignment', 'left');

% Merge 按钮
hMergeBtn = uicontrol(p3, 'Style', 'pushbutton', ...
    'String',          '✔  Merge（合并选中 ROI）', ...
    'Position',        [8 innerH-308 colW-16 42], ...
    'FontSize',        12, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.10 0.60 0.30], ...
    'ForegroundColor', 'white', ...
    'Callback',        @cb_merge);

%% ================================================================
%% 面板4: 已合并ROI列表
%% ================================================================
hMergedTable = uitable(p4, ...
    'Position',    [5 5 colW-10 panH-32], ...
    'ColumnName',  {'合并 ROI 名称', 'Index', '包含原始 ROI'}, ...
    'ColumnWidth', {115, 48, 182}, ...
    'ColumnEditable', [false false false], ...
    'RowName',     [], ...
    'Data',        {}, ...
    'FontSize',    9);

%% ================================================================
%% 底部按钮栏
%% ================================================================
% 重置按钮
uicontrol(fig, 'Style', 'pushbutton', 'String', '↺  重置', ...
    'Position', [8 8 110 32], 'FontSize', 11, ...
    'BackgroundColor', [0.80 0.35 0.15], 'ForegroundColor', 'white', ...
    'Callback', @cb_reset);

% 生成新Atlas按钮
uicontrol(fig, 'Style', 'pushbutton', 'String', '💾  生成新 Atlas', ...
    'Position', [128 8 162 32], 'FontSize', 11, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.45 0.20 0.80], 'ForegroundColor', 'white', ...
    'Callback', @cb_generateAtlas);

% 状态栏
hStatus = uicontrol(fig, 'Style', 'text', ...
    'String', '就绪 | 请先加载 Atlas 文件', ...
    'Position', [300 8 FW-315 28], ...
    'HorizontalAlignment', 'left', 'FontSize', 9, ...
    'BackgroundColor', [0.15 0.17 0.22], ...
    'ForegroundColor', [0.45 0.75 0.45]);

%% ================================================================
%% 嵌套回调函数
%% ================================================================

%--- (1) 选择Atlas文件 -------------------------------------------
    function cb_selectAtlas(~, ~)
        [fname, fpath] = uigetfile('*.nii', '选择 Atlas NIfTI 文件');
        if isequal(fname, 0), return; end

        setStatus('⏳ 正在加载文件，请稍候...');

        fullPath = fullfile(fpath, fname);

        % 用SPM12加载NIfTI
        try
            vol  = spm_vol(fullPath);
            % 关键修复：round() 消除 float32→float64 的浮点误差
            % Atlas 的 Index 本质上都是整数，存为 float32 时会产生微小误差
            % 例如 1.0 可能变成 1.0000001192，直接比较会失败
            data = round(double(spm_read_vols(vol(1))));
        catch e
            errordlg(['NIfTI 加载失败：' e.message], '错误');
            setStatus('❌ 加载失败');
            return;
        end

        % 查找并加载 _Labels.mat
        [~, baseName] = fileparts(fname);
        labFile = fullfile(fpath, [baseName '_Labels.mat']);
        if ~exist(labFile, 'file')
            errordlg(sprintf('找不到对应的 Labels 文件：\n%s', labFile), '错误');
            setStatus('❌ 找不到 Labels 文件');
            return;
        end
        try
            tmp = load(labFile, 'Labels');
            if ~isfield(tmp, 'Labels')
                error('mat文件中没有变量 "Labels"');
            end
            Labels_ = tmp.Labels;
            % 统一将第1列（名称）转为 char，兼容 string 和 char 两种存储格式
            for ii = 1:size(Labels_, 1)
                if isstring(Labels_{ii, 1})
                    Labels_{ii, 1} = char(Labels_{ii, 1});
                end
            end
        catch e
            errordlg(['Labels 文件加载失败：' e.message], '错误');
            setStatus('❌ Labels 加载失败');
            return;
        end

        % 更新状态变量
        S.atlasFile    = fullPath;
        S.atlasVol     = vol(1);
        S.atlasData    = data;
        S.Labels       = Labels_;
        S.nROI         = size(Labels_, 1);
        S.selected     = false(S.nROI, 1);
        S.disabled     = false(S.nROI, 1);
        S.mergedList   = {};
        S.orientation  = 'axial';
        S.nSlices      = size(data, 3);
        S.currentSlice = max(1, round(S.nSlices / 2));

        % 重置方向选择为 Axial
        set(hOrBG, 'SelectedObject', hOrAx);

        % 更新UI
        set(hFileLbl, 'String', fullPath);
        refreshSlider();
        refreshROITable();
        set(hMergedTable, 'Data', {});
        set(hPreview,    'String', {});
        set(hMergeName,  'String', '');
        set(hMergeIdx,   'String', '');

        refreshImage();

        % 验证 Labels 中的 Index 是否能在图像中找到（帮助排查数据问题）
        allLabIdx  = cellfun(@(x) round(x), S.Labels(:,2));
        uniqueVox  = unique(data(:));
        uniqueVox  = uniqueVox(uniqueVox ~= 0);   % 去掉背景
        nFound     = sum(ismember(allLabIdx, uniqueVox));
        if nFound == 0
            warnMsg = sprintf(['⚠  警告：Labels 文件中的 %d 个 ROI Index 在图像中均未找到对应体素！\n' ...
                '请检查 Labels 的第2列 Index 是否与图像中的实际值匹配。\n' ...
                '图像中实际存在的非零值范围：[%g, %g]，Labels Index 范围：[%g, %g]'], ...
                S.nROI, min(uniqueVox), max(uniqueVox), min(allLabIdx), max(allLabIdx));
            warndlg(warnMsg, '数据不匹配警告');
            setStatus('⚠  已加载但 Labels Index 与图像值不匹配，请检查数据');
        else
            setStatus(sprintf('✅ 已加载：%s  |  共 %d 个 ROI（%d 个在当前图像中有体素）|  尺寸：%d×%d×%d', ...
                fname, S.nROI, nFound, size(data,1), size(data,2), size(data,3)));
        end
    end

%--- (2) ROI表格勾选回调 -----------------------------------------
    function cb_roiSelect(~, evt)
        r = evt.Indices(1);
        c = evt.Indices(2);
        if c ~= 3, return; end  % 只处理"选择"列

        % 如果该ROI已被禁用，撤销勾选
        if S.disabled(r)
            d = get(hROITable, 'Data');
            d{r, 3} = false;
            set(hROITable, 'Data', d);
            setStatus(sprintf('⚠  ROI "%s" 已参与合并，不可再选。请先按"生成新Atlas"或"重置"', S.Labels{r,1}));
            return;
        end

        S.selected(r) = evt.NewData;
        refreshPreview();
        refreshImage();
    end

%--- (3) Merge 按钮 -----------------------------------------------
    function cb_merge(~, ~)
        if isempty(S.atlasData)
            warndlg('请先加载 Atlas 文件', '提示'); return;
        end

        selIdx = find(S.selected & ~S.disabled);
        if isempty(selIdx)
            warndlg('请先在 ROI 列表中勾选至少一个 ROI', '提示'); return;
        end

        mName = strtrim(get(hMergeName, 'String'));
        mIdxStr = strtrim(get(hMergeIdx, 'String'));
        mIdx  = str2double(mIdxStr);

        % 输入验证
        if isempty(mName)
            warndlg('请输入合并后 ROI 的名称', '提示'); return;
        end
        if isnan(mIdx) || ~isfinite(mIdx)
            warndlg('请输入有效的 Index（整数）', '提示'); return;
        end
        mIdx = round(mIdx);

        % 检查名称和Index的唯一性
        for k = 1:numel(S.mergedList)
            if strcmp(S.mergedList{k}.name, mName)
                warndlg(sprintf('ROI 名称 "%s" 已存在，请使用不同名称', mName), '重复名称');
                return;
            end
            if S.mergedList{k}.newIndex == mIdx
                warndlg(sprintf('ROI Index %d 已存在，请使用不同 Index', mIdx), '重复 Index');
                return;
            end
        end

        % 构建合并条目
        m.name      = mName;
        m.newIndex  = mIdx;
        m.roiRows   = selIdx;
        m.origNames = S.Labels(selIdx, 1);
        m.origIdxs  = cell2mat(S.Labels(selIdx, 2));

        S.mergedList{end+1} = m;

        % 将已合并的ROI设为禁用
        S.disabled(selIdx) = true;
        S.selected(selIdx) = false;

        % 刷新界面
        refreshROITable();
        refreshMergedTable();
        refreshPreview();
        refreshImage();

        set(hMergeName, 'String', '');
        set(hMergeIdx,  'String', '');

        setStatus(sprintf('✅ 已合并为 "%s" (Index=%d)，包含 %d 个原始 ROI', ...
            mName, mIdx, numel(selIdx)));
    end

%--- (4) 生成新Atlas按钮 -----------------------------------------
    function cb_generateAtlas(~, ~)
        if isempty(S.atlasData)
            warndlg('请先加载 Atlas 文件', '提示'); return;
        end
        if isempty(S.mergedList)
            warndlg('目前没有已合并的 ROI，请先进行合并操作', '提示'); return;
        end

        % 输入新文件名
        ans_ = inputdlg('请输入新 Atlas 文件名（不含扩展名）:', '生成新 Atlas', 1, {'merged_atlas'});
        if isempty(ans_), return; end
        newBase = strtrim(ans_{1});
        if isempty(newBase)
            warndlg('文件名不能为空', '提示'); return;
        end
        % 去掉用户可能输入的扩展名
        newBase = strrep(newBase, '.nii', '');

        % 选择保存目录
        saveDir = uigetdir(fileparts(S.atlasFile), '选择保存目录');
        if isequal(saveDir, 0), return; end

        newNii = fullfile(saveDir, [newBase '.nii']);
        newMat = fullfile(saveDir, [newBase '_Labels.mat']);

        % 确认覆盖
        if exist(newNii, 'file') || exist(newMat, 'file')
            ans2 = questdlg(sprintf('文件已存在，是否覆盖？\n%s', newNii), ...
                '确认覆盖', '覆盖', '取消', '取消');
            if ~strcmp(ans2, '覆盖'), return; end
        end

        setStatus('⏳ 正在生成新 Atlas...');
        drawnow;

        % 构建新的atlas数据（背景为0）
        newData = zeros(size(S.atlasData));
        nMerged = numel(S.mergedList);
        Labels  = cell(nMerged, 2);  %#ok<NASGU>

        for k = 1:nMerged
            m = S.mergedList{k};
            Labels{k, 1} = m.name;
            Labels{k, 2} = m.newIndex;
            % 将所有原始ROI的voxel赋新Index
            for j = 1:numel(m.origIdxs)
                newData(S.atlasData == m.origIdxs(j)) = m.newIndex;
            end
        end

        % 用SPM12写入NIfTI
        try
            newVol         = S.atlasVol;
            newVol.fname   = newNii;
            newVol.descrip = sprintf('Merged Atlas - generated by AtlasMergerTool (%s)', datestr(now));
            % 根据最大Index选择数据类型
            maxIdx = max(cellfun(@(x) x.newIndex, S.mergedList));
            if maxIdx <= 32767
                newVol.dt = [spm_type('int16') spm_platform('bigend')];
            else
                newVol.dt = [spm_type('float32') spm_platform('bigend')];
            end
            spm_write_vol(newVol, newData);
        catch e
            errordlg(['写入 NIfTI 失败：' e.message], '错误');
            setStatus('❌ 生成失败');
            return;
        end

        % 保存Labels mat文件
        save(newMat, 'Labels');

        % ---- 保存合并信息文件（txt + mat 双格式）--------------------
        infoTxt = fullfile(saveDir, [newBase '_MergeInfo.txt']);
        infoMat = fullfile(saveDir, [newBase '_MergeInfo.mat']);
        try
            saveMergeInfo(infoTxt, infoMat, newBase, nMerged);
        catch e
            warndlg(['合并信息文件保存失败：' e.message], '警告');
        end

        msgbox(sprintf(['✅ 新 Atlas 已成功保存！\n\n', ...
            '图像文件：\n  %s\n\n', ...
            '标签文件：\n  %s\n\n', ...
            '合并信息（文本）：\n  %s\n\n', ...
            '合并信息（MAT）：\n  %s\n\n', ...
            '共 %d 个合并后的 ROI'], ...
            newNii, newMat, infoTxt, infoMat, nMerged), ...
            '生成成功', 'help');

        % 生成后恢复所有ROI为可选状态（需求3）
        S.disabled(:) = false;
        S.selected(:) = false;
        S.mergedList  = {};

        refreshROITable();
        refreshMergedTable();
        refreshPreview();
        refreshImage();

        setStatus(sprintf('✅ 新 Atlas 已保存至：%s  |  ROI 列表已重置为可选状态', newNii));
    end

%--- (5) 滑块回调 ------------------------------------------------
    function cb_slider(~, ~)
        if isempty(S.atlasData), return; end
        S.currentSlice = max(1, min(S.nSlices, round(get(hSlider, 'Value'))));
        set(hSliceLbl, 'String', sprintf('%d/%d', S.currentSlice, S.nSlices));
        refreshImage();
    end

%--- (6) 方向切换回调 --------------------------------------------
    function cb_orientation(~, evt)
        if isempty(S.atlasData), return; end
        switch evt.NewValue.String
            case 'Axial'
                S.orientation  = 'axial';
                S.nSlices      = size(S.atlasData, 3);
            case 'Coronal'
                S.orientation  = 'coronal';
                S.nSlices      = size(S.atlasData, 2);
            case 'Sagittal'
                S.orientation  = 'sagittal';
                S.nSlices      = size(S.atlasData, 1);
        end
        S.currentSlice = max(1, round(S.nSlices / 2));
        refreshSlider();
        refreshImage();
    end

%--- (7) 重置按钮 ------------------------------------------------
    function cb_reset(~, ~)
        ans3 = questdlg('确定要重置所有内容吗？（当前合并结果将全部清除）', ...
            '确认重置', '重置', '取消', '取消');
        if ~strcmp(ans3, '重置'), return; end

        S.atlasFile    = '';
        S.atlasVol     = [];
        S.atlasData    = [];
        S.Labels       = {};
        S.nROI         = 0;
        S.selected     = logical([]);
        S.disabled     = logical([]);
        S.mergedList   = {};
        S.orientation  = 'axial';
        S.currentSlice = 1;
        S.nSlices      = 1;

        set(hFileLbl,     'String', '← 请先选择 Atlas NIfTI 文件 (.nii)');
        set(hROITable,    'Data',   {});
        set(hMergedTable, 'Data',   {});
        set(hPreview,     'String', {});
        set(hMergeName,   'String', '');
        set(hMergeIdx,    'String', '');
        set(hSlider,      'Min', 1, 'Max', 2, 'Value', 1);
        set(hSliceLbl,    'String', '-/-');
        set(hOrBG,        'SelectedObject', hOrAx);
        cla(hAx);
        set(hAx, 'Color', 'k');

        setStatus('🔄 已重置 | 请重新加载 Atlas 文件');
    end

%% ================================================================
%% 辅助/刷新函数
%% ================================================================

%--- 更新切片滑块 ------------------------------------------------
    function refreshSlider()
        nS   = max(S.nSlices, 2);
        step = [1/(nS-1), min(1, 10/(nS-1))];
        set(hSlider, 'Min', 1, 'Max', nS, 'Value', S.currentSlice, ...
            'SliderStep', step);
        set(hSliceLbl, 'String', sprintf('%d/%d', S.currentSlice, S.nSlices));
    end

%--- 刷新ROI表格 -------------------------------------------------
    function refreshROITable()
        n = S.nROI;
        d = cell(n, 4);
        for i = 1:n
            % uitable 只接受 char，不接受 string —— 统一转换
            name = S.Labels{i, 1};
            if isstring(name), name = char(name); end
            d{i, 1} = name;
            d{i, 2} = S.Labels{i, 2};
            d{i, 3} = S.selected(i);
            if S.disabled(i)
                d{i, 4} = '✗ 已合并';
            else
                d{i, 4} = '✓ 可选';
            end
        end
        set(hROITable, 'Data', d);
    end

%--- 刷新待合并预览列表 ------------------------------------------
    function refreshPreview()
        selIdx = find(S.selected & ~S.disabled);
        if isempty(selIdx)
            set(hPreview, 'String', {});
        else
            strs = cell(numel(selIdx), 1);
            for k = 1:numel(selIdx)
                i = selIdx(k);
                name = S.Labels{i,1};
                if isstring(name), name = char(name); end
                strs{k} = sprintf('  %s   [Index: %g]', name, S.Labels{i,2});
            end
            set(hPreview, 'String', strs);
        end
    end

%--- 刷新已合并ROI表格 -------------------------------------------
    function refreshMergedTable()
        nM = numel(S.mergedList);
        d  = cell(nM, 3);
        for k = 1:nM
            m      = S.mergedList{k};
            d{k,1} = m.name;
            d{k,2} = m.newIndex;
            d{k,3} = strjoin(m.origNames, ', ');
        end
        set(hMergedTable, 'Data', d);
    end

%--- 刷新图像（含高亮） ------------------------------------------
    function refreshImage()
        if isempty(S.atlasData) || S.nROI == 0, return; end

        %% 1. 提取当前切片
        switch S.orientation
            case 'axial'
                sl = S.atlasData(:, :, S.currentSlice);
            case 'coronal'
                sl = squeeze(S.atlasData(:, S.currentSlice, :));
            case 'sagittal'
                sl = squeeze(S.atlasData(S.currentSlice, :, :));
        end
        sl = rot90(sl);          % 转为正常观察方向
        [H, W] = size(sl);

        %% 2. 为每个ROI预先分配颜色
        %   - 未选中：暗淡的 HSV 色（亮度约 0.40，饱和度低）
        %   - 已选中：鲜艳的 HSV 色（亮度 1.0，饱和度高）
        %   - 背景(0)：黑色
        nROI_   = S.nROI;
        % 使用线性间隔的色相，让相邻 ROI 颜色也有区别
        hues    = linspace(0, 1 - 1/nROI_, nROI_)';
        % 未选中时：低饱和、低亮度（保证可见但不抢眼）
        dimClr  = hsv2rgb([hues, repmat(0.55, nROI_, 1), repmat(0.45, nROI_, 1)]);
        % 选中时：高饱和、高亮度（鲜明高亮）
        selClr  = hsv2rgb([hues, ones(nROI_, 1), ones(nROI_, 1)]);

        %% 3. 逐像素填色（建立"标签索引→像素"映射）
        rgb = zeros(H, W, 3, 'double');   % 背景为黑
        for i = 1:nROI_
            roiVal = round(S.Labels{i, 2});   % round：防浮点误差
            mask   = (sl == roiVal);           % sl 已在加载时 round，比较安全
            if ~any(mask(:)), continue; end

            if S.selected(i)
                c = selClr(i, :);
            else
                c = dimClr(i, :);
            end
            rgb(:,:,1) = rgb(:,:,1) + mask * c(1);
            rgb(:,:,2) = rgb(:,:,2) + mask * c(2);
            rgb(:,:,3) = rgb(:,:,3) + mask * c(3);
        end

        %% 4. 在 axes 中显示
        imagesc(hAx, rgb);
        axis(hAx, 'image', 'off');
        set(hAx, 'XColor', 'none', 'YColor', 'none');
    end

%--- 更新状态栏 --------------------------------------------------
    function setStatus(msg)
        set(hStatus, 'String', msg);
        drawnow;
    end

%--- 保存合并信息（txt + mat）------------------------------------
    function saveMergeInfo(txtPath, matPath, newAtlasName, nMerged)
        % ---- 1. 构建结构化数据 ----
        % MergeInfo 是一个 struct array，每个元素对应一条合并记录
        MergeInfo = struct( ...
            'NewROI_Name',    {}, ...
            'NewROI_Index',   {}, ...
            'Orig_ROI_Names', {}, ...
            'Orig_ROI_Indices', {});

        for k = 1:nMerged
            m = S.mergedList{k};
            MergeInfo(k).NewROI_Name      = m.name;
            MergeInfo(k).NewROI_Index     = m.newIndex;
            MergeInfo(k).Orig_ROI_Names   = m.origNames;   % cell array of strings
            MergeInfo(k).Orig_ROI_Indices = m.origIdxs;    % double array
        end

        % 元信息
        MetaInfo.OrigAtlasFile  = S.atlasFile;
        MetaInfo.NewAtlasName   = newAtlasName;
        MetaInfo.NumMergedROIs  = nMerged;
        MetaInfo.NumOrigROIs    = S.nROI;
        MetaInfo.GeneratedTime  = datestr(now, 'yyyy-mm-dd HH:MM:SS');

        % ---- 2. 保存 MAT 文件 ----
        save(matPath, 'MergeInfo', 'MetaInfo');

        % ---- 3. 保存可读的 TXT 文件 ----
        fid = fopen(txtPath, 'w', 'n', 'UTF-8');
        if fid == -1
            error('无法创建文件：%s', txtPath);
        end

        % 文件头
        fprintf(fid, '================================================================\r\n');
        fprintf(fid, '  Atlas ROI 合并信息报告\r\n');
        fprintf(fid, '================================================================\r\n');
        fprintf(fid, '  生成时间    : %s\r\n', MetaInfo.GeneratedTime);
        fprintf(fid, '  原始 Atlas  : %s\r\n', MetaInfo.OrigAtlasFile);
        fprintf(fid, '  新 Atlas    : %s\r\n', MetaInfo.NewAtlasName);
        fprintf(fid, '  原始ROI总数 : %d\r\n', MetaInfo.NumOrigROIs);
        fprintf(fid, '  合并后ROI数 : %d\r\n', MetaInfo.NumMergedROIs);
        fprintf(fid, '================================================================\r\n\r\n');

        % 每条合并记录
        for k = 1:nMerged
            m = S.mergedList{k};
            nOrig = numel(m.origIdxs);

            fprintf(fid, '【合并 %d / %d】\r\n', k, nMerged);
            fprintf(fid, '  新脑区名称  : %s\r\n', m.name);
            fprintf(fid, '  新脑区Index : %d\r\n', m.newIndex);
            fprintf(fid, '  包含 %d 个原始脑区：\r\n', nOrig);
            for j = 1:nOrig
                fprintf(fid, '    [%d]  %s  (Index: %d)\r\n', ...
                    j, m.origNames{j}, m.origIdxs(j));
            end
            fprintf(fid, '\r\n');
        end

        % 附录：所有原始ROI的汇总表
        fprintf(fid, '================================================================\r\n');
        fprintf(fid, '  附录：原始 ROI → 新 ROI 完整映射表\r\n');
        fprintf(fid, '================================================================\r\n');
        fprintf(fid, '  %-40s  %-10s  ->  %-40s  %-10s\r\n', ...
            '原始ROI名称', '原始Index', '新ROI名称', '新Index');
        fprintf(fid, '  %s\r\n', repmat('-', 1, 110));
        for k = 1:nMerged
            m = S.mergedList{k};
            for j = 1:numel(m.origIdxs)
                fprintf(fid, '  %-40s  %-10d  ->  %-40s  %-10d\r\n', ...
                    m.origNames{j}, m.origIdxs(j), m.name, m.newIndex);
            end
        end
        fprintf(fid, '================================================================\r\n');

        fclose(fid);
    end

%--- 关闭窗口 ----------------------------------------------------
    function cb_close(~, ~)
        delete(fig);
    end

end % AtlasMergerTool