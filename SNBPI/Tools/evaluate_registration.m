function evaluate_registration()
%EVALUATE_REGISTRATION  Assess PET/MRI-to-MNI registration quality.
%
%   Prompts the user to:
%     (1) Select one or more NIfTI images via spm_select
%     (2) Choose the output EXCEL file path via uiputfile
%
%   Produces:
%     - EXCEL report with per-image scores (NMI, Dice, Total)
%     - HTML QC report with tri-planar overlays (GM TPM in red on the
%       registered image), sorted by score ascending for quick visual review.
%
%   Scoring:
%     - NMI  : Normalised Mutual Information vs SPM_T1 template (weight 40%)
%     - Dice : Spatial overlap vs brain mask (weight 60%)
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
[~, baseName, ~] = fileparts(fname);
outputHtmlPath  = fullfile(fpath, [baseName '.html']);

%% -- 3. Locate template, mask and GM TPM via SNBPI installation path ---------
snbpiStr = which('SNBPI');
if isempty(snbpiStr)
    error('[evaluate_registration] SNBPI not found on MATLAB path.');
end
snbpiDir     = fileparts(snbpiStr);
templatePath = fullfile(snbpiDir, 'Template', 'SPM_T1.nii');
maskPath     = fullfile(snbpiDir, 'TPM',      'mask_All.nii');
gmPath       = fullfile(snbpiDir, 'TPM',      'TPM_Gray.nii');

assert(isfile(templatePath), '[evaluate_registration] Template not found: %s', templatePath);
assert(isfile(maskPath),     '[evaluate_registration] Mask not found: %s',     maskPath);
assert(isfile(gmPath),       '[evaluate_registration] GM TPM not found: %s',   gmPath);

%% -- 4. Load template, brain mask and GM TPM (shared across all images) ------
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

fprintf('[INFO] Loading GM TPM...\n');
gmVol  = spm_vol(gmPath);
gmOrig = double(spm_read_vols(gmVol));
if isequal(size(gmOrig), size(templateImg)) && ...
        isequal(gmVol.mat, templateVol.mat)
    gmInTemplate = gmOrig;
else
    fprintf('[INFO] Resampling GM TPM to template space...\n');
    gmInTemplate = resampleImgToRef(gmPath, templatePath, 'linear');
end
gmInTemplate(~isfinite(gmInTemplate)) = 0;
gmInTemplate = max(0, min(1, gmInTemplate));  % clamp to [0,1]

%% -- 4b. Compute slice indices at world origin [0,0,0] -----------------------
vox_at_origin = templateVol.mat \ [0; 0; 0; 1];
sliceX = max(1, min(size(templateImg,1), round(vox_at_origin(1))));  % sagittal
sliceY = max(1, min(size(templateImg,2), round(vox_at_origin(2))));  % coronal
sliceZ = max(1, min(size(templateImg,3), round(vox_at_origin(3))));  % axial
fprintf('[INFO] QC slice indices (template space): X=%d Y=%d Z=%d\n', ...
        sliceX, sliceY, sliceZ);

%% -- 5. Evaluate each image --------------------------------------------------
results = repmat(struct( ...
    'filename','', 'fullpath','', ...
    'nmi_raw',NaN, 'nmi_score',NaN, ...
    'dice_raw',NaN,'dice_score',NaN, ...
    'score',NaN,   'errMsg','', ...
    'inputResampled',[]), nFiles, 1);

for i = 1:nFiles
    imgPath = strtrim(files(i,:));
    [~, shortName, ext] = fileparts(imgPath);
    fprintf('[%d/%d] Evaluating: %s%s\n', i, nFiles, shortName, ext);

    try
        [sc, det] = eval_single(imgPath, templatePath, templateImg, brainMask);
        results(i).filename       = [shortName ext];
        results(i).fullpath       = imgPath;
        results(i).nmi_raw        = det.nmi_raw;
        results(i).nmi_score      = det.nmi_score;
        results(i).dice_raw       = det.dice_raw;
        results(i).dice_score     = det.dice_score;
        results(i).score          = sc;
        results(i).errMsg         = '';
        results(i).inputResampled = det.inputResampled;
        fprintf('         Score: %.1f  |  NMI: %.4f  |  Dice: %.4f\n', ...
                sc, det.nmi_raw, det.dice_raw);
    catch ME
        results(i).filename       = [shortName ext];
        results(i).fullpath       = imgPath;
        results(i).errMsg         = ME.message;
        results(i).inputResampled = [];
        fprintf('[ERROR]  %s\n', ME.message);
    end
end

%% -- 5b. Sort results worst -> best (errors/NaN first) ----------------------
scoresForSort = arrayfun(@(r) sort_key(r), results);
[~, order]    = sort(scoresForSort, 'ascend');
results       = results(order);

%% -- 6. Generate EXCEL report ------------------------------------------------
fprintf('[INFO] Generating EXCEL report...\n');
write_excel_report(results, outputExcelPath);
fprintf('[DONE] Excel report saved to: %s\n', outputExcelPath);

%% -- 7. Generate HTML QC report -----------------------------------------------
fprintf('[INFO] Generating HTML QC report...\n');
write_html_report(results, gmInTemplate, [sliceX, sliceY, sliceZ], outputHtmlPath);
fprintf('[DONE] HTML report saved to: %s\n', outputHtmlPath);
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

details.nmi_raw        = nmi_raw;
details.nmi_score      = nmi_score;
details.dice_raw       = dice_raw;
details.dice_score     = dice_score;
details.inputResampled = inputResampled;
end


%% ============================================================================
%  SUBFUNCTION: write_excel_report
%% ============================================================================
function write_excel_report(results, outputPath)
    nFiles = numel(results);

    varNames = {
        'ID', 'FileName', 'FullFilePath', ...
        'NMI_Raw', 'NMI_Score', ...
        'Dice_Raw', 'Dice_Score', ...
        'TotalScore', 'ErrorMessage'
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
        data{i,9} = res.errMsg;
    end

    T = cell2table(data, 'VariableNames', varNames);
    writetable(T, outputPath, 'Sheet', 'Registration_Results', 'WriteVariableNames', true);
end


%% ============================================================================
%  SUBFUNCTION: write_html_report
%  One card per image: axial / coronal / sagittal with GM overlay.
%  Images are base64-encoded PNGs — single self-contained HTML file.
%% ============================================================================
function write_html_report(results, gmInTemplate, sliceIdx, htmlPath)
    nFiles = numel(results);

    sliceX = sliceIdx(1);
    sliceY = sliceIdx(2);
    sliceZ = sliceIdx(3);

    % Pre-extract GM slices (shared across all images)
    gmAxial    = orient_axial(   gmInTemplate(:, :, sliceZ));
    gmCoronal  = orient_coronal( squeeze(gmInTemplate(:, sliceY, :)));
    gmSagittal = orient_sagittal(squeeze(gmInTemplate(sliceX, :, :)));

    % Open file
    fid = fopen(htmlPath, 'w', 'n', 'UTF-8');
    if fid == -1
        error('[write_html_report] Cannot open file: %s', htmlPath);
    end
    cleanObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    % ---- HTML head ----------------------------------------------------------
    fprintf(fid, '<!DOCTYPE html>\n<html lang="en">\n<head>\n');
    fprintf(fid, '<meta charset="UTF-8">\n');
    fprintf(fid, '<title>Registration QC Report</title>\n');
    fprintf(fid, '<style>\n');
    fprintf(fid, 'body{font-family:Arial,Helvetica,sans-serif;background:#f5f5f5;margin:20px;}\n');
    fprintf(fid, 'h1{text-align:center;color:#333;}\n');
    fprintf(fid, 'p.subtitle{text-align:center;color:#777;font-size:14px;}\n');
    fprintf(fid, '.card{background:#fff;border:1px solid #ddd;border-radius:8px;');
    fprintf(fid, 'margin:12px auto;max-width:900px;padding:16px;display:flex;');
    fprintf(fid, 'flex-wrap:wrap;align-items:center;gap:12px;}\n');
    fprintf(fid, '.card.error{border-color:#c00;}\n');
    fprintf(fid, '.views{display:flex;gap:6px;}\n');
    fprintf(fid, '.views img{height:180px;border:1px solid #eee;}\n');
    fprintf(fid, '.info{flex:1;min-width:200px;font-size:13px;line-height:1.6;}\n');
    fprintf(fid, '.info .fname{font-weight:bold;font-size:14px;word-break:break-all;}\n');
    fprintf(fid, '.info .err{color:#c00;}\n');
    fprintf(fid, '</style>\n');
    fprintf(fid, '</head>\n<body>\n');
    fprintf(fid, '<h1>Registration QC Report</h1>\n');
    fprintf(fid, '<p class="subtitle">%d image(s) &mdash; sorted by score ascending (lowest first). ', nFiles);
    fprintf(fid, 'Red overlay = GM TPM.</p>\n');

    % ---- One card per image -------------------------------------------------
    for i = 1:nFiles
        res = results(i);
        isError = ~isempty(res.errMsg);

        if isError
            fprintf(fid, '<div class="card error">\n');
        else
            fprintf(fid, '<div class="card">\n');
        end

        % -- Images -----------------------------------------------------------
        fprintf(fid, '<div class="views">\n');
        if ~isError && ~isempty(res.inputResampled)
            % Axial
            bg  = orient_axial(res.inputResampled(:, :, sliceZ));
            rgb = overlay_red(bg, gmAxial, 0.5);
            fprintf(fid, '<img src="data:image/png;base64,%s" title="Axial">\n', ...
                    encode_rgb_png(rgb));
            % Coronal
            bg  = orient_coronal(squeeze(res.inputResampled(:, sliceY, :)));
            rgb = overlay_red(bg, gmCoronal, 0.5);
            fprintf(fid, '<img src="data:image/png;base64,%s" title="Coronal">\n', ...
                    encode_rgb_png(rgb));
            % Sagittal
            bg  = orient_sagittal(squeeze(res.inputResampled(sliceX, :, :)));
            rgb = overlay_red(bg, gmSagittal, 0.7);
            fprintf(fid, '<img src="data:image/png;base64,%s" title="Sagittal">\n', ...
                    encode_rgb_png(rgb));
        else
            fprintf(fid, '<span style="color:#999;">No image available</span>\n');
        end
        fprintf(fid, '</div>\n');

        % -- Info text --------------------------------------------------------
        fprintf(fid, '<div class="info">\n');
        fprintf(fid, '<div class="fname">#%d &nbsp; %s</div>\n', ...
                i, escape_html(res.filename));
        if isError
            errTxt = res.errMsg;
            if length(errTxt) > 120, errTxt = [errTxt(1:117) '...']; end
            fprintf(fid, '<div class="err">Error: %s</div>\n', escape_html(errTxt));
        else
            fprintf(fid, 'Score: %.1f &nbsp;|&nbsp; NMI: %.4f (%.1f) &nbsp;|&nbsp; Dice: %.4f (%.1f)\n', ...
                    res.score, res.nmi_raw, res.nmi_score, ...
                    res.dice_raw, res.dice_score);
        end
        fprintf(fid, '</div>\n');
        fprintf(fid, '</div>\n');

        if mod(i, 10) == 0
            fprintf('[INFO] HTML card %d/%d written.\n', i, nFiles);
        end
    end

    % ---- Footer -------------------------------------------------------------
    fprintf(fid, '<p style="text-align:center;color:#aaa;font-size:11px;margin-top:30px;">');
    fprintf(fid, 'Generated by evaluate_registration &mdash; %s</p>\n', ...
            datestr(now)); %#ok<TNOW1,DATST>
    fprintf(fid, '</body>\n</html>\n');
end


%% ============================================================================
%  SUBFUNCTION: encode_rgb_png
%  Convert an [M x N x 3] double RGB array (range [0,1]) to a base64 PNG
%  string via a temporary file.
%% ============================================================================
function b64 = encode_rgb_png(rgb)
    img8 = uint8(round(rgb * 255));
    tmpFile = [tempname '.png'];
    imwrite(img8, tmpFile);
    fid = fopen(tmpFile, 'r');
    raw = fread(fid, Inf, 'uint8=>uint8');
    fclose(fid);
    delete(tmpFile);
    b64 = matlab.net.base64encode(raw);
end


%% ============================================================================
%  SUBFUNCTION: escape_html
%  Minimal HTML escaping for safe display.
%% ============================================================================
function s = escape_html(s)
    s = strrep(s, '&',  '&amp;');
    s = strrep(s, '<',  '&lt;');
    s = strrep(s, '>',  '&gt;');
    s = strrep(s, '"',  '&quot;');
end


%% ============================================================================
%  SUBFUNCTION: overlay_red
%  Alpha-blend a red layer (driven by prob) on top of a grayscale background.
%% ============================================================================
function rgb = overlay_red(bgSlice, probSlice, alphaScale)
    bg = double(bgSlice);
    bg(~isfinite(bg)) = 0;
    nz = bg(bg > 0);
    if numel(nz) > 10
        lo = prctile(nz, 1);
        hi = prctile(nz, 99);
    else
        lo = 0; hi = 1;
    end
    if hi <= lo, hi = lo + eps; end
    bg = (bg - lo) / (hi - lo);
    bg = max(0, min(1, bg));

    gray_rgb = repmat(bg, [1 1 3]);

    prob = double(probSlice);
    prob(~isfinite(prob)) = 0;
    prob = max(0, min(1, prob));
    alpha  = alphaScale * prob;
    alpha3 = repmat(alpha, [1 1 3]);

    red_layer = zeros(size(gray_rgb));
    red_layer(:,:,1) = 1;

    rgb = (1 - alpha3) .* gray_rgb + alpha3 .* red_layer;
    rgb = max(0, min(1, rgb));
end


%% ============================================================================
%  ORIENTATION HELPERS
%% ============================================================================
function out = orient_axial(slice2d)
    out = rot90(slice2d);
end

function out = orient_coronal(slice2d)
    out = rot90(slice2d);
end

function out = orient_sagittal(slice2d)
    out = fliplr(rot90(slice2d));
end


%% ============================================================================
%  OTHER HELPERS
%% ============================================================================
function v = clamp100(x)
    v = max(0, min(100, x));
end

function k = sort_key(res)
    if ~isempty(res.errMsg) || isnan(res.score)
        k = -Inf;
    else
        k = res.score;
    end
end