function setOriginToCentroid
% 使用SPM将NIfTI图像原点调整到图像重心
% 依赖：SPM12

%% 1. 选择图像文件
files = spm_select(Inf, 'image', 'Please select NIfTI images to adjust origin');
if isempty(files)
    disp('No files selected, exiting.');
    return;
end

nFiles = size(files, 1);
fprintf('Selected %d image files.\n', nFiles);

%% 2. 逐个处理图像
for i = 1:nFiles
    fname = deblank(files(i, :));
    fprintf('\nProcessing [%d/%d]: %s\n', i, nFiles, fname);

    try
        %% 2.1 读取图像头信息与数据
        V   = spm_vol(fname);
        img = spm_read_vols(V);

        %% 2.2 处理 NaN / Inf / 负值
        img(~isfinite(img)) = 0;
        img(img < 0)        = 0;

        %% 2.3 计算重心（体素坐标，1-based）
        totalIntensity = sum(img(:));

        if totalIntensity == 0
            warning('Image %s total intensity is zero, skipping.', fname);
            continue;
        end

        [x, y, z] = ndgrid(1:V.dim(1), 1:V.dim(2), 1:V.dim(3));

        cx = sum(img(:) .* x(:)) / totalIntensity;
        cy = sum(img(:) .* y(:)) / totalIntensity;
        cz = sum(img(:) .* z(:)) / totalIntensity;

        %fprintf(' Center of mass (voxel): [%.2f, %.2f, %.2f]\n', cx, cy, cz);

        %% 2.4 将重心体素坐标转换为毫米坐标
        centroid_vox = [cx; cy; cz; 1];           % 齐次坐标
        centroid_mm  = V.mat * centroid_vox;       % 乘以仿射矩阵
        % fprintf('Center of mass (mm): [%.2f, %.2f, %.2f]\n', ...
        %         centroid_mm(1), centroid_mm(2), centroid_mm(3));

        %% 2.5 修改仿射矩阵，使重心映射到 [0, 0, 0]
        % 原矩阵: mm = M * vox
        % 新需求: 0  = M_new * centroid_vox
        % => M_new 的第4列（平移项）= M[:,4] - centroid_mm(1:3)
        M_new         = V.mat;
        M_new(1:3, 4) = V.mat(1:3, 4) - centroid_mm(1:3);

        %% 2.6 将新矩阵写回
        V.mat = M_new;

        spm_create_vol(V);          % 只更新头信息，不重写体素数据

        %fprintf('  Origin successfully adjusted to center of mass.\n');

    catch ME
        warning('Error processing %s: %s', fname, ME.message);
    end
end

fprintf('\nAll processing completed!\n');