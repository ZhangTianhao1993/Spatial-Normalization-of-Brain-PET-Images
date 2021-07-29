function TemplateBasedSpatialNormalizationMethod(Templatename,PETnames,...
    bbox,voxelsize,normprefix,d)
% This is a SPM batch for template based brain PET images spatial normalization.
% 
% Templatename: The file name for the template image.
% PETnames: The files names for PET images.
% bbox: Bounding box for normalized image.
% voxelsize: Voxel size for normalized image.
% normprefix: The prefix for normalized PET image.
% d: For recording progress bar
%
% Author: Zhang Tianhao 2017/7/29
% =========================================================================

n = length(PETnames);
%nrun = X; % enter the number of runs here
for i=1:n
    matlabbatch{1}.spm.tools.oldnorm.estwrite.subj.source = '<UNDEFINED>';
    matlabbatch{1}.spm.tools.oldnorm.estwrite.subj.wtsrc = '';
    matlabbatch{1}.spm.tools.oldnorm.estwrite.subj.resample = '<UNDEFINED>';
    matlabbatch{1}.spm.tools.oldnorm.estwrite.eoptions.template = '<UNDEFINED>';
    matlabbatch{1}.spm.tools.oldnorm.estwrite.eoptions.weight = '';
    matlabbatch{1}.spm.tools.oldnorm.estwrite.eoptions.smosrc = 8;
    matlabbatch{1}.spm.tools.oldnorm.estwrite.eoptions.smoref = 0;
    matlabbatch{1}.spm.tools.oldnorm.estwrite.eoptions.regtype = 'mni';
    matlabbatch{1}.spm.tools.oldnorm.estwrite.eoptions.cutoff = 25;
    matlabbatch{1}.spm.tools.oldnorm.estwrite.eoptions.nits = 16;
    matlabbatch{1}.spm.tools.oldnorm.estwrite.eoptions.reg = 1;
    matlabbatch{1}.spm.tools.oldnorm.estwrite.roptions.preserve = 0;
    matlabbatch{1}.spm.tools.oldnorm.estwrite.roptions.bb = bbox;
    matlabbatch{1}.spm.tools.oldnorm.estwrite.roptions.vox = voxelsize;
    matlabbatch{1}.spm.tools.oldnorm.estwrite.roptions.interp = 4;
    matlabbatch{1}.spm.tools.oldnorm.estwrite.roptions.wrap = [0 0 0];
    matlabbatch{1}.spm.tools.oldnorm.estwrite.roptions.prefix = normprefix;
    jobs = matlabbatch;
    inputs = cell(3, 1);
    inputs{1, 1} = PETnames(i); % Old Normalise: Estimate & Write: Source Image - cfg_files
    inputs{2, 1} = PETnames(i); % Old Normalise: Estimate & Write: Images to Write - cfg_files
    inputs{3, 1} = Templatename; % Old Normalise: Estimate & Write: Template Image - cfg_files
    spm('defaults', 'FMRI');
    spm_jobman('run', jobs, inputs{:});
    d.Value = i/n;
end
end
