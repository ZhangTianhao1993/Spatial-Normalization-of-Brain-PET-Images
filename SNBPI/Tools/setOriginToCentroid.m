function setOriginToCentroid
% setOriginToCentroid  使用 SPM12 将 NIfTI 图像原点调整到强度重心
% 支持 3D 与 4D 数据。
%
% 对 4D 文件：从时间均值图计算重心，对所有 volume 应用同一个仿射矩阵，
% 因此不会出现 "images do not all have same orientation" 的报错。
%
% 依赖：SPM12

%% 1. 选择图像文件
files = spm_select(Inf, 'image', 'Please select NIfTI images to adjust origin');
if isempty(files)
    disp('No files selected, exiting.');
    return;
end

% 去掉可能存在的 ",N" 帧后缀，并按文件去重
% 这样即使用户在对话框里选了 4D 文件的多帧（例如 data.nii,1 ... data.nii,N），
% 我们也只把每个物理文件处理一次。
fileList = cell(size(files,1), 1);
for i = 1:size(files,1)
    fn = deblank(files(i,:));
    cidx = find(fn == ',', 1, 'last');
    if ~isempty(cidx) && all(isstrprop(fn(cidx+1:end), 'digit'))
        fn = fn(1:cidx-1);
    end
    fileList{i} = fn;
end
fileList = unique(fileList);
nFiles   = numel(fileList);
fprintf('Selected %d unique image file(s).\n', nFiles);

% 用于汇总：记录哪些文件是非 3D，以及它们各自的 volume 数
non3dList = {};   % 每项形如 {filename, nVol}

%% 2. 逐个文件处理
for i = 1:nFiles
    fname = fileList{i};
    fprintf('\nProcessing [%d/%d]: %s\n', i, nFiles, fname);

    try
        %% 2.0 先清掉残留的 sidecar .mat 文件
        % 这一步有两个作用：
        %  (a) 修复被旧版脚本搞坏、出现"per-volume 矩阵不一致"的文件；
        %  (b) 确保后续 spm_read_vols 不会因为 sidecar 中的 per-volume 矩阵不一致而报错。
        [pth, nam] = fileparts(fname);
        sidecar = fullfile(pth, [nam '.mat']);
        if exist(sidecar, 'file')
            delete(sidecar);
            fprintf('  Removed sidecar .mat: %s\n', sidecar);
        end

        %% 2.1 读取所有 volume 的头与体素数据
        V    = spm_vol(fname);        % 3D 时是单个 struct，4D 时是 struct array
        nVol = numel(V);
        data = spm_read_vols(V);      % 3D -> 3D array, 4D -> 4D array

        %% 2.2 非 3D 图像：静默地取时间均值作为重心计算的代表图，
        %      同时记到 non3dList 里，循环结束后再统一汇报。
        if nVol > 1
            non3dList(end+1, :) = {fname, nVol}; %#ok<AGROW>
            img = mean(data, 4);
        else
            img = data;
        end

        %% 2.3 处理 NaN / Inf / 负值
        img(~isfinite(img)) = 0;
        img(img < 0)        = 0;

        %% 2.4 计算重心（体素坐标，1-based）
        totalIntensity = sum(img(:));
        if totalIntensity == 0
            warning('Image %s total intensity is zero, skipping.', fname);
            continue;
        end

        dim       = V(1).dim;
        [x, y, z] = ndgrid(1:dim(1), 1:dim(2), 1:dim(3));
        cx = sum(img(:) .* x(:)) / totalIntensity;
        cy = sum(img(:) .* y(:)) / totalIntensity;
        cz = sum(img(:) .* z(:)) / totalIntensity;

        %% 2.5 将重心体素坐标转换为毫米坐标（用共享的仿射矩阵）
        M           = V(1).mat;
        centroid_mm = M * [cx; cy; cz; 1];

        %% 2.6 构造新仿射：平移使重心落到 [0, 0, 0]
        M_new         = M;
        M_new(1:3, 4) = M(1:3, 4) - centroid_mm(1:3);

        %% 2.7 一次性写回到文件头（对 3D / 4D 都生效，所有 volume 共用同一个矩阵）
        spm_get_space(fname, M_new);

        fprintf('  Origin set to centroid. Single affine applied to all %d volume(s).\n', nVol);

    catch ME
        warning('Error processing %s: %s', fname, ME.message);
    end
end

fprintf('\nAll processing completed!\n');