function Sdb = cp_init(Sdir)
% Initialized data paths required for data processing
% according to the specific directories structure (see the database_part
% directory for illustration)
% Sdb will handle the list of subjects directories for processing - including
% paths to the anatomical/atlas files that are searched inside
% db_ft/PROJ/SUBJ/mri ; surf ; tex and vol subdirectories
% 
% Prepare Mtrans_ref transformation matrix according to referencial.txt file
% for atlas surf and vol realignment
%
%-CREx180530

% Check for required files in databases
Sdp = struct('iproc', [], 'group', []);
Sdir = check_opt(Sdir, Sdp);



% Define all datapaths from ft database
dp_meg = meg_datapaths(Sdir);

% Check for transform files + anat files + meg path

Ns = length(dp_meg);
for i = 1 : Ns
    dps = dp_meg(i);
    dps.trans = prep_trans(dps, Sdir);
    % Add mri, surf, vol and tex files paths
    % File expected with extension gii or nii or gz
    dps = add_anat(dps);
    dps.meg = [dps.dir, filesep, 'meg'];
    
    if i==1
        Sdb = dps;
    else
        Sdb(i) = dps;
    end
end


function dps = add_anat(dps)

dps.surf = find_files([dps.dir, filesep, 'surf']);
dps.tex = find_files([dps.dir, filesep, 'tex']);
dps.vol = find_files([dps.dir, filesep, 'vol']);
pmri = find_files([dps.dir, filesep, 'mri']);
dps.mri = pmri{1};

% Prepare transform mat for the forward model
function ptr = prep_trans(dps, Sdir)

ptrans = make_dir([dps.dir, filesep, 'trans']);
dtrm = dir([ptrans, filesep, '*.trm']);
% Expected transform mat
ptr = [ptrans, filesep, 'Mtrans_ref.mat'];
dmat = dir(ptr);
if isempty(dmat)
    pref = fullfile(Sdir.db_ft, dps.proj, 'referential', 'referential.txt');
    if isempty(dtrm)
        % trm files are expected in standard BV and FS databases according to
        % referential.txt file // IF TRM files are always the same from BV/FS pipeline, 
        % we should integrate the referential file inside ft_crex toolbox
        Mtrans_ref = read_trans_each(pref, dps.subj, Sdir.db_bv, Sdir.db_fs);
        if ~isempty(Mtrans_ref)
            save(ptr, 'Mtrans_ref');
        else
            ptr = [];
        end
    else
        % TO DO !! trm in trans directory
        
    end
end
        
        

% Find all directories for MEG data processing
function dp = meg_datapaths(Sdir)

% Main database directory
db_dir = Sdir.db_ft;


% Add group level directory if Sdir.group is not empty
if ~isempty(Sdir.group)
    cpmeg = {db_dir, 0
        Sdir.proj, 0
        Sdir.group, 0
        Sdir.subj, 1};
    igrp = 3;
    isubj = 4;
else
    cpmeg = {db_dir, 0
        Sdir.proj, 0
        Sdir.subj, 1};
    isubj = 3;
    igrp = [];    
end
iproj = 2;

[alldp, subj, grp, prj] = define_datapaths(cpmeg, isubj, igrp, iproj);

dp = cell2struct([alldp'; subj'; grp'; prj'], {'dir', 'subj', 'group', 'proj'});

iproc = Sdir.iproc;
if ~isempty(iproc)
    if max(iproc) <= length(alldp)
        dp = dp(iproc);
    end
end
