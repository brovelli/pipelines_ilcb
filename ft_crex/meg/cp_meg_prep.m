function Sdb = cp_meg_prep(Sdb, opt)
% M/SEEG preprocessing to prepare data for source estimation:
%  1 - preprocessing on continuous dataset:
%       * filtering (hp, lp or bp filter) by ft_preprocessing
%       * removing of bad channels
%       * removing of strong artefacts (required for ICA) 
%       * reject ICA component(s)
% 2 - epoching:
%       * removing of bad trials
%       * downsampling
%
% All steps are optional and configurable in the opt structure:
%
%-- for data processing on continuous dataset:
%
% - opt.continuous.filt: filtering option with fields:
%   .type: filter type ('hp', 'lp' or 'bp') 
%       [ default: [] (empty == no filtering) ]
%	.fc: cut-off frequency(ies) in Hz - one value for 'lp' and 'hp' type,
%       2 values for 'bp' [default: []]
%
% - opt.continuous.ica: ICA parameters with fields:
%   .reject: flag to indicate if ICA rejection is to be done (when reject==1) 
%       [ default: 0 (no ICA)]
%   .numcomp: number of components
%       [ default: 'all' ]
%
% - opt.continuous.rm_sens_run: 'same' or 'each': string that indicate if
% the same bad channels are to be considered for all the runs of the 
% subject recording session or if different selections of bad channels are
% to be set for each run [ default: 'each' - bad channel selection is asked for
%   each run ]
%
%-- epoching parameters: 
%
% - opt.epoched.trigfun: project-specific function to define markers values
%       and associated condition names for epoching
%       [ see ft_crex/_specproj/trigfun_te.m for example ]
%
% - opt.epoched.trialfun: project-specific function to define trials
% according to response triggers values 
%       [ see ft_crex/_specproj/trialfun_te.m for example - default is the
%       'ft_trialfun_general' ]
%
% - opt.epoched.conditions: to specify which conditions as defined in trigfun
%       functions are to be processed, and in the same order as defined in 
%       the conditions cell. Ex.: {'A', 'S', 'R', 'SAR'} 
%       [ default: [] (empty == all conditions in trigfun function are to 
%       process) ]
%
% - opt.epoched.dt_s: [prestim postim] durations relative to the trigger in
%   seconds. [ default: [0.5 1] s ]
%   * If several conditions were specified in opt.epoched.conditions but only
%   one dt_s interval, the same epoching interval is applied for all the
%   conditions.
%   * For epoching of different lengths according to the condition,
%   the opt.epoched.conditions must be set with the associated opt.epoched.dt_s
%   holding the epoching intervals par conditions at each row (
%   ex.: [3 3; 3 3; 3 3; 1.5 5] associated with {'A', 'S', 'R', 'SAR'}
%
% - opt.epoched.rm_trials_cond: 'same' or 'each' to indicate if bad trials
% selection that was done for the first condition is to be applied to all the
% other conditions (for the case when conditions == different epoching
% versions/durations with minor time shifting)
%   [ default: 'each' - bad trials are not the same per condition ]
%
% - opt.resample_fs: downsampling frequency in Hz 
%       [ default: [] (no remsampling)
%
% When new MEG data are found during database initialisation by cp_init.m,
% the preprocessing pipeline is executed according to opt otpions.
%
% A set of figures is generated in each dataset directory (in db_fieldtrip/
% PROJ/(group)/SUBJ/meg/contnuous/prep/(filt* or no_filt)/_preproc_fig).
% Theses figures helps for bad channels identification (see cmeg_cleanup_fig).
% At the end of creating figures for all new data sets (which can be long),
% the bad channels selection is requested in the command window.
% --> this create the file 'rm_sens.txt' in data prep directory containing the bad
% channels list as well as the 'preproc.mat' file that holds the effective data
% preprocessing options (channels, ICA components and strong artefacts
% removing). It is possible to add/modify channels to remove by
% adding/removing channels in rm_sens.txt file. According to
% opt.continuous.rm_sens_run option, the update of the channel to remove
% will be done.
% , rm_sens, rm_comp, 
%
%-- TO DO:  - GUI for artefact identification
%           - frequency analysis at trial level
% (to be added: - opt.epoched.tshift_s: shift time for triggers)
%
%-CREx180726

% Default options

%-- Default for continuous dataset
%- Filtering
opt.continuous.filt = check_opt(opt.continuous.filt,...
                        struct('type', [], 'fc', []));
%- ICA
opt.continuous.ica = check_opt(opt.continuous.ica,...
                        struct('reject', 0, 'numcomp', 'all'));
                    
%- RM sensor mode 
opt.continuous = check_opt(opt.continuous, struct('rm_sens_run', 'each'));

%-- Default for epoching
opt.epoched = check_opt(opt.epoched, struct('trigfun', [],...
                                    'trialfun', [],...
                                    'conditions', [],...
                                    'dt_s', [3 3], ...
                                    'rm_trials_cond', 'each',...
                                    'resample_fs', []));
                                
if isempty(opt.epoched.trigfun)
    warning('MEG preprocessing:');
    warning('opt.trigfun is required to know the marker values to consider for epoching');
    error('Abort processing')
end

fica = opt.continuous.ica.reject;
fopt = opt.continuous.filt;

% Check for HP filtering if ICA is required
fc_hp = 0.5;
if fica
    fopt = check_ica_filt_opt(fopt, fc_hp);
    opt.continuous.filt = fopt;
end

isval = 0;
while ~isval    
    Sdb = prep_pipeline(Sdb, opt);
    % Final review
    %---- Confirm a last time all the preprocessing parameters for all subjects (if
    % any change in parameters, write the new one in txt file and launch the
    % prep_pipeline
    isval = cp_meg_review_gui(Sdb, opt);
end

%---- Do the preprocessing with the requested filtering option and the cleaning
% paramters
Sdb = cp_meg_epoching(Sdb, opt);

function Sdb = prep_pipeline(Sdb, opt)

% Initialize all param_txt files
Sdb = cp_meg_prep_init(Sdb, opt);

%- Make figures to help for bad channels + strong artefact identification 
% A light data set version is processed from the original data set for visualization
% with:
% - at least a HP filtering with fc = 0.5 Hz if fopt.type is empty or 'lp'
% - a resampling at 400 Hz
Sdb = cp_meg_cleanup_fig(Sdb);

% Input of bad channels 
%%% TO DO: add the strong artefact input too --> rms
Sdb = cp_meg_rmsens_gui(Sdb, opt.continuous);

% ICA for artefact cleaning
Sdb = cp_meg_cleanup_ica(Sdb, opt.continuous.ica.numcomp);

% Bad trials identification with semi-automatic method -- on the HP and
% resampling data version, cleaning from artefacts
Sdb = cp_meg_cleanup_trials(Sdb, opt);
