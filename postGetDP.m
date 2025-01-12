function [vol_all,ef_mag,ef_all] = postGetDP(P1,P2,numOfTissue,node,cond,hdrInfo,uniTag,indSolved,indInCore)
% [vol_all,ef_mag,ef_all] = postGetDP(P1,P2,node,hdrInfo,uniTag,indSolved,indInCore)
%
% Post processing after solving the model / generating the lead field.
% Save the result in Matlab format in the MRI voxel space. For the lead
% field, it's saved in Matlab format for roast_target() to work.
%
% (c) Yu (Andy) Huang, Parra Lab at CCNY
% yhuang16@citymail.cuny.edu
% October 2017
% August 2019 adding lead field
% UPDATED BY AA 08/12/21 for >6 tissues

[dirname,baseFilename] = fileparts(P1);
if isempty(dirname), dirname = pwd; end

% node = node + 0.5; already done right after mesh

if ~isempty(P2) % for roast()
    
    % convert pseudo-world coordinates back to voxel coordinates for
    % interpolation into regular grid in the voxel space
    for i=1:3, node(:,i) = node(:,i)/hdrInfo.pixdim(i); end

    [~,baseFilenameRasRSPD] = fileparts(P2);
    
    [xi,yi,zi] = ndgrid(1:hdrInfo.dim(1),1:hdrInfo.dim(2),1:hdrInfo.dim(3));
    
    disp('converting the results into Matlab format...');
    fid = fopen([dirname filesep baseFilename '_' uniTag '_v.pos']);
    fgetl(fid);
    C = textscan(fid,'%d %f');
    fclose(fid);
    
    C{2} = C{2} - min(C{2}); % re-reference the voltage
    
    F = TriScatteredInterp(node(C{1},1:3), C{2});
    vol_all = F(xi,yi,zi);
    
    fid = fopen([dirname filesep baseFilename '_' uniTag '_e.pos']);
    fgetl(fid);
    C = textscan(fid,'%d %f %f %f');
    fclose(fid);
    
    ef_all = zeros([hdrInfo.dim 3]);
    F = TriScatteredInterp(node(C{1},1:3), C{2});
    ef_all(:,:,:,1) = F(xi,yi,zi);
    F = TriScatteredInterp(node(C{1},1:3), C{3});
    ef_all(:,:,:,2) = F(xi,yi,zi);
    F = TriScatteredInterp(node(C{1},1:3), C{4});
    ef_all(:,:,:,3) = F(xi,yi,zi);
    
    ef_mag = sqrt(sum(ef_all.^2,4));
    
    disp('saving the final results...')
    save([dirname filesep baseFilename '_' uniTag '_roastResult.mat'],'vol_all','ef_all','ef_mag','-v7.3');
    
    if isempty(strfind(P2,'example/nyhead'))
        template = load_untouch_nii(P2);
    else
        template = load_untouch_nii([dirname filesep baseFilenameRasRSPD '_T1orT2_masks.nii']);
    end % Load the original MRI to save the results as NIFTI format
    
    template.hdr.dime.datatype = 16;
    template.hdr.dime.bitpix = 32;
    template.hdr.dime.scl_slope = 1; % so that display of NIFTI will not alter the data
    template.hdr.dime.cal_max = 0;
    template.hdr.dime.cal_min = 0;
    
    template.img = single(vol_all);
    template.hdr.dime.glmax = max(vol_all(:));
    template.hdr.dime.glmin = min(vol_all(:));
    template.hdr.hist.descrip = 'voltage';
    template.fileprefix = [dirname filesep baseFilename '_' uniTag '_v'];
    save_untouch_nii(template,[dirname filesep baseFilename '_' uniTag '_v.nii']);
    
    template.img = single(ef_mag);
    template.hdr.dime.glmax = max(ef_mag(:));
    template.hdr.dime.glmin = min(ef_mag(:));
    template.hdr.hist.descrip = 'EF mag';
    template.fileprefix = [dirname filesep baseFilename '_' uniTag '_emag'];
    save_untouch_nii(template,[dirname filesep baseFilename '_' uniTag '_emag.nii']);
    
    % McCann et al 2019
%     gm_id = 2; gm_con = 0.276;
%     wm_id = 1; wm_con = 0.126;
%     csf_id = 3; csf_con = 1.65;
%     bone_id = 4; bone_con = 0.01;
%     skin_id = 5; skin_con = 0.465;
%     air_id = 6; air_con = 2.5e-14; % NOT ZERO!!
    
    am = load_untouch_nii(fullfile(dirname,[baseFilenameRasRSPD '_T1orT2_masks.nii']));
    allMask_d = double(am.img);
    
    % Create Conductivity Masks
    allCond=zeros(size(ef_mag,1),size(ef_mag,2),size(ef_mag,3));
    maskName = fieldnames(cond); maskName = maskName(1:end-2);
%     numOfTissue = length(maskName);
    for t = 1:numOfTissue
        allCond(allMask_d==t) = cond.(maskName{t});
    end
%     allCond(allMask_d(:,:,:)==wm_id) = wm_con;
%     allCond(allMask_d(:,:,:)==csf_id) = csf_con;
%     allCond(allMask_d(:,:,:)==bone_id) = bone_con;
%     allCond(allMask_d(:,:,:)==skin_id) = skin_con;
%     allCond(allMask_d(:,:,:)==air_id) = air_con;
    
    save([dirname filesep baseFilename '_allCond.mat'],'allCond');
    
    disp('Computing Jroast/Jbrain ...'); %added AI 1/19/18
    if ~isa(allCond, 'double')
        allCond=double(allCond);
    end
    
    Jroast = allCond.*ef_mag;
    
    % make J nii
    Jroast(isnan(Jroast))=0;
    Jbrain = zeros(size(Jroast,1),size(Jroast,2),size(Jroast,3));
    Jbrain(allMask_d == 1 | allMask_d == 2) = Jroast(allMask_d == 1 | allMask_d == 2);
    % save Jroast.mat Jroast
    % save_nii(J_nii_mod,'Jmap_mod.nii')
    save([dirname filesep baseFilename '_' uniTag '_Jbrain.mat'],'Jbrain');
    save([dirname filesep baseFilename '_' uniTag '_Jroast.mat'],'Jroast'); %baseFilename is T1 (nii file name without .nii)
    
    template.img = single(Jroast);
    template.hdr.dime.glmax = max(Jroast(:));
    template.hdr.dime.glmin = min(Jroast(:));
    template.hdr.hist.descrip = 'Jroast';
    template.fileprefix = [dirname filesep baseFilename '_' uniTag '_Jroast'];
    save_untouch_nii(template,[dirname filesep baseFilename '_' uniTag '_Jroast.nii']);
    
    template.img = single(Jbrain);
    template.hdr.dime.glmax = max(Jbrain(:));
    template.hdr.dime.glmin = min(Jbrain(:));
    template.hdr.hist.descrip = 'Jbrain';
    template.fileprefix = [dirname filesep baseFilename '_' uniTag '_Jbrain'];
    save_untouch_nii(template,[dirname filesep baseFilename '_' uniTag '_Jbrain.nii']);

    template.img = single(allCond);
    template.hdr.dime.glmax = max(allCond(:));
    template.hdr.dime.glmin = min(allCond(:));
    template.hdr.hist.descrip = 'Conductivity';
    template.fileprefix = [dirname filesep baseFilename '_' uniTag '_Cond'];
    save_untouch_nii(template,[dirname filesep baseFilename '_' uniTag '_Cond.nii']);
    
    template.hdr.dime.dim(1) = 4;
    template.hdr.dime.dim(5) = 3;
    template.img = single(ef_all);
    template.hdr.dime.glmax = max(ef_all(:));
    template.hdr.dime.glmin = min(ef_all(:));
    template.hdr.hist.descrip = 'EF';
    template.fileprefix = [dirname filesep baseFilename '_' uniTag '_e'];
    save_untouch_nii(template,[dirname filesep baseFilename '_' uniTag '_e.nii']);
    
    save([dirname filesep baseFilename '_EV.mat'],'vol_all','ef_all','ef_mag');    
    
    disp('======================================================');
    disp('Results are saved as:');
    disp([dirname filesep baseFilename '_' uniTag '_result.mat']);
    disp('...and also saved as NIFTI files:');
    disp(['Voltage: ' dirname filesep baseFilename '_' uniTag '_v.nii']);
    disp(['E-field: ' dirname filesep baseFilename '_' uniTag '_e.nii']);
    disp(['Current Density: ' dirname filesep baseFilename '_' uniTag '_Jroast.nii']);
    disp(['Masked Current Density: ' dirname filesep baseFilename '_' uniTag '_Jbrain.nii']);
    disp(['E-field magnitude: ' dirname filesep baseFilename '_' uniTag '_emag.nii']);
    disp('======================================================');
    disp('You can also find all the results in the following two text files: ');
    disp(['Voltage: ' dirname filesep baseFilename '_' uniTag '_v.pos']);
    disp(['E-field: ' dirname filesep baseFilename '_' uniTag '_e.pos']);
    disp('======================================================');
    disp('Look up the detailed info for this simulation in the log file: ');
    disp([dirname filesep baseFilename '_log']);
    disp(['under the simulation tag "' uniTag '".']);
    disp('======================================================');  
else % for roast_target()
    
    %     indBrain = elem((elem(:,5)==1 | elem(:,5)==2),1:4);
%     indBrain = unique(indBrain(:));
%     
%     Atemp = nan(size(node,1),3);
%     A = nan(length(indBrain),3,length(indSolved));

    A_all = nan(size(node,1),3,length(indSolved));
    
    disp('assembling the lead field...');
    for i=1:length(indSolved)
        
        disp(['packing electrode ' num2str(i) ' out of ' num2str(length(indSolved)) ' ...']);
        fid = fopen([dirname filesep baseFilename '_' uniTag '_e' num2str(indSolved(i)) '.pos']);
        fgetl(fid);
        C = textscan(fid,'%d %f %f %f');
        fclose(fid);
        
%         Atemp(C{1},:) = cell2mat(C(2:4));
%         
%         A(:,:,i) = Atemp(indBrain,:);
        
        A_all(C{1},:,i) = cell2mat(C(2:4));
        
        % to save disk space
%         delete([dirname filesep baseFilename '_' uniTag '_e' num2str(indSolved(i)) '.pos']);
    end
    
%     indAdata = find(~isnan(sum(sum(A,3),2))); % make sure no NaN is in matrix A
%     A = A(indAdata,:,:);
%     
%     A = reshape(A,length(indBrain)*3,length(indSolved)); % this is bug
%     
%     locs = node(indBrain,1:3);
%     locs = locs(indAdata,:); % ...also applies to mesh coordinates
    
    % re-ordering to match the electrode order in .loc file
%     A = A(:,indInCore);
    A_all = A_all(:,:,indInCore);
    
    disp('saving the final results...')
%     save([dirname filesep baseFilename '_' uniTag '_roastResult.mat'],'A','locs','-v7.3');
    save([dirname filesep baseFilename '_' uniTag '_roastResult.mat'],'A_all','-v7.3');
    
    disp('======================================================');
    disp('The lead field matrix is saved as:');
    disp([dirname filesep baseFilename '_' uniTag '_roastResult.mat']);
    disp('======================================================');
    % disp('You can also find all the results in the following two text files: ');
    % disp(['Voltage: ' dirname filesep baseFilename '_' uniTag '_v.pos']);
    % disp(['E-field: ' dirname filesep baseFilename '_' uniTag '_e.pos']);
    disp('======================================================');
    disp('Look up the detailed info for this simulation in the log file: ');
    disp([dirname filesep baseFilename '_roastLog']);
    disp(['under the simulation tag "' uniTag '".']);
    disp('======================================================');
    disp('======================================================');
    disp('Now you can do targeting by calling: ');
    disp('roast_target(subj,simTag,targetCoord,varargin)');
    disp('Please refer to the README and roast_target() documentation for details.');
    disp('======================================================');
    
end