function recreateImageGrid(fig)
%ROV.UI.RECREATEIMAGEGRID  (Re)create the nRows x nCols axes grid.
%
% PURPOSE
%   Called both at startup and whenever the user changes the Rows/Cols
%   controls. Deletes any existing axes, then lays out a fresh grid of
%   uiaxes on fig.UserData.h.imagePanel in normalised units.
%
% INPUT
%   fig : main uifigure handle (fig.UserData.nRows/nCols determine size).
%
% SIDE EFFECTS
%   Replaces fig.UserData.h.imageAxesCell with a new 1 x (nR*nC) cell
%   array of uiaxes handles.
%
% NOTES
%   Gap sizes are chosen so slice-index titles ("z = N") never collide
%   with adjacent axes.
%
% EXAMPLE
%   rov.ui.recreateImageGrid(fig);

    s = fig.UserData;

    % --- clear old axes -----------------------------------------------
    if ~isempty(s.h.imageAxesCell)
        for k = 1:numel(s.h.imageAxesCell)
            if isvalid(s.h.imageAxesCell{k})
                delete(s.h.imageAxesCell{k});
            end
        end
    end
    s.h.imageAxesCell = {};

    nR = s.nRows;  nC = s.nCols;

    % Margins / gaps (normalised)
    ML = 0.005;  MR = 0.005;  MT = 0.030;  MB = 0.005;
    GH = 0.005;  GV = 0.030;

    PW = (1 - ML - MR - GH*(nC-1)) / nC;
    PH = (1 - MT - MB - GV*(nR-1)) / nR;

    for k = 1:nR*nC
        r  = ceil(k/nC);
        c  = mod(k-1, nC) + 1;
        x0 = ML + (c-1)*(PW + GH);
        y0 = 1  - MT - r*PH - (r-1)*GV;

        ax = uiaxes(s.h.imagePanel, ...
            'Units','normalized', ...
            'Position',[x0, y0, PW, PH], ...
            'Color','k', 'XColor','none','YColor','none', 'Box','off');
        ax.Toolbar.Visible = 'off';
        rov.util.safeDisableInteractivity(ax);
        s.h.imageAxesCell{k} = ax;
    end

    fig.UserData = s;
end
