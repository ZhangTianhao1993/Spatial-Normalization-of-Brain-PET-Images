function transformedImg = resampleImgToRef(originalImgName, referImgName, interpMethod)
    % resampleImgToRef: Resample an image to the space of a reference image
    % Inputs:
    %   originalImgName : Path to the image to be resampled
    %   referImgName    : Path to the reference image (target space)
    %   interpMethod    : Interpolation method, options: 'linear' (default), 'nearest', 'cubic', 'spline'

    if nargin < 3
        interpMethod = 'linear';
    end

    % Load volume headers and data
    referv = spm_vol(referImgName);
    originv = spm_vol(originalImgName);
    A = spm_read_vols(referv);
    B = spm_read_vols(originv);

    % Extract affine transformation matrices (transposed for coordinate mapping)
    a = referv.mat';
    b = originv.mat';

    % Dimensions of reference and original volumes
    [rows_A, cols_A, depths_A] = size(A);
    [rows_B, cols_B, depths_B] = size(B);

    % Generate grid coordinates in reference image space
    [X_A, Y_A, Z_A] = ndgrid(1:rows_A, 1:cols_A, 1:depths_A);
    coords_A = [X_A(:), Y_A(:), Z_A(:), ones(numel(X_A), 1)] * a;

    % Transform reference coordinates into original image space
    coords_A_in_B = coords_A / b;

    % Create interpolator for original image
    F = griddedInterpolant({1:rows_B, 1:cols_B, 1:depths_B}, B, interpMethod, interpMethod);

    % Resample and reshape to reference dimensions
    transformedImg = reshape( ...
        F(coords_A_in_B(:,1), coords_A_in_B(:,2), coords_A_in_B(:,3)), ...
        [rows_A, cols_A, depths_A]);
end
