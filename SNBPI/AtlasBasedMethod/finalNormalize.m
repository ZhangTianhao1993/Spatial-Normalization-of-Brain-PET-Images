function finalNormalize(imageName,TPMnum,bbox,voxelsize,normprefix)
[filepath,imagename,ext] = fileparts(imageName);
cimageName = [filepath,'\c',imagename,ext];

matlabbatch{1}.spm.spatial.preproc.channel.vols = '<UNDEFINED>';
matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0.001;
matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = 60;
matlabbatch{1}.spm.spatial.preproc.channel.write = [0 0];
for i=1:TPMnum
    matlabbatch{1}.spm.spatial.preproc.tissue(i).tpm = '<UNDEFINED>';
    matlabbatch{1}.spm.spatial.preproc.tissue(i).ngaus = 1;
    matlabbatch{1}.spm.spatial.preproc.tissue(i).native = [0 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(i).warped = [0 0];
end
matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
matlabbatch{1}.spm.spatial.preproc.warp.write = [0 1];
matlabbatch{2}.spm.spatial.normalise.write.subj.def(1) = cfg_dep('Segment: Forward Deformations', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','fordef', '()',{':'}));
matlabbatch{2}.spm.spatial.normalise.write.subj.resample = '<UNDEFINED>';
matlabbatch{2}.spm.spatial.normalise.write.woptions.bb = bbox;
matlabbatch{2}.spm.spatial.normalise.write.woptions.vox = voxelsize;
matlabbatch{2}.spm.spatial.normalise.write.woptions.interp = 4;
matlabbatch{2}.spm.spatial.normalise.write.woptions.prefix = normprefix;
jobs = matlabbatch;
inputs = cell(TPMnum+2, 1);
inputs{1, 1} = {cimageName}; % Segment: Volumes - cfg_files
for i=1:TPMnum
    inputs{1+i, 1} = {[filepath,'\TPM',num2str(i),imagename,'.nii']}; % Segment: Tissue probability map - cfg_files
end
inputs{TPMnum+2, 1} = {imageName}; % Normalise: Write: Images to Write - cfg_files
spm('defaults', 'FMRI');
spm_jobman('run', jobs, inputs{:});
end