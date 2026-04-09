function AtlasMergerTool()
% AtlasMergerTool - Interactive brain region Atlas merging tool
%
% Features:
%   1. Load NIfTI format Atlas images and corresponding _Labels.mat label files
%   2. Display image, ROI list, merge operations and merge results in a 4-column interactive UI
%   3. Highlight corresponding brain regions on the image when an ROI is checked
%   4. Merge selected ROIs into a new ROI and output a new Atlas file
%
% Dependencies:
%   SPM12 (must be added to the MATLAB path)
%
% Usage:
%   AtlasMergerTool()

%% ================================================================
%% State variables (shared across all nested functions)
%% ================================================================
S.atlasFile    = '';
S.atlasVol     = [];       % SPM vol struct
S.atlasData    = [];       % 3D double array
S.Labels       = {};       % n x 2 cell: {ROI name (str), Index (double)}
S.nROI         = 0;
S.selected     = logical([]);  % n x 1 logical, whether checked
S.disabled     = logical([]);  % n x 1 logical, disabled after merging
S.mergedList   = {};       % cell array of merged ROI structs
S.orientation  = 'axial';
S.currentSlice = 1;
S.nSlices      = 1;

%% ================================================================
%% UI layout constants
%% ================================================================
FW   = 1600;   % Window width
FH   = 900;    % Window height
colW = 378;    % Column width
gap  = 8;      % Gap between columns
lm   = 5;      % Left margin
panH = FH - 92;  % Panel height
panY = 45;        % Panel bottom Y coordinate
cX   = @(c) lm + (c-1)*(colW+gap);  % X coordinate of column c

%% ================================================================
%% Create main window
%% ================================================================
% Note: CloseRequestFcn must be set after fig is assigned,
% otherwise the anonymous function captures an unassigned fig (classic MATLAB trap)
fig = figure( ...
    'Name',        'Atlas ROI Merger Tool | AtlasMergerTool', ...
    'NumberTitle', 'off', ...
    'Position',    [20 30 FW FH], ...
    'MenuBar',     'none', ...
    'ToolBar',     'none', ...
    'Color',       [0.15 0.17 0.22], ...
    'Resize',      'off');
set(fig, 'CloseRequestFcn', @cb_close);

%% ================================================================
%% Top toolbar
%% ================================================================
% Select file button
uicontrol(fig, 'Style', 'pushbutton', ...
    'String',          'Select Atlas (.nii)', ...
    'Position',        [8 FH-42 175 33], ...
    'FontSize',        10, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.20 0.55 0.95], ...
    'ForegroundColor', 'white', ...
    'Callback',        @cb_selectAtlas);

hFileLbl = uicontrol(fig, 'Style', 'text', ...
    'String',           'Please select an Atlas NIfTI file (.nii) first', ...
    'Position',         [192 FH-40 FW-400 26], ...
    'HorizontalAlignment', 'left', ...
    'FontSize',         9, ...
    'BackgroundColor',  [0.15 0.17 0.22], ...
    'ForegroundColor',  [0.65 0.75 0.85]);

%% ================================================================
%% Create four panels
%% ================================================================
panelColor = [0.18 0.20 0.26];
titleColor = [0.22 0.24 0.32]; %#ok<NASGU>

p1 = makepanel(' (1) Original Atlas Image',          cX(1), panY, colW, panH);
p2 = makepanel(' (2) ROI List (check to highlight)', cX(2), panY, colW, panH);
p3 = makepanel(' (3) Merge Operations',              cX(3), panY, colW, panH);
p4 = makepanel(' (4) Merged ROI List',               cX(4), panY, colW, panH);

    function p = makepanel(title_, x, y, w, h)
        p = uipanel(fig, ...
            'Units',           'pixels', ...     % Must specify, default is normalized!
            'Title',           title_, ...
            'Position',        [x y w h], ...
            'FontSize',        10, 'FontWeight', 'bold', ...
            'ForegroundColor', [0.55 0.75 0.95], ...
            'BackgroundColor', panelColor, ...
            'BorderType',      'line', ...
            'HighlightColor',  [0.30 0.35 0.45]);
    end

%% ================================================================
%% Panel 1: Image display
%% ================================================================
hAx = axes('Parent', p1, 'Units', 'pixels', ...
    'Position', [8 58 colW-16 panH-95]);
set(hAx, 'Color', 'k', 'XColor', 'none', 'YColor', 'none');
axis(hAx, 'image', 'off');

% Slice slider
uicontrol(p1, 'Style', 'text', 'String', 'Slice:', ...
    'Position', [8 35 38 18], 'FontSize', 9, ...
    'BackgroundColor', panelColor, 'ForegroundColor', [0.75 0.85 0.95]);
hSlider = uicontrol(p1, 'Style', 'slider', ...
    'Position', [50 33 colW-108 22], 'Min', 1, 'Max', 2, 'Value', 1, ...
    'SliderStep', [1 1], 'Callback', @cb_slider, ...
    'BackgroundColor', [0.28 0.32 0.42]);
hSliceLbl = uicontrol(p1, 'Style', 'text', 'String', '-/-', ...
    'Position', [colW-54 33 50 20], 'FontSize', 9, ...
    'BackgroundColor', [0.10 0.12 0.16], 'ForegroundColor', [0.9 0.95 1.0], ...
    'HorizontalAlignment', 'center');

% Orientation selection
hOrBG = uibuttongroup(p1, ...
    'Units',               'pixels', ...    % Must specify, default is normalized!
    'Position',            [8 10 colW-16 22], ...
    'BorderType',          'none', ...
    'BackgroundColor',     panelColor, ...
    'SelectionChangedFcn', @cb_orientation);
hOrAx = makeRadio(hOrBG, 'Axial',    0,   1);
hOrCo = makeRadio(hOrBG, 'Coronal',  80,  0); %#ok<NASGU>
hOrSa = makeRadio(hOrBG, 'Sagittal', 165, 0); %#ok<NASGU>

    function rb = makeRadio(parent, str, x, val)
        rb = uicontrol(parent, 'Style', 'radiobutton', 'String', str, ...
            'Position', [x 2 80 18], 'Value', val, 'FontSize', 9, ...
            'BackgroundColor', panelColor, 'ForegroundColor', [0.80 0.90 1.0]);
    end

%% ================================================================
%% Panel 2: ROI list (uitable)
%% ================================================================
hROITable = uitable(p2, ...
    'Position',    [5 5 colW-10 panH-32], ...
    'ColumnName',  {'ROI Name', 'Index', 'Select', 'Status'}, ...
    'ColumnWidth', {152, 52, 45, 88}, ...
    'ColumnEditable', [false false true false], ...
    'ColumnFormat', {'char', 'numeric', 'logical', 'char'}, ...
    'RowName',     [], ...
    'Data',        {}, ...
    'FontSize',    9, ...
    'CellEditCallback', @cb_roiSelect);

%% ================================================================
%% Panel 3: Merge operations
%% ================================================================
innerH = panH - 28;  % Available inner height (minus title bar)

% Selected ROI preview label
uicontrol(p3, 'Style', 'text', 'String', 'Selected ROIs (to be merged):', ...
    'Position', [8 innerH-28 260 20], 'FontSize', 9, ...
    'HorizontalAlignment', 'left', ...
    'BackgroundColor', panelColor, 'ForegroundColor', [0.65 0.80 0.95]);

% Selected ROI preview listbox
hPreview = uicontrol(p3, 'Style', 'listbox', ...
    'Position', [8 innerH-148 colW-16 118], ...
    'String', {}, 'FontSize', 9, 'Enable', 'inactive', ...
    'BackgroundColor', [0.10 0.12 0.18], ...
    'ForegroundColor', [0.85 0.95 0.75]);

% Separator line (simulated with text)
uicontrol(p3, 'Style', 'text', 'String', repmat('-', 1, 60), ...
    'Position', [8 innerH-158 colW-16 12], 'FontSize', 7, ...
    'BackgroundColor', panelColor, 'ForegroundColor', [0.35 0.40 0.55]);

% Merged name input
uicontrol(p3, 'Style', 'text', 'String', 'Merged ROI Name:', ...
    'Position', [8 innerH-180 160 18], 'FontSize', 9, ...
    'HorizontalAlignment', 'left', ...
    'BackgroundColor', panelColor, 'ForegroundColor', [0.75 0.85 0.95]);
hMergeName = uicontrol(p3, 'Style', 'edit', ...
    'Position', [8 innerH-206 colW-16 24], 'FontSize', 10, ...
    'BackgroundColor', [0.10 0.12 0.18], 'ForegroundColor', [0.95 0.98 1.0], ...
    'HorizontalAlignment', 'left');

% Merged Index input
uicontrol(p3, 'Style', 'text', 'String', 'Merged ROI Index (integer):', ...
    'Position', [8 innerH-232 230 18], 'FontSize', 9, ...
    'HorizontalAlignment', 'left', ...
    'BackgroundColor', panelColor, 'ForegroundColor', [0.75 0.85 0.95]);
hMergeIdx = uicontrol(p3, 'Style', 'edit', ...
    'Position', [8 innerH-258 colW-16 24], 'FontSize', 10, ...
    'BackgroundColor', [0.10 0.12 0.18], 'ForegroundColor', [0.95 0.98 1.0], ...
    'HorizontalAlignment', 'left');

% Merge button
hMergeBtn = uicontrol(p3, 'Style', 'pushbutton', ...
    'String',          'Merge (combine selected ROIs)', ...
    'Position',        [8 innerH-308 colW-16 42], ...
    'FontSize',        12, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.10 0.60 0.30], ...
    'ForegroundColor', 'white', ...
    'Callback',        @cb_merge); %#ok<NASGU>

%% ================================================================
%% Panel 4: Merged ROI list
%% ================================================================
hMergedTable = uitable(p4, ...
    'Position',    [5 5 colW-10 panH-32], ...
    'ColumnName',  {'Merged ROI Name', 'Index', 'Original ROIs'}, ...
    'ColumnWidth', {130, 48, 167}, ...
    'ColumnEditable', [false false false], ...
    'RowName',     [], ...
    'Data',        {}, ...
    'FontSize',    9);

%% ================================================================
%% Bottom button bar
%% ================================================================
% Reset button
uicontrol(fig, 'Style', 'pushbutton', 'String', 'Reset', ...
    'Position', [8 8 110 32], 'FontSize', 11, ...
    'BackgroundColor', [0.80 0.35 0.15], 'ForegroundColor', 'white', ...
    'Callback', @cb_reset);

% Generate new Atlas button
uicontrol(fig, 'Style', 'pushbutton', 'String', 'Generate New Atlas', ...
    'Position', [128 8 162 32], 'FontSize', 11, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.45 0.20 0.80], 'ForegroundColor', 'white', ...
    'Callback', @cb_generateAtlas);

% Status bar
hStatus = uicontrol(fig, 'Style', 'text', ...
    'String', 'Ready | Please load an Atlas file first', ...
    'Position', [300 8 FW-315 28], ...
    'HorizontalAlignment', 'left', 'FontSize', 9, ...
    'BackgroundColor', [0.15 0.17 0.22], ...
    'ForegroundColor', [0.45 0.75 0.45]);

%% ================================================================
%% Nested callback functions
%% ================================================================

%--- (1) Select Atlas file ---------------------------------------
    function cb_selectAtlas(~, ~)
        % Resolve the default directory:
        % locate the SNBPI main program directory and navigate to
        % fullfile(str, 'ExtractROIValues', 'Atlas')
        defaultDir = getAtlasDefaultDir();

        [fname, fpath] = uigetfile( ...
            fullfile(defaultDir, '*.nii'), ...
            'Select Atlas NIfTI file');
        if isequal(fname, 0), return; end

        setStatus('Loading file, please wait...');

        fullPath = fullfile(fpath, fname);

        % Load NIfTI with SPM12
        try
            vol  = spm_vol(fullPath);
            % Key fix: round() to eliminate float32->float64 floating-point errors.
            % Atlas indices are essentially integers, but stored as float32 they
            % may pick up tiny errors (e.g. 1.0 becoming 1.0000001192), which
            % breaks direct equality comparisons.
            data = round(double(spm_read_vols(vol(1))));
        catch e
            errordlg(['Failed to load NIfTI: ' e.message], 'Error');
            setStatus('Load failed');
            return;
        end

        % Find and load _Labels.mat
        [~, baseName] = fileparts(fname);
        labFile = fullfile(fpath, [baseName '_Labels.mat']);
        if ~exist(labFile, 'file')
            errordlg(sprintf('Corresponding Labels file not found:\n%s', labFile), 'Error');
            setStatus('Labels file not found');
            return;
        end
        try
            tmp = load(labFile, 'Labels');
            if ~isfield(tmp, 'Labels')
                error('Variable "Labels" not found in mat file');
            end
            Labels_ = tmp.Labels;
            % Convert column 1 (name) to char, to support both string and char storage
            for ii = 1:size(Labels_, 1)
                if isstring(Labels_{ii, 1})
                    Labels_{ii, 1} = char(Labels_{ii, 1});
                end
            end
        catch e
            errordlg(['Failed to load Labels file: ' e.message], 'Error');
            setStatus('Labels load failed');
            return;
        end

        % Update state variables
        S.atlasFile    = fullPath;
        S.atlasVol     = vol(1);
        S.atlasData    = data;
        S.Labels       = Labels_;
        S.nROI         = size(Labels_, 1);
        S.selected     = false(S.nROI, 1);
        S.disabled     = false(S.nROI, 1);
        S.mergedList   = {};
        S.orientation  = 'axial';
        S.nSlices      = size(data, 3);
        S.currentSlice = max(1, round(S.nSlices / 2));

        % Reset orientation selection to Axial
        set(hOrBG, 'SelectedObject', hOrAx);

        % Update UI
        set(hFileLbl, 'String', fullPath);
        refreshSlider();
        refreshROITable();
        set(hMergedTable, 'Data', {});
        set(hPreview,    'String', {});
        set(hMergeName,  'String', '');
        set(hMergeIdx,   'String', '');

        refreshImage();

        % Validate that Indices in Labels can be found in the image (for diagnostics)
        allLabIdx  = cellfun(@(x) round(x), S.Labels(:,2));
        uniqueVox  = unique(data(:));
        uniqueVox  = uniqueVox(uniqueVox ~= 0);   % Remove background
        nFound     = sum(ismember(allLabIdx, uniqueVox));
        if nFound == 0
            warnMsg = sprintf(['Warning: none of the %d ROI indices in the Labels file were found in the image!\n' ...
                'Please check whether column 2 (Index) of Labels matches the actual values in the image.\n' ...
                'Non-zero value range in image: [%g, %g], Labels Index range: [%g, %g]'], ...
                S.nROI, min(uniqueVox), max(uniqueVox), min(allLabIdx), max(allLabIdx));
            warndlg(warnMsg, 'Data mismatch warning');
            setStatus('Loaded, but Labels Index does not match image values. Please check the data.');
        else
            setStatus(sprintf('Loaded: %s  |  %d ROIs (%d present in image)  |  Size: %dx%dx%d', ...
                fname, S.nROI, nFound, size(data,1), size(data,2), size(data,3)));
        end
    end

%--- (1a) Determine default directory for Atlas file picker ------
    function d = getAtlasDefaultDir()
        % Try to locate the SNBPI main program directory and then
        % navigate to its ExtractROIValues/Atlas subfolder.
        d = pwd;  % Fallback: current directory
        str = '';

        % Strategy 1: use which() to locate the SNBPI main program file
        candidates = {'SNBPI', 'SNBPI.m'};
        for k = 1:numel(candidates)
            p = which(candidates{k});
            if ~isempty(p)
                str = fileparts(p);
                break;
            end
        end

        % Strategy 2: search the MATLAB path for a folder named "SNBPI"
        if isempty(str)
            pathDirs = strsplit(path, pathsep);
            for k = 1:numel(pathDirs)
                [~, folderName] = fileparts(pathDirs{k});
                if strcmpi(folderName, 'SNBPI')
                    str = pathDirs{k};
                    break;
                end
            end
        end

        % Strategy 3: walk up from the current file's location looking for SNBPI
        if isempty(str)
            here = fileparts(mfilename('fullpath'));
            cur  = here;
            for k = 1:6  % climb at most 6 levels
                [~, folderName] = fileparts(cur);
                if strcmpi(folderName, 'SNBPI')
                    str = cur;
                    break;
                end
                parent = fileparts(cur);
                if isempty(parent) || strcmp(parent, cur), break; end
                cur = parent;
            end
        end

        % If SNBPI directory was found, build the target Atlas folder path
        if ~isempty(str)
            target = fullfile(str, 'ExtractROIValues', 'Atlas');
            if exist(target, 'dir')
                d = target;
            elseif exist(str, 'dir')
                d = str;
            end
        end
    end

%--- (2) ROI table check callback --------------------------------
    function cb_roiSelect(~, evt)
        r = evt.Indices(1);
        c = evt.Indices(2);
        if c ~= 3, return; end  % Only handle the "Select" column

        % If this ROI has been disabled, undo the check
        if S.disabled(r)
            d = get(hROITable, 'Data');
            d{r, 3} = false;
            set(hROITable, 'Data', d);
            setStatus(sprintf('ROI "%s" has already been merged and cannot be reselected. Please click "Generate New Atlas" or "Reset" first.', S.Labels{r,1}));
            return;
        end

        S.selected(r) = evt.NewData;
        refreshPreview();
        refreshImage();
    end

%--- (3) Merge button --------------------------------------------
    function cb_merge(~, ~)
        if isempty(S.atlasData)
            warndlg('Please load an Atlas file first', 'Notice'); return;
        end

        selIdx = find(S.selected & ~S.disabled);
        if isempty(selIdx)
            warndlg('Please check at least one ROI in the ROI list', 'Notice'); return;
        end

        mName = strtrim(get(hMergeName, 'String'));
        mIdxStr = strtrim(get(hMergeIdx, 'String'));
        mIdx  = str2double(mIdxStr);

        % Input validation
        if isempty(mName)
            warndlg('Please enter a name for the merged ROI', 'Notice'); return;
        end
        if isnan(mIdx) || ~isfinite(mIdx)
            warndlg('Please enter a valid Index (integer)', 'Notice'); return;
        end
        mIdx = round(mIdx);

        % Check uniqueness of name and Index
        for k = 1:numel(S.mergedList)
            if strcmp(S.mergedList{k}.name, mName)
                warndlg(sprintf('ROI name "%s" already exists, please use a different name', mName), 'Duplicate name');
                return;
            end
            if S.mergedList{k}.newIndex == mIdx
                warndlg(sprintf('ROI Index %d already exists, please use a different Index', mIdx), 'Duplicate Index');
                return;
            end
        end

        % Build merge entry
        m.name      = mName;
        m.newIndex  = mIdx;
        m.roiRows   = selIdx;
        m.origNames = S.Labels(selIdx, 1);
        m.origIdxs  = cell2mat(S.Labels(selIdx, 2));

        S.mergedList{end+1} = m;

        % Disable the merged ROIs
        S.disabled(selIdx) = true;
        S.selected(selIdx) = false;

        % Refresh UI
        refreshROITable();
        refreshMergedTable();
        refreshPreview();
        refreshImage();

        set(hMergeName, 'String', '');
        set(hMergeIdx,  'String', '');

        setStatus(sprintf('Merged into "%s" (Index=%d), containing %d original ROIs', ...
            mName, mIdx, numel(selIdx)));
    end

%--- (4) Generate new Atlas button -------------------------------
    function cb_generateAtlas(~, ~)
        if isempty(S.atlasData)
            warndlg('Please load an Atlas file first', 'Notice'); return;
        end
        if isempty(S.mergedList)
            warndlg('There are no merged ROIs yet. Please perform a merge first.', 'Notice'); return;
        end

        % Enter new file name
        ans_ = inputdlg('Enter the new Atlas file name (without extension):', 'Generate New Atlas', 1, {'merged_atlas'});
        if isempty(ans_), return; end
        newBase = strtrim(ans_{1});
        if isempty(newBase)
            warndlg('File name cannot be empty', 'Notice'); return;
        end
        % Strip any extension the user may have entered
        newBase = strrep(newBase, '.nii', '');

        % Select save directory
        saveDir = uigetdir(fileparts(S.atlasFile), 'Select save directory');
        if isequal(saveDir, 0), return; end

        newNii = fullfile(saveDir, [newBase '.nii']);
        newMat = fullfile(saveDir, [newBase '_Labels.mat']);

        % Confirm overwrite
        if exist(newNii, 'file') || exist(newMat, 'file')
            ans2 = questdlg(sprintf('File already exists. Overwrite?\n%s', newNii), ...
                'Confirm overwrite', 'Overwrite', 'Cancel', 'Cancel');
            if ~strcmp(ans2, 'Overwrite'), return; end
        end

        setStatus('Generating new Atlas...');
        drawnow;

        % Build new atlas data (background is 0)
        newData = zeros(size(S.atlasData));
        nMerged = numel(S.mergedList);
        Labels  = cell(nMerged, 2);  %#ok<NASGU>

        for k = 1:nMerged
            m = S.mergedList{k};
            Labels{k, 1} = m.name;
            Labels{k, 2} = m.newIndex;
            % Assign the new Index to all voxels belonging to the original ROIs
            for j = 1:numel(m.origIdxs)
                newData(S.atlasData == m.origIdxs(j)) = m.newIndex;
            end
        end

        % Write NIfTI via SPM12
        try
            newVol         = S.atlasVol;
            newVol.fname   = newNii;
            newVol.descrip = sprintf('Merged Atlas - generated by AtlasMergerTool (%s)', datestr(now));
            % Choose data type based on maximum Index
            maxIdx = max(cellfun(@(x) x.newIndex, S.mergedList));
            if maxIdx <= 32767
                newVol.dt = [spm_type('int16') spm_platform('bigend')];
            else
                newVol.dt = [spm_type('float32') spm_platform('bigend')];
            end
            spm_write_vol(newVol, newData);
        catch e
            errordlg(['Failed to write NIfTI: ' e.message], 'Error');
            setStatus('Generation failed');
            return;
        end

        % Save Labels mat file
        save(newMat, 'Labels');

        % ---- Save merge info files (txt + mat) ---------------------
        infoTxt = fullfile(saveDir, [newBase '_MergeInfo.txt']);
        infoMat = fullfile(saveDir, [newBase '_MergeInfo.mat']);
        try
            saveMergeInfo(infoTxt, infoMat, newBase, nMerged);
        catch e
            warndlg(['Failed to save merge info files: ' e.message], 'Warning');
        end

        msgbox(sprintf(['New Atlas saved successfully!\n\n', ...
            'Image file:\n  %s\n\n', ...
            'Labels file:\n  %s\n\n', ...
            'Merge info (text):\n  %s\n\n', ...
            'Merge info (MAT):\n  %s\n\n', ...
            'Total merged ROIs: %d'], ...
            newNii, newMat, infoTxt, infoMat, nMerged), ...
            'Generation successful', 'help');

        % After generation, restore all ROIs to selectable state (requirement 3)
        S.disabled(:) = false;
        S.selected(:) = false;
        S.mergedList  = {};

        refreshROITable();
        refreshMergedTable();
        refreshPreview();
        refreshImage();

        setStatus(sprintf('New Atlas saved to: %s  |  ROI list has been reset to selectable', newNii));
    end

%--- (5) Slider callback -----------------------------------------
    function cb_slider(~, ~)
        if isempty(S.atlasData), return; end
        S.currentSlice = max(1, min(S.nSlices, round(get(hSlider, 'Value'))));
        set(hSliceLbl, 'String', sprintf('%d/%d', S.currentSlice, S.nSlices));
        refreshImage();
    end

%--- (6) Orientation change callback -----------------------------
    function cb_orientation(~, evt)
        if isempty(S.atlasData), return; end
        switch evt.NewValue.String
            case 'Axial'
                S.orientation  = 'axial';
                S.nSlices      = size(S.atlasData, 3);
            case 'Coronal'
                S.orientation  = 'coronal';
                S.nSlices      = size(S.atlasData, 2);
            case 'Sagittal'
                S.orientation  = 'sagittal';
                S.nSlices      = size(S.atlasData, 1);
        end
        S.currentSlice = max(1, round(S.nSlices / 2));
        refreshSlider();
        refreshImage();
    end

%--- (7) Reset button --------------------------------------------
    function cb_reset(~, ~)
        ans3 = questdlg('Are you sure you want to reset everything? (All current merge results will be cleared.)', ...
            'Confirm reset', 'Reset', 'Cancel', 'Cancel');
        if ~strcmp(ans3, 'Reset'), return; end

        S.atlasFile    = '';
        S.atlasVol     = [];
        S.atlasData    = [];
        S.Labels       = {};
        S.nROI         = 0;
        S.selected     = logical([]);
        S.disabled     = logical([]);
        S.mergedList   = {};
        S.orientation  = 'axial';
        S.currentSlice = 1;
        S.nSlices      = 1;

        set(hFileLbl,     'String', 'Please select an Atlas NIfTI file (.nii) first');
        set(hROITable,    'Data',   {});
        set(hMergedTable, 'Data',   {});
        set(hPreview,     'String', {});
        set(hMergeName,   'String', '');
        set(hMergeIdx,    'String', '');
        set(hSlider,      'Min', 1, 'Max', 2, 'Value', 1);
        set(hSliceLbl,    'String', '-/-');
        set(hOrBG,        'SelectedObject', hOrAx);
        cla(hAx);
        set(hAx, 'Color', 'k');

        setStatus('Reset complete | Please reload an Atlas file');
    end

%% ================================================================
%% Helper / refresh functions
%% ================================================================

%--- Update slice slider -----------------------------------------
    function refreshSlider()
        nS   = max(S.nSlices, 2);
        step = [1/(nS-1), min(1, 10/(nS-1))];
        set(hSlider, 'Min', 1, 'Max', nS, 'Value', S.currentSlice, ...
            'SliderStep', step);
        set(hSliceLbl, 'String', sprintf('%d/%d', S.currentSlice, S.nSlices));
    end

%--- Refresh ROI table -------------------------------------------
    function refreshROITable()
        n = S.nROI;
        d = cell(n, 4);
        for i = 1:n
            % uitable accepts only char, not string -- convert uniformly
            name = S.Labels{i, 1};
            if isstring(name), name = char(name); end
            d{i, 1} = name;
            d{i, 2} = S.Labels{i, 2};
            d{i, 3} = S.selected(i);
            if S.disabled(i)
                d{i, 4} = 'Merged';
            else
                d{i, 4} = 'Available';
            end
        end
        set(hROITable, 'Data', d);
    end

%--- Refresh the merge preview list ------------------------------
    function refreshPreview()
        selIdx = find(S.selected & ~S.disabled);
        if isempty(selIdx)
            set(hPreview, 'String', {});
        else
            strs = cell(numel(selIdx), 1);
            for k = 1:numel(selIdx)
                i = selIdx(k);
                name = S.Labels{i,1};
                if isstring(name), name = char(name); end
                strs{k} = sprintf('  %s   [Index: %g]', name, S.Labels{i,2});
            end
            set(hPreview, 'String', strs);
        end
    end

%--- Refresh merged ROI table ------------------------------------
    function refreshMergedTable()
        nM = numel(S.mergedList);
        d  = cell(nM, 3);
        for k = 1:nM
            m      = S.mergedList{k};
            d{k,1} = m.name;
            d{k,2} = m.newIndex;
            d{k,3} = strjoin(m.origNames, ', ');
        end
        set(hMergedTable, 'Data', d);
    end

%--- Refresh image (with highlight) ------------------------------
    function refreshImage()
        if isempty(S.atlasData) || S.nROI == 0, return; end

        %% 1. Extract current slice
        switch S.orientation
            case 'axial'
                sl = S.atlasData(:, :, S.currentSlice);
            case 'coronal'
                sl = squeeze(S.atlasData(:, S.currentSlice, :));
            case 'sagittal'
                sl = squeeze(S.atlasData(S.currentSlice, :, :));
        end
        sl = rot90(sl);          % Rotate to a natural viewing orientation
        [H, W] = size(sl);

        %% 2. Pre-assign a color for each ROI
        %   - Unselected: dim HSV color (brightness ~0.40, low saturation)
        %   - Selected:   vivid HSV color (brightness 1.0, high saturation)
        %   - Background (0): black
        nROI_   = S.nROI;
        % Linearly spaced hues so adjacent ROI colors differ
        hues    = linspace(0, 1 - 1/nROI_, nROI_)';
        % Unselected: low saturation, low brightness (visible but subdued)
        dimClr  = hsv2rgb([hues, repmat(0.55, nROI_, 1), repmat(0.45, nROI_, 1)]);
        % Selected: high saturation, high brightness (vivid highlight)
        selClr  = hsv2rgb([hues, ones(nROI_, 1), ones(nROI_, 1)]);

        %% 3. Fill pixels (build a "label index -> pixel" mapping)
        rgb = zeros(H, W, 3, 'double');   % Background is black
        for i = 1:nROI_
            roiVal = round(S.Labels{i, 2});   % round: guard against float errors
            mask   = (sl == roiVal);           % sl was rounded at load time; safe to compare
            if ~any(mask(:)), continue; end

            if S.selected(i)
                c = selClr(i, :);
            else
                c = dimClr(i, :);
            end
            rgb(:,:,1) = rgb(:,:,1) + mask * c(1);
            rgb(:,:,2) = rgb(:,:,2) + mask * c(2);
            rgb(:,:,3) = rgb(:,:,3) + mask * c(3);
        end

        %% 4. Display in the axes
        imagesc(hAx, rgb);
        axis(hAx, 'image', 'off');
        set(hAx, 'XColor', 'none', 'YColor', 'none');
    end

%--- Update status bar -------------------------------------------
    function setStatus(msg)
        set(hStatus, 'String', msg);
        drawnow;
    end

%--- Save merge info (txt + mat) ---------------------------------
    function saveMergeInfo(txtPath, matPath, newAtlasName, nMerged)
        % ---- 1. Build structured data ----
        % MergeInfo is a struct array, each element representing one merge record
        MergeInfo = struct( ...
            'NewROI_Name',    {}, ...
            'NewROI_Index',   {}, ...
            'Orig_ROI_Names', {}, ...
            'Orig_ROI_Indices', {});

        for k = 1:nMerged
            m = S.mergedList{k};
            MergeInfo(k).NewROI_Name      = m.name;
            MergeInfo(k).NewROI_Index     = m.newIndex;
            MergeInfo(k).Orig_ROI_Names   = m.origNames;   % cell array of strings
            MergeInfo(k).Orig_ROI_Indices = m.origIdxs;    % double array
        end

        % Metadata
        MetaInfo.OrigAtlasFile  = S.atlasFile;
        MetaInfo.NewAtlasName   = newAtlasName;
        MetaInfo.NumMergedROIs  = nMerged;
        MetaInfo.NumOrigROIs    = S.nROI;
        MetaInfo.GeneratedTime  = datestr(now, 'yyyy-mm-dd HH:MM:SS');

        % ---- 2. Save MAT file ----
        save(matPath, 'MergeInfo', 'MetaInfo');

        % ---- 3. Save human-readable TXT file ----
        fid = fopen(txtPath, 'w', 'n', 'UTF-8');
        if fid == -1
            error('Cannot create file: %s', txtPath);
        end

        % Header
        fprintf(fid, '================================================================\r\n');
        fprintf(fid, '  Atlas ROI Merge Information Report\r\n');
        fprintf(fid, '================================================================\r\n');
        fprintf(fid, '  Generated time   : %s\r\n', MetaInfo.GeneratedTime);
        fprintf(fid, '  Original Atlas   : %s\r\n', MetaInfo.OrigAtlasFile);
        fprintf(fid, '  New Atlas        : %s\r\n', MetaInfo.NewAtlasName);
        fprintf(fid, '  Original ROI num : %d\r\n', MetaInfo.NumOrigROIs);
        fprintf(fid, '  Merged ROI num   : %d\r\n', MetaInfo.NumMergedROIs);
        fprintf(fid, '================================================================\r\n\r\n');

        % Each merge record
        for k = 1:nMerged
            m = S.mergedList{k};
            nOrig = numel(m.origIdxs);

            fprintf(fid, '[Merge %d / %d]\r\n', k, nMerged);
            fprintf(fid, '  New ROI name  : %s\r\n', m.name);
            fprintf(fid, '  New ROI Index : %d\r\n', m.newIndex);
            fprintf(fid, '  Contains %d original ROIs:\r\n', nOrig);
            for j = 1:nOrig
                fprintf(fid, '    [%d]  %s  (Index: %d)\r\n', ...
                    j, m.origNames{j}, m.origIdxs(j));
            end
            fprintf(fid, '\r\n');
        end

        % Appendix: summary table of all original ROIs
        fprintf(fid, '================================================================\r\n');
        fprintf(fid, '  Appendix: Original ROI -> New ROI full mapping table\r\n');
        fprintf(fid, '================================================================\r\n');
        fprintf(fid, '  %-40s  %-10s  ->  %-40s  %-10s\r\n', ...
            'Original ROI name', 'Orig Index', 'New ROI name', 'New Index');
        fprintf(fid, '  %s\r\n', repmat('-', 1, 110));
        for k = 1:nMerged
            m = S.mergedList{k};
            for j = 1:numel(m.origIdxs)
                fprintf(fid, '  %-40s  %-10d  ->  %-40s  %-10d\r\n', ...
                    m.origNames{j}, m.origIdxs(j), m.name, m.newIndex);
            end
        end
        fprintf(fid, '================================================================\r\n');

        fclose(fid);
    end

%--- Close window ------------------------------------------------
    function cb_close(~, ~)
        delete(fig);
    end

end % AtlasMergerTool