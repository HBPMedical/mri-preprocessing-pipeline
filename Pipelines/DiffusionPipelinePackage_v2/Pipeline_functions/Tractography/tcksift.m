function [Output_tck, mrtrixParams] = tcksift(Input_tck, Input_FOD, Output_tck, mrtrixParams)

% This will perform tractography filtering based on the previously 
% calculated Input_tck tractogram.
% IMPORTANT: mrtrix/bin *must* be in the global path
%
% Input_tck = Full path to the previously computed tck tractogram file
% Input_FOD = Full path to the previously computed FOD file
% Output_tck = Full path to output tractography (.tck) file
% mrtrixParams = Parameters to be used for processing
%
% NOTE: If inputs are left blank ('') then defaults will be used or the
%       user will be ask to select appropriate files.
%
% Additional options can be configured within the mrtrixParams structure
%
% (C) D Slater, LREN 6/2/2015

%% Check that input variables are correct

% Calculated FOD file
if ~exist(Input_FOD,'file') && (~mrtrixParams.commandsOnly == true || isempty(Input_FOD))
    [FileName,PathName] = uigetfile('.nii','Select the FOD data');
    Input_FOD=fullfile(PathName,FileName);
end
if exist(Input_FOD,'file')
    [pathstr,name,ext] = fileparts(Input_FOD);
else [pathstr,name,ext] = fileparts(mrtrixParams.DWIpath);
    CC = strsplit(name,'.');
    name = [CC{1} '_fod'];
end

% Input track file
if ~exist(Input_tck,'file') && (~mrtrixParams.commandsOnly == true || isempty(Input_tck))
    [FileName,PathName] = uigetfile('.nii','Select the tck data to be filtered');
    Input_tck=fullfile(PathName,FileName);
end

% Track output
if isempty(Output_tck)
    CC = strsplit(name,'.');
    Output_tck=fullfile(pathstr,[CC{1} '_SIFT.tck']);
end

% SIFT2 weights file
if mrtrixParams.doSIFT2
    SIFT2_weights = fullfile(pathstr,[CC{1} '_SIFT2.txt']);
else SIFT2_weights = [];
end
mrtrixParams.SIFT2_weights = SIFT2_weights;

% Check/Load settings
if isempty(mrtrixParams) || ~isfield(mrtrixParams,'lmax')
    mrtrixParams = default_mrtrixParams;
end


%% Build tcksift commands

if mrtrixParams.commandsOnly ==1 && mrtrixParams.doACT ==1
    ACT_option = ['-act ' mrtrixParams.Output5TT ' '];
elseif mrtrixParams.commandsOnly ==0 && exists(mrtrixParams.Output5TT,'file')
    ACT_option = ['-act ' mrtrixParams.Output5TT ' '];
else ACT_option = '';
end
Terminate_option = ['-term_number ' num2str(mrtrixParams.term_number) ' '];
if mrtrixParams.forceoverwrite==true
    force_option = '-force ';
else force_option = '';
end
if mrtrixParams.doSIFT
    sift2tracks = Output_tck;
else sift2tracks = Input_tck;
end
if mrtrixParams.doACT
    act_option = ['-act ' mrtrixParams.Output5TT];
else act_option = '';
end

cat_options = [ACT_option Terminate_option force_option];

tcksift_command = ['tcksift ' Input_tck ' ' Input_FOD ' ' Output_tck ' ' cat_options '; rm ' Input_tck];
if mrtrixParams.doSIFT2
tcksift2_command = ['tcksift2 ' sift2tracks ' ' Input_FOD ' ' SIFT2_weights ' ' act_option];
else tcksift2_command = [];
end
mrtrixParams.commands.tcksift = [tcksift_command '; ' tcksift2_command];


%% Run the tckgen_command outside of matlab

if mrtrixParams.commandsOnly==false;
    [status,cmdout] = unix(tcksift_command);
    if ~(status==0)
        disp('There was a problem executing the tcksift operating system command. The command did not complete successfully')
        disp(cmdout)
    end
end



