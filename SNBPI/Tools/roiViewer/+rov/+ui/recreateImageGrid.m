function recreateImageGrid(fig)
%ROV.UI.RECREATEIMAGEGRID  (Re)create the nRows x nCols axes grid.
%
% PURPOSE
%   Called both at startup and whenever the user changes the Rows/Cols
%   controls. Deletes any existing axes, then lays out a fresh grid of
%   uiaxes inside a uigridlayout container (placed on fig.UserData.h.imagePanel).
%   Using uigridlayout ensures correct resizing behaviour even when the
%   figure is maximised.
%
% INPUT
%   fig : main uifigure handle (fig.UserData.nRows/nCols determine size).
%
% SIDE EFFECTS
%   Replaces fig.UserData.h.imageAxesCell with a new 1 x (nR*nC) cell
%   array of uiaxes handles.
%   Creates or reuses a uigridlayout (stored in fig.UserData.h.imageAxesGrid)
%   that is a child of h.imagePanel.
%
% NOTES
%   Gap sizes are set via RowSpacing / ColumnSpacing and Padding of the
%   grid layout. These values were chosen so that slice-index titles ("z = N")
%   never collide with adjacent axes.
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

    nR = s.nRows;  
    nC = s.nCols;

    % --- Create or reuse the grid layout container --------------------
    % The grid is placed inside s.h.imagePanel and fills it completely.
    if isfield(s.h, 'imageAxesGrid') && isvalid(s.h.imageAxesGrid)
        grid = s.h.imageAxesGrid;
        % Clear any remaining children (axes) from previous layout
        delete(grid.Children);
    else
        % Create a new grid layout as child of imagePanel
        grid = uigridlayout(s.h.imagePanel, ...
            'RowHeight', repmat({'1x'}, 1, nR), ...
            'ColumnWidth', repmat({'1x'}, 1, nC), ...
            'Padding', [5 5 5 5], ...          % [left bottom right top] in pixels
            'RowSpacing', 20, ...              % enough vertical gap for "z = N" title
            'ColumnSpacing', 5, ...
            'BackgroundColor', s.h.imagePanel.BackgroundColor);
        s.h.imageAxesGrid = grid;
    end

    % Update grid dimensions if rows/cols have changed
    grid.RowHeight = repmat({'1x'}, 1, nR);
    grid.ColumnWidth = repmat({'1x'}, 1, nC);

    % --- Create new axes inside the grid layout -----------------------
    for r = 1:nR
        for c = 1:nC
            ax = uiaxes(grid, ...
                'Color', 'k', ...
                'XColor', 'none', ...
                'YColor', 'none', ...
                'Box', 'off');
            ax.Toolbar.Visible = 'off';
            rov.util.safeDisableInteractivity(ax);
            % Place axes in the grid cell
            ax.Layout.Row = r;
            ax.Layout.Column = c;
            % Store axes handle in linear indexing order (row-major)
            idx = (r-1)*nC + c;
            s.h.imageAxesCell{idx} = ax;
        end
    end

    fig.UserData = s;
end