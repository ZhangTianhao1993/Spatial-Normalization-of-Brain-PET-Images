function AtlasBased_worker(paramFile)
% AtlasBased_worker
% Entry point for a background MATLAB process spawned by
% AtlasBased_dispatch. Each "white window" launched by the dispatcher
% runs this function on its own slice of subjects.
%
% Input:
%   paramFile - Path to a .mat file produced by the dispatcher, holding:
%       PETnames  : cell array of subject names assigned to this worker
%       bbox, vx, nf, rt, sT, sD : algorithm parameters
%       logFile   : path where this worker writes its OK/FAIL summary
%       diaryFile : path where this worker dumps its command-window log
%       doneFlag  : path written when the worker finishes (poll target)
%       addPaths  : list of folders to addpath() before running
%
% Behavior:
%   1. Restores the MATLAB path (the spawned process starts clean).
%   2. Initializes SPM in PET mode.
%   3. Calls AtlasBasedSpatialNormalizationMethod once with the assigned
%      subjects; per-subject failures are caught inside that function.
%   4. Writes a small log file and a "done" marker so the launcher can
%      poll for completion.
%
% This worker NEVER opens a parallel pool. Process-level parallelism is
% achieved by the dispatcher launching multiple workers concurrently.
% =========================================================================

S = load(paramFile);

% --- 1) Restore MATLAB path in this fresh process ---------------------
if isfield(S, 'addPaths')
    for k = 1:numel(S.addPaths)
        if exist(S.addPaths{k}, 'dir')
            addpath(S.addPaths{k});
        end
    end
end

% --- 2) Initialize SPM (best effort; failure here is non-fatal) -------
try
    spm('Defaults', 'PET');
    spm_jobman('initcfg');
catch
    % SPM may not be on the path yet, or may already be initialized.
    % We let the algorithm raise a clearer error later if SPM is missing.
end

% --- 3) Capture command-window output to disk for debugging -----------
diary(S.diaryFile); diary on
fprintf('=== Worker started %s, %d subjects ===\n', ...
    datestr(now), numel(S.PETnames));

% --- 4) Run the algorithm on this worker's slice ----------------------
failed = AtlasBasedSpatialNormalizationMethod( ...
    S.PETnames, S.bbox, S.vx, S.nf, S.rt, [], S.sT, S.sD);

% --- 5) Write per-worker summary log ----------------------------------
nTotal = numel(S.PETnames);
nFail  = numel(failed);
nOK    = nTotal - nFail;

fid = fopen(S.logFile, 'w');
fprintf(fid, 'OK=%d FAIL=%d TOTAL=%d\n', nOK, nFail, nTotal);
for i = 1:nFail
    fprintf(fid, '[FAIL] %s\n', failed{i});
end
fclose(fid);

fprintf('=== Worker finished. OK=%d FAIL=%d ===\n', nOK, nFail);
diary off

% --- 6) Drop a "done" flag the launcher can poll for ------------------
fid = fopen(S.doneFlag, 'w');
fprintf(fid, 'done\n');
fclose(fid);
end