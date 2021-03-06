function Sdb = cp_meg_cleanup_trials(Sdb, opt)
% To identify bad trials, the filtered version of continuous
% data is used to extract trial, then resampled at 400 Hz
%
%-CREx180803
dopt = [];
dopt.type = 'hp';
dopt.fc = 0.5;   
dopt.res_fs = 400;
if ~isfield(opt, 'preproc') || isempty(opt.preproc)
    opt.preproc = dopt;
else
    opt.preproc = check_opt(opt.preproc, dopt);
end
opt_tr = opt.preproc;

Ns = length(Sdb);

% Initialize waitbar
wb = waitbar(0, 'Bad trials identification...', 'name', 'MEG preprocessing');
wb_custcol(wb, [0 0.6 0.8]);

% Epoching options
eopt = opt.epoched;
eopt.res_fs = opt_tr.res_fs;

isa_s = strcmp(opt.continuous.rm_sens_run, 'same');
isa_t = strcmp(eopt.rm_trials_cond, 'same');

fica =  opt.continuous.ica.reject;
for i = 1 : Ns
    dps = Sdb(i);
    dpmeg = dps.meg;
    
    Sprep = dpmeg.preproc;
    
    if ~any(Sprep.do.rmt)
        continue;
    end
    
    % Subject info
    sinfo = dps.sinfo;

    % Run directories
    rdir = dpmeg.run.dir;
    Nr = length(rdir);
    isbadc = zeros(Nr, 1);

    for j = 1 : Nr
        % If the initial data visualisation was already done
        if ~Sprep.do.rmt(j)
            continue;
        end
        srun = rdir{j};
		stit = [sinfo, '--', srun];
		        
        waitbar((i-1)/Ns + (j-1)/(Nr*Ns), wb, ['Bad trials: ',  stit]);
        
        Spar = Sprep.param_run{j};
        
        % If ICA components are to be rejected, the data version to
        % identify bad trials have to be processed identically to it has been 
        % before the ICA calculation
        ftData = prepare_data(Spar, opt_tr);

        % Get epochs for each contidions
        allTrials = extract_trials(ftData, Spar, eopt);
        
        % Select the bad trials by concatenating all the conditions to have a
        % whole view of the outliers
        allTa = struct2cell(allTrials);
        allTa = ft_appenddata([], allTa{:});
        
        % idtr allowing for trial identification when all trials are append
        idtr = concat_trial_id(allTrials);
        fprintf('\n\n-------\n Reject trials/channels:\n %s\n---------\n', stit);
        [badc, badtr] = rejectvisual_ft(allTa, idtr);

        % Add the new bad channels to txt bad sensor list + to the
        % preproc_ica.mat if ica was requested for preprocessing
        if ~isempty(badc)
            isbadc(j) = 1;
            Spar = add_badchan(Spar, Sprep.param_txt.rms.(srun), badc);
        end
        [cond, Nc] = get_names(allTrials);
        Ntr = [];
        for k = 1 : Nc
            cnam = cond{k};
            Ntr.(cnam) = length(allTrials.(cnam).trial);
        end
        if isa_t
            % Same trials to be removed for all conditions
            rmtr = unique(cell2mat(badtr));
            Spar.rm.trials.allcond = rmtr;
            % Write it
            write_bad(Sprep.param_txt.rmt.(srun).allcond, rmtr, 'trials');   
            Spar.Ntr.allcond = Ntr.(cnam);
        else
            % Write bad trials for each condition
            for k = 1 : Nc
                cnam = cond{k};
                Spar.rm.trials.(cnam) = badtr{k};
                write_bad(Sprep.param_txt.rmt.(srun).(cnam), badtr{k}, 'trials');             
            end
            Spar.Ntr = Ntr;
        end
        
        % Keep the parameters used to prepare data before trials review
        preproc_trials = [];
        preproc_trials.conditions = Spar.conditions;
        preproc_trials.dt_s = Spar.dt_s;
        % Removing of sensors, artefact and ica components
        preproc_trials.rm = rmfield(Spar.rm, 'trials');
        preproc_trials.Ntr = Ntr;
        
        save([Spar.dir.preproc, filesep, 'preproc_trials.mat'], 'preproc_trials'); 
        
        Sprep.param_run{j} = Spar;
        Sprep.do.rmt(j) = 0;
    end
    % Merge the bad channel(s) for all runs
    if any(isbadc) && isa_s
        Sprep = merge_badchan(Sprep);
        if fica
            add_ica_rms(Sprep);
        end
    end

    Sdb(i).meg.preproc = Sprep;
end
close(wb);
    
% Add new bad channels
function Spar = add_badchan(Spar, ptxt, badc)
rms = [Spar.rm.sens ; badc];
Spar.rm.sens = rms;
write_bad(ptxt, rms, 'sens')
pica = [Spar.dir.ica, filesep, 'preproc_ica.mat'];
if exist(pica, 'file')   
    preproc_ica = loadvar(pica);
    preproc_ica.rms.after = unique([preproc_ica.rms.after; badc]);
    save(pica, 'preproc_ica');
end

% Launch the ft visual rejection
function [badc, badtr] = rejectvisual_ft(allTa, idtr)
isok = 'no';
while strcmpi(isok(1:2), 'no')           
    cfg             = [];
    cfg.channel     = 'all';
    cfg.method      = 'summary';
    cfg.megscale    = 1;
    cfg.viewmode    = 'toggle';
    cfg.layout      = cmeg_det_lay(allTa.label);
    cfg.keeptrial   = 'yes';
    cfg.keepchannel = 'no';
    allTreja        = ft_rejectvisual(cfg, allTa);
    isok = questdlg('Confirm the bad channels/trials selection ?',...
        'Confirm',...
        'No (redo)', 'Yes', 'Yes');
end
% Check if new bad channels were identified with 'summary' method
plab = allTreja.cfg.channel;
alab = allTreja.label;
badc = setxor(plab, alab);

% Sample index of trials declared as "BAD"
reji = allTreja.cfg.artfctdef.summary.artifact(:,1);
% All sample indices of trials (it is a "fake" rebuilt one by
% fieldtrip assuming trials == successive epochs of continuous data)
sind = allTreja.sampleinfo(:, 1);

irej = ismember(sind, reji);
Nc = max(idtr(:, 2));
badtr = cell(Nc, 1);
for k = 1 : Nc
    isrm = irej==1 & idtr(:, 2)==k;
    badtr{k} = idtr(isrm, 1);
end

% Keep trial's condition identification
function idtr = concat_trial_id(allTrials)
cond = fieldnames(allTrials);
Nc = length(cond);
idtr = cell(Nc, 1);
idcond = cell(Nc, 1);
for k = 1 : Nc
    ntr = length(allTrials.(cond{k}).trial);
    idtr{k} = (1:ntr)';
    idcond{k} = ones(ntr, 1)*k;
end
idtr = [cell2mat(idtr) cell2mat(idcond)];

% Merge bad channel across run
function Sprep = merge_badchan(Sprep)
Nr = length(Sprep.param_run);
fprintf('\nMerge the bad channels selection of the %d run(s)\n', Nr)
rms = Sprep.param_run{1}.rm.sens;
for j = 2 : Nr
    rms = unique([rms; Sprep.param_run{j}.rm.sens]);
end
write_bad(Sprep.param_txt.rms.allrun, rms, 'sens');
% Add merged selection to preproc_trial
for j = 1 : Nr
    Spar = Sprep.param_run{j};
    Spar.rm.sens = rms;
    preproc_trials = loadvar([Spar.dir.preproc, filesep, 'preproc_trials.mat']); 
    preproc_trials.rm.sens = rms;
    save([Spar.dir.preproc, filesep, 'preproc_trials.mat'], 'preproc_trials'); 
    Sprep.param_run{j} = Spar;    
end             
        
% Add the bad channels to be removed after the ICA rejection in
% the preproc_ica.mat for each run
% It is assumed here that if the parameter
% mopt.continuous.rm_sens_run has been set to 'same' once, it
% should not be changed for further processing of the data of
% the same experiment
function add_ica_rms(Sprep)
Nr = length(Sprep.param_run);
for j = 1 : Nr
    rms = Sprep.param_run{j}.rm.sens;
    pica = [Sprep.param_run{j}.dir.ica, filesep, 'preproc_ica.mat'];
    preproc_ica = loadvar(pica);
    rmsa = setxor(rms, preproc_ica.rms.before);
    preproc_ica.rms.after = unique([preproc_ica.rms.after; rmsa]);
    save(pica, 'preproc_ica');               
end
