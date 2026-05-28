function fig = roiOverlayViewer(varargin)
%ROIOVERLAYVIEWER  Interactive viewer: mean brain image + atlas ROI overlay.
%
% PURPOSE
%   Thin entry point. Parses inputs, creates the uifigure, initialises
%   state, builds the four UI panels, and (if inputs are supplied) loads
%   the data immediately.
%
% SYNTAX
%   roiOverlayViewer()
%   roiOverlayViewer(imageNames, atlasNames)
%   roiOverlayViewer(imageNames, atlasNames, atlasLabels)
%   fig = roiOverlayViewer(...)
%
% INPUTS
%   imageNames  : cell array of char vectors - paths to brain images
%                 (.nii/.img). May be empty; atlas itself will be used
%                 as the background image in that case.
%   atlasNames  : cell array of char vectors - one or more atlas files.
%                 If a single atlas is given and a file
%                 '<name>_Labels.mat' sits next to it, the Labels
%                 variable (n x 2 cell: {name, value}) is auto-loaded.
%   atlasLabels : (optional) n x 2 cell {name, value}. Overrides the
%                 auto-loaded labels.
%
% OUTPUT
%   fig : handle to the created uifigure (useful for scripting/tests).
%
% EXAMPLE
%   roiOverlayViewer();                        % fully interactive
%   roiOverlayViewer({}, {'AAL.nii'});          % auto-load AAL_Labels.mat
%   roiOverlayViewer({'a.nii','b.nii'}, {'AAL.nii','HO.nii'});
%
% DEPENDENCIES
%   SPM12 on the MATLAB path, computeMeanBrainImage.m, MATLAB R2020b+.
%
% See also: rov.initState, rov.io.loadData

    % --- Parse inputs --------------------------------------------------
    imgIn    = {};  atlasIn = {};  labelsIn = {};
    if nargin >= 1, imgIn    = varargin{1}; end
    if nargin >= 2, atlasIn  = varargin{2}; end
    if nargin >= 3, labelsIn = varargin{3}; end

    % Auto-load <atlas>_Labels.mat for single-atlas call w/o explicit labels
    if isempty(labelsIn) && iscell(atlasIn) && isscalar(atlasIn)
        labelsIn = rov.io.tryLoadAtlasLabels(atlasIn{1});
    end

    % --- Create figure (fit to screen on small displays) ---------------
    scr  = get(0, 'ScreenSize');
    figW = min(1500, scr(3) - 80);
    figH = min(800,  scr(4) - 120);
    figX = max(1, (scr(3) - figW) / 2);
    figY = max(1, (scr(4) - figH) / 2);
    fig = uifigure('Name', 'ROI Overlay Viewer', ...
                   'Position', [figX figY figW figH], ...
                   'Color', [0.11 0.11 0.11]);
    fig.UserData = rov.initState(imgIn, atlasIn, labelsIn);

    % --- Main 4-column grid: controls | image | colorbar | legend -----
    mg = uigridlayout(fig, [1,4], ...
        'ColumnWidth',   {286, '1x', 95, 220}, ...
        'RowHeight',     {'1x'}, ...
        'Padding',       [4 4 4 4], ...
        'ColumnSpacing', 4, ...
        'BackgroundColor', [0.11 0.11 0.11]);

    s = fig.UserData;
    s.h.mainGrid    = mg;
    s.h.leftPanel   = uipanel(mg, 'BackgroundColor',[0.14 0.14 0.17], 'BorderType','none');
    s.h.midPanel    = uipanel(mg, 'BackgroundColor',[0.07 0.07 0.07], 'BorderType','none');
    s.h.cbPanel     = uipanel(mg, 'BackgroundColor',[0.10 0.10 0.13], 'BorderType','none');
    s.h.rightPanel  = uipanel(mg, 'BackgroundColor',[0.14 0.14 0.17], 'BorderType','none');
    s.h.leftPanel.Layout.Column  = 1;
    s.h.midPanel.Layout.Column   = 2;
    s.h.cbPanel.Layout.Column    = 3;
    s.h.rightPanel.Layout.Column = 4;
    fig.UserData = s;

    % --- Build panels --------------------------------------------------
    rov.ui.buildLeftPanel(fig);
    rov.ui.buildMiddlePanel(fig);
    rov.ui.buildColorbarPanel(fig);
    rov.ui.buildRightPanel(fig);

    if ~isempty(imgIn) && ~isempty(atlasIn)
        rov.io.loadData(fig);
    end

    if nargout == 0, clear fig; end
end
