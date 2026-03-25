% List of open inputs
% Deformations: Image to base Id on - cfg_files
% Deformations: Apply to - cfg_files
function B_transformed = deformImgBasedOnAtlas(originalImgName,referImgName)
    % matlabbatch{1}.spm.util.defs.comp{1}.id.space = '<UNDEFINED>';
    % matlabbatch{1}.spm.util.defs.out{1}.pull.fnames = '<UNDEFINED>';
    % matlabbatch{1}.spm.util.defs.out{1}.pull.savedir.savesrc = 1;
    % matlabbatch{1}.spm.util.defs.out{1}.pull.interp = 4;
    % matlabbatch{1}.spm.util.defs.out{1}.pull.mask = 1;
    % matlabbatch{1}.spm.util.defs.out{1}.pull.fwhm = [0 0 0];
    % matlabbatch{1}.spm.util.defs.out{1}.pull.prefix = 'e';
    % jobs = repmat(matlabbatch, 1, 1);
    % inputs = cell(2, 1);
    % 
    % inputs{1, 1} = {referImgName}; % Deformations: Image to base Id on - cfg_files
    % inputs{2, 1} = {originalImgName}; % Deformations: Apply to - cfg_files
    % 
    % spm('defaults', 'FMRI');
    % spm_jobman('run', jobs, inputs{:});
    referv = spm_vol(referImgName);
    originv = spm_vol(originalImgName);
    A = spm_read_vols(referv);
    B = spm_read_vols(originv);
    a = referv.mat';
    b = originv.mat';
    % 获取矩阵A和B的大小
    [rows_A, cols_A, depths_A] = size(A);
    [rows_B, cols_B, depths_B] = size(B);
    
    % 创建A的物理坐标网格（使用 ndgrid）
    [X_A, Y_A, Z_A] = ndgrid(1:rows_A, 1:cols_A, 1:depths_A);
    coords_A = [X_A(:), Y_A(:), Z_A(:), ones(numel(X_A), 1)] * a;
    
    % 创建B的物理坐标网格（使用 ndgrid）
    [X_B, Y_B, Z_B] = ndgrid(1:rows_B, 1:cols_B, 1:depths_B);
    %coords_B = [X_B(:), Y_B(:), Z_B(:), ones(numel(X_B), 1)] * b;
    
    % 将A的物理坐标转换到B的索引空间
    coords_A_in_B = coords_A / b;
    
    % 提取坐标
    X_A_in_B = coords_A_in_B(:, 1);
    Y_A_in_B = coords_A_in_B(:, 2);
    Z_A_in_B = coords_A_in_B(:, 3);
    
    % 使用 griddedInterpolant 进行线性插值
    F = griddedInterpolant(X_B, Y_B, Z_B, B); % 'spline' 是三次样条
    
    % 插值计算
    B_transformed = F(X_A_in_B, Y_A_in_B, Z_A_in_B);
    
    % 将插值结果重塑为A的大小
    B_transformed = reshape(B_transformed, [rows_A, cols_A, depths_A]);
    %B_transformed = permute(B_transformed,[])
end
