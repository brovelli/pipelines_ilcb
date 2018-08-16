function meg_fftstack_fig(spData, opt) %spsparam,datapath,pathsavfig,datatyp)
% Figure of stacked spectra (one spectrum computed for each channel, all spectra
% superimposed on the same figure).
% Mise en forme tres specifique d'une figure represantant les spectres stackes ...
% La FFT stackee associee a chaque canal est tracee, et ce pour tous les
% canaux. Les noms des canaux dont les valeurs d'amplitude de leur spectre
% sont les plus extremes comparees aux autres spectres sont indiques sur le
% graphe : soit les 5 canaux avec les valeurs d'amplitude maximale de 
% l'amplitude du spectre dans la bande de frequence d'interet (0.1 � 100
% Hz). Il en est de meme pour les 5 canaux dont l'amplitude est minimale.

%-- Before plotting, check if data exists...
if ~isfield(spData, 'spectra') || isempty(spData.spectra) || sum(sum(spData.spectra))==0 
    disp('spData is empty')
    return;
end

%-- Check for inputs
defopt = struct('sps_param', [], 'savepath', pwd, 'info', []);
% Set default option if required
if nargin < 2
    opt = defopt;
else
    opt = check_opt(opt, defopt);
end


% Spectra calculation parameters
if isempty(opt.sps_param)
    stktit = [];
else
    sppar = opt.sps_param;
    stktit = ['- [ Nsp= ',num2str(sppar.n),' ; Dsp= ',num2str(sppar.dur),' s ; ti= ',...
    num2str(sppar.dur*2),' s ]'];
end
% Info on data path to add on the figure title
datapath = opt.info;
% Save path
psav = opt.savepath;

% Fixed ptions for the labelling of the spectra displaying the highest and 
% lowest values of amplitude at several frequencies of interest

% Number of maximum and minimum values of amplitude from different channels 
% to find on the spectrum
Nex = 3;

% Frequencies to detect extrema 
fcheck = [1 35 120]; 
 % Frequency windows for labeling extrema  
fwin = [0.8 4 ; 5 40 ; 120 200];  

%---- Prepare data

% First by removing data with spectrum value == 0

fz = spData.spectra(:, 1)==0;
if any(fz)
    disp('!! Frequency spectrum == 0 for channel(s) :')
    disp(spData.label(fz))
    zlab = spData.label(fz);
    % Keep only non-zero data
    spData.label = spData.label(~fz);
    spData.spectra = spData.spectra(~fz, :);
else
    zlab = [];
end

% Define a smooth version (5-span points smoothing) 
Nc = length(spData.label);
smo = zeros(size(spData.spectra));
for k = 1: Nc
    smo(k,:) = smooth(spData.spectra(k, :), 5);
end
spDatasmo = spData;
spDatasmo.spectra = smo;

% Define a downsampled version
% Make a lighter .fig to "easily navigate inside" (- in frenchglish)
% One sample every 0.5 Hz
spDatad = downsample_sp(spData, 0.5);

%------ Make the figures
% Generic title
gtit = {['Stacked spectrum - ',num2str(Nc),' channels ',stktit]
            datapath };

%--Initial data
% hp = plot_spectra(spData);
% % Add labels of extremum values
% put_labarrow(spData, hp, fcheck, fwin, Nex);
% % Title
% title(gtit,'interpreter','none','fontsize',12,'fontname','AvantGarde');
% % Save it
% export_fig([psav, filesep, 'fftstack.png'],'-m1.5','-nocrop')
% close

%--Smooth data
hp = plot_spectra(spDatasmo);
add_zlab(zlab);

% Title
gso = gtit;
gso{1} = ['[ Smooth span=5 ] - ', gtit{1}];
title(gso,'interpreter','none', 'fontsize',11, 'FontWeight','normal');
% Add labels of extremum values
put_labarrow(spDatasmo, hp, fcheck, fwin, Nex);
% Save as jpeg
export_fig([psav, filesep, 'fftstack_smooth.png'],'-m1.5','-nocrop')
close

%--Downsample version with interactive selection for bad channel
if ~isempty(spDatad)       
    plot_spectra(spDatad);
    add_zlab(zlab);
    gso = gtit;
    gso{1} = ['[ Smooth span=5 & Downsamp. ] - ', gtit{1}];     
    title(gso, 'interpreter','none', 'fontsize',11, 'FontWeight', 'normal');
    save_fig([psav, filesep, 'fftstack_dispnam_downsamp.fig'])
    close
end

fprintf('\nFigure of stacked spectrum saved in ---\n----> %s\n', psav);

function add_zlab(zlab)
if isempty(zlab)
    return;
end
put_figtext([{'Channel(s) with sp==0:'}; zlab], 'sw');

% Index of frequencies in freq vector that are nearest to fcheck frequencies 
% values
function ifreq = det_ifreq(freq, fcheck)
Nf = length(fcheck);
ifreq = zeros(Nf, 1);
for i = 1 : Nf
    ind = find(freq >= fcheck(i), 1, 'first');
    if ~isempty(ind)
        ifreq(i) = ind;
    end
end
ifreq = ifreq(ifreq > 0);

% For each frequency of interest (FOI), find the 3 max and 3 min values of
% amplitude - only keep unique labels
function ibad = find_extrema_chan(spData, fcheck, Nex)

% Find associated frequency index
ifreq = det_ifreq(spData.freq, fcheck);

Nf = length(ifreq);

% 3 indices of Min and Max labels for each FOI
ibad = zeros(Nex, 2, Nf);

labini = (1:length(spData.label))';
labrem = labini;
for i = 1 : Nf
    % Only consider labels not previously found
    ampif = spData.spectra(labrem, ifreq(i));
    [~, isort] = sort(ampif);
    labex = labrem(isort);
    % isort : ind
    % Keep the Nex most extremum values at the 2 tails
    ibad(:,:, i) = [labex(1:Nex) labex(end-(Nex-1):end)]; 
    labrem = labex(Nex+1 : end-Nex);  
end

% Add labels of channels of spectra displaying extremum values of amplitude 
% (as minimum and maximum values)
function put_labarrow(spData, hspect, fcheck, fwin, Nex)  

% Number of extremum data for minimum as well as for maximum values


% Indices of labels with extremum values at each frequency of interest
% (fcheck)
ichanext = find_extrema_chan(spData, fcheck, Nex);

% Each fcheck is associated with a fwin = frequency window where to plot label
% names and narrows related with extremum data find at each fcheck

% Plot narrows and labels associated with each frequencies window    
Nw = length(fwin(:,1));

for j = 1 : Nw
    
    % Channels with extremum values to plot inside the window
    ibadchanw = ichanext(:,:, j);
        
    % Frequencies window limits (in log10 as the plot scale)
    fint = log10(fwin(j,:));
    % Define frequency abscisses for each arrows 
    fnar = logspace(fint(1), fint(2), Nex)';
    
    ibadw = ibadchanw(:);
    
    ifreqw = det_ifreq(spData.freq, fnar);
    % Indices for both side (minimum / maximum)
    ifw = repmat(ifreqw, 2, 1);
    
    % Associated frequencies (x-values) for minimum, then maximum arrows to
    % plot
    farr = spData.freq(ifw)';
    
    % Associated amplitudes (y-values) for minimum and maximum spectra
    amp = diag(spData.spectra(ibadw, ifw)); 
    
    % Arrows coordinates as a [Nx Ny] matrix
    arcoord = [farr amp];
    
    if j == 1
        % Values based on the figure for transform arrows coordinates in
        % normalized unit
        xx = log10(xlim);
        yy = log10(ylim);

        Dxl = abs(diff(xx));
        Dyl = abs(diff(yy));

        % Fixed values to define the coordinates of the begining of the arrow
        % Small amoung of shift in x and y directions from the ending of the
        % arrow : dshift, defined for each arrow (linked to Nex minimum then Nex
        % maximum) (one row per arrow, x in column 1, y in column 2)
        transl = [-0.01 -0.08 ; 0.01 0.08];
        dshift = [repmat(transl(1,:), Nex, 1) ; repmat(transl(2,:), Nex, 1)];
    end
    
    % Define arrows coordinates in the Normalized units of the figure 
    % To be plot by annotation function
    % Arrow ending cooredinates in log10
	arc = log10(arcoord);
    pos = get(gca,'position');
    xnar = pos(3).* abs( arc(:,1) - xx(1) )./Dxl + pos(1);  
    ynar = pos(4).* abs( arc(:,2) - yy(1) )./Dyl + pos(2);  
    
    arrbeg = [(xnar + dshift(:,1)) (ynar + dshift(:,2))];
    arrend = [ xnar ynar];
    lab = spData.label(ibadw);
    
    for k = 1 : length(lab)
        slab = lab{k};
        % Get color from handle of the spectrum with displayname property =
        % the channel name
        ip = findobj(hspect, 'type', 'line', 'DisplayName', slab);
        col = get(ip, 'color');
        
        annotation('textarrow',[arrbeg(k,1) arrend(k,1)],...
                [arrbeg(k,2) arrend(k,2)],'string', slab,...
                'fontsize',10,'FontWeight','bold','TextBackgroundColor','none',...
                'TextColor',col,'textedgecolor','none',...
                'headstyle','vback1','headwidth',6,...
                'headlength',6,'color',col)
    end
end

% Simple loglog plot of spectra with label name add to each spectrum object
function hp = plot_spectra(spData)
        
 	figure
    set(gcf,'visible','off','units','centimeters','position',[2 2 24 18])
    hp = loglog(spData.freq, spData.spectra);
   
    for j = 1 : length(hp)
        set(hp(j),'displayname', spData.label{j})
    end
    xlabel('Frequency (Hz)', 'fontsize', 13)
    ylabel('Amplitude (T)', 'fontsize', 13)
    set(gca,'fontsize', 13)

% Downsampling data of spectra in order to facilitate the navigation with the 
% mouse inside the figure (to display channels name by editing the figure...) 
% Only if it allows to reduce the number of point by a factor 4 at least
function spDatad = downsample_sp(spData, df)
spDatad = [];
% df : frequency between 2 points of the resampling version

% Calculate sampling rate of the original data
freq = spData.freq;
dfi = diff(freq([1 end]))/(length(freq)-1);

% Check if downsampling is relevant
% Upsampling and not downsampling - empty data are returned
if df < dfi
    fprintf('\nDownsampling impossible with the new sampling rate :  %f Hz', df);
elseif dfi > df/4
    fprintf('\nDownsampling not relevant with the actual sampling :  %f Hz', df);
else
    % Resampling factor relative to the initial sampling frequency
    fact = round(df / dfi);
    
    spres = resample(spData.spectra', 1, fact);
    spres = spres';
    
    fres = linspace(freq(1), freq(end), length(spres(1,:)));
    
    spDatad.freq = fres;
    spDatad.spectra = spres;
    % Add label field
    spDatad.label = spData.label;
end
