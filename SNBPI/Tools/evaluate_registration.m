function evaluate_registration()
%EVALUATE_REGISTRATION  Assess PET/MRI-to-MNI registration quality.
%
%   Prompts the user to:
%     (1) Select one or more NIfTI images via spm_select
%     (2) Choose the output EXCEL file path via uiputfile
%
%   Produces:
%     - EXCEL report with per-image scores
%     - PDF QC report with tri-planar overlays (GM TPM in red on the
%       registered image), 4 images per page, sorted worst-to-best.
%
%   Scoring:
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
[~, baseName, ~] = fileparts(fname);
outputPdfPath   = fullfile(fpath, [baseName '.pdf']);

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
% Map world origin to voxel index in template space (all resampled images
% live in this same grid, so one set of slice indices is shared globally).
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
    'score',NaN,   'quality','', 'errMsg','', ...
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
        results(i).quality        = quality_label(sc);
        results(i).errMsg         = '';
        results(i).inputResampled = det.inputResampled;
        fprintf('         Score: %.1f  |  NMI: %.4f  |  Dice: %.4f\n', ...
                sc, det.nmi_raw, det.dice_raw);
    catch ME
        results(i).filename       = [shortName ext];
        results(i).fullpath       = imgPath;
        results(i).quality        = 'Error';
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

%% -- 7. Generate PDF QC report -----------------------------------------------
fprintf('[INFO] Generating PDF QC report...\n');
write_pdf_report(results, gmInTemplate, [sliceX, sliceY, sliceZ], outputPdfPath);
fprintf('[DONE] PDF report saved to: %s\n', outputPdfPath);
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
        'TotalScore', 'Quality', 'ErrorMessage'
    };

    data = cell(nFiles, length(varNames));
    for i = 1:nFiles
        res = results(i);
        data{i,1}  = i;
        data{i,2}  = res.filename;
        data{i,3}  = res.fullpath;
        data{i,4}  = res.nmi_raw;
        data{i,5}  = res.nmi_score;
        data{i,6}  = res.dice_raw;
        data{i,7}  = res.dice_score;
        data{i,8}  = res.score;
        data{i,9}  = res.quality;
        data{i,10} = res.errMsg;
    end

    T = cell2table(data, 'VariableNames', varNames);
    writetable(T, outputPath, 'Sheet', 'Registration_Results', 'WriteVariableNames', true);
end


%% ============================================================================
%  SUBFUNCTION: write_pdf_report
%  4 images per page, each as a column of 3 views (axial/coronal/sagittal)
%  with a caption block at the bottom. Sorted worst -> best.
%% ============================================================================
function write_pdf_report(results, gmInTemplate, sliceIdx, pdfPath)
    nFiles    = numel(results);
    COLS      = 4;
    nPages    = ceil(nFiles / COLS);

    sliceX = sliceIdx(1);
    sliceY = sliceIdx(2);
    sliceZ = sliceIdx(3);

    % Pre-extract GM slices (shared across all images)
    gmAxial    = orient_axial(   gmInTemplate(:, :, sliceZ));
    gmCoronal  = orient_coronal( squeeze(gmInTemplate(:, sliceY, :)));
    gmSagittal = orient_sagittal(squeeze(gmInTemplate(sliceX, :, :)));

    firstPage = true;
    for p = 1:nPages
        idxStart = (p-1)*COLS + 1;
        idxEnd   = min(p*COLS, nFiles);

        fig = figure('Visible','off', 'Color','w', ...
                     'Units','inches', 'Position',[0 0 11 8.5], ...
                     'PaperUnits','inches', 'PaperSize',[11 8.5], ...
                     'PaperPosition',[0 0 11 8.5]);

        tl = tiledlayout(fig, 4, COLS, ...
                         'TileSpacing','compact', 'Padding','compact');
        title(tl, sprintf('Registration QC Report (page %d / %d)', p, nPages), ...
              'FontWeight','bold', 'FontSize',12);

        % Force consistent page size: invisible full-figure rectangle so
        % exportgraphics' tight crop always equals the full figure extent.
        annotation(fig, 'rectangle', [0 0 1 1], ...
                   'Color','w', 'LineWidth',0.01);

        for c = 1:COLS
            globalIdx = idxStart + c - 1;
            if globalIdx > nFiles
                % Empty placeholder tiles
                for row = 1:4
                    ax = nexttile(tl, (row-1)*COLS + c);
                    axis(ax, 'off');
                end
                continue;
            end

            res = results(globalIdx);
            drawColumn(tl, c, COLS, res, gmAxial, gmCoronal, gmSagittal, ...
                       sliceIdx, globalIdx);
        end

        if firstPage
            exportgraphics(fig, pdfPath, 'ContentType','vector');
            firstPage = false;
        else
            exportgraphics(fig, pdfPath, 'ContentType','vector', 'Append',true);
        end
        close(fig);
        fprintf('[INFO] PDF page %d/%d written.\n', p, nPages);
    end
end


%% ============================================================================
%  SUBFUNCTION: drawColumn
%  Render one column (3 views + caption) for one image.
%% ============================================================================
function drawColumn(tl, col, nCols, res, gmAxial, gmCoronal, gmSagittal, ...
                    sliceIdx, globalIdx)

    sliceX = sliceIdx(1);
    sliceY = sliceIdx(2);
    sliceZ = sliceIdx(3);

    hasImage = ~isempty(res.inputResampled) && ~strcmp(res.quality,'Error');

    % ---- Row 1: Axial -------------------------------------------------------
    ax1 = nexttile(tl, (1-1)*nCols + col);
    if hasImage
        bg = orient_axial(res.inputResampled(:, :, sliceZ));
        rgb = overlay_red(bg, gmAxial, 0.5);
        imshow(rgb, 'Parent', ax1);
    else
        show_error_placeholder(ax1);
    end
    title(ax1, 'Axial', 'FontSize',9);

    % ---- Row 2: Coronal -----------------------------------------------------
    ax2 = nexttile(tl, (2-1)*nCols + col);
    if hasImage
        bg = orient_coronal(squeeze(res.inputResampled(:, sliceY, :)));
        rgb = overlay_red(bg, gmCoronal, 0.5);
        imshow(rgb, 'Parent', ax2);
    else
        show_error_placeholder(ax2);
    end
    title(ax2, 'Coronal', 'FontSize',9);

    % ---- Row 3: Sagittal ----------------------------------------------------
    ax3 = nexttile(tl, (3-1)*nCols + col);
    if hasImage
        bg = orient_sagittal(squeeze(res.inputResampled(sliceX, :, :)));
        rgb = overlay_red(bg, gmSagittal, 0.7);
        imshow(rgb, 'Parent', ax3);
    else
        show_error_placeholder(ax3);
    end
    title(ax3, 'Sagittal', 'FontSize',9);

    % ---- Row 4: Caption -----------------------------------------------------
    axC = nexttile(tl, (4-1)*nCols + col);
    axis(axC, 'off');
    xlim(axC, [0 1]); ylim(axC, [0 1]);

    qColor = quality_color(res.quality);
    fname  = strrep(res.filename, '_', '\_');  % escape TeX

    if strcmp(res.quality,'Error')
        line1 = sprintf('#%d  %s', globalIdx, fname);
        line2 = '\color[rgb]{0.8,0,0}Status: ERROR';
        errTxt = res.errMsg;
        if length(errTxt) > 40, errTxt = [errTxt(1:37) '...']; end
        line3 = sprintf('%s', strrep(errTxt,'_','\_'));
        line4 = '';
        line5 = '';
    else
        line1 = sprintf('#%d  %s', globalIdx, fname);
        line2 = sprintf('\\color[rgb]{%.2f,%.2f,%.2f}Score: %.1f  (%s)', ...
                        qColor(1), qColor(2), qColor(3), res.score, res.quality);
        line3 = sprintf('NMI : %.4f  (%.1f)', res.nmi_raw,  res.nmi_score);
        line4 = sprintf('Dice: %.4f  (%.1f)', res.dice_raw, res.dice_score);
        line5 = '';
    end

    caption = sprintf('%s\n%s\n%s\n%s\n%s', line1, line2, line3, line4, line5);
    text(axC, 0.02, 0.95, caption, ...
         'VerticalAlignment','top', 'HorizontalAlignment','left', ...
         'FontSize',8, 'FontName','Helvetica', 'Interpreter','tex');
end


%% ============================================================================
%  SUBFUNCTION: overlay_red
%  Alpha-blend a red layer (driven by prob) on top of a grayscale background.
%% ============================================================================
function rgb = overlay_red(bgSlice, probSlice, alphaScale)
    % Contrast-stretch background to [0,1] using robust percentiles
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

    % Grayscale RGB
    gray_rgb = repmat(bg, [1 1 3]);

    % Red layer driven by probability
    prob = double(probSlice);
    prob(~isfinite(prob)) = 0;
    prob = max(0, min(1, prob));
    alpha = alphaScale * prob;
    alpha3 = repmat(alpha, [1 1 3]);

    red_layer = zeros(size(gray_rgb));
    red_layer(:,:,1) = 1;

    rgb = (1 - alpha3) .* gray_rgb + alpha3 .* red_layer;
    rgb = max(0, min(1, rgb));
end


%% ============================================================================
%  SUBFUNCTION: show_error_placeholder
%% ============================================================================
function show_error_placeholder(ax)
    imshow(ones(10,10,3) .* reshape([1 0.9 0.9],1,1,3), 'Parent', ax);
    text(ax, 5, 5, 'N/A', 'HorizontalAlignment','center', ...
         'VerticalAlignment','middle', 'Color',[0.6 0 0], ...
         'FontWeight','bold', 'FontSize',10);
end


%% ============================================================================
%  ORIENTATION HELPERS
%  Put anatomical "up" at the top of the image. Assumes input arrays follow
%  SPM/NIfTI convention (+X = right, +Y = anterior, +Z = superior) in
%  template (MNI) space.
%% ============================================================================
function out = orient_axial(slice2d)
    % Input is X-by-Y (after indexing (:,:,z)). Rotate so +Y (anterior) is up.
    out = rot90(slice2d);
end

function out = orient_coronal(slice2d)
    % Input is X-by-Z (after squeeze(:,y,:)). Rotate so +Z (superior) is up.
    out = rot90(slice2d);
end

function out = orient_sagittal(slice2d)
    % Input is Y-by-Z (after squeeze(x,:,:)). Rotate so +Z (superior) is up
    % and flip so +Y (anterior) is on the left (neurological convention).
    out = fliplr(rot90(slice2d));
end


%% ============================================================================
%  OTHER HELPERS
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

function c = quality_color(quality)
    switch quality
        case 'Excellent', c = [0.00 0.60 0.00];
        case 'Good',      c = [0.50 0.70 0.00];
        case 'Fair',      c = [0.90 0.50 0.00];
        case 'Failed',    c = [0.80 0.00 0.00];
        case 'Error',     c = [0.80 0.00 0.00];
        otherwise,        c = [0.00 0.00 0.00];
    end
end

function k = sort_key(res)
    % Errors and NaN scores sort first (worst).
    if strcmp(res.quality, 'Error') || isnan(res.score)
        k = -Inf;
    else
        k = res.score;
    end
end