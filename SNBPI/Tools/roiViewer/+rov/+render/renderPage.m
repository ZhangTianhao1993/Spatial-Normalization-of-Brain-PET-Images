function renderPage(fig)
%ROV.RENDER.RENDERPAGE  Render the current page of slices into the image grid.
%
% PURPOSE
%   Pulls s.sliceList(s.pageStart : s.pageStart+nAxes-1) and draws each
%   onto the pre-created uiaxes. Unused axes on the final page are
%   blanked (solid black).
%
% INPUT
%   fig : main uifigure handle.
%
% SIDE EFFECTS
%   Updates s.h.sliceInfoLbl.Text and clamps s.pageStart to valid range.
%
% EXAMPLE
%   rov.render.renderPage(fig);

    s = fig.UserData;
    if ~s.isDataLoaded, return; end

    if s.mipMode
        ax = s.h.imageAxesCell{1};
        cla(ax);
        rov.render.renderMipOnAxes(ax, s);
        s.h.sliceInfoLbl.Text = sprintf('MIP (%s)', s.viewDir);
        return;
    end

    if isempty(s.sliceList)
        rov.util.setStatus(fig, ...
            'No slices to display. Adjust Spacing or View direction.');
        return;
    end

    nAxes    = s.nRows * s.nCols;
    nSlices  = numel(s.sliceList);

    s.pageStart  = max(1, min(s.pageStart, nSlices));
    fig.UserData = s;

    idxEnd     = min(s.pageStart + nAxes - 1, nSlices);
    pageSlices = s.sliceList(s.pageStart : idxEnd);
    nShow      = numel(pageSlices);

    axLabelMap = struct('Transverse','z','Coronal','y','Sagittal','x');
    lbl        = axLabelMap.(s.viewDir);

    for k = 1:nAxes
        ax = s.h.imageAxesCell{k};
        cla(ax);
        if k <= nShow
            rov.render.renderSliceOnAxes(ax, pageSlices(k), lbl, fig);
        else
            set(ax, 'Color','k', 'XColor','none','YColor','none');
        end
    end

    s.h.sliceInfoLbl.Text = sprintf('Slices %d-%d  /  %d', ...
        s.pageStart, idxEnd, nSlices);
    fig.UserData = s;
end
