function nameMap = buildNameMap(atlasLabels, uniLabels)
%ROV.COMPUTE.BUILDNAMEMAP  Map unique label values to human-readable names.
%
% PURPOSE
%   Looks up each unique atlas label value in the optional n x 2 Labels
%   cell {name, value}. Any value not found falls back to a default
%   'Label_<value>' name so the legend still has something to show.
%
% INPUTS
%   atlasLabels : n x 2 cell {name(char|string), value(numeric)} or empty.
%   uniLabels   : vector of unique label values appearing in the atlas.
%
% OUTPUT
%   nameMap : numel(uniLabels) x 1 cell of char vectors.
%
% EXAMPLE
%   names = rov.compute.buildNameMap(labels, [1 2 7 42]);

    n       = numel(uniLabels);
    nameMap = cell(n, 1);

    if isempty(atlasLabels)
        for j = 1:n
            nameMap{j} = sprintf('Label_%g', uniLabels(j));
        end
        return;
    end

    % Robustly coerce the value column to numeric
    try
        valCol = cell2mat(atlasLabels(:,2));
    catch
        valCol = cellfun(@(x) double(x), atlasLabels(:,2));
    end
    nameCol = atlasLabels(:,1);

    for j = 1:n
        idx = find(valCol == double(uniLabels(j)), 1);
        if ~isempty(idx)
            nm = nameCol{idx};
            if isstring(nm), nm = char(nm); end
            nameMap{j} = nm;
        else
            nameMap{j} = sprintf('Label_%g', uniLabels(j));
        end
    end
end
