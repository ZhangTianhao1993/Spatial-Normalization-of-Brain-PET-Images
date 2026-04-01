function transformedImg = resampleImgToRef(originalImgName, referImgName, interpMethod)
    % resampleImgToRef: 将原图重采样到参考图像空间
    % 输入:
    %   originalImgName : 待重采样图像路径
    %   referImgName    : 参考图像路径（目标空间）
    %   interpMethod    : 插值方法，可选 'linear'(默认),'nearest','cubic','spline'

    if nargin < 3
        interpMethod = 'linear';
    end

    referv = spm_vol(referImgName);
    originv = spm_vol(originalImgName);
    A = spm_read_vols(referv);
    B = spm_read_vols(originv);

    a = referv.mat';
    b = originv.mat';

    [rows_A, cols_A, depths_A] = size(A);
    [rows_B, cols_B, depths_B] = size(B);

    % Atlas空间的体素索引 → 世界坐标
    [X_A, Y_A, Z_A] = ndgrid(1:rows_A, 1:cols_A, 1:depths_A);
    coords_A = [X_A(:), Y_A(:), Z_A(:), ones(numel(X_A), 1)] * a;

    % 世界坐标 → 原图体素索引
    coords_A_in_B = coords_A / b;

    % 构造插值器
    F = griddedInterpolant({1:rows_B, 1:cols_B, 1:depths_B}, B, interpMethod, interpMethod);


    % 插值并重塑
    transformedImg = reshape( ...
        F(coords_A_in_B(:,1), coords_A_in_B(:,2), coords_A_in_B(:,3)), ...
        [rows_A, cols_A, depths_A]);
end