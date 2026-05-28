function failedSubjects = AtlasBasedSpatialNormalizationMethod( ...
    PETnames, bbox, vx, nf, rt, d, sT, sD)
% AtlasBasedSpatialNormalizationMethod
% Atlas-based spatial normalization for a list of PET images.
%
% Inputs:
%   PETnames - Cell array of PET image names (each entry typically ends
%              with a frame index like ',1' which is stripped internally).
%   bbox     - 2x3 bounding box matrix [min X Y Z; max X Y Z].
%   vx       - 1x3 voxel size vector (mm).
%   nf       - Char prefix for the normalized output image.
%   rt       - Regularization term (real number).
%   d        - uiprogressdlg handle, or [] when running headless.
%   sT       - Logical flag: keep adaptive TPM files if non-zero.
%   sD       - Logical flag: keep deformation field if non-zero.
%
% Output:
%   failedSubjects - Cell array of strings describing subjects that
%                    failed, in the form "<name> | <id> | <message>".
%                    Empty when everything succeeded.
%
% Design notes:
%   - The loop is a plain serial 'for'. Parallelism is handled OUTSIDE
%     this function by AtlasBased_dispatch / AtlasBased_worker, which
%     spawn independent MATLAB processes. This avoids any dependency on
%     the Parallel Computing Toolbox and avoids nested parallelism when
%     the function is called from a background worker.
%   - A try/catch wraps each subject so that a single failure does NOT
%     abort the whole batch; failures are accumulated and returned.
%   - The progress-bar handle 'd' is checked with isvalid() so the
%     function works both in GUI mode (with a progress dialog) and in
%     headless background mode (d = []).
%
% Author: Zhang Tianhao 2021/7/29
%         (refactored 2026 to remove parfor and add fault tolerance)
% =========================================================================

n = length(PETnames);

% Locate the SNBPI main folder so we can find the TPM resources.
str = which('SNBPI');
[mainfilepath, ~, ~] = fileparts(str);

% Load TPM resources ONCE outside the loop. They are read-only and
% identical for every subject, so reloading per iteration just wastes IO.
maskstr = load(fullfile(mainfilepath, 'TPM', 'mask.mat'));
mask    = maskstr.mask;
TPMstr  = load(fullfile(mainfilepath, 'TPM', 'TPM.mat'));
TPM     = TPMstr.TPM;

failedSubjects = {};

% Initialize progress bar if a valid handle was provided.
if ~isempty(d) && isvalid(d)
    d.Value = 0;
end

for i = 1:n
    imageNamei = PETnames{i};
    subjOrig   = imageNamei;   % keep original name for logging
    try
        % Strip the trailing ',1' frame index, matching original behavior.
        imageNamei(end-1:end) = [];

        % --- Pre-processing -------------------------------------------
        cleanImg(imageNamei);
        initialNormalize(imageNamei);

        % Clean up intermediate files left by initialNormalize.
        [filepath, imagename, ext] = fileparts(imageNamei);
        yName = fullfile(filepath, ['y_c', imagename, '.nii']);
        if exist(yName, 'file'); delete(yName); end
        matfilename = fullfile(filepath, ['c', imagename, '_seg8.mat']);
        if exist(matfilename, 'file'); delete(matfilename); end

        % --- Build subject-specific TPM and run normalization ----------
        tempImgName = fullfile(filepath, ['temp', imagename, ext]);
        [newTPM, ~, ~] = computeNewTPM(tempImgName, TPM, mask, 30, 36, 30, rt);
        [~, ~, ~, TPMnum] = size(newTPM);

        finalNormalize(imageNamei, TPMnum, bbox, vx, nf);

        % --- Post-processing / cleanup ---------------------------------
        deleteFiles(imageNamei);
        newyName = fullfile(filepath, ['y_', imagename, '.nii']);
        movefile(yName, newyName);

        if sT == 0
            deleteTPMfiles(imageNamei, TPMnum);
        end
        if sD == 0
            delete(newyName);
        end

    catch ME
        % Record the failure but DO NOT rethrow: keep going with the rest.
        failedSubjects{end+1} = sprintf('%s | %s | %s', ...
            subjOrig, ME.identifier, ME.message); %#ok<AGROW>
        fprintf(2, '[FAIL] %s\n   %s\n', subjOrig, ME.message);
    end

    % Update progress bar if available.
    if ~isempty(d) && isvalid(d)
        d.Value = i / n;
    end
end

if ~isempty(d) && isvalid(d)
    d.Value = 1;
end
end