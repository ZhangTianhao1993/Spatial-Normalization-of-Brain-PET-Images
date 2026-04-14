function updateColorbar(fig)
%ROV.RENDER.UPDATECOLORBAR  Draw the colorbar column.
%
% PURPOSE
%   In Continuous single-atlas mode, draws a proper colormap ramp with
%   numeric tick labels spanning the active range as returned by
%   rov.util.effectiveCbRange (which honours the user-typed Min / Max
%   if set, otherwise falls back to the data range).
%
%   In Discrete / multi-atlas mode, draws a blank white 0..1 strip so
%   the column width stays the same and the main image area does not
%   reflow.
%
% DEGENERATE RANGE HANDLING
%   When vmin == vmax (e.g. a binary 0/1 mask whose only non-zero value
%   is 1, giving vmin = vmax = 1):
%     - The colorbar still needs *some* range to draw against; we pad
%       symmetrically *for display only*.
%     - We DO NOT write the padded values back to the state; the
%       renderer reads s.cbUserMin/Max (or atlasVmin/Vmax) directly via
%       effectiveCbRange and uses its own degenerate-range branch in
%       rov.render.renderSliceOnAxes to show the mask in the colormap's
%       top colour. This is what fixes the old "binary mask shows as
%       middle of colormap" bug.
%
% INPUT
%   fig : main uifigure handle.
%
% SIDE EFFECTS
%   Repaints s.h.cbAx and updates s.h.lblCbTitle text.
%
% EXAMPLE
%   rov.render.updateColorbar(fig);

    s      = fig.UserData;
    isCont = rov.util.isContinuousMode(s) && ~isempty(s.cmap);
    cbAx   = s.h.cbAx;
    cla(cbAx);

    if isCont
        nC    = size(s.cmap, 1);
        cbImg = reshape(s.cmap, [nC, 1, 3]);

        [vmin, vmax, isDeg] = rov.util.effectiveCbRange(s);

        if isDeg
            c = vmin;
            if c == 0
                dispMin = -0.5;  dispMax = 0.5;
            else
                pad     = max(abs(c) * 0.5, 0.5);
                dispMin = c - pad;  dispMax = c + pad;
            end
        else
            dispMin = vmin;  dispMax = vmax;
        end

        image(cbAx, [0 1], [dispMin dispMax], cbImg);

        ticks      = linspace(dispMin, dispMax, 5);
        tickLabels = arrayfun(@(v) sprintf('%.3g', v), ticks, ...
                              'UniformOutput', false);

        set(cbAx, ...
            'YDir','normal', 'XTick', [], ...
            'YTick', ticks, 'YTickLabel', tickLabels, ...
            'TickLength',[0 0], ...
            'YColor',[0.88 0.88 0.88], 'FontSize', 10, ...
            'XLim',[0 1], 'YLim',[dispMin dispMax], ...
            'YAxisLocation','right', ...
            'Color','none', 'Box','on');

        if isDeg
            s.h.lblCbTitle.Text = sprintf('Colorbar (=%.3g)', vmin);
        else
            s.h.lblCbTitle.Text = 'Colorbar';
        end

    else
        cbImg = ones(2, 1, 3);
        image(cbAx, [0 1], [0 1], cbImg);
        set(cbAx, ...
            'YDir','normal', 'XTick', [], ...
            'YTick',[0 0.5 1], 'YTickLabel',{'0','0.5','1'}, ...
            'TickLength',[0 0], ...
            'YColor',[0.88 0.88 0.88], 'FontSize', 10, ...
            'XLim',[0 1], 'YLim',[0 1], ...
            'YAxisLocation','right', ...
            'Color','none', 'Box','on');
        s.h.lblCbTitle.Text = 'Colorbar (n/a)';
    end

    cbAx.DataAspectRatioMode = 'auto';
    fig.UserData             = s;
end
