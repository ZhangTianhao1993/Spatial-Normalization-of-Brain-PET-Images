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
        s.cmap = getCmap256(s.colormapName);

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

function cmap = getCmap256(name)
%GETCMAP256  Return a 256x3 colormap by name. Built-in colormaps are resolved
% via feval; custom ones (inferno/viridis/magma/plasma/nih) are defined here.
    switch lower(name)
        case 'inferno'
            x = linspace(0, 1, 11)';
            r = [0.001462 0.039001 0.116656 0.260134 0.437975 0.612867 0.778469 0.906158 0.979728 0.994862 0.988362]';
            g = [0.000466 0.019443 0.036102 0.056139 0.117203 0.206250 0.345040 0.501291 0.664951 0.830258 0.988362]';
            b = [0.013866 0.196908 0.356205 0.445244 0.434325 0.387804 0.289670 0.163746 0.091025 0.059142 0.043137]';
            cmap = interp1(x, [r g b], linspace(0, 1, 256), 'pchip');
        case 'viridis'
            x = linspace(0, 1, 11)';
            r = [0.267004 0.282623 0.253935 0.206756 0.163625 0.127568 0.134692 0.266941 0.477504 0.741388 0.993248]';
            g = [0.004874 0.140926 0.265254 0.387588 0.504401 0.596048 0.665657 0.718701 0.752500 0.766436 0.906157]';
            b = [0.329415 0.457517 0.529432 0.543109 0.547535 0.546753 0.504430 0.430477 0.320736 0.132859 0.143654]';
            cmap = interp1(x, [r g b], linspace(0, 1, 256), 'pchip');
        case 'magma'
            x = linspace(0, 1, 11)';
            r = [0.001462 0.105107 0.287678 0.490989 0.667304 0.831306 0.935182 0.983268 0.988745 0.992376 0.987622]';
            g = [0.000466 0.050691 0.060353 0.111646 0.219223 0.349389 0.494984 0.646067 0.778656 0.907109 0.988362]';
            b = [0.013866 0.217846 0.390452 0.454334 0.422139 0.383379 0.345555 0.327410 0.414977 0.590600 0.749504]';
            cmap = interp1(x, [r g b], linspace(0, 1, 256), 'pchip');
        case 'plasma'
            x = linspace(0, 1, 11)';
            r = [0.050383 0.296143 0.502731 0.673102 0.820376 0.930075 0.983213 0.993376 0.989372 0.975306 0.940015]';
            g = [0.029803 0.010139 0.003717 0.095613 0.251031 0.435973 0.632226 0.813163 0.914467 0.975161 0.975158]';
            b = [0.527975 0.619574 0.507087 0.379886 0.265592 0.154904 0.059061 0.034648 0.124292 0.294898 0.542298]';
            cmap = interp1(x, [r g b], linspace(0, 1, 256), 'pchip');
        case 'nih'
            x = [0 0.25 0.5 0.75 1]';
            r = [0 1 1 1 1]';
            g = [0 0 0.5 1 1]';
            b = [0 0 0 0 1]';
            cmap = interp1(x, [r g b], linspace(0, 1, 256), 'linear');
        case 'ge'
            x = [0 0.15 0.3 0.45 0.6 0.75 0.9 1]';
            r = [0 0 0 0 0 1 1 1]';
            g = [0 0 0 1 1 1 0 1]';
            b = [0 0.56 1 0.56 0 0 0 1]';
            cmap = interp1(x, [r g b], linspace(0, 1, 256), 'linear');
        otherwise
            cmap = feval(name, 256);
    end
end
