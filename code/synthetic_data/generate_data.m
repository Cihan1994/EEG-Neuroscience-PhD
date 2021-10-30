clear all;clc

%% add path to the generate signals script
% https://data.mrc.ox.ac.uk/data-set/simulated-eeg-data-generator
clear; clc;
addpath generate_signals\
addpath C:\External_Software\fieldtrip-20210807\


desired_time = 2; % in seconds
desired_fs = 500;
desired_noise_level = 0.7;
desired_trials = 500;
desired_participants = 1;
desired_total_trials = desired_participants * desired_trials;
desired_jitter = 30;
desired_peak_fs = 30;
desired_toi = [0, desired_time];

n_samples = desired_time * desired_fs;
peak_time = floor(n_samples/3)*2;

my_noise = noise(n_samples, desired_total_trials, desired_fs);
my_peak = peak(n_samples, desired_total_trials, desired_fs, desired_peak_fs, peak_time, desired_jitter);

signal = my_peak + (my_noise*desired_noise_level);

if desired_total_trials > 1
    my_noise = split_vector(my_noise, n_samples);
    my_peak = split_vector(my_peak, n_samples);
end

%% add the pink noise on top of the sythetic data
signals = zeros(n_samples, desired_total_trials);
for t = 1:desired_total_trials
    noise_j = my_noise(:,t);
    peak_j = my_peak(:,t);
    sig_w_pink_noise = peak_j + (noise_j*desired_noise_level);
    signals(:,t) = sig_w_pink_noise;
end

%% create synth participants and generate their ERPs
make_plot = 1;
participants = {};
k_trials = desired_trials;
for p = 1:desired_participants
    
    if p == 1
        subset = signals(:,1:k_trials);
    else
        subset = signals(:,k_trials+1:k_trials + (desired_trials));
        k_trials = k_trials + desired_trials;
    end
    
    erp = mean(subset,2);
    data.erp = erp;
    data.trials = subset;
    participants{p} = data;
    
    if make_plot == 1
        %bandpass_erp = bandpass(erp, [0.1,30]);
        %plot(subset, 'Color',[0, 0.5, 0, 0.1]);
        hold;
        plot(erp);
        hold;
    end
    
end

%% create spectrograms using morlett waveletts on both the trial and ERP leve
cfg              = [];
cfg.output       = 'pow';
cfg.method       = 'wavelet';
cfg.taper        = 'hanning';
cfg.width = 3;
cfg.foi =   5:30;
cfg.t_ftimwin = ones(length(cfg.foi),1).*0.25;
cfg.toi          = desired_toi(1):0.002:desired_toi(2);

end_value = desired_toi(2);  
start_value = desired_toi(1);
n_elements = n_samples;
step_size = (end_value-start_value)/(n_elements-1);

all_participant_data = [];
for p=1:desired_participants
    disp(p);
    data = participants{p};
    erp = data.erp;
    trials = data.trials;
    time = start_value:step_size:end_value;
    
    % erp level
    erp_level.dimord = 'chan_time';
    erp_level.trial = erp';
    erp_level.elec = {};
    erp_level.label = {'A1'};
    erp_level.time = time;
    erp_tf = ft_freqanalysis(cfg, erp_level);
    freq_of_maximum_power_erp = freq_of_max_pow(erp_tf);
    
    % trial-level
    trial_level.dimord = 'chan_time';
    trial_level.trial = create_ft_data(desired_trials, trials);
    trial_level.elec = {};
    trial_level.label = {'A1'};
    trial_level.time = create_fieldtrip_format(desired_trials,time);
    tl_tf = ft_freqanalysis(cfg, trial_level);
    freq_of_maximum_power_trial_level = freq_of_max_pow(tl_tf);
    
    all_participant_data(p,1) = freq_of_maximum_power_erp;
    all_participant_data(p,2) = freq_of_maximum_power_trial_level;
end

all_participant_data;


cfg = [];
cfg.baseline = 'no';
cfg.xlim = [desired_toi(1),desired_toi(2)];
cfg.channel = 'A1';
ft_singleplotTFR(cfg, tl_tf);
title('Trial Level')

cfg = [];
cfg.baseline = 'no';
cfg.xlim = [desired_toi(1),desired_toi(2)];
cfg.channel = 'A1';
ft_singleplotTFR(cfg, erp_tf);
title('GA Level')

%% gets the frequency of maximum power
function freq = freq_of_max_pow(data)
    f = data.freq;
    d = squeeze(data.powspctrm);
    [row, col] = find(ismember(d, max(d(:))));
    freq = f(row);
end


%% converts to a FT format
function data = create_fieldtrip_format(n, series)
    data = {};
    for k = 1:n
        data{k} = series;
    end
end

function dataset = create_ft_data(n, data)
    dataset = {};
    data = data';
    for k =1:n
        dataset{k} = data(k,:);
    end
end

%% split vector
function v = split_vector(vector, n_samples)
    n_chunks = size(vector,2)/n_samples;

    curr_chunk = n_samples;
    v = zeros(n_samples, n_chunks);
    for chunk = 1:n_chunks
        if chunk == 1
            c = vector(1, 1:curr_chunk);
            curr_chunk = curr_chunk + n_samples;
        else
            c = vector(1, (curr_chunk-n_samples)+1: curr_chunk);
            curr_chunk = curr_chunk + n_samples;
        end

        c = c';
        v(:, chunk) = c(:,1);
        
    end
end