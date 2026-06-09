classdef SNBPI < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure

        % Menus
        ToolsMenu                   matlab.ui.container.Menu
        AtlasMergerMenu             matlab.ui.container.Menu
        OverlayViewerMenu           matlab.ui.container.Menu
        DeleteFilesMenu             matlab.ui.container.Menu
        Dicom2BidsMenu              matlab.ui.container.Menu
        NiiCropperMenu              matlab.ui.container.Menu
        HelpMenu                    matlab.ui.container.Menu
        CheckforUpdatesMenu         matlab.ui.container.Menu
        AtlasROIReadmeMenu          matlab.ui.container.Menu

        % Main layout
        MainGrid                    matlab.ui.container.GridLayout
        TitleLabel                  matlab.ui.control.Label

        % Set Origin panel
        SetOriginPanel              matlab.ui.container.Panel
        SetOriginGrid               matlab.ui.container.GridLayout
        SetOriginButton             matlab.ui.control.Button

        % Spatial Normalization panel
        SpatialNormPanel            matlab.ui.container.Panel
        SpatialNormGrid             matlab.ui.container.GridLayout
        MRIBasedButton              matlab.ui.control.Button
        TemplateBasedButton         matlab.ui.control.Button
        AtlasBasedButton            matlab.ui.control.Button

        % Quality Check panel
        QCPanel                     matlab.ui.container.Panel
        QCGrid                      matlab.ui.container.GridLayout
        QCButton                    matlab.ui.control.Button

        % Intensity Normalization panel
        IntensityNormPanel          matlab.ui.container.Panel
        IntensityNormGrid           matlab.ui.container.GridLayout
        IntensityNormButton         matlab.ui.control.Button

        % Smooth panel
        SmoothPanel                 matlab.ui.container.Panel
        SmoothGrid                  matlab.ui.container.GridLayout
        SmoothButton                matlab.ui.control.Button

        % Extract ROI Values panel
        ExtractROIPanel             matlab.ui.container.Panel
        ExtractROIGrid              matlab.ui.container.GridLayout
        ExtractROIButton            matlab.ui.control.Button
    end

    % Callbacks that handle component events
    methods (Access = private)

        function startupFcn(app)
            fprintf(['Citing Information:\n Zhang Tianhao; Nie Binbin; Liu Hua; Shan Baoci;' ...
                'Unified Spatial Normalization of Brain PET Image Using Adaptive Brain Probabilistic Atlas; ' ...
                'European Journal of Nuclear Medicine and Molecular Imaging, 2022\n']);
            scnsize = get(0,'ScreenSize');
            w = scnsize(3);
            h = scnsize(4);
            figW = 480;
            figH = 640;
            if w > figW && h > figH
                app.UIFigure.Position = [round((w-figW)/2)+1, round((h-figH)/2)+1, figW, figH];
            else
                app.UIFigure.Position = [1, 1, w, h];
            end
            t = timer('StartDelay', 2, ...
                      'ExecutionMode', 'singleShot', ...
                      'TimerFcn', @(~,~) checkUpdateAndClean(), ...
                      'StopFcn',  @(t,~) delete(t));
            start(t);

            function checkUpdateAndClean()
                try
                    checkUpdate(false);
                catch
                end
            end
        end

        % Button callbacks
        function SetOriginButtonPushed(app, event)
            setOriginToCentroid;
        end

        function MRIBasedButtonPushed(app, event)
            MRIBased;
        end

        function TemplateBasedButtonPushed(app, event)
            TemplateBased;
        end

        function AtlasBasedButtonPushed(app, event)
            AtlasBased;
        end

        function QCButtonPushed(app, event)
            evaluate_registration();
        end

        function IntensityNormButtonPushed(app, event)
            PETIntensityNormalize;
        end

        function SmoothButtonPushed(app, event)
            spm_jobman('interactive','','spm.spatial.smooth');
        end

        function ExtractROIButtonPushed(app, event)
            extractROIvalue;
        end

        % Menu callbacks
        function AtlasMergerMenuSelected(app, event)
            AtlasMergerTool();
        end

        function OverlayViewerMenuSelected(app, event)
            roiOverlayViewer;
        end

        function DeleteFilesMenuSelected(app, event)
            deleteFilesApp;
        end

        function Dicom2BidsMenuSelected(app, event)
            dicom2bids_gui;
        end

        function NiiCropperMenuSelected(app, event)
            NiiCropper;
        end

        function CheckforUpdatesMenuSelected(app, event)
            checkUpdate(true);
        end
        function AtlasROIReadmeMenuSelected(app, event)
            try
                classPath = which('SNBPI');
                [folder, ~, ~] = fileparts(classPath);
                htmlPath = fullfile(folder, 'Atlas_ROI_Toolkit_Readme.html');
                if exist(htmlPath, 'file')
                    web(['file:///' strrep(htmlPath, '\', '/')], '-browser');
                else
                    uialert(app.UIFigure, ...
                        sprintf('HTML file not found:\n%s', htmlPath), ...
                        'File Not Found');
                end
            catch ME
                uialert(app.UIFigure, ME.message, 'Error');
            end
        end
    end

    % Component initialization
    methods (Access = private)

        function createComponents(app)

            % Create UIFigure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 480 640];
            app.UIFigure.Name = 'SNBPI';

            % ---- Menus ----
            app.ToolsMenu = uimenu(app.UIFigure);
            app.ToolsMenu.Text = 'Tools';

            app.AtlasMergerMenu = uimenu(app.ToolsMenu);
            app.AtlasMergerMenu.MenuSelectedFcn = createCallbackFcn(app, @AtlasMergerMenuSelected, true);
            app.AtlasMergerMenu.Text = 'Atlas Merger';

            app.OverlayViewerMenu = uimenu(app.ToolsMenu);
            app.OverlayViewerMenu.MenuSelectedFcn = createCallbackFcn(app, @OverlayViewerMenuSelected, true);
            app.OverlayViewerMenu.Text = 'Overlay Viewer';

            app.DeleteFilesMenu = uimenu(app.ToolsMenu);
            app.DeleteFilesMenu.MenuSelectedFcn = createCallbackFcn(app, @DeleteFilesMenuSelected, true);
            app.DeleteFilesMenu.Text = 'Delete Files';

            app.Dicom2BidsMenu = uimenu(app.ToolsMenu);
            app.Dicom2BidsMenu.MenuSelectedFcn = createCallbackFcn(app, @Dicom2BidsMenuSelected, true);
            app.Dicom2BidsMenu.Text = 'DICOM to BIDS';

            app.NiiCropperMenu = uimenu(app.ToolsMenu);
            app.NiiCropperMenu.MenuSelectedFcn = createCallbackFcn(app, @NiiCropperMenuSelected, true);
            app.NiiCropperMenu.Text = 'NIfTI Cropper';

            app.HelpMenu = uimenu(app.UIFigure);
            app.HelpMenu.Text = 'Help';

            app.CheckforUpdatesMenu = uimenu(app.HelpMenu);
            app.CheckforUpdatesMenu.MenuSelectedFcn = createCallbackFcn(app, @CheckforUpdatesMenuSelected, true);
            app.CheckforUpdatesMenu.Text = 'Check for Updates';

            app.AtlasROIReadmeMenu = uimenu(app.HelpMenu);
            app.AtlasROIReadmeMenu.MenuSelectedFcn = createCallbackFcn(app, @AtlasROIReadmeMenuSelected, true);
            app.AtlasROIReadmeMenu.Text = 'Atlas ROI Toolkit Readme';

            % ---- Main Grid ----
            app.MainGrid = uigridlayout(app.UIFigure);
            app.MainGrid.ColumnWidth = {'1x'};
            app.MainGrid.RowHeight = {60, 70, 90, 70, 70, 70, 70};
            app.MainGrid.RowSpacing = 8;
            app.MainGrid.Padding = [10 10 10 10];

            % ---- Title Label ----
            app.TitleLabel = uilabel(app.MainGrid);
            app.TitleLabel.Text = 'The Toolbox of Spatial Normalization of Brain PET Images';
            app.TitleLabel.HorizontalAlignment = 'center';
            app.TitleLabel.VerticalAlignment = 'center';
            app.TitleLabel.FontSize = 16;
            app.TitleLabel.FontWeight = 'bold';
            app.TitleLabel.WordWrap = 'on';
            app.TitleLabel.Layout.Row = 1;
            app.TitleLabel.Layout.Column = 1;

            % ---- Set Origin Panel ----
            app.SetOriginPanel = uipanel(app.MainGrid);
            app.SetOriginPanel.Title = 'Set Origin';
            app.SetOriginPanel.Layout.Row = 2;
            app.SetOriginPanel.Layout.Column = 1;

            app.SetOriginGrid = uigridlayout(app.SetOriginPanel);
            app.SetOriginGrid.ColumnWidth = {'1x'};
            app.SetOriginGrid.RowHeight = {'1x'};
            app.SetOriginGrid.Padding = [10 5 10 5];

            app.SetOriginButton = uibutton(app.SetOriginGrid, 'push');
            app.SetOriginButton.ButtonPushedFcn = createCallbackFcn(app, @SetOriginButtonPushed, true);
            app.SetOriginButton.Text = 'Set Origin to Centroid';
            app.SetOriginButton.Layout.Row = 1;
            app.SetOriginButton.Layout.Column = 1;

            % ---- Spatial Normalization Panel ----
            app.SpatialNormPanel = uipanel(app.MainGrid);
            app.SpatialNormPanel.Title = 'Spatial Normalization';
            app.SpatialNormPanel.Layout.Row = 3;
            app.SpatialNormPanel.Layout.Column = 1;

            app.SpatialNormGrid = uigridlayout(app.SpatialNormPanel);
            app.SpatialNormGrid.ColumnWidth = {'1x', '1x', '1x'};
            app.SpatialNormGrid.RowHeight = {'1x'};
            app.SpatialNormGrid.ColumnSpacing = 10;
            app.SpatialNormGrid.Padding = [10 5 10 5];

            app.MRIBasedButton = uibutton(app.SpatialNormGrid, 'push');
            app.MRIBasedButton.ButtonPushedFcn = createCallbackFcn(app, @MRIBasedButtonPushed, true);
            app.MRIBasedButton.Text = 'MRI Based';
            app.MRIBasedButton.Layout.Row = 1;
            app.MRIBasedButton.Layout.Column = 1;

            app.TemplateBasedButton = uibutton(app.SpatialNormGrid, 'push');
            app.TemplateBasedButton.ButtonPushedFcn = createCallbackFcn(app, @TemplateBasedButtonPushed, true);
            app.TemplateBasedButton.Text = 'Template Based';
            app.TemplateBasedButton.Layout.Row = 1;
            app.TemplateBasedButton.Layout.Column = 2;

            app.AtlasBasedButton = uibutton(app.SpatialNormGrid, 'push');
            app.AtlasBasedButton.ButtonPushedFcn = createCallbackFcn(app, @AtlasBasedButtonPushed, true);
            app.AtlasBasedButton.Text = 'Atlas Based';
            app.AtlasBasedButton.Layout.Row = 1;
            app.AtlasBasedButton.Layout.Column = 3;

            % ---- Quality Check Panel ----
            app.QCPanel = uipanel(app.MainGrid);
            app.QCPanel.Title = 'Quality Check';
            app.QCPanel.Layout.Row = 4;
            app.QCPanel.Layout.Column = 1;

            app.QCGrid = uigridlayout(app.QCPanel);
            app.QCGrid.ColumnWidth = {'1x'};
            app.QCGrid.RowHeight = {'1x'};
            app.QCGrid.Padding = [10 5 10 5];

            app.QCButton = uibutton(app.QCGrid, 'push');
            app.QCButton.ButtonPushedFcn = createCallbackFcn(app, @QCButtonPushed, true);
            app.QCButton.Text = 'Spatial Normalization Quality Check';
            app.QCButton.Layout.Row = 1;
            app.QCButton.Layout.Column = 1;

            % ---- Intensity Normalization Panel ----
            app.IntensityNormPanel = uipanel(app.MainGrid);
            app.IntensityNormPanel.Title = 'Intensity Normalization';
            app.IntensityNormPanel.Layout.Row = 5;
            app.IntensityNormPanel.Layout.Column = 1;

            app.IntensityNormGrid = uigridlayout(app.IntensityNormPanel);
            app.IntensityNormGrid.ColumnWidth = {'1x'};
            app.IntensityNormGrid.RowHeight = {'1x'};
            app.IntensityNormGrid.Padding = [10 5 10 5];

            app.IntensityNormButton = uibutton(app.IntensityNormGrid, 'push');
            app.IntensityNormButton.ButtonPushedFcn = createCallbackFcn(app, @IntensityNormButtonPushed, true);
            app.IntensityNormButton.Text = 'Intensity Normalization';
            app.IntensityNormButton.Layout.Row = 1;
            app.IntensityNormButton.Layout.Column = 1;

            % ---- Smooth Panel ----
            app.SmoothPanel = uipanel(app.MainGrid);
            app.SmoothPanel.Title = 'Smooth';
            app.SmoothPanel.Layout.Row = 6;
            app.SmoothPanel.Layout.Column = 1;

            app.SmoothGrid = uigridlayout(app.SmoothPanel);
            app.SmoothGrid.ColumnWidth = {'1x'};
            app.SmoothGrid.RowHeight = {'1x'};
            app.SmoothGrid.Padding = [10 5 10 5];

            app.SmoothButton = uibutton(app.SmoothGrid, 'push');
            app.SmoothButton.ButtonPushedFcn = createCallbackFcn(app, @SmoothButtonPushed, true);
            app.SmoothButton.Text = 'Smooth';
            app.SmoothButton.Layout.Row = 1;
            app.SmoothButton.Layout.Column = 1;

            % ---- Extract ROI Values Panel ----
            app.ExtractROIPanel = uipanel(app.MainGrid);
            app.ExtractROIPanel.Title = 'Extract ROI Values';
            app.ExtractROIPanel.Layout.Row = 7;
            app.ExtractROIPanel.Layout.Column = 1;

            app.ExtractROIGrid = uigridlayout(app.ExtractROIPanel);
            app.ExtractROIGrid.ColumnWidth = {'1x'};
            app.ExtractROIGrid.RowHeight = {'1x'};
            app.ExtractROIGrid.Padding = [10 5 10 5];

            app.ExtractROIButton = uibutton(app.ExtractROIGrid, 'push');
            app.ExtractROIButton.ButtonPushedFcn = createCallbackFcn(app, @ExtractROIButtonPushed, true);
            app.ExtractROIButton.Text = 'Extract ROI Values';
            app.ExtractROIButton.Layout.Row = 1;
            app.ExtractROIButton.Layout.Column = 1;

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        function app = SNBPI
            createComponents(app)
            registerApp(app, app.UIFigure)
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure)
        end
    end
end