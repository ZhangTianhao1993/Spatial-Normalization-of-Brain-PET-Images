function result = checkAtlasValidity(atlasNames, extraROIMethod)
% CHECKATLASVALIDITY  Validate atlas selection against the chosen extraction method.
%
%   result = checkAtlasValidity(atlasNames, extraROIMethod)
%
%   Inputs:
%     atlasNames     - cell array of atlas file paths (TextArea.Value)
%     extraROIMethod - 'mean', 'median', or 'weight'
%
%   Output struct fields:
%     allowedMethods  - cell array of methods valid for this atlas input
%     isMethodAllowed - logical, whether extraROIMethod is currently valid
%     needConfirm     - logical, whether to ask user to confirm before running
%     labelCount      - number of unique non-zero labels (single atlas only, else [])
%     selectionMsg    - message to show when atlas is selected ('' = silent)
%     runMsg          - message to show / confirm at run time  ('' = silent)

result.allowedMethods  = {'mean', 'median', 'weight'};
result.isMethodAllowed = true;
result.needConfirm     = false;
result.labelCount      = [];
result.selectionMsg    = '';
result.runMsg          = '';

% Strip empty / whitespace-only entries produced by the TextArea widget
atlasNames = atlasNames(~cellfun(@(s) isempty(strtrim(s)), atlasNames));
atlasNum   = numel(atlasNames);

if atlasNum == 0
    return;
end

% =========================================================================
if atlasNum == 1
% =========================================================================
%   Single atlas: all three methods are always available.
%   Only warn when mean/median is chosen on a file with > 1000 labels.

    if ismember(extraROIMethod, {'mean', 'median'})
        try
            vol       = spm_read_vols(spm_vol(atlasNames{1}));
            uniLabels = unique(vol(isfinite(vol) & vol ~= 0));
            result.labelCount = numel(uniLabels);

            if result.labelCount > 1000
                result.needConfirm = true;
                result.runMsg = sprintf( ...
                    ['Detected %d non-zero brain region labels, far exceeding the typical atlas range.\n\n' ...
                     'If the file is a probability map or continuous value map, consider using the weight method.\n' ...
                     'If this is indeed a multi-label atlas, click ''Continue'' to proceed (may take a while).'], ...
                    result.labelCount);
            end
        catch ME
            warning('checkAtlasValidity:readFail', 'Failed to read atlas, skipping label count check.\n%s', ME.message);
        end
    end

% =========================================================================
else
% =========================================================================
%   Multiple atlases: check whether ALL of them are binary (0/1) images.
%   • All binary  → mean / median / weight all allowed
%   • Any non-binary → only weight allowed

    isBinaryAll = true;
    for i = 1:atlasNum
        try
            vol        = spm_read_vols(spm_vol(atlasNames{i}));
            finiteVals = vol(isfinite(vol));
            uniqueVals = unique(finiteVals);
            if ~all(ismember(uniqueVals, [0, 1]))
                isBinaryAll = false;
                break;
            end
        catch ME
            warning('checkAtlasValidity:readFail', 'Failed to read atlas #%d.\n%s', i, ME.message);
            isBinaryAll = false;
            break;
        end
    end

    if ~isBinaryAll
        result.allowedMethods = {'weight'};
        result.selectionMsg   = [...
            'The provided multiple atlases contain non-binary (not 0/1) images.' newline ...
            'The allowed method has been automatically restricted to ''weight'''];

        if ~strcmp(extraROIMethod, 'weight')
            result.isMethodAllowed = false;
            result.runMsg = [...
                'The provided multiple atlases contain non-binary (not 0/1) images.' newline ...
                'Only the ''weight'' method is supported. Please reselect the method before running.'];
        end
    end
    % (isBinaryAll == true: allowedMethods stays {'mean','median','weight'})

end
end
