function transformedImg = deformImgBasedOnAtlas(originalImgName,referImgName)
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
    F = griddedInterpolant(X_B, Y_B, Z_B, B); 
    
    % 插值计算
    transformedImg = F(X_A_in_B, Y_A_in_B, Z_A_in_B);
    
    % 将插值结果重塑为A的大小
    transformedImg = reshape(transformedImg, [rows_A, cols_A, depths_A]);
    %B_transformed = permute(B_transformed,[])
end
