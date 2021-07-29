function smoothImg(imageNamei)
% smoothing image using SPM batch code
matlabbatch{1}.spm.spatial.smooth.data = '<UNDEFINED>';
matlabbatch{1}.spm.spatial.smooth.fwhm = [3 3 3];
matlabbatch{1}.spm.spatial.smooth.dtype = 0;
matlabbatch{1}.spm.spatial.smooth.im = 0;
matlabbatch{1}.spm.spatial.smooth.prefix = 's';
jobs = matlabbatch;
inputs = cell(1,1);
inputs{1, 1} = {imageNamei}; % Smooth: Images to smooth - cfg_files
spm('defaults', 'FMRI');
spm_jobman('run', jobs, inputs{:});
end
