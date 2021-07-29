function MRIBasedSpatialNormalizationMethod(MRInames,PETnames,bbox,...
    voxelsize,coregprefix,normprefix,d)
% This is a SPM batch for MRI based brain PET images spatial normalization.
%
% MRInames: The files names for MRI images.
% PETnames: The files names for PET images.
% bbox: Bounding box for normalized image.
% voxelsize: Voxel size for normalized image.
% coregprefix: The prefix for co-registered PET image.
% normprefix: The prefix for normalized PET image.
% d: For recording progress bar
%
% Author: Zhang Tianhao 2021/7/29
% =========================================================================

n = length(MRInames);
str = which('SNBPI');
[filepath,name,ext] = fileparts(str);
for i=1:n
%nrun = X; % enter the number of runs here
    matlabbatch{1}.spm.spatial.coreg.estwrite.ref = '<UNDEFINED>';
    matlabbatch{1}.spm.spatial.coreg.estwrite.source = '<UNDEFINED>';
    matlabbatch{1}.spm.spatial.coreg.estwrite.other = {''};
    matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
    matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.sep = [4 2];
    matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
    matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.fwhm = [7 7];
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.interp = 4;
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.mask = 0;
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.prefix = coregprefix;
    matlabbatch{2}.spm.spatial.preproc.channel.vols = '<UNDEFINED>';
    matlabbatch{2}.spm.spatial.preproc.channel.biasreg = 0.001;
    matlabbatch{2}.spm.spatial.preproc.channel.biasfwhm = 60;
    matlabbatch{2}.spm.spatial.preproc.channel.write = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(1).tpm = {[filepath,'\TPM\TPM_Gray.nii']};
    matlabbatch{2}.spm.spatial.preproc.tissue(1).ngaus = 1;
    matlabbatch{2}.spm.spatial.preproc.tissue(1).native = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(1).warped = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(2).tpm = {[filepath,'\TPM\TPM_White.nii']};
    matlabbatch{2}.spm.spatial.preproc.tissue(2).ngaus = 1;
    matlabbatch{2}.spm.spatial.preproc.tissue(2).native = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(2).warped = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(3).tpm = {[filepath,'\TPM\TPM_CSF.nii']};
    matlabbatch{2}.spm.spatial.preproc.tissue(3).ngaus = 2;
    matlabbatch{2}.spm.spatial.preproc.tissue(3).native = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(3).warped = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(4).tpm = {[filepath,'\TPM\TPM_Bone.nii']};
    matlabbatch{2}.spm.spatial.preproc.tissue(4).ngaus = 3;
    matlabbatch{2}.spm.spatial.preproc.tissue(4).native = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(4).warped = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(5).tpm = {[filepath,'\TPM\TPM_Skin.nii']};
    matlabbatch{2}.spm.spatial.preproc.tissue(5).ngaus = 4;
    matlabbatch{2}.spm.spatial.preproc.tissue(5).native = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(5).warped = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(6).tpm = {[filepath,'\TPM\TPM_Background.nii']};
    matlabbatch{2}.spm.spatial.preproc.tissue(6).ngaus = 2;
    matlabbatch{2}.spm.spatial.preproc.tissue(6).native = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(6).warped = [0 0];
    matlabbatch{2}.spm.spatial.preproc.warp.mrf = 1;
    matlabbatch{2}.spm.spatial.preproc.warp.cleanup = 1;
    matlabbatch{2}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
    matlabbatch{2}.spm.spatial.preproc.warp.affreg = 'mni';
    matlabbatch{2}.spm.spatial.preproc.warp.fwhm = 0;
    matlabbatch{2}.spm.spatial.preproc.warp.samp = 3;
    matlabbatch{2}.spm.spatial.preproc.warp.write = [0 1];
    matlabbatch{3}.spm.spatial.normalise.write.subj.def(1) = cfg_dep('Segment: Forward Deformations', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','fordef', '()',{':'}));
    matlabbatch{3}.spm.spatial.normalise.write.subj.resample(1) = cfg_dep('Coregister: Estimate & Reslice: Resliced Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','rfiles'));
    matlabbatch{3}.spm.spatial.normalise.write.woptions.bb = bbox;
    matlabbatch{3}.spm.spatial.normalise.write.woptions.vox = voxelsize;
    matlabbatch{3}.spm.spatial.normalise.write.woptions.interp = 4;
    matlabbatch{3}.spm.spatial.normalise.write.woptions.prefix = normprefix;

    jobs = matlabbatch;
    inputs = cell(3, 1);
    inputs{1, 1} = MRInames(i); % Coregister: Estimate & Reslice: Reference Image - cfg_files
    inputs{2, 1} =PETnames(i); % Coregister: Estimate & Reslice: Source Image - cfg_files
    inputs{3, 1} = MRInames(i); % Segment: Volumes - cfg_files
    spm('defaults', 'FMRI');
    spm_jobman('run', jobs, inputs{:});
    d.Value = i/n;
end
end

