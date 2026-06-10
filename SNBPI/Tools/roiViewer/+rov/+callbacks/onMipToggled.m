function onMipToggled(fig)
%ROV.CALLBACKS.ONMIPTOGGLED  Handle MIP Mode checkbox toggle.
%
% PURPOSE
%   Switches the viewer between slice-grid mode and maximum intensity
%   projection (MIP) mode. Saves/restores Rows, Cols, and Spacing so the
%   user's slice-mode settings are preserved across toggles.

    s = fig.UserData;

    if s.h.chkMip.Value
        % ===== MIP ON =====
        s.mipSavedRows    = s.nRows;
        s.mipSavedCols    = s.nCols;
        s.mipSavedSpacing = s.spacing;
        s.nRows           = 1;
        s.nCols           = 1;
        s.mipMode         = true;

        s.h.numRows.Enable    = 'off';
        s.h.numCols.Enable    = 'off';
        s.h.numSpacing.Enable = 'off';

        if isfield(s.h, 'btnPageUp')   && isvalid(s.h.btnPageUp),   s.h.btnPageUp.Enable   = 'off'; end
        if isfield(s.h, 'btnStepUp')   && isvalid(s.h.btnStepUp),   s.h.btnStepUp.Enable   = 'off'; end
        if isfield(s.h, 'btnStepDown') && isvalid(s.h.btnStepDown), s.h.btnStepDown.Enable = 'off'; end
        if isfield(s.h, 'btnPageDown') && isvalid(s.h.btnPageDown), s.h.btnPageDown.Enable = 'off'; end

        fig.UserData = s;
        rov.ui.recreateImageGrid(fig);
        if s.isDataLoaded
            rov.render.renderPage(fig);
            rov.util.setStatus(fig, sprintf('MIP mode (%s) active.', s.viewDir));
        end
    else
        % ===== MIP OFF =====
        if isempty(s.mipSavedRows)
            s.mipSavedRows = 4;  s.mipSavedCols = 5;  s.mipSavedSpacing = 10;
        end
        s.nRows    = s.mipSavedRows;
        s.nCols    = s.mipSavedCols;
        s.spacing  = s.mipSavedSpacing;
        s.mipMode  = false;

        s.h.numRows.Value       = s.nRows;
        s.h.numCols.Value       = s.nCols;
        s.h.numSpacing.Value    = s.spacing;
        s.h.numRows.Enable      = 'on';
        s.h.numCols.Enable      = 'on';
        s.h.numSpacing.Enable   = 'on';

        if isfield(s.h, 'btnPageUp')   && isvalid(s.h.btnPageUp),   s.h.btnPageUp.Enable   = 'on'; end
        if isfield(s.h, 'btnStepUp')   && isvalid(s.h.btnStepUp),   s.h.btnStepUp.Enable   = 'on'; end
        if isfield(s.h, 'btnStepDown') && isvalid(s.h.btnStepDown), s.h.btnStepDown.Enable = 'on'; end
        if isfield(s.h, 'btnPageDown') && isvalid(s.h.btnPageDown), s.h.btnPageDown.Enable = 'on'; end

        fig.UserData = s;
        if s.isDataLoaded
            rov.compute.computeSliceList(fig);
        end
        rov.ui.recreateImageGrid(fig);
        if s.isDataLoaded
            rov.render.renderPage(fig);
            rov.util.setStatus(fig, sprintf(...
                'Slice mode restored. %d slice(s).', numel(s.sliceList)));
        end
    end
end
