function SmoothNormalizedImages(PETnames, prefix, fwhmStr, uifig)
% SmoothNormalizedImages   Apply SPM smoothing to intensity‑normalized PET images
%
%   PETnames : cell array, paths to original PET images (may include ',1' volume suffix)
%   prefix   : prefix of intensity‑normalized output files (e.g., 'n')
%   fwhmStr  : FWHM string, e.g., '8 8 8' or '8'
%   uifig    : optional, UIFigure handle for uialert; if omitted, warning is used

    if nargin < 4
        uifig = [];
    end

    % Parse FWHM
    fwhm = str2num(strtrim(fwhmStr)); %#ok<ST2NM>
    if isempty(fwhm)
        msg = 'Invalid FWHM value. Please enter numbers like "8 8 8".';
        if ~isempty(uifig)
            uialert(uifig, msg, 'Alert');
        else
            warning(msg);
        end
        return;
    end
    if isscalar(fwhm)
        fwhm = [fwhm fwhm fwhm];
    end

    % Build list of normalized image filenames (with prefix)
    nPET = numel(PETnames);
    normNames = cell(nPET, 1);
    for i = 1:nPET
        [pth, nm, ext] = fileparts(PETnames{i});
        commaIdx = strfind(ext, ',');
        if ~isempty(commaIdx)
            volSuffix = ext(commaIdx:end);
            ext = ext(1:commaIdx-1);
        else
            volSuffix = ',1';
        end
        normNames{i} = fullfile(pth, [prefix nm ext volSuffix]);
    end

    % Run SPM smoothing job
    matlabbatch = {};
    matlabbatch{1}.spm.spatial.smooth.data   = normNames;
    matlabbatch{1}.spm.spatial.smooth.fwhm   = fwhm;
    matlabbatch{1}.spm.spatial.smooth.dtype  = 0;
    matlabbatch{1}.spm.spatial.smooth.im     = 0;
    matlabbatch{1}.spm.spatial.smooth.prefix = 's';
    spm_jobman('run', matlabbatch);
end