function checkReferenceMaskAlignment(meanImg, ReferenceMask)
% checkReferenceMaskAlignment - Display brain slices with semi-transparent
% reference mask overlay. Only slices containing mask voxels are shown.
%
% Inputs:
%   meanImg       - 3D brain image matrix (X x Y x Z)
%   ReferenceMask - 3D reference region mask (X x Y x Z), same size as meanImg
%
% Usage:
%   checkReferenceMaskAlignment(meanImg, ReferenceMask)

    %% Input validation
    if ~isequal(size(meanImg), size(ReferenceMask))
        error('meanImg and ReferenceMask must have the same dimensions.');
    end

    %% Find slices that contain mask voxels
    sliceHasMask = squeeze(any(any(ReferenceMask > 0, 1), 2));
    activeSlices = find(sliceHasMask);
    nSlices      = numel(activeSlices);

    if nSlices == 0
        warning('ReferenceMask contains no non-zero voxels. Nothing to display.');
        return;
    end

    %% Normalize image for display
    imgMin = min(meanImg(:));
    imgMax = max(meanImg(:));
    if imgMax > imgMin
        imgNorm = (meanImg - imgMin) / (imgMax - imgMin);
    else
        imgNorm = zeros(size(meanImg));
    end

    %% Overlay settings
    maskColor = [1.0, 0.2, 0.2];   % Red (R, G, B)
    maskAlpha = 0.45;               % Transparency

    %% Subplot layout (close to square)
    nCols = ceil(sqrt(nSlices));
    nRows = ceil(nSlices / nCols);

    %% Create figure
    fig = figure('Name', 'Reference Mask Alignment Check', ...
                 'NumberTitle', 'off', ...
                 'Color', [0.1, 0.1, 0.1], ...
                 'MenuBar', 'none', ...
                 'ToolBar', 'figure');

    screenSz = get(0, 'ScreenSize');
    figW     = min(screenSz(3) * 0.9, nCols * 160 + 80);
    figH     = min(screenSz(4) * 0.85, nRows * 160 + 100);
    set(fig, 'Position', [(screenSz(3)-figW)/2, (screenSz(4)-figH)/2, figW, figH]);

    %% Title annotation
    annotation(fig, 'textbox', [0, 0.95, 1, 0.05], ...
        'String', sprintf('Reference Mask Alignment Check  |  %d / %d slices with mask  |  Red = reference region', ...
                          nSlices, size(meanImg, 3)), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment',   'middle', ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'Color', [1,1,1], 'EdgeColor', 'none', 'BackgroundColor', 'none');

    %% Plot each active slice
    for k = 1 : nSlices
        z = activeSlices(k);

        ax = subplot(nRows, nCols, k, 'Parent', fig);

        % Extract slice and rotate 90° clockwise to correct orientation
        slice2D   = rot90(imgNorm(:, :, z), 1);
        maskSlice = rot90(ReferenceMask(:, :, z) > 0, 1);

        % Convert grayscale to RGB
        rgbImg = repmat(slice2D, [1, 1, 3]);

        % Blend mask as semi-transparent red overlay
        for ch = 1 : 3
            channel = rgbImg(:, :, ch);
            channel(maskSlice) = channel(maskSlice) * (1 - maskAlpha) + ...
                                  maskColor(ch) * maskAlpha;
            rgbImg(:, :, ch) = channel;
        end

        imshow(rgbImg, 'Parent', ax);
        title(ax, sprintf('z = %d', z), ...
              'FontSize', 7, 'Color', [0.85, 0.85, 0.85], 'FontWeight', 'normal');
        set(ax, 'XTick', [], 'YTick', [], 'XColor', 'none', 'YColor', 'none');
    end

    %% Hide unused subplot panels
    for k = nSlices + 1 : nRows * nCols
        ax = subplot(nRows, nCols, k, 'Parent', fig);
        set(ax, 'Visible', 'off');
    end

    %% Tighten subplot spacing
    tightfig_custom(fig, nRows, nCols);

    %% Legend patch (bottom-right)
    annotation(fig, 'rectangle', [0.84, 0.01, 0.04, 0.025], ...
        'FaceColor', maskColor, 'EdgeColor', 'none', 'FaceAlpha', maskAlpha + 0.2);
    annotation(fig, 'textbox', [0.89, 0.005, 0.1, 0.03], ...
        'String', 'Reference mask', 'Color', [1,1,1], ...
        'FontSize', 8, 'EdgeColor', 'none', 'BackgroundColor', 'none', ...
        'VerticalAlignment', 'middle');
end


%% Helper: compact subplot layout
function tightfig_custom(fig, nRows, nCols)
    margin_top    = 0.06;
    margin_bottom = 0.04;
    margin_left   = 0.01;
    margin_right  = 0.01;
    gap_v         = 0.005;
    gap_h         = 0.005;

    pw = (1 - margin_left - margin_right - gap_h * (nCols - 1)) / nCols;
    ph = (1 - margin_top  - margin_bottom - gap_v * (nRows - 1)) / nRows;

    axes_list = findobj(fig, 'Type', 'axes');
    [~, idx]  = sort(arrayfun(@(a) a.Position(2) * 1000 - a.Position(1), axes_list), 'descend');
    axes_list = axes_list(idx);

    k = 0;
    for r = 1 : nRows
        for c = 1 : nCols
            k = k + 1;
            if k > numel(axes_list), break; end
            x0 = margin_left + (c - 1) * (pw + gap_h);
            y0 = 1 - margin_top - r * ph - (r - 1) * gap_v;
            set(axes_list(k), 'Position', [x0, y0, pw, ph]);
        end
    end
end