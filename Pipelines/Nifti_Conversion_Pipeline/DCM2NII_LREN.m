function isDone = DCM2NII_LREN(SubjectFolder,SubjID,OutputFolder,NiFti_Server_OutputFolder,ProtocolsFile,dcm2niiProgram)

% This function convert the dicom files to Nifti format using
% the SPM tools and dcm2nii tool developed by Chris Rorden
% Webpage: http://www.mccauslandcenter.sc.edu/mricro/mricron/dcm2nii.html
%
%% Input Parameters
%    SubjectFolder : Folder with dicom data beloging to all subjects.
%    SubjID : Subject identifier.
%    OutputFolder: Folder where the converted data will be saved locally.
%    NiFti_Server_OutputFolder: Output Folder where subject's Nifti data will be saved in the server.
%    ProtocolsFile : File with MRI protocol definitions.
%
%% Output Parameters:
%  Subj_OutputFolder: Subject Output Folder where Nifti data will be saved locally.
%   isDone : isDone >= 1 : Subject finished without errors and n files where processed.
%            isDone = 0 : Subject finished without errors but no processing was performed.
%            isDone = -1 : Subject finished with errors.
%
%% Lester Melie-Garcia
% LREN, CHUV.
% Lausanne, May 21st, 2014

try
    if  ~exist(OutputFolder,'dir')
        mkdir(OutputFolder);
    end;
    if ~strcmp(OutputFolder(end),filesep)
        OutputFolder = [OutputFolder,filesep];
    end;
    if ~ isempty(NiFti_Server_OutputFolder)
      if ~strcmp(NiFti_Server_OutputFolder(end),filesep)
          NiFti_Server_OutputFolder = [NiFti_Server_OutputFolder,filesep];
      end;
    end;
    if ~strcmp(SubjectFolder(end),filesep)
        SubjectFolder = [SubjectFolder,filesep];
    end;

    spm_jobman('initcfg');

    SubjectFolder = [SubjectFolder,SubjID,filesep];
    TempCovFolder = 'Nifti_temp';
    SessionFolders = getListofFolders(SubjectFolder);
    Ns = length(SessionFolders);  % Number of sessions ...
    Subj_OutputFolder = [OutputFolder,SubjID,filesep];
    mkdir(Subj_OutputFolder);
    matlabbatch{1}.spm.util.import.dicom.root = 'flat'; %'series'; %'patid';
    matlabbatch{1}.spm.util.import.dicom.protfilter = '.*';
    matlabbatch{1}.spm.util.import.dicom.convopts.format = 'nii';
    matlabbatch{1}.spm.util.import.dicom.convopts.icedims = 0;
    diffusion_protocol = cellstr(get_protocol_names(ProtocolsFile,'__Dicom2Nifti__','[diffusion]')); % protocol name ..
    MT_protocol = cellstr(get_protocol_names(ProtocolsFile,'__Dicom2Nifti__','[MT]'));
    PD_protocol = cellstr(get_protocol_names(ProtocolsFile,'__Dicom2Nifti__','[PD]'));
    T1_protocol = cellstr(get_protocol_names(ProtocolsFile,'__Dicom2Nifti__','[T1]'));
    fMRI_dropout_protocol = cellstr(get_protocol_names(ProtocolsFile,'__Dicom2Nifti__','[fMRI_dropout]'));
    nb_processed_files = 0;
    for j=1:Ns
        Session = SessionFolders{j};
        if ~isempty(str2num(Session))  %#ok  % Just fixing the name padding a zero as prefix
            if str2num(Session)<10  %#ok
                Sessionstr = ['0',Session];
            else
                Sessionstr = Session;
            end;
        else
            if j<10
                Sessionstr = ['0',num2str(j)];
            else
                Sessionstr = num2str(j);
            end;
        end;
        OutputSessionFolder = [Subj_OutputFolder,Sessionstr,filesep];
        TempOutput = [Subj_OutputFolder,Sessionstr,filesep,TempCovFolder,filesep];
        if ~exist(TempOutput,'dir')
            mkdir(TempOutput);
        end;
        TempOutputSessionFolder = [TempOutput,TempCovFolder,filesep];
        matlabbatch{1}.spm.util.import.dicom.outdir = {TempOutputSessionFolder};
        DataFolder = [SubjectFolder,Session,filesep];
        FolderNames = getListofFolders(DataFolder);
        if ~isempty(FolderNames)
            for i=1:length(FolderNames)
                which_prot = which_protocol(FolderNames{i},diffusion_protocol,MT_protocol,PD_protocol,T1_protocol,fMRI_dropout_protocol);
                RepetFolders = getListofFolders([DataFolder,FolderNames{i}]);
                if length(RepetFolders)<1
                    RepetFolders = {'01'};
                    RepFlag = false;
                else
                    RepFlag = true;
                end;
                for k=1:length(RepetFolders)
                    if ~exist(TempOutputSessionFolder,'dir')
                        mkdir(TempOutputSessionFolder);
                    end;
                    if RepFlag
                        InSubDir = [DataFolder,FolderNames{i},filesep,RepetFolders{k},filesep];
                    else
                        InSubDir = [DataFolder,FolderNames{i},filesep];
                    end;
                    switch which_prot
                        case {'MT','PD','T1'}
                            dicom_files = spm_select('FPListRec',InSubDir,'.*');
                            filehdr = spm_dicom_headers(dicom_files(1,:));
                            matlabbatch{1}.spm.util.import.dicom.data = cellstr(dicom_files);  % Input Folder to be converted.
                            spm_jobman('run',matlabbatch);
                            nb_processed_files = nb_processed_files + 1;
                            OrgOutputFolder = Reorg_Nifti(FolderNames{i},OutputSessionFolder,TempOutputSessionFolder,RepetFolders{k});
                        case 'other'
                            other2nii(InSubDir,Subj_OutputFolder,FolderNames{i},Sessionstr,SubjID,RepetFolders{k},dcm2niiProgram);
                            nb_processed_files = nb_processed_files + 1;
                        case 'diff'
                            DWI2nii(InSubDir,Subj_OutputFolder,FolderNames{i},Sessionstr,SubjID,RepetFolders{k},dcm2niiProgram);
                            nb_processed_files = nb_processed_files + 1;
                        case 'fMRI_dropout'
                            dicom_files = spm_select('FPListRec',InSubDir,'.*');
                            matlabbatch{1}.spm.util.import.dicom.data = cellstr(dicom_files); % Input Folder to be converted.
                            spm_jobman('run',matlabbatch);
                            nb_processed_files = nb_processed_files + 1;
                            Reorg_Nifti(FolderNames{i},OutputSessionFolder,TempOutputSessionFolder,RepetFolders{k});
                    end;
                end;
                if strcmpi(which_prot,'fMRI_dropout')
                    EchoCombining(OutputSessionFolder,FolderNames{i}); % This is specific for fMRI dropout sequences that need Echoes combination ...
                end;
            end;
        end;
        rmdir(TempOutput,'s');
    end;

    if ~ isempty(NiFti_Server_OutputFolder)
      mkdir(NiFti_Server_OutputFolder,SubjID);
      copyfile(Subj_OutputFolder,[NiFti_Server_OutputFolder,SubjID]);
    end;

    isDone = nb_processed_files;
catch ME  %#ok
    warning(ME.message);
    for printStack = 1:length(ME.stack)
        disp(ME.stack(printStack).file);
        disp(ME.stack(printStack).line);
    end
    %    rethrow(ME)
    isDone = -1;
end;
end

%%  =====      Internal Functions =====  %%
%%  EchoCombining(DataFolder,fMRI_SequenceName)
function EchoCombining(DataFolder,fMRI_SequenceName)

if ~strcmp(DataFolder(end),filesep)
    DataFolder = [DataFolder,filesep];
end;
InputFolder = [DataFolder,fMRI_SequenceName,filesep];

RepetFolders = getListofFolders(InputFolder,'yes'); % Getting the list of Folders organized ...
Nf = floor(length(RepetFolders)/3);

for i=1:Nf
    Echo1_List = spm_vol(spm_select('FPListRec',[InputFolder,RepetFolders{3*(i-1)+1}],'.*'));
    Echo2_List = spm_vol(spm_select('FPListRec',[InputFolder,RepetFolders{3*(i-1)+2}],'.*'));
    Echo3_List = spm_vol(spm_select('FPListRec',[InputFolder,RepetFolders{3*(i-1)+3}],'.*'));
    OutputFolder = [DataFolder,fMRI_SequenceName,'_Echocombined',filesep,RepetFolders{3*(i-1)+1},filesep];
    if ~exist(OutputFolder,'dir')
        mkdir(OutputFolder);
    end;
    NEchoes = min([length(Echo1_List),length(Echo2_List),length(Echo3_List)]);
    for k=1:NEchoes
        SaveStruct = Echo1_List(k);
        SaveStruct.fname = [OutputFolder,'comb',spm_str_manip(SaveStruct.fname,'t')];
        spm_write_vol(SaveStruct,squeeze(spm_read_vols(Echo1_List(k))+spm_read_vols(Echo2_List(k))+spm_read_vols(Echo3_List(k))));
    end;
end;

end

%% Reorg_Nifti(FolderName,Subj_OutputFolder,SubjID)
function OrgOutputFolder = Reorg_Nifti(FolderName,OutputSessionFolder,TempOutputSessionFolder,RepetFolder)

if ~strcmp(OutputSessionFolder(end),filesep)
    OutputSessionFolder = [OutputSessionFolder,filesep];
end;
if ~strcmp(TempOutputSessionFolder(end),filesep)
    TempOutputSessionFolder = [TempOutputSessionFolder,filesep];
end;
OrgOutputFolder = [OutputSessionFolder,FolderName];
if ~exist(OrgOutputFolder,'dir')
    mkdir(OrgOutputFolder);
end;

if ~isempty(str2num(RepetFolder))  %#ok  % Just fixing the name padding a zero as prefix
    if str2num(RepetFolder)<10  %#ok
        RepetFolder = ['0',RepetFolder];
    end;
end;

movefile(TempOutputSessionFolder,[OrgOutputFolder,filesep,RepetFolder]);
OrgOutputFolder = [OrgOutputFolder,filesep,RepetFolder];

end
%% DWI2nii(InSubDir,Subj_OutputFolder)
function DWI2nii(InSubDir,Subj_OutputFolder,diff_Folder,Sessionstr,SubjID,RepetFolder,dcm2niiProgram)

if ~strcmp(InSubDir(end),filesep)
    InSubDir = [InSubDir,filesep];
end;
if ~strcmp(Subj_OutputFolder(end),filesep)
    Subj_OutputFolder = [Subj_OutputFolder,filesep];
end;

OutputFolder = [Subj_OutputFolder,Sessionstr,filesep,diff_Folder,filesep,RepetFolder,filesep];
if ~exist(OutputFolder,'dir')
    mkdir(OutputFolder);
end;
job_dcm2nii_LREN(InSubDir,OutputFolder,'DTI',dcm2niiProgram);
bvecsFile = pickfiles(OutputFolder,'.bvec');  % gradient directions info
bvalsFile = pickfiles(OutputFolder,'.bval'); % b-values
dataFile  = pickfiles(OutputFolder,'.nii');
if (~isempty(bvecsFile))&&(~isempty(bvalsFile))&&(~isempty(bvecsFile))
    movefile(bvecsFile,[OutputFolder,filesep,SubjID,'.bvecs']);
    movefile(bvalsFile,[OutputFolder,filesep,SubjID,'.bvals']);
    movefile(dataFile,[OutputFolder,filesep,SubjID,'_data.nii']);
end;

end

function other2nii(InSubDir,Subj_OutputFolder,d_Folder,Sessionstr,SubjID,RepetFolder,dcm2niiProgram)

if ~strcmp(InSubDir(end),filesep)
    InSubDir = [InSubDir,filesep];
end;
if ~strcmp(Subj_OutputFolder(end),filesep)
    Subj_OutputFolder = [Subj_OutputFolder,filesep];
end;

OutputFolder = [Subj_OutputFolder,Sessionstr,filesep,d_Folder,filesep,RepetFolder,filesep];
if ~exist(OutputFolder,'dir')
    mkdir(OutputFolder);
end;
job_dcm2nii_LREN(InSubDir,OutputFolder,'T1',dcm2niiProgram);
dataFiles  = pickfiles(OutputFolder,'.nii');

for df = 1:size(dataFiles)
    [FilePath,FileName,FileExt]=fileparts(deblank(dataFiles(df,:)));
    movefile(deblank(dataFiles(df,:)),[FilePath,filesep,'s',SubjID,'_',FileName,FileExt]);
end
end

%% function which_prot = which_protocol(FolderName,diffusion_protocol,MT_protocol,PD_protocol,T1_protocol)
function which_prot = which_protocol(FolderName,diffusion_protocol,MT_protocol,PD_protocol,T1_protocol,fMRI_dropout_protocol)

if ismember(FolderName,diffusion_protocol)
    which_prot = 'diff';
elseif ismember(FolderName,MT_protocol)
    which_prot = 'MT';
elseif ismember(FolderName,PD_protocol)
    which_prot = 'PD';
elseif ismember(FolderName,T1_protocol)
    which_prot = 'T1';
elseif ismember(FolderName,fMRI_dropout_protocol)
    which_prot = 'fMRI_dropout';
else
    which_prot = 'other';
end;

end
