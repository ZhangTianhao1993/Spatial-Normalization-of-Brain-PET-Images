function NiiCropper()
% NiiCropper - NIfTI 3D/4D 图像查看与裁剪工具
%
% 依赖：SPM12
%   确保 SPM12 已加入 MATLAB 路径，例如：
%     addpath('C:\spm12');
%   然后直接运行本程序即可。
%
% 用法：直接运行 NiiCropper
%
% 功能：
%   - 加载 3D/4D .nii 或 .nii.gz 文件
%   - 三视图显示（Axial / Coronal / Sagittal）
%   - 鼠标点击切换切片层
%   - 4D 图像帧选择（逐帧浏览）
%   - 鼠标拖拽调整 ROI 方框（支持移动和8方向缩放）
%   - 一键 Crop 并保存新 NIfTI 文件

    %% ── 检查依赖 ──────────────────────────────────────────────────────────
    if ~exist('spm_vol', 'file')
        errordlg( ...
            sprintf(['未找到 SPM12 函数 spm_vol。\n\n' ...
                     '请确认 SPM12 已安装并加入 MATLAB 路径：\n' ...
                     '  addpath(''C:\\spm12'');\n\n' ...
                     '然后重新运行 NiiCropper。']), ...
            'NiiCropper - 缺少依赖');
        return;
    end

    %% ── 创建主窗口 ────────────────────────────────────────────────────────
    hFig = figure( ...
        'Name',            'NiiCropper — NIfTI 查看与裁剪工具', ...
        'NumberTitle',     'off', ...
        'Color',           [0.13 0.14 0.16], ...
        'MenuBar',         'none', ...
        'ToolBar',         'none', ...
        'Resize',          'on', ...
        'Units',           'pixels', ...
        'Position',        [80 80 1280 780], ...
        'CloseRequestFcn', @onClose);

    %% ── 初始化数据容器 ────────────────────────────────────────────────────
    D = initData();

    %% ── 构建界面 ──────────────────────────────────────────────────────────
    H = buildUI(hFig);

    %% ── 初始布局（buildUI 返回后 H 已就绪）──────────────────────────────
    onResize([], []);

    %% ── 绑定回调 ──────────────────────────────────────────────────────────
    set(hFig, ...
        'WindowButtonDownFcn',   @onMouseDown, ...
        'WindowButtonMotionFcn', @onMouseMove, ...
        'WindowButtonUpFcn',     @onMouseUp);

    %% ════════════════════════════════════════════════════════════════════
    %                        数据初始化
    %  ════════════════════════════════════════════════════════════════════
    function D = initData()
        D.nii       = [];          % SPM V 结构体数组（spm_vol 返回值）
        D.vol4d     = [];          % 原始数据 [X Y Z T]
        D.vol       = [];          % 当前显示的 3D 体积
        D.dim       = [1 1 1];     % [X Y Z]
        D.nVol      = 1;           % 4D 的帧数
        D.is4D      = false;
        D.curVol    = 1;           % 当前帧
        D.curSlice  = [1 1 1];     % [x y z] 当前切片坐标
        D.roi       = [1 1 1 1 1 1]; % [x1 x2 y1 y2 z1 z2]
        D.globalMin = 0;
        D.globalMax = 1;
        D.mat       = eye(4);      % 4×4 voxel→world 变换矩阵（来自 V.mat）
        D.datatype  = 16;          % NIfTI datatype code（默认 float32）
        D.descrip   = '';          % 图像描述字符串
        % 鼠标拖拽状态
        D.drag.active   = false;
        D.drag.mode     = '';      % 'move'|'resize'
        D.drag.handle   = '';      % 'ax'|'cor'|'sag'
        D.drag.edge     = '';      % 'n','s','e','w','ne','nw','se','sw'
        D.drag.startPt  = [0 0];   % axes 坐标（图像像素）
        D.drag.startROI = [1 1 1 1 1 1];
    end

    %% ════════════════════════════════════════════════════════════════════
    %                        界面构建
    %  ════════════════════════════════════════════════════════════════════
    function H = buildUI(fig)
        BG   = [0.13 0.14 0.16];
        PAN  = [0.17 0.18 0.21];
        ACC  = [0.25 0.60 0.90];
        TXT  = [0.88 0.90 0.92];
        DARK = [0.10 0.11 0.13];

        % ── 固定尺寸常量（像素，不随窗口变化）────────────────────────
        topH   = 48;    % 顶部工具栏高度（px）
        rightW = 310;   % 右侧控制面板宽度（px）
        pad    = 8;     % 通用间距（px）
        sldH   = 24;    % 滑块高度（px）
        lblW   = 68;    % 滑块标签宽度（px）
        panTtl = 22;    % uipanel 标题高度（px）

        % ── 顶部工具栏（归一化，贴顶） ────────────────────────────────
        H.hTop = uipanel(fig, 'Units','normalized', ...
            'Position',[0, 1-topH/1, 1, topH/1], ...  % 先占位，resize 修正
            'BackgroundColor',DARK, 'BorderType','none');
        % 实际用 SizeChangedFcn 来定位，这里先设 normalized 占位
        set(H.hTop, 'Units','pixels');   % 切回 pixels 方便内部布局

        uicontrol(H.hTop, 'Style','pushbutton', 'String','📂  加载 NIfTI', ...
            'Units','pixels', 'Position',[10 8 132 32], ...
            'BackgroundColor',ACC, 'ForegroundColor','w', ...
            'FontSize',11, 'FontWeight','bold', 'Callback',@onLoadNii);

        H.txtFile = uicontrol(H.hTop, 'Style','text', 'String','未加载文件', ...
            'Units','normalized', 'Position',[0 0 1 1], ... % 占位，resize 中修正
            'BackgroundColor',DARK, 'ForegroundColor',[0.55 0.58 0.62], ...
            'FontSize',10, 'HorizontalAlignment','left');

        H.btnCrop = uicontrol(H.hTop, 'Style','pushbutton', 'String','✂  Crop & 保存', ...
            'Units','pixels', 'Position',[10 8 144 32], ...  % resize 中修正 X
            'BackgroundColor',[0.18 0.65 0.42], 'ForegroundColor','w', ...
            'FontSize',11, 'FontWeight','bold', 'Callback',@onCropSave);

        % ── 右侧控制面板容器（固定宽度，贴右）────────────────────────
        H.hRight = uipanel(fig, 'Units','pixels', ...
            'Position',[0 0 rightW 100], ...  % resize 中修正
            'BackgroundColor',BG, 'BorderType','none');

        % 4D 控制区
        p4dH = 80;
        H.hP4D = uipanel(H.hRight, 'Units','pixels', ...
            'Position',[pad pad rightW-pad*2 p4dH], ...
            'BackgroundColor',PAN, 'BorderType','none', ...
            'Title','4D 图像控制', 'ForegroundColor',ACC, ...
            'FontSize',10, 'FontWeight','bold');
        makeLabel(H.hP4D, [10 34 80 20], '当前帧:', TXT, PAN);
        H.sliderVol = makeSliderN(H.hP4D, @(s,~) onVolume(s));
        set(H.sliderVol, 'Position', [10 12 rightW-pad*2-70 22]);
        H.lblVol = makeLabel(H.hP4D, [rightW-pad*2-55 12 50 22], '1/1', TXT, PAN);

        % ROI 控制区
        proiH = 210;
        p4dBottom = pad + p4dH + pad;
        H.hPROI = uipanel(H.hRight, 'Units','pixels', ...
            'Position',[pad p4dBottom+pad rightW-pad*2 proiH], ...
            'BackgroundColor',PAN, 'BorderType','none', ...
            'Title','ROI 裁剪框', 'ForegroundColor',[0.95 0.75 0.20], ...
            'FontSize',10, 'FontWeight','bold');
        lbls = {'X 起始','X 结束','Y 起始','Y 结束','Z 起始','Z 结束'};
        H.roiEdits = gobjects(1,6);
        editW = floor((rightW-pad*2 - 30) / 2);
        for i = 1:6
            ci = mod(i-1,2);
            ri = floor((i-1)/2);
            ex = 10 + ci*(editW+10);
            ey = 146 - ri*54;
            makeLabel(H.hPROI, [ex ey+26 editW 18], lbls{i}, [0.60 0.65 0.70], PAN);
            H.roiEdits(i) = uicontrol(H.hPROI, 'Style','edit', 'String','1', ...
                'Units','pixels', 'Position',[ex ey editW 26], ...
                'BackgroundColor',DARK, 'ForegroundColor',TXT, ...
                'FontSize',11, 'Callback',@(~,~) onROIEditChange());
        end
        uicontrol(H.hPROI, 'Style','pushbutton', 'String','重置为全图', ...
            'Units','pixels','Position',[10 10 editW 28], ...
            'BackgroundColor',[0.32 0.33 0.38],'ForegroundColor',TXT, ...
            'FontSize',10, 'Callback',@onROIReset);
        uicontrol(H.hPROI, 'Style','pushbutton', 'String','居中 50%', ...
            'Units','pixels','Position',[10+editW+10 10 editW 28], ...
            'BackgroundColor',[0.32 0.33 0.38],'ForegroundColor',TXT, ...
            'FontSize',10, 'Callback',@onROICenter);

        % 图像信息区
        pinfoH = 128;
        proiBottom = p4dBottom + pad + proiH + pad;
        H.hPInfo = uipanel(H.hRight, 'Units','pixels', ...
            'Position',[pad proiBottom rightW-pad*2 pinfoH], ...
            'BackgroundColor',PAN, 'BorderType','none', ...
            'Title','图像信息', 'ForegroundColor',TXT, ...
            'FontSize',10, 'FontWeight','bold');
        H.txtInfo = uicontrol(H.hPInfo, 'Style','text', ...
            'String','加载 NIfTI 文件后显示信息', ...
            'Units','pixels', 'Position',[8 8 rightW-pad*2-16 pinfoH-panTtl-8], ...
            'BackgroundColor',PAN, 'ForegroundColor',[0.58 0.63 0.68], ...
            'FontSize',9, 'HorizontalAlignment','left', 'Max',10, 'Min',0);

        % 操作说明区
        phelpH = 118;
        pinfoBottom = proiBottom + pinfoH + pad;
        H.hPHelp = uipanel(H.hRight, 'Units','pixels', ...
            'Position',[pad pinfoBottom rightW-pad*2 phelpH], ...
            'BackgroundColor',PAN, 'BorderType','none', ...
            'Title','操作说明', 'ForegroundColor',TXT, ...
            'FontSize',10, 'FontWeight','bold');
        helpTxt = sprintf(['🖱 单击图像 → 跳转到该层\n' ...
                           '🔲 拖拽 ROI 框内部 → 移动\n' ...
                           '↔ 拖拽 ROI 框边缘 → 缩放\n' ...
                           '🔄 滑块 → 切换切片层\n' ...
                           '✂  Crop & 保存 → 导出文件']);
        uicontrol(H.hPHelp, 'Style','text', 'String',helpTxt, ...
            'Units','pixels', 'Position',[8 8 rightW-pad*2-16 phelpH-panTtl-8], ...
            'BackgroundColor',PAN, 'ForegroundColor',[0.55 0.60 0.65], ...
            'FontSize',9, 'HorizontalAlignment','left', 'Max',10, 'Min',0);

        % ── 左侧三视图面板（归一化，自动随窗口伸缩）─────────────────
        % 每个面板 + 滑块占左侧区域的一半高度
        % 面板本身用 normalized，内部 axes 也用 normalized
        H.hPanAx = uipanel(fig, 'Units','normalized', ...
            'BackgroundColor',PAN, 'BorderType','none', ...
            'Title','AXIAL  (Z)', 'ForegroundColor',ACC, ...
            'FontSize',9, 'FontWeight','bold');
        H.axAx = axes(H.hPanAx, 'Units','normalized', ...
            'Position',[0.01 0.02 0.98 0.95], ...
            'Color',DARK, 'XColor',BG, 'YColor',BG, ...
            'XTickLabel',{}, 'YTickLabel',{});

        H.hPanCor = uipanel(fig, 'Units','normalized', ...
            'BackgroundColor',PAN, 'BorderType','none', ...
            'Title','CORONAL  (Y)', 'ForegroundColor',ACC, ...
            'FontSize',9, 'FontWeight','bold');
        H.axCor = axes(H.hPanCor, 'Units','normalized', ...
            'Position',[0.01 0.02 0.98 0.95], ...
            'Color',DARK, 'XColor',BG, 'YColor',BG, ...
            'XTickLabel',{}, 'YTickLabel',{});

        H.hPanSag = uipanel(fig, 'Units','normalized', ...
            'BackgroundColor',PAN, 'BorderType','none', ...
            'Title','SAGITTAL  (X)', 'ForegroundColor',ACC, ...
            'FontSize',9, 'FontWeight','bold');
        H.axSag = axes(H.hPanSag, 'Units','normalized', ...
            'Position',[0.01 0.02 0.98 0.95], ...
            'Color',DARK, 'XColor',BG, 'YColor',BG, ...
            'XTickLabel',{}, 'YTickLabel',{});

        % 三个滑块（归一化宽度，固定像素高度）
        H.sliderZ   = makeSliderN(fig, @(s,~) onSliceZ(s));
        H.lblSliceZ = makeLabelN(fig, 'Z: 1', TXT, BG);
        H.sliderY   = makeSliderN(fig, @(s,~) onSliceY(s));
        H.lblSliceY = makeLabelN(fig, 'Y: 1', TXT, BG);
        H.sliderX   = makeSliderN(fig, @(s,~) onSliceX(s));
        H.lblSliceX = makeLabelN(fig, 'X: 1', TXT, BG);

        % ── 绑定窗口 SizeChangedFcn ───────────────────────────────────
        set(fig, 'SizeChangedFcn', @onResize);

        % ── 初始化图像句柄 ────────────────────────────────────────────
        initAxes(H.axAx);
        initAxes(H.axCor);
        initAxes(H.axSag);

        H.hImgAx   = [];  H.hImgCor   = [];  H.hImgSag   = [];
        H.hROIAx   = [];  H.hROICor   = [];  H.hROISag   = [];
        H.hCrossAx = [];  H.hCrossCor = [];  H.hCrossSag = [];

        % 把布局常量存进 figure UserData，onResize 从这里读
        % （不用 H.LAY，避免 buildUI 返回前 H 未赋值的问题）
        ud.topH   = topH;
        ud.rightW = rightW;
        ud.pad    = pad;
        ud.sldH   = sldH;
        ud.lblW   = lblW;
        set(fig, 'UserData', ud);

        % 注意：不在这里调用 onResize，主函数拿到 H 后再调用
    end

    %% ── 响应式布局核心 ───────────────────────────────────────────────────
    function onResize(~, ~)
        % 读取布局常量（存在 figure UserData 里，buildUI 完成后即可用）
        ud = get(hFig, 'UserData');
        if isempty(ud) || ~isstruct(ud) || ~isfield(ud,'topH')
            return;   % buildUI 尚未完成，忽略
        end

        set(hFig,'Units','pixels');
        figPos = get(hFig,'Position');
        figW = figPos(3);
        figH = figPos(4);

        topH   = ud.topH;
        rightW = ud.rightW;
        pad    = ud.pad;
        sldH   = ud.sldH;
        lblW   = ud.lblW;
        panTtl = 22;

        % ── 顶部工具栏 ────────────────────────────────────────────────
        set(H.hTop, 'Units','pixels', ...
            'Position',[0, figH-topH, figW, topH]);
        % 文件名标签：左156到Crop按钮左侧
        set(H.txtFile, 'Units','pixels', ...
            'Position',[155, 12, figW-155-154-10, 22]);
        % Crop 按钮贴右
        set(H.btnCrop, 'Units','pixels', ...
            'Position',[figW-154, 8, 144, 32]);

        % ── 右侧面板容器：贴右，全高（工具栏以下）─────────────────
        contentH = figH - topH;
        set(H.hRight, 'Units','pixels', ...
            'Position',[figW-rightW, 0, rightW, contentH]);

        % ── 左侧视图区域 ──────────────────────────────────────────────
        % 可用宽度（减去右侧面板和间距）
        leftW   = figW - rightW - pad;
        % 每个视图宽度（左右两列各占一半）
        viewW   = floor((leftW - pad*3) / 2);
        % 每个视图面板高度：
        % 垂直空间 = contentH - pad*3 - sldH*2（三个滑块各一行）- panTtl*2
        % 分两行，每行一个视图
        viewH   = floor((contentH - pad*3 - sldH*2 - panTtl*2) / 2);
        viewH   = max(50, viewH);  % 最小高度保护

        col1_x = pad;
        col2_x = pad*2 + viewW;

        % 从下往上计算 Y 坐标
        row1_sld_y = pad;
        row1_pan_y = row1_sld_y + sldH + pad;
        row2_sld_y = row1_pan_y + viewH + panTtl + pad;
        row2_pan_y = row2_sld_y + sldH + pad;

        % Axial 面板（上排左）
        set(H.hPanAx, 'Units','pixels', ...
            'Position',[col1_x, row2_pan_y, viewW, viewH+panTtl]);
        % Coronal 面板（上排右）
        set(H.hPanCor, 'Units','pixels', ...
            'Position',[col2_x, row2_pan_y, viewW, viewH+panTtl]);
        % Sagittal 面板（下排左）
        set(H.hPanSag, 'Units','pixels', ...
            'Position',[col1_x, row1_pan_y, viewW, viewH+panTtl]);

        % Z 滑块（Axial 下方）
        set(H.sliderZ, 'Units','pixels', ...
            'Position',[col1_x, row2_sld_y, viewW-lblW-pad, sldH]);
        set(H.lblSliceZ, 'Units','pixels', ...
            'Position',[col1_x+viewW-lblW, row2_sld_y, lblW, sldH]);
        % Y 滑块（Coronal 下方）
        set(H.sliderY, 'Units','pixels', ...
            'Position',[col2_x, row2_sld_y, viewW-lblW-pad, sldH]);
        set(H.lblSliceY, 'Units','pixels', ...
            'Position',[col2_x+viewW-lblW, row2_sld_y, lblW, sldH]);
        % X 滑块（Sagittal 下方）
        set(H.sliderX, 'Units','pixels', ...
            'Position',[col1_x, row1_sld_y, viewW-lblW-pad, sldH]);
        set(H.lblSliceX, 'Units','pixels', ...
            'Position',[col1_x+viewW-lblW, row1_sld_y, lblW, sldH]);

        % ── 右侧面板内部：从下往上堆叠（相对 hRight） ────────────────
        rw = rightW - pad*2;

        % 4D 面板（贴底）
        p4dH = 80;
        set(H.hP4D, 'Units','pixels', ...
            'Position',[pad, pad, rw, p4dH]);
        set(H.sliderVol, 'Units','pixels', ...
            'Position',[10 12 rw-70 22]);
        set(H.lblVol, 'Units','pixels', ...
            'Position',[rw-55 12 50 22]);

        % ROI 面板
        proiH    = 210;
        proiY    = pad + p4dH + pad;
        set(H.hPROI, 'Units','pixels', ...
            'Position',[pad, proiY, rw, proiH]);

        % 图像信息面板
        pinfoH   = 128;
        pinfoY   = proiY + proiH + pad;
        set(H.hPInfo, 'Units','pixels', ...
            'Position',[pad, pinfoY, rw, pinfoH]);
        set(H.txtInfo, 'Units','pixels', ...
            'Position',[8 8 rw-16 pinfoH-panTtl-8]);

        % 操作说明面板（填满剩余空间，但至少 80px）
        phelpY   = pinfoY + pinfoH + pad;
        phelpH   = max(80, contentH - phelpY - pad);
        set(H.hPHelp, 'Units','pixels', ...
            'Position',[pad, phelpY, rw, phelpH]);
    end

    %% ── 辅助控件工厂（归一化版，仅占位，resize 中设真实位置）────────────
    function h = makeSliderN(parent, cb)
        h = uicontrol(parent, 'Style','slider', ...
            'Units','pixels', 'Position',[0 0 100 24], ...
            'Min',1, 'Max',1.001, 'Value',1, ...
            'SliderStep',[1 1], ...
            'BackgroundColor',[0.25 0.26 0.30], ...
            'Callback',cb);
    end

    function h = makeLabelN(parent, str, fg, bg)
        h = uicontrol(parent, 'Style','text', 'String',str, ...
            'Units','pixels', 'Position',[0 0 68 24], ...
            'BackgroundColor',bg, 'ForegroundColor',fg, ...
            'FontSize',9, 'HorizontalAlignment','left');
    end

    function h = makeLabel(parent, pos, str, fg, bg)
        h = uicontrol(parent, 'Style','text', 'String',str, ...
            'Units','pixels','Position',pos, ...
            'BackgroundColor',bg,'ForegroundColor',fg, ...
            'FontSize',9,'HorizontalAlignment','left');
    end

    function initAxes(ax)
        cla(ax);
        set(ax,'Color',[0.10 0.11 0.13]);
        axis(ax,'off');
        text(ax, 0.5, 0.5, '← 请先加载 NIfTI 文件', ...
            'Units','normalized','HorizontalAlignment','center', ...
            'VerticalAlignment','middle','Color',[0.35 0.37 0.42], ...
            'FontSize',11);
    end

    %% ════════════════════════════════════════════════════════════════════
    %                        文件加载（SPM12）
    %  ════════════════════════════════════════════════════════════════════
    function onLoadNii(~,~)
        [fname, fpath] = uigetfile( ...
            {'*.nii;*.nii.gz','NIfTI 文件 (*.nii, *.nii.gz)'; '*.*','所有文件'}, ...
            '选择 NIfTI 文件');
        if isequal(fname,0), return; end

        fullpath = fullfile(fpath, fname);
        set(H.txtFile,'String',['加载中... ' fullpath]);
        drawnow;

        try
            % ── SPM12 读取方式 ─────────────────────────────────────────
            % spm_vol 返回 V 结构体数组，每个元素对应一个 volume（3D帧）
            V = spm_vol(fullpath);

            nVol = numel(V);   % 4D 图像有多个 V

            % 读取全部数据
            % spm_read_vols 对 3D 返回 [X Y Z]，对 4D 返回 [X Y Z T]
            img = spm_read_vols(V);
            img = double(img);

        catch ME
            errordlg(sprintf('加载失败：\n%s', ME.message), 'NiiCropper');
            set(H.txtFile,'String','加载失败');
            return;
        end

        sz = size(img);

        % 确定维度
        if ndims(img) == 3
            D.vol4d = img;
            D.dim   = sz(1:3);
            D.nVol  = 1;
            D.is4D  = false;
        elseif ndims(img) == 4
            D.vol4d = img;
            D.dim   = sz(1:3);
            D.nVol  = sz(4);
            D.is4D  = true;
        else
            errordlg('只支持 3D 和 4D NIfTI 图像','NiiCropper');
            return;
        end

        % 保存 SPM V 结构体（第一帧用于 header 信息）
        D.nii       = V;
        D.mat       = V(1).mat;      % 4×4 体素→世界坐标矩阵
        D.datatype  = V(1).dt(1);    % 数据类型 code
        D.descrip   = V(1).descrip;

        D.curVol    = 1;
        D.curSlice  = round(D.dim / 2);
        D.curSlice  = max(1, D.curSlice);

        % 全局归一化
        D.globalMin = min(img(:));
        D.globalMax = max(img(:));
        if D.globalMax == D.globalMin
            D.globalMax = D.globalMin + 1;
        end

        % 默认 ROI = 整张图
        D.roi = [1 D.dim(1) 1 D.dim(2) 1 D.dim(3)];

        % 更新控件范围
        updateSliderRanges();

        % 获取当前体积
        D.vol = getVolume();

        % 更新文件名显示
        set(H.txtFile,'String', fullpath);

        % ── 图像信息（从 V(1).mat 提取体素大小）─────────────────────
        % mat 的列向量长度即为各方向体素大小
        voxSz = sqrt(sum(V(1).mat(1:3,1:3).^2, 1));
        dtName = spm_type(D.datatype);   % 数据类型名称字符串
        infoStr = sprintf(['维度: %d × %d × %d  帧数: %d\n' ...
                           '体素大小: %.2f × %.2f × %.2f mm\n' ...
                           '数据类型: %s\n' ...
                           '值域: %.1f ~ %.1f'], ...
            D.dim(1), D.dim(2), D.dim(3), D.nVol, ...
            voxSz(1), voxSz(2), voxSz(3), ...
            dtName, D.globalMin, D.globalMax);
        set(H.txtInfo,'String',infoStr);

        % 初次绘图
        redrawAll();
    end

    %% ════════════════════════════════════════════════════════════════════
    %                        滑块 & 4D 控制回调
    %  ════════════════════════════════════════════════════════════════════
    function onSliceZ(s)
        if isempty(D.vol), return; end
        D.curSlice(3) = max(1, min(D.dim(3), round(get(s,'Value'))));
        set(H.lblSliceZ,'String',sprintf('Z: %d',D.curSlice(3)));
        redrawAll();
    end
    function onSliceY(s)
        if isempty(D.vol), return; end
        D.curSlice(2) = max(1, min(D.dim(2), round(get(s,'Value'))));
        set(H.lblSliceY,'String',sprintf('Y: %d',D.curSlice(2)));
        redrawAll();
    end
    function onSliceX(s)
        if isempty(D.vol), return; end
        D.curSlice(1) = max(1, min(D.dim(1), round(get(s,'Value'))));
        set(H.lblSliceX,'String',sprintf('X: %d',D.curSlice(1)));
        redrawAll();
    end

    function onVolume(s)
        if ~D.is4D, return; end
        D.curVol = max(1, min(D.nVol, round(get(s,'Value'))));
        set(H.lblVol,'String',sprintf('%d/%d',D.curVol,D.nVol));
        D.vol = getVolume();
        redrawAll();
    end

    %% ════════════════════════════════════════════════════════════════════
    %                        ROI 编辑框回调
    %  ════════════════════════════════════════════════════════════════════
    function onROIEditChange()
        if isempty(D.vol), return; end
        newROI = zeros(1,6);
        for k = 1:6
            v = str2double(get(H.roiEdits(k),'String'));
            if isnan(v), v = D.roi(k); end
            newROI(k) = v;
        end
        D.roi = clampROI(newROI);
        syncROIEdits();
        redrawROI();
    end

    function onROIReset(~,~)
        if isempty(D.vol), return; end
        D.roi = [1 D.dim(1) 1 D.dim(2) 1 D.dim(3)];
        syncROIEdits();
        redrawROI();
    end

    function onROICenter(~,~)
        if isempty(D.vol), return; end
        q1 = round(D.dim * 0.25);
        q3 = round(D.dim * 0.75);
        D.roi = [q1(1) q3(1) q1(2) q3(2) q1(3) q3(3)];
        D.roi = clampROI(D.roi);
        syncROIEdits();
        redrawROI();
    end

    %% ════════════════════════════════════════════════════════════════════
    %                        鼠标事件
    %  ════════════════════════════════════════════════════════════════════
    function onMouseDown(~,~)
        if isempty(D.vol), return; end

        % 找当前鼠标在哪个 axes
        [ax, axName] = getCurrentAxes();
        if isempty(ax), return; end

        pt = get(ax,'CurrentPoint');
        px = pt(1,1);  py = pt(1,2);

        % 判断点击类型：ROI 边缘/内部，还是空白区域
        [inROI, edge] = hitTestROI(ax, axName, px, py);

        if strcmp(get(hFig,'SelectionType'), 'normal')
            if inROI
                % 拖拽 ROI
                D.drag.active   = true;
                D.drag.handle   = axName;
                D.drag.startPt  = [px py];
                D.drag.startROI = D.roi;
                if isempty(edge)
                    D.drag.mode = 'move';
                    D.drag.edge = '';
                    set(hFig,'Pointer','fleur');
                else
                    D.drag.mode = 'resize';
                    D.drag.edge = edge;
                    set(hFig,'Pointer', edgeCursor(edge));
                end
            else
                % 点击跳转到该层
                jumpToSlice(axName, px, py);
            end
        end
    end

    function onMouseMove(~,~)
        if isempty(D.vol), return; end

        if D.drag.active
            [ax, axName] = getCurrentAxes();
            % 允许跨 axes 追踪：使用记录的 axes
            ax = getAxByName(D.drag.handle);
            if isempty(ax), return; end

            pt = get(ax,'CurrentPoint');
            px = pt(1,1);  py = pt(1,2);
            dx = px - D.drag.startPt(1);
            dy = py - D.drag.startPt(2);

            if strcmp(D.drag.mode, 'move')
                D.roi = moveROI(D.drag.startROI, D.drag.handle, dx, dy);
            else
                D.roi = resizeROI(D.drag.startROI, D.drag.handle, D.drag.edge, dx, dy);
            end
            D.roi = clampROI(D.roi);
            syncROIEdits();
            redrawROI();
        else
            % 悬停光标变化
            [ax, axName] = getCurrentAxes();
            if isempty(ax)
                set(hFig,'Pointer','arrow');
                return;
            end
            pt = get(ax,'CurrentPoint');
            px = pt(1,1);  py = pt(1,2);
            [inROI, edge] = hitTestROI(ax, axName, px, py);
            if inROI
                if isempty(edge)
                    set(hFig,'Pointer','fleur');
                else
                    set(hFig,'Pointer', edgeCursor(edge));
                end
            else
                set(hFig,'Pointer','crosshair');
            end
        end
    end

    function onMouseUp(~,~)
        D.drag.active = false;
        set(hFig,'Pointer','arrow');
    end

    %% ════════════════════════════════════════════════════════════════════
    %                        Crop & 保存（SPM12）
    %  ════════════════════════════════════════════════════════════════════
    function onCropSave(~,~)
        if isempty(D.nii)
            warndlg('请先加载 NIfTI 文件','NiiCropper');
            return;
        end
        roi = round(D.roi);
        x1=roi(1); x2=roi(2); y1=roi(3); y2=roi(4); z1=roi(5); z2=roi(6);

        % 验证
        if x1>=x2 || y1>=y2 || z1>=z2
            errordlg('ROI 范围无效，请调整裁剪框','NiiCropper');
            return;
        end

        [fname, fpath] = uiputfile( ...
            {'*.nii','NIfTI 文件 (*.nii)'}, ...
            '保存裁剪后的图像', 'cropped.nii');
        if isequal(fname,0), return; end

        savePath = fullfile(fpath, fname);

        try
            % ── 裁剪数据 ──────────────────────────────────────────────
            if D.is4D
                croppedImg = D.vol4d(x1:x2, y1:y2, z1:z2, :);
            else
                croppedImg = D.vol4d(x1:x2, y1:y2, z1:z2);
            end

            newDim = [x2-x1+1, y2-y1+1, z2-z1+1];
            nT     = size(croppedImg, 4);   % 3D 时为 1

            % ── 修正仿射矩阵（平移原点到 ROI 起始体素）──────────────
            % 新原点 = 原图中 (x1,y1,z1) 体素在世界坐标中的位置
            newMat      = D.mat;
            originShift = D.mat * [x1-1; y1-1; z1-1; 0];  % 相对偏移（体素→mm）
            newMat(1,4) = D.mat(1,4) + originShift(1);
            newMat(2,4) = D.mat(2,4) + originShift(2);
            newMat(3,4) = D.mat(3,4) + originShift(3);

            % ── 用 SPM12 nifti 对象写出文件 ───────────────────────────
            % 构造一个新的 V 结构体（基于第一帧）
            Vref        = D.nii(1);
            Vout        = Vref;
            Vout.fname  = savePath;
            Vout.dim    = newDim;
            Vout.mat    = newMat;
            Vout.dt     = [spm_type('float32'), spm_platform('bigend')];
            Vout.descrip= 'NiiCropper cropped';
            Vout.n      = [1 1];   % 帧索引（volume/timepoint）

            if nT == 1
                % 3D 直接写
                Vout = spm_create_vol(Vout);
                spm_write_vol(Vout, croppedImg);
            else
                % 4D：逐帧写入同一文件
                % SPM 写 4D 需要先在头信息里声明帧数
                % 方法：循环 spm_write_vol，每帧的 V.n(1) 递增
                for t = 1:nT
                    Vout.n = [t 1];
                    if t == 1
                        % 第一帧创建文件
                        Vout = spm_create_vol(Vout);
                    end
                    spm_write_vol(Vout, croppedImg(:,:,:,t));
                end
            end

            msgbox(sprintf(['裁剪完成！\n已保存至：%s\n\n' ...
                            '裁剪范围：\n' ...
                            '  X: %d ~ %d  (%d 体素)\n' ...
                            '  Y: %d ~ %d  (%d 体素)\n' ...
                            '  Z: %d ~ %d  (%d 体素)\n' ...
                            '  T: %d 帧'], ...
                savePath, x1,x2,x2-x1+1, y1,y2,y2-y1+1, z1,z2,z2-z1+1, nT), ...
                'NiiCropper - 保存成功');

        catch ME
            errordlg(sprintf('保存失败：\n%s', ME.message), 'NiiCropper');
        end
    end

    %% ════════════════════════════════════════════════════════════════════
    %                        绘图核心
    %  ════════════════════════════════════════════════════════════════════
    function redrawAll()
        if isempty(D.vol), return; end
        drawAxial();
        drawCoronal();
        drawSagittal();
        redrawROI();
        syncSliders();
    end

    function drawAxial()
        ax = H.axAx;
        z  = D.curSlice(3);
        z  = max(1, min(D.dim(3), z));

        slice = D.vol(:,:,z);
        slice = normalizeSlice(slice);
        % MATLAB imagesc: 第一维为行（Y），第二维为列（X）
        % NIfTI: vol(X,Y,Z)，axial 切面 = vol(:,:,z)，维度 [X,Y]
        % 需要转置使 X 为横轴，Y 为纵轴
        slice = slice';   % 转置后 size = [Y, X]

        if isempty(H.hImgAx) || ~isvalid(H.hImgAx)
            axes(ax); hold(ax,'off');
            H.hImgAx = imagesc(ax, slice);
            colormap(ax, gray(256));
            axis(ax,'image');
            set(ax,'XDir','normal','YDir','reverse');
            hold(ax,'on');
            % 十字线
            H.hCrossAx(1) = plot(ax, [D.curSlice(1) D.curSlice(1)], [0.5 D.dim(2)+0.5], ...
                '--', 'Color',[0.20 0.85 0.45], 'LineWidth',0.8);
            H.hCrossAx(2) = plot(ax, [0.5 D.dim(1)+0.5], [D.curSlice(2) D.curSlice(2)], ...
                '--', 'Color',[0.20 0.85 0.45], 'LineWidth',0.8);
            set(ax,'XLim',[0.5 D.dim(1)+0.5],'YLim',[0.5 D.dim(2)+0.5]);
            axis(ax,'off');
        else
            set(H.hImgAx, 'CData', slice);
            set(H.hCrossAx(1), 'XData',[D.curSlice(1) D.curSlice(1)]);
            set(H.hCrossAx(2), 'YData',[D.curSlice(2) D.curSlice(2)]);
        end
    end

    function drawCoronal()
        ax = H.axCor;
        y  = D.curSlice(2);
        y  = max(1, min(D.dim(2), y));

        slice = squeeze(D.vol(:,y,:));       % [X Z]
        slice = normalizeSlice(slice);
        slice = slice';   % 转置后 [Z, X]

        if isempty(H.hImgCor) || ~isvalid(H.hImgCor)
            axes(ax); hold(ax,'off');
            H.hImgCor = imagesc(ax, slice);
            colormap(ax, gray(256));
            axis(ax,'image');
            set(ax,'XDir','normal','YDir','normal');
            hold(ax,'on');
            H.hCrossCor(1) = plot(ax, [D.curSlice(1) D.curSlice(1)], [0.5 D.dim(3)+0.5], ...
                '--', 'Color',[0.20 0.85 0.45], 'LineWidth',0.8);
            H.hCrossCor(2) = plot(ax, [0.5 D.dim(1)+0.5], [D.curSlice(3) D.curSlice(3)], ...
                '--', 'Color',[0.20 0.85 0.45], 'LineWidth',0.8);
            set(ax,'XLim',[0.5 D.dim(1)+0.5],'YLim',[0.5 D.dim(3)+0.5]);
            axis(ax,'off');
        else
            set(H.hImgCor, 'CData', slice);
            set(H.hCrossCor(1), 'XData',[D.curSlice(1) D.curSlice(1)]);
            set(H.hCrossCor(2), 'YData',[D.curSlice(3) D.curSlice(3)]);
        end
    end

    function drawSagittal()
        ax = H.axSag;
        x  = D.curSlice(1);
        x  = max(1, min(D.dim(1), x));

        slice = squeeze(D.vol(x,:,:));       % [Y Z]
        slice = normalizeSlice(slice);
        slice = slice';   % 转置后 [Z, Y]

        if isempty(H.hImgSag) || ~isvalid(H.hImgSag)
            axes(ax); hold(ax,'off');
            H.hImgSag = imagesc(ax, slice);
            colormap(ax, gray(256));
            axis(ax,'image');
            set(ax,'XDir','normal','YDir','normal');
            hold(ax,'on');
            H.hCrossSag(1) = plot(ax, [D.curSlice(2) D.curSlice(2)], [0.5 D.dim(3)+0.5], ...
                '--', 'Color',[0.20 0.85 0.45], 'LineWidth',0.8);
            H.hCrossSag(2) = plot(ax, [0.5 D.dim(2)+0.5], [D.curSlice(3) D.curSlice(3)], ...
                '--', 'Color',[0.20 0.85 0.45], 'LineWidth',0.8);
            set(ax,'XLim',[0.5 D.dim(2)+0.5],'YLim',[0.5 D.dim(3)+0.5]);
            axis(ax,'off');
        else
            set(H.hImgSag, 'CData', slice);
            set(H.hCrossSag(1), 'XData',[D.curSlice(2) D.curSlice(2)]);
            set(H.hCrossSag(2), 'YData',[D.curSlice(3) D.curSlice(3)]);
        end
    end

    function redrawROI()
        if isempty(D.vol), return; end
        roi = round(D.roi);
        x1=roi(1); x2=roi(2); y1=roi(3); y2=roi(4); z1=roi(5); z2=roi(6);

        % Axial: 横轴=X, 纵轴=Y
        drawROIRect(H.axAx,  'hROIAx',  x1, y1, x2-x1, y2-y1);
        % Coronal: 横轴=X, 纵轴=Z
        drawROIRect(H.axCor, 'hROICor', x1, z1, x2-x1, z2-z1);
        % Sagittal: 横轴=Y, 纵轴=Z
        drawROIRect(H.axSag, 'hROISag', y1, z1, y2-y1, z2-z1);
    end

    function drawROIRect(ax, fieldName, left, bottom, width, height)
        ROI_COLOR = [0.95 0.75 0.20];
        width  = max(1, width);
        height = max(1, height);
        if isempty(H.(fieldName)) || ~isvalid(H.(fieldName))
            H.(fieldName) = rectangle(ax, ...
                'Position', [left-0.5, bottom-0.5, width, height], ...
                'EdgeColor', ROI_COLOR, 'LineWidth', 2.0, ...
                'LineStyle', '-', 'FaceColor','none', ...
                'PickableParts','none');
        else
            set(H.(fieldName), 'Position', [left-0.5, bottom-0.5, width, height]);
        end
    end

    %% ════════════════════════════════════════════════════════════════════
    %                        鼠标交互辅助函数
    %  ════════════════════════════════════════════════════════════════════
    function jumpToSlice(axName, px, py)
        % 点击坐标转体素坐标，更新对应的切片
        switch axName
            case 'ax'
                % Axial: px=X方向, py=Y方向
                D.curSlice(1) = clampDim(round(px), 1);
                D.curSlice(2) = clampDim(round(py), 2);
                set(H.sliderX,'Value', D.curSlice(1));
                set(H.sliderY,'Value', D.curSlice(2));
                set(H.lblSliceX,'String',sprintf('X: %d',D.curSlice(1)));
                set(H.lblSliceY,'String',sprintf('Y: %d',D.curSlice(2)));
            case 'cor'
                % Coronal: px=X方向, py=Z方向
                D.curSlice(1) = clampDim(round(px), 1);
                D.curSlice(3) = clampDim(round(py), 3);
                set(H.sliderX,'Value', D.curSlice(1));
                set(H.sliderZ,'Value', D.curSlice(3));
                set(H.lblSliceX,'String',sprintf('X: %d',D.curSlice(1)));
                set(H.lblSliceZ,'String',sprintf('Z: %d',D.curSlice(3)));
            case 'sag'
                % Sagittal: px=Y方向, py=Z方向
                D.curSlice(2) = clampDim(round(px), 2);
                D.curSlice(3) = clampDim(round(py), 3);
                set(H.sliderY,'Value', D.curSlice(2));
                set(H.sliderZ,'Value', D.curSlice(3));
                set(H.lblSliceY,'String',sprintf('Y: %d',D.curSlice(2)));
                set(H.lblSliceZ,'String',sprintf('Z: %d',D.curSlice(3)));
        end
        redrawAll();
    end

    function v = clampDim(v, dim)
        v = max(1, min(D.dim(dim), v));
    end

    function [inROI, edge] = hitTestROI(~, axName, px, py)
        % 返回：inROI=是否在框内/边上，edge=方向字符串（空=内部）
        THRESH = 8;  % 像素容差
        roi = round(D.roi);
        switch axName
            case 'ax'
                rx1=roi(1)-0.5; rx2=roi(2)+0.5;
                ry1=roi(3)-0.5; ry2=roi(4)+0.5;
            case 'cor'
                rx1=roi(1)-0.5; rx2=roi(2)+0.5;
                ry1=roi(5)-0.5; ry2=roi(6)+0.5;
            case 'sag'
                rx1=roi(3)-0.5; rx2=roi(4)+0.5;
                ry1=roi(5)-0.5; ry2=roi(6)+0.5;
            otherwise
                inROI=false; edge=''; return;
        end

        % 屏幕坐标转换（近似，axes 为图像坐标）
        inBox = px>=rx1 && px<=rx2 && py>=ry1 && py<=ry2;
        if ~inBox
            inROI=false; edge=''; return;
        end

        inROI = true;
        onW = abs(px-rx1) < THRESH;
        onE = abs(px-rx2) < THRESH;
        onN = abs(py-ry1) < THRESH;
        onS = abs(py-ry2) < THRESH;

        if onN && onW, edge='nw';
        elseif onN && onE, edge='ne';
        elseif onS && onW, edge='sw';
        elseif onS && onE, edge='se';
        elseif onN, edge='n';
        elseif onS, edge='s';
        elseif onW, edge='w';
        elseif onE, edge='e';
        else, edge='';
        end
    end

    function newROI = moveROI(startROI, axName, dx, dy)
        newROI = startROI;
        switch axName
            case 'ax'   % dx=X, dy=Y
                newROI(1) = startROI(1) + dx;
                newROI(2) = startROI(2) + dx;
                newROI(3) = startROI(3) + dy;
                newROI(4) = startROI(4) + dy;
            case 'cor'  % dx=X, dy=Z
                newROI(1) = startROI(1) + dx;
                newROI(2) = startROI(2) + dx;
                newROI(5) = startROI(5) + dy;
                newROI(6) = startROI(6) + dy;
            case 'sag'  % dx=Y, dy=Z
                newROI(3) = startROI(3) + dx;
                newROI(4) = startROI(4) + dx;
                newROI(5) = startROI(5) + dy;
                newROI(6) = startROI(6) + dy;
        end
    end

    function newROI = resizeROI(startROI, axName, edge, dx, dy)
        newROI = startROI;
        MIN_SZ = 2;
        switch axName
            case 'ax'
                % 横轴=X(1,2), 纵轴=Y(3,4)
                [newROI(1),newROI(2)] = applyEdge1D( ...
                    startROI(1),startROI(2), dx, ...
                    any(strcmp(edge,{'w','nw','sw'})), ...
                    any(strcmp(edge,{'e','ne','se'})), MIN_SZ);
                [newROI(3),newROI(4)] = applyEdge1D( ...
                    startROI(3),startROI(4), dy, ...
                    any(strcmp(edge,{'n','nw','ne'})), ...
                    any(strcmp(edge,{'s','sw','se'})), MIN_SZ);
            case 'cor'
                % 横轴=X(1,2), 纵轴=Z(5,6)
                [newROI(1),newROI(2)] = applyEdge1D( ...
                    startROI(1),startROI(2), dx, ...
                    any(strcmp(edge,{'w','nw','sw'})), ...
                    any(strcmp(edge,{'e','ne','se'})), MIN_SZ);
                [newROI(5),newROI(6)] = applyEdge1D( ...
                    startROI(5),startROI(6), dy, ...
                    any(strcmp(edge,{'n','nw','ne'})), ...
                    any(strcmp(edge,{'s','sw','se'})), MIN_SZ);
            case 'sag'
                % 横轴=Y(3,4), 纵轴=Z(5,6)
                [newROI(3),newROI(4)] = applyEdge1D( ...
                    startROI(3),startROI(4), dx, ...
                    any(strcmp(edge,{'w','nw','sw'})), ...
                    any(strcmp(edge,{'e','ne','se'})), MIN_SZ);
                [newROI(5),newROI(6)] = applyEdge1D( ...
                    startROI(5),startROI(6), dy, ...
                    any(strcmp(edge,{'n','nw','ne'})), ...
                    any(strcmp(edge,{'s','sw','se'})), MIN_SZ);
        end
    end

    function [a,b] = applyEdge1D(a0,b0, delta, doMin, doMax, minSz)
        a = a0; b = b0;
        if doMin, a = a0 + delta; end
        if doMax, b = b0 + delta; end
        if b - a < minSz
            if doMin, a = b - minSz; else, b = a + minSz; end
        end
    end

    function cursor = edgeCursor(edge)
        switch edge
            case {'n','s'},     cursor = 'top';
            case {'e','w'},     cursor = 'left';
            case {'ne','sw'},   cursor = 'botr';
            case {'nw','se'},   cursor = 'botl';
            otherwise,          cursor = 'arrow';
        end
    end

    function [ax, axName] = getCurrentAxes()
        axList = {H.axAx, H.axCor, H.axSag};
        names  = {'ax', 'cor', 'sag'};
        ax = []; axName = '';
        for k = 1:3
            if isvalid(axList{k})
                pt = get(axList{k}, 'CurrentPoint');
                xl = get(axList{k}, 'XLim');
                yl = get(axList{k}, 'YLim');
                if pt(1,1)>=xl(1) && pt(1,1)<=xl(2) && ...
                   pt(1,2)>=yl(1) && pt(1,2)<=yl(2)
                    ax = axList{k};
                    axName = names{k};
                    return;
                end
            end
        end
    end

    function ax = getAxByName(name)
        switch name
            case 'ax',  ax = H.axAx;
            case 'cor', ax = H.axCor;
            case 'sag', ax = H.axSag;
            otherwise,  ax = [];
        end
    end

    %% ════════════════════════════════════════════════════════════════════
    %                        工具函数
    %  ════════════════════════════════════════════════════════════════════
    function vol = getVolume()
        if isempty(D.vol4d)
            vol = [];
            return;
        end
        if D.is4D
            vol = D.vol4d(:,:,:, D.curVol);
        else
            vol = D.vol4d;
        end
    end

    function s = normalizeSlice(s)
        s = (s - D.globalMin) / (D.globalMax - D.globalMin);
        s = max(0, min(1, s));
    end

    function roi = clampROI(roi)
        roi = round(roi);
        roi(1) = max(1, min(D.dim(1)-1, roi(1)));
        roi(2) = max(roi(1)+1, min(D.dim(1), roi(2)));
        roi(3) = max(1, min(D.dim(2)-1, roi(3)));
        roi(4) = max(roi(3)+1, min(D.dim(2), roi(4)));
        roi(5) = max(1, min(D.dim(3)-1, roi(5)));
        roi(6) = max(roi(5)+1, min(D.dim(3), roi(6)));
    end

    function syncROIEdits()
        roi = round(D.roi);
        for k = 1:6
            set(H.roiEdits(k), 'String', num2str(roi(k)));
        end
    end

    function updateSliderRanges()
        % Z 滑块
        set(H.sliderZ, 'Min',1, 'Max',max(2,D.dim(3)), ...
            'Value', D.curSlice(3), ...
            'SliderStep',[1/max(1,D.dim(3)-1) 10/max(1,D.dim(3)-1)]);
        set(H.lblSliceZ,'String',sprintf('Z: %d',D.curSlice(3)));
        % Y 滑块
        set(H.sliderY, 'Min',1, 'Max',max(2,D.dim(2)), ...
            'Value', D.curSlice(2), ...
            'SliderStep',[1/max(1,D.dim(2)-1) 10/max(1,D.dim(2)-1)]);
        set(H.lblSliceY,'String',sprintf('Y: %d',D.curSlice(2)));
        % X 滑块
        set(H.sliderX, 'Min',1, 'Max',max(2,D.dim(1)), ...
            'Value', D.curSlice(1), ...
            'SliderStep',[1/max(1,D.dim(1)-1) 10/max(1,D.dim(1)-1)]);
        set(H.lblSliceX,'String',sprintf('X: %d',D.curSlice(1)));
        % Volume 滑块
        if D.is4D && D.nVol > 1
            set(H.sliderVol, 'Min',1, 'Max',D.nVol, 'Value',1, ...
                'SliderStep',[1/max(1,D.nVol-1) 5/max(1,D.nVol-1)]);
            set(H.lblVol,'String',sprintf('1/%d',D.nVol));
        else
            set(H.sliderVol,'Min',1,'Max',1.001,'Value',1);
            set(H.lblVol,'String','1/1');
        end
        % 重置 image 句柄（换图后需要重新 imagesc）
        H.hImgAx  = []; H.hImgCor  = []; H.hImgSag  = [];
        H.hROIAx  = []; H.hROICor  = []; H.hROISag  = [];
        H.hCrossAx = []; H.hCrossCor = []; H.hCrossSag = [];
        cla(H.axAx); cla(H.axCor); cla(H.axSag);
    end

    function syncSliders()
        set(H.sliderX,'Value',D.curSlice(1));
        set(H.sliderY,'Value',D.curSlice(2));
        set(H.sliderZ,'Value',D.curSlice(3));
    end

    function onClose(~,~)
        delete(hFig);
    end

end % NiiCropper