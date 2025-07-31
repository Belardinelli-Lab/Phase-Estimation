%% Script to loop through entire folder of datafiles                                           COMMENTS AND EXPLANATIONS
                                                                                                % Lines 5, 6 and 10 are the only lines  
% Restore MATLAB default path and add necessary paths                                           % in the entire script 
                                                                                                % that need to be adjusted
    % Restore MATLAB default path and add necessary paths
    restoredefaultpath
    addpath 'C:\Users\melis\Documents\MATLAB\fieldtrip-20240731'
    addpath 'C:\Users\melis\Documents\MATLAB\Scripts'
    ft_defaults
    
    % Define the directory containing the BrainVision files
    data_dir = 'C:\Users\melis\Documents\Trento\TESTMS\Data\TG111224'; 
    output_dir = fullfile(data_dir, 'Processed');                                               % Directory to save processed files
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);                                                                      % Create output directory if  
    end                                                                                         % it doesn't exist
    
    file_list = dir(fullfile(data_dir, '*.vhdr'));                                              % Get a list of all .vhdr files

%% First Loop: Load, preprocess, and save filtered data
    for file_idx = 1:length(file_list)
        % Get the current .vhdr file and construct associated file paths
        vhdr_file = fullfile(data_dir, file_list(file_idx).name);                               % Full path to .vhdr file
        [~, base_name, ~] = fileparts(vhdr_file);
        eeg_file = fullfile(data_dir, [base_name, '.eeg']);                                     % Full path to corresponding .eeg file
    
        % Extract the base name and replace underscores with spaces
        name = strrep(base_name, '_', ' ');                                                     % Replace '_' with ' ' in base filename
        fprintf(['Processing file (loading and preprocessing):' ...
            ' %s (Name: %s)\n'], vhdr_file, name);                                              % Debugging output

%% Segment data into trials with correct trialfunction
        cfg = [];
        cfg.trialfun = 'trialfun_checkphase'; 
        cfg.headerfile = vhdr_file;                                                             % Use dynamically assigned vhdr_file
        cfg.datafile = eeg_file;                                                                % Use dynamically assigned eeg_file
        trialdata = ft_definetrial(cfg);
        preproc_data = ft_preprocessing(trialdata);
    
        % Resample the data
        cfg = [];
        cfg.resamplefs = 1000;
        resampdata = ft_resampledata(cfg, preproc_data);
    
        % Select specific channels and preprocess
        cfg = [];
        cfg.channel = {'C3', 'FC1', 'CP1', 'FC5', 'CP5'};
        EEGchannel_data = ft_preprocessing(cfg, resampdata);
    
        % Create a new data structure for the filtered data
        filtered_data = EEGchannel_data;
        filtered_data.label = {'C3_Hjorth'};                                                    % New channel name
    
        % Apply the Hjorth filter
            for i = 1:numel(EEGchannel_data.trial)
                original_matrix = EEGchannel_data.trial{i};
                c3_data = original_matrix(1,:);                                                 % Extract the first row (C3)
                avg_other_channels = mean(original_matrix(2:end,:), 1);                         % Calculate average of the other rows
                filtered_row = c3_data - 0.25 * avg_other_channels;                             % Apply the Hjorth filter
                filtered_data.trial{i} = filtered_row;                                          % Store result in the new data structure
            end

        % Update the number of channels
        filtered_data.hdr.nChans = 1;
        filtered_data.hdr.label = filtered_data.label;
    
        % Save the filtered data
        save(fullfile(output_dir, [base_name, '_filtered.mat']), 'filtered_data');
    end

%% Second Loop: Load processed data and perform Phastimate
for file_idx = 1:length(file_list)
    % Get the current file's base name
    [~, base_name, ~] = fileparts(file_list(file_idx).name);

    % Load the filtered data
    filtered_file = fullfile(output_dir, [base_name, '_filtered.mat']);
    if ~isfile(filtered_file)
        fprintf('Filtered file not found for %s. Skipping.\n', base_name);
        continue;
    end
    load(filtered_file, 'filtered_data');                                                       % Load saved filtered_data

    fprintf('Processing file (Phastimate): %s\n', base_name);                                   % Debugging output

    %% Phastimate
    fs = 1000;
    D = designfilt('bandpassfir', 'FilterOrder', 128, ...
        'CutoffFrequency1', 9, 'CutoffFrequency2', 13, 'SampleRate', fs);
    offset_correction = 4;

    num_trials = length(filtered_data.trial);                                                   % Get the number of trials
    output = struct('phase', [], 'amplitude', []);                                              % Initialize the output structure

    % Loop through all trials
    for i = 1:num_trials
        data = filtered_data.trial{i}';                                                         % Get the data for the current trial
        [phase, amplitude] = phastimate(data, D, 64, 30, 128, offset_correction);               % Run phastimate on the current trial

        % Store the phase and amplitude in the output structure
        output(i).phase = phase;
        output(i).amplitude = amplitude;
    end

    % Combine all phase data from the output structure into a single array
    all_phases = [];

    for i = 1:numel(output)
        all_phases = [all_phases; output(i).phase];                                             % Concatenate phases from each trial
    end

    % Create a rose plot (histogram of phase angles)
    figure('Name', sprintf('File: %s', base_name), 'NumberTitle', 'off');                       % Unique figure for each file
    polarhistogram(all_phases, 24); 
    title(strrep(base_name, '_', ' '));                                                         % Title with spaces instead 
    % %% plot single trial
    % % Specify the trial number
    % trial_number = 13;  % Change this to your desired trial number
    % 
    % % Create the figure with the trial number included in the name
    % figure('Name', sprintf('File: %s, Trial: %d', base_name, trial_number), 'NumberTitle', 'off');
    % 
    % % Plot the specified trial
    % plot(filtered_data.trial{trial_number});
    % 
    % % Update the title to include the trial number and replace underscores in the base name
    % title(sprintf('%s - Trial %d', strrep(base_name, '_', ' '), trial_number));



end

% Save all figures to a Figures folder
figures_dir = fullfile(data_dir, 'Figures');  % Define the Figures folder path
if ~exist(figures_dir, 'dir')
    mkdir(figures_dir);  % Create the folder if it doesn't exist
end

% Loop through each figure and save it with the dataset name
for file_idx = 1:length(file_list)
    [~, base_name, ~] = fileparts(file_list(file_idx).name);  % Extract dataset name
    figure_file = fullfile(figures_dir, [base_name, '.fig']);  % Define the .fig file path

    % Select the current figure
    figure(file_idx);  % Bring the figure to focus

    % Save the figure
    savefig(figure_file);

    fprintf('Figure for %s saved to %s\n', base_name, figure_file);  % Log success
end
