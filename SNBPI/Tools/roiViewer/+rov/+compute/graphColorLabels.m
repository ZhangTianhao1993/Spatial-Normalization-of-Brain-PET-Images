function colorIdx = graphColorLabels(atlas, uniLabels, palette)
%ROV.COMPUTE.GRAPHCOLORLABELS  Assign palette indices to ROIs avoiding neighbour colour clashes.
%
% PURPOSE
%   Implements a greedy graph-colouring over the 6-connected spatial
%   adjacency of labelled ROIs, so that adjacent regions in 3D never
%   share the same display colour (when possible given palette size).
%
% INPUTS
%   atlas     : 3D integer-valued volume (0 = background).
%   uniLabels : vector of unique non-zero label values present in atlas.
%   palette   : P x 3 RGB matrix (output of buildQualPalette).
%
% OUTPUT
%   colorIdx : N x 1 integer vector (1 .. P), one colour index per ROI
%              in uniLabels order.
%
% NOTES
%   Uses containers.Map for label lookup (available on every supported
%   MATLAB release, unlike the R2022b+ `dictionary` type).
%
% EXAMPLE
%   ul = unique(atlas(atlas>0));
%   pal = rov.compute.buildQualPalette(numel(ul));
%   idx = rov.compute.graphColorLabels(atlas, ul, pal);

    n        = numel(uniLabels);
    nC       = size(palette, 1);
    colorIdx = zeros(n, 1);
    if n == 0, return; end

    [X, Y, Z] = size(atlas);
    keys      = num2cell(double(uniLabels(:)'));
    vals      = num2cell(1:n);
    lmap      = containers.Map(keys, vals);

    adj    = false(n, n);
    shifts = [ 1 0 0; -1 0 0;  0 1 0;  0 -1 0;  0 0 1;  0 0 -1];

    for sIdx = 1:size(shifts,1)
        sh = circshift(atlas, [shifts(sIdx,1), shifts(sIdx,2), shifts(sIdx,3)]);
        em = true(X, Y, Z);
        if shifts(sIdx,1) > 0, em(1,:,:)   = false;
        elseif shifts(sIdx,1) < 0, em(end,:,:) = false; end
        if shifts(sIdx,2) > 0, em(:,1,:)   = false;
        elseif shifts(sIdx,2) < 0, em(:,end,:) = false; end
        if shifts(sIdx,3) > 0, em(:,:,1)   = false;
        elseif shifts(sIdx,3) < 0, em(:,:,end) = false; end

        bnd = em & atlas > 0 & sh > 0 & atlas ~= sh & isfinite(atlas) & isfinite(sh);
        av  = double(atlas(bnd));
        bv  = double(sh(bnd));
        if isempty(av), continue; end
        pairs = unique(sort([av, bv], 2), 'rows');
        for p = 1:size(pairs,1)
            if ~isKey(lmap, pairs(p,1)) || ~isKey(lmap, pairs(p,2)), continue; end
            i1 = lmap(pairs(p,1));
            i2 = lmap(pairs(p,2));
            adj(i1,i2) = true;
            adj(i2,i1) = true;
        end
    end

    for i = 1:n
        used = colorIdx(adj(i,:));
        used(used == 0) = [];
        found = false;
        for c = 1:nC
            if ~ismember(c, used)
                colorIdx(i) = c;
                found = true;
                break;
            end
        end
        if ~found
            colorIdx(i) = mod(i-1, nC) + 1;
        end
    end
end
