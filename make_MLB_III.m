function matlabbatch = make_MLB_III(dirname,estFile,writeFile)
matlabbatch{1}.spm.spatial.normalise.estwrite.subj.vol = {fullfile(dirname,estFile)};
matlabbatch{1}.spm.spatial.normalise.estwrite.subj.resample = {fullfile(dirname,[writeFile ',1'])
    fullfile(dirname,[writeFile ',2'])
    fullfile(dirname,[writeFile ',3'])};
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.biasreg = 0.0001;
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.biasfwhm = 60;
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.tpm = {'/blue/camctrp/working/aprinda/freesurfer_output/tpm.nii'};
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.affreg = 'mni';
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.reg = [0 0.001 0.5 0.05 0.2];
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.fwhm = 0;
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.samp = 3;
matlabbatch{1}.spm.spatial.normalise.estwrite.woptions.bb = [-90.5 -108.5 -90.5; 89.5 107.5 89.5];
matlabbatch{1}.spm.spatial.normalise.estwrite.woptions.vox = [1 1 1];
matlabbatch{1}.spm.spatial.normalise.estwrite.woptions.interp = 4;
matlabbatch{1}.spm.spatial.normalise.estwrite.woptions.prefix = 'wuf';