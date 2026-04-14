function computeColors(fig)
%ROV.COMPUTE.COMPUTECOLORS  Populate colour / legend state from the loaded atlas(es).
%
% PURPOSE
%   Depending on s.colorScheme and s.nAtlas, builds one of two things:
%     1. Continuous mode (single atlas): a 256-colour colormap plus
%        s.atlasVmin/Vmax data range, and legend entries derived from
%        the label list (unless there are more than 500 unique labels,
%        in which case the legend is collapsed to a single "see colorbar"
%        entry).
%     2. Discrete mode: s.colorEntries = struct array with
%        (atlasIdx, label, color, name) for each ROI (single atlas) or
%        for each atlas (multi-atlas), and a matching legend list.
%
% INPUT
%   fig : main uifigure handle.
%
% SIDE EFFECTS
%   Writes fig.UserData.{cmap, atlasVmin, atlasVmax, colorEntries,
%                        legendEntries}.
%
% EXAMPLE
%   rov.compute.computeColors(fig);

    s = fig.UserData;
    if ~s.isDataLoaded, return; end

    isCont = rov.util.isContinuousMode(s);

    if isCont
        % ---- Continuous (single atlas) ------------------------------
        s.cmap = feval(s.colormapName, 256);

        vol  = s.atlasVols{1};
        vals = vol(isfinite(vol) & vol ~= 0);
        if isempty(vals)
            s.atlasVmin     = 0;
            s.atlasVmax     = 1;
            s.legendEntries = struct('color',{},'name',{});
            s.colorEntries  = struct('atlasIdx',{},'label',{},'color',{},'name',{});
            fig.UserData    = s;
            return;
        end
        s.atlasVmin = min(vals);
        s.atlasVmax = max(vals);

        uniLbls = unique(vals);
        if numel(uniLbls) <= 500
            nameMap = rov.compute.buildNameMap(s.atlasLabels, uniLbls);
            nL      = numel(uniLbls);
            entries = repmat(struct('color',[],'name',''), nL, 1);

            % Use effectiveCbRange so legend swatches match what is
            % actually painted on the slices (including any user
            % override of Min / Max).
            [vmin, vmax, isDeg] = rov.util.effectiveCbRange(s);
            for j = 1:nL
                if isDeg
                    cidx = 256/2;     % middle of colormap
                else
                    w    = max(0, min(1, (uniLbls(j) - vmin) / (vmax - vmin)));
                    cidx = min(256, max(1, round(w*255) + 1));
                end
                entries(j).color = s.cmap(cidx, :);
                entries(j).name  = nameMap{j};
            end
            s.legendEntries = entries;
        else
            s.legendEntries = struct( ...
                'color', s.cmap(128,:), ...
                'name',  '(Continuous - see colorbar)');
        end
        s.colorEntries = [];

    else
        % ---- Discrete ----------------------------------------------
        if s.nAtlas == 1
            vol     = s.atlasVols{1};
            uniLbls = unique(vol(isfinite(vol) & vol ~= 0));
            nL      = numel(uniLbls);
            if nL == 0
                s.legendEntries = struct('color',{},'name',{});
                s.colorEntries  = struct('atlasIdx',{},'label',{},'color',{},'name',{});
                s.cmap          = [];
                fig.UserData    = s;
                return;
            end
            % One unique colour per ROI (no graph colouring): users
            % wanted every region distinguishable in the legend, even
            % when not spatially adjacent.
            palette = rov.compute.buildQualPalette(nL);
            nameMap = rov.compute.buildNameMap(s.atlasLabels, uniLbls);

            entries = repmat( ...
                struct('atlasIdx',[],'label',[],'color',[],'name',''), nL, 1);
            for j = 1:nL
                entries(j).atlasIdx = 1;
                entries(j).label    = uniLbls(j);
                entries(j).color    = palette(j, :);
                entries(j).name     = nameMap{j};
            end
        else
            BP = rov.compute.basePal();
            entries = repmat( ...
                struct('atlasIdx',[],'label',[],'color',[],'name',''), s.nAtlas, 1);
            for i = 1:s.nAtlas
                Vi        = spm_vol(s.atlasNames{i});
                [~, fn, ~] = fileparts(Vi.fname);
                entries(i).atlasIdx = i;
                entries(i).label    = NaN;
                entries(i).color    = BP(mod(i-1, size(BP,1)) + 1, :);
                entries(i).name     = fn;
            end
        end
        s.colorEntries = entries;

        % Build matching legend entries
        nE  = numel(entries);
        leg = repmat(struct('color',[],'name',''), nE, 1);
        for j = 1:nE
            leg(j).color = entries(j).color;
            leg(j).name  = entries(j).name;
        end
        s.legendEntries = leg;
        s.cmap          = [];
    end

    fig.UserData      = s;
end
