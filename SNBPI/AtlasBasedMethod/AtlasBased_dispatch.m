function tmpDir = AtlasBased_dispatch(PETnames, bbox, vx, nf, rt, ...
                                      sT, sD, nProc, showWindow,outDir)
% AtlasBased_dispatch
% Split a list of subjects into N slices and launch N independent MATLAB
% processes (one per slice). Each process runs AtlasBased_worker on its
% own slice. This is the same trick CAT12 uses for "background parallel
% processing": OS-level process spawning + on-disk coordination.
%
% Inputs:
%   PETnames   - Cell array of PET image names.
%   bbox,vx,nf,rt,sT,sD - Algorithm parameters, forwarded as-is.
%   nProc      - Desired number of background processes (>=1). Will be
%                clamped to numel(PETnames).
%   showWindow - true  : show a regular MATLAB window per worker
%                        (CAT12-like behavior).
%                false : run minimized / no desktop.
%   outDir - Where to put the per-run log folder. If empty, falls back
%            to the system temp directory.
%
% Output:
%   tmpDir - Folder containing all per-worker .mat / log / done files.
%
% Notes:
%   - The spawned processes are detached from the launching MATLAB. You
%     can close the GUI MATLAB and they will keep running.
%   - On Windows we use 'start' so the new process is independent. On
%     Unix we use 'nohup ... &' for the same reason.
%   - We pause briefly between launches to avoid simultaneous license
%     check-outs from MATLAB's network license server.
% =========================================================================

n     = numel(PETnames);
nProc = max(1, min(nProc, n));

% --- Collect paths to forward to the workers --------------------------
% A freshly spawned MATLAB starts with a default path, so we explicitly
% pass the SNBPI tree and the SPM root directory.
str = which('SNBPI');
[mainfilepath, ~, ~] = fileparts(str);
addPaths = strsplit(genpath(mainfilepath), pathsep);
addPaths(cellfun(@isempty, addPaths)) = [];
spmDir = fileparts(which('spm'));
if ~isempty(spmDir)
    addPaths{end+1} = spmDir;
end

% --- Create a unique workspace for this run ---------------------------
if nargin < 10 || isempty(outDir)
    baseDir = tempdir;
else
    baseDir = outDir;
end
tmpDir = fullfile(baseDir, ...
    ['SNBPI_logs_' datestr(now, 'yyyymmdd_HHMMSS_FFF')]);
mkdir(tmpDir);

% --- Slice the subject list as evenly as possible ---------------------
edges = round(linspace(0, n, nProc+1));

for k = 1:nProc
    idx = (edges(k)+1):edges(k+1);
    if isempty(idx); continue; end

    % Build per-worker parameter file.
    paramFile = fullfile(tmpDir, sprintf('part_%02d.mat', k));
    S = struct();
    S.PETnames  = PETnames(idx);
    S.bbox = bbox; S.vx = vx; S.nf = nf; S.rt = rt;
    S.sT = sT;     S.sD = sD;
    S.logFile   = fullfile(tmpDir, sprintf('part_%02d_log.txt',   k));
    S.diaryFile = fullfile(tmpDir, sprintf('part_%02d_diary.txt', k));
    S.doneFlag  = fullfile(tmpDir, sprintf('part_%02d.done',      k));
    S.addPaths  = addPaths;
    save(paramFile, '-struct', 'S');

    % --- Build the OS command to spawn an independent MATLAB ----------
    if ispc
        if showWindow
            % CAT12-style: command-window-only MATLAB, no full desktop.
            cmd = sprintf(['start "SNBPI_%02d" matlab ' ...
                '-nodesktop -nosplash -minimize ' ...
                '-r "AtlasBased_worker(''%s''); exit"'], ...
                k, strrep(paramFile, '\', '\\'));
        else
            % Fully headless: not even a command window.
            cmd = sprintf(['start "SNBPI_%02d" /B matlab ' ...
                '-batch "AtlasBased_worker(''%s'')"'], ...
                k, strrep(paramFile, '\', '\\'));
        end
    else
        if showWindow
            cmd = sprintf(['nohup matlab -nodesktop -nosplash ' ...
                '-r "AtlasBased_worker(''%s''); exit" ' ...
                '> "%s/stdout_%02d.log" 2>&1 &'], ...
                paramFile, tmpDir, k);
        else
            cmd = sprintf(['nohup matlab -batch ' ...
                '"AtlasBased_worker(''%s'')" ' ...
                '> "%s/stdout_%02d.log" 2>&1 &'], ...
                paramFile, tmpDir, k);
        end
    end

    fprintf('Launching worker %02d (%d subjects)\n', k, numel(idx));
    system(cmd);

    % Stagger launches to avoid hammering the license server.
    pause(3);
end

% --- Drop a README so users know what these files mean ----------------
fid = fopen(fullfile(tmpDir, 'README.txt'), 'w');
fprintf(fid, 'SNBPI background run @ %s\n', datestr(now));
fprintf(fid, 'Subjects = %d, Processes = %d\n', n, nProc);
fprintf(fid, 'When all part_*.done files exist, the run is finished.\n');
fprintf(fid, 'Failures are listed as [FAIL] lines in part_*_log.txt.\n');
fclose(fid);

fprintf('\nAll workers launched. Workspace:\n  %s\n', tmpDir);
end