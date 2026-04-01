function evaluate_registration()
%EVALUATE_REGISTRATION  Assess PET/MRI-to-MNI registration quality.
%
%   Prompts the user to:
%     (1) Select one or more NIfTI images via spm_select
%     (2) Choose the output EXCEL file path via uiputfile
%
%   Produces a EXCEL report containing per-image scores:
%     - NMI  : Normalised Mutual Information vs SPM_T1 template (weight 40%)
%     - Dice : Spatial overlap vs brain mask (weight 60%)
%
%   Colour coding  :  Green >= 90  |  Yellow-green >= 85  |  Amber >= 80  |  Red < 80
%
%   Requirements   :  SPM12 (spm_vol, spm_read_vols, spm_select)
%                     compute_nmi.m, resampleImgToRef.m

%% -- 1. Select input images --------------------------------------------------
files = spm_select(Inf, 'image', 'Select NIfTI images to evaluate');
if isempty(strtrim(files))
    warning('[evaluate_registration] No files selected. Aborting.');
    return;
end
nFiles = size(files, 1);
fprintf('[INFO] %d image(s) selected.\n', nFiles);

%% -- 2. Select EXCEL output path -----------------------------------------------
[fname, fpath] = uiputfile( ...
    '*.xlsx', ...
    'Save registration quality report as', ...
    fullfile(pwd, 'registration_report.xlsx'));
if isequal(fname, 0)
    warning('[evaluate_registration] No output path selected. Aborting.');
    return;
end
outputExcelPath = fullfile(fpath, fname);

%% -- 3. Locate template and mask via SNBPI installation path -----------------
snbpiStr = which('SNBPI');
if isempty(snbpiStr)
    error('[evaluate_registration] SNBPI not found on MATLAB path.');
end
snbpiDir     = fileparts(snbpiStr);
templatePath = fullfile(snbpiDir, 'Template', 'SPM_T1.nii');
maskPath     = fullfile(snbpiDir, 'TPM',      'mask_All.nii');

assert(isfile(templatePath), '[evaluate_registration] Template not found: %s', templatePath);
assert(isfile(maskPath),     '[evaluate_registration] Mask not found: %s',     maskPath);

%% -- 4. Load template and brain mask (shared across all images) --------------
fprintf('[INFO] Loading MNI T1 template...\n');
templateVol = spm_vol(templatePath);
templateImg = double(spm_read_vols(templateVol));

fprintf('[INFO] Loading brain mask...\n');
maskVol  = spm_vol(maskPath);
maskOrig = double(spm_read_vols(maskVol));
if isequal(size(maskOrig), size(templateImg)) && ...
        isequal(maskVol.mat, templateVol.mat)
    brainMask = maskOrig > 0.5;
else
    fprintf('[INFO] Resampling mask to template space...\n');
    maskResampled = resampleImgToRef(maskPath, templatePath, 'nearest');
    brainMask     = maskResampled > 0.5;
end

%% -- 5. Evaluate each image --------------------------------------------------
results = repmat(struct( ...
    'filename','', 'fullpath','', ...
    'nmi_raw',NaN, 'nmi_score',NaN, ...
    'dice_raw',NaN,'dice_score',NaN, ...
    'score',NaN,   'quality','', 'errMsg',''), nFiles, 1);

for i = 1:nFiles
    imgPath = strtrim(files(i,:));
    [~, shortName, ext] = fileparts(imgPath);
    fprintf('[%d/%d] Evaluating: %s%s\n', i, nFiles, shortName, ext);

    try
        [sc, det] = eval_single(imgPath, templatePath, templateImg, brainMask);
        results(i).filename   = [shortName ext];
        results(i).fullpath   = imgPath;
        results(i).nmi_raw    = det.nmi_raw;
        results(i).nmi_score  = det.nmi_score;
        results(i).dice_raw   = det.dice_raw;
        results(i).dice_score = det.dice_score;
        results(i).score      = sc;
        results(i).quality    = quality_label(sc);
        results(i).errMsg     = '';
        fprintf('         Score: %.1f  |  NMI: %.4f  |  Dice: %.4f\n', ...
                sc, det.nmi_raw, det.dice_raw);
    catch ME
        results(i).filename = [shortName ext];
        results(i).fullpath = imgPath;
        results(i).quality  = 'Error';
        results(i).errMsg   = ME.message;
        fprintf('[ERROR]  %s\n', ME.message);
    end
end

%% -- 6. Generate EXCEL report ------------------------------------
fprintf('[INFO] Generating EXCEL report...\n');
write_excel_report(results, outputExcelPath);
fprintf('[DONE] Report saved to: %s\n', outputExcelPath);
end


%% ============================================================================
%  SUBFUNCTION: eval_single
%  Core metric computation for one image.
%% ============================================================================
function [score, details] = eval_single(inputImgPath, templatePath, templateImg, brainMask)

inputResampled = resampleImgToRef(inputImgPath, templatePath, 'linear');
inputResampled(~isfinite(inputResampled)) = 0;

% -- Metric 1: NMI vs T1 template --------------------------------------------
nmi_raw   = compute_nmi(inputResampled, templateImg, [], 64);
LOW_NMI   = 1.00;
HIGH_NMI  = 1.20;
nmi_score = clamp100((nmi_raw - LOW_NMI) / (HIGH_NMI - LOW_NMI) * 100);

% -- Metric 2: Dice overlap vs brain mask ------------------------------------
dice_raw   = 0;
dice_score = 0;

validVox = inputResampled(inputResampled > 0 & isfinite(inputResampled));
if numel(validVox) > 100
    thresholds = multithresh(inputResampled, 8);
    thresh     = thresholds(1) * 0.5;
    inputMask  = inputResampled > thresh;

    intersection = sum(inputMask(:) & brainMask(:));
    dice_raw     = 2 * intersection / ...
                   (sum(inputMask(:)) + sum(brainMask(:)) + eps);
    dice_score   = clamp100(dice_raw * 100);
else
    warning('[eval_single] Too few valid voxels — Dice set to 0.');
end

% -- Weighted composite score ------------------------------------------------
W_NMI  = 0.40;
W_DICE = 0.60;
score  = clamp100(W_NMI * nmi_score + W_DICE * dice_score);

details.nmi_raw    = nmi_raw;
details.nmi_score  = nmi_score;
details.dice_raw   = dice_raw;
details.dice_score = dice_score;
end


%% ============================================================================
%  NEW SUBFUNCTION: write_excel_report (ALL ENGLISH, NO CHINESE)
%% ============================================================================
function write_excel_report(results, outputPath)
    nFiles = numel(results);
    
    % Unique English variable names (NO CHINESE)
    varNames = {
        'ID', 'FileName', 'FullFilePath', ...
        'NMI_Raw', 'NMI_Score', ...
        'Dice_Raw', 'Dice_Score', ...
        'TotalScore', 'Quality', 'ErrorMessage'
    };
    
    % English headers only
    headers = {
        'ID', 'FileName', 'FullFilePath', ...
        'NMI Raw', 'NMI Score', ...
        'Dice Raw', 'Dice Score', ...
        'Total Score', 'Quality', 'Error Message'
    };
    
    data = cell(nFiles, length(varNames));
    
    for i = 1:nFiles
        res = results(i);
        data{i,1} = i;
        data{i,2} = res.filename;
        data{i,3} = res.fullpath;
        data{i,4} = res.nmi_raw;
        data{i,5} = res.nmi_score;
        data{i,6} = res.dice_raw;
        data{i,7} = res.dice_score;
        data{i,8} = res.score;
        data{i,9} = res.quality;
        data{i,10} = res.errMsg;
    end
    
    T = cell2table([data], 'VariableNames', varNames);
    
    % English sheet name
    writetable(T, outputPath, 'Sheet', 'Registration_Results', 'WriteVariableNames', true);
end


%% ============================================================================
%  HELPER SUBFUNCTIONS
%% ============================================================================

function v = clamp100(x)
    v = max(0, min(100, x));
end

function label = quality_label(score)
    if     score >= 90, label = 'Excellent';
    elseif score >= 85, label = 'Good';
    elseif score >= 80, label = 'Fair';
    else,               label = 'Failed';
    end
end