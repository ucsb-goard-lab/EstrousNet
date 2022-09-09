classdef EstrousNetClassifier < handle
    %% EstrusNetClassifier.m
    %----------------------------------------------------------------------%
    %   This class uses a pretrained algorithm to identify the stages of
    %   the estrous cycle. If cytology images were taken sequentially, the
    %   EstrousNet output will be fit to an archetypal cycle for more
    %   informed classification. 
    %
    %   Notes:
    %
    %   'getTestFolder' This function expects test images to be contained
    %    within one parent directory. For more complex subfolder structure,
    %    code must be modified.
    %
    %   'generateCyclicityPredictions' If seq_flag is set to 'true'
    %    (though EstrousNetGUI.mlapp or programmaticallly), the output 
    %    labels from EstrousNetClassifier will be fit to an archetypal 
    %    cycle. Abnormally senescent diestrus will trigger a pseudopregnancy
    %    flag.
    %
    %   'getClassification' Test image luminance is normalized and images
    %    are converted to 3d greyscale before classifications are
    %    generated. EstrousNetPlotting.mlapp plots results.
    %
    %   'run' Run all relevant functions independent of
    %    EstrousNetGUI.mlapp.
    %
    %
    %   Written by Nora Wolcott May 2020
    %   Last updated 08/2021
    %-------------------------------------------------------------------------%
    properties
        trainedNet % imported to classifier
        testFolder
        rawImages
        processedImages % normalized and converted to greyscale
        labelProbabilities % classification probability by stage
        netLabels % EstrousNet classifications
        cyclicityLabels % classifications when fit to linear cycle
        finalLabels % composite EstrousNet and cyclicity classifications
        confidence_index % degree of certainty, defined in GUI
    end
    
    methods
        function obj = EstrousNetClassifier()
        end
        
        function getTestFolder(obj,testFolder)
            if nargin < 2 || isempty(testFolder)
                disp('Select your folder of test images: ')
                testFolder = uigetdir('','Select test folder');
            end
            obj.testFolder = testFolder;
        end
        
%         %         Only use if not using GUI to load pretrained net
%                 function getTrainedNet(obj,trainedNet)
%                     if nargin < 2 || isempty(trainedNet)
%                         disp('Select your trained network: ')
%                         [net_fn, net_pn] = uigetfile('*.mat','Select pretrained net');
%                         disp('Loading trained network...')
%                         trainedNet = importdata(strcat(net_pn, '/', net_fn));
%                     end
%                     obj.trainedNet = trainedNet;
%                     disp('Ready to get predictions')
%                 end
        
        function out = checkPseudopregnancy(obj, single_mouse)
            sampling_data = reshape(single_mouse', 1, []);
            most_recent_array = sampling_data(end-3:end);
            if length(sampling_data)> 6 % in case sampling is too short 
                recent_array = sampling_data(end-6:end);
            else
                recent_array = sampling_data; % throw warning since there isn't much data
                warning('Input data may be too short to reliably detect pseudopregnancy.')
            end
            short_loc_D = find(most_recent_array==1);
            loc_D = find(recent_array==1);
            short_consecutive_D = find(diff(short_loc_D)==1);
            consecutive_D = find(diff(loc_D)==1);
            
            sample_freq = size(single_mouse, 2);
            short_length_string = length(find(diff(short_consecutive_D)==1))+1;
            length_string = length(find(diff(consecutive_D)==1))+1;
            if sample_freq == 1 && short_length_string > 2
                out = true;
                % pseudo_warning = warndlg('WARNING: Your animal may be pseudopregnant','WARNING');
            elseif sample_freq > 1 && length_string > 4
                out = true;
                % pseudo_warning = warndlg('WARNING: Your animal may be pseudopregnant','WARNING');
            else
                out = false;
            end
        end
        
        %% Determine cyclicity prediction, v2
        % WARNING: will not work well until at least one week of cyclicity is established
        % To enable this function, images must be taken sequentially and
        % filenames must reflect the order of images
        function generateCyclicityPredictions(obj, sampling_freq)
            if nargin < 2 || isempty(sampling_freq)
                list = {'1','2','Other'};
                [sampling_freq,~] = listdlg('PromptString',{'How many times per day did you sample?',''},...
                    'SelectionMode','single','ListString',list);
                if sampling_freq == 3 % If entered value is "other" manually enter value
                    prompt = 'Enter sampling frequency:';
                    dlgtitle = 'Other value';
                    dims = [1 35];
                    definput = {'20','hsv'};
                    sampling_freq = inputdlg(prompt,dlgtitle,dims,definput);
                    sampling_freq = str2double(cell2mat(sampling_freq));
                end
            end
            
            % get numerical vector of net labels
            first_guess = cell2mat(cellstr(obj.netLabels(1)));
            caps = isstrprop(first_guess,'upper'); % survey labels for capital letters
            if sum(caps) > 0
                single_mouse = regexprep(cellstr(obj.netLabels),{'Diestrus','Proestrus','Estrus','Metestrus'},...
                {'1','2','3','4'});
            else
            single_mouse = regexprep(cellstr(obj.netLabels),{'diestrus','proestrus','metestrus','estrus'},...
                {'1','2','4','3'}); % order switched to account for 'estrus' character overlap
            end
            single_mouse = str2num(cell2mat(single_mouse)); % convert to double
            
            % check for pseudopregnancy
            if obj.checkPseudopregnancy(single_mouse)
                warning('Abnormal cycle detected: your animal may be pseudopregnant.');
            end
            
            % find archetypal cycle that fits data
            possible_shifts = sampling_freq * length(categories(obj.netLabels)); 
            slope = 1/sampling_freq; % archetypal stage changes by 0.5 every sample
            cycle = 1:slope:length(categories(obj.netLabels));
            numCycles = floor(length(single_mouse)/length(cycle));
            remainder = rem(length(single_mouse),length(cycle));
            archetypal_cycle = [repmat(cycle,1,numCycles),cycle(1:remainder)];
            
            best_fit = zeros(1,possible_shifts); % instantiate arrays
            fitted_cycle = zeros(possible_shifts, length(single_mouse));
            for ii = 1:possible_shifts
                shift = ii-1;
                fitted_cycle(ii,:) = circshift(archetypal_cycle,shift); % shift array by x amount
                best_fit(1,ii) = immse(single_mouse', fitted_cycle(ii,:));% save mean squared error between cycles
            end
            [~,best_fit_idx] = min(best_fit); % cycles with smallest mean squared error
            test_vec = fitted_cycle(best_fit_idx,:);
            
            % correct for wrapped remainder tail: make sure vector is sequential
            target_vec = repmat(1:4, 1, ceil(length(test_vec)/length(categories(obj.netLabels)) + sampling_freq)); % repeating template vector
            for t = 1:possible_shifts-1 % shift and check
                sim(t) = sum(test_vec == target_vec(t : (t - 1) +  length(test_vec))); % similarity between shifted & ideal vectors
            end
            
            [~, idx] = max(sim); % which offset forces the greatest similarity
            obj.cyclicityLabels = target_vec(min(idx) : (min(idx) - 1) + length(test_vec)); % numeric labels corrected for sequence
            
            cyclicityLabel_string = sprintfc('%d',obj.cyclicityLabels); % convert to cell array of strings
            obj.cyclicityLabels = categorical(regexprep(cyclicityLabel_string,{'1','2','4','3'},...
                {'diestrus','proestrus','metestrus','estrus'}))'; % convert numerical to categorical labels
        end
        
        function setNet(obj, trainedNet)
            if nargin < 2 || isempty(trainedNet)
                disp('Select your trained network: ')
                [net_fn, net_pn] = uigetfile('*.mat','Select pretrained net');
                disp('Loading trained network...')
                trainedNet = importdata(strcat(net_pn, filesep, net_fn));
            end
            obj.trainedNet = trainedNet;
        end
        
        function preprocessImages(obj)
            if isempty(obj.testFolder)
                disp('Select test folder')
                obj.testFolder =  uigetdir('Select test folder');
            end
            
            addpath(obj.testFolder)
            test_names = [dir(fullfile(obj.testFolder, '*.jpg')); dir(fullfile(obj.testFolder, '*.png'));...
                dir(fullfile(obj.testFolder, '*.bmp'))];
            num_imds = length(test_names);
            
            oldFolder = obj.testFolder; % save old folder
            obj.rawImages = imageDatastore(fullfile(oldFolder), 'LabelSource', 'foldernames', 'IncludeSubfolders', true);
            
            % normalize luminance
            test_im_array = cell(num_imds,1);
            desired_lum = 125; % set desired luminance
            for ii = 1:num_imds
                im = imread(fullfile(test_names(ii).folder,test_names(ii).name));
                lum_diff = mean(mean(im, [1 2])) - desired_lum; % how far image is from desired luminance
                im_norm = im - lum_diff; % normalize luminance
                im_grey = rgb2gray(im_norm); % convert to greyscale
                im_3d = cat(3,im_grey, im_grey, im_grey); % make 3d
                test_im_array{ii} = im_3d;
            end
            
            % save original images to display later
            newFolder = fullfile(obj.testFolder,'processedTestImages');
            mkdir(newFolder)
            
            % write your processed images to a new subfolder named "processedTestImages"
            for i = 1:length(test_im_array)
                new_im = test_im_array{i};
                filename = strcat(newFolder,filesep,test_names(i).name);
                imwrite(new_im, filename);
            end
            
            obj.testFolder = newFolder; % change test folder to the folder containing your processsed images
        end
        
        function [aug_test_imds] = prepareImageDatastore(obj)
            if isempty(obj.rawImages) % if preprocessing was skipped
                obj.rawImages = imageDatastore(fullfile(obj.testFolder), 'LabelSource', 'foldernames', 'IncludeSubfolders', true);
            end
            obj.processedImages = imageDatastore(fullfile(obj.testFolder), 'LabelSource', 'foldernames', 'IncludeSubfolders', true);
           
            inputSize = obj.trainedNet.Layers(1).InputSize;
            aug_test_imds = augmentedImageDatastore(inputSize(1:2), obj.processedImages); % resizing images to fit the network
        end
        
        function getClassification(obj, aug_test_imds)
            [obj.netLabels, score2] = obj.trainedNet.classify(aug_test_imds);
            obj.finalLabels = obj.netLabels; % set final labels to be based in net labels
            obj.labelProbabilities = [score2(:,1),score2(:,end),score2(:,2:end-1)]; % switch 2nd and last dims
            [obj.testFolder,~,~] = fileparts(obj.testFolder); % change test folder back to base directory
        end 
        
        % Run class independent of GUI
        function run(obj)
            obj.getTestFolder();
            obj.setNet();
            obj.preprocessImages();
            obj.prepareImageDatastore();
            obj.getClassification();
        end
    end
end