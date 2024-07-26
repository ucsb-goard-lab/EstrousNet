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
    %   Last updated 07/2024
    %-------------------------------------------------------------------------%
    properties
        class_opts
        trainedNet % imported to classifier
        testFolder
        rawImages
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
            obj.class_opts = {'diestrus','proestrus','metestrus','estrus'};
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
                single_mouse = regexprep(cellstr(obj.netLabels),obj.class_opts,...
                    {'1','2','4','3'}); % order switched to account for 'estrus' character overlap
            end
            single_mouse = str2num(cell2mat(single_mouse)); % convert to double

            % check for pseudopregnancy
            if obj.checkPseudopregnancy(single_mouse)
                warning('Abnormal cycle detected: your animal may be pseudopregnant.');
            end

            % find archetypal cycle that fits data
            possible_shifts = sampling_freq * length(unique(obj.netLabels));
            slope = 1/sampling_freq; % archetypal stage changes by 0.5 every sample
            cycle = 1:slope:length(unique(obj.netLabels));
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
            target_vec = repmat(1:4, 1, ceil(length(test_vec)/length(unique(obj.netLabels)) + sampling_freq)); % repeating template vector
            for t = 1:possible_shifts-1 % shift and check
                sim(t) = sum(test_vec == target_vec(t : (t - 1) +  length(test_vec))); % similarity between shifted & ideal vectors
            end

            [~, idx] = max(sim); % which offset forces the greatest similarity
            obj.cyclicityLabels = target_vec(min(idx) : (min(idx) - 1) + length(test_vec)); % numeric labels corrected for sequence

            cyclicityLabel_string = sprintfc('%d',obj.cyclicityLabels); % convert to cell array of strings
            obj.cyclicityLabels = categorical(regexprep(cyclicityLabel_string,{'1','2','4','3'},...
                obj.class_opts))'; % convert numerical to categorical labels
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

        function [processedImages] = preprocessImages(obj)
            if isempty(obj.testFolder)
                disp('Select test folder')
                obj.testFolder =  uigetdir('Select test folder');
            end

            addpath(obj.testFolder)
            test_names = [dir(fullfile(obj.testFolder, '*.jpg')); dir(fullfile(obj.testFolder, '*.png'));...
                dir(fullfile(obj.testFolder, '*.bmp')); dir(fullfile(obj.testFolder, '*.tif'));...
                dir(fullfile(obj.testFolder, '*.tiff'))];
            num_imds = length(test_names);

            obj.rawImages = imageDatastore(fullfile(obj.testFolder), 'LabelSource', 'foldernames', 'IncludeSubfolders', true);
            min_imsize = 100; % set size to crop to (reduce speed)
            desired_lum = 125; % set desired luminance
            processedImages = zeros(num_imds,min_imsize*min_imsize);
            for j = 1:num_imds
                imagePath = fullfile(obj.testFolder, test_names(j).name);
                img = imread(imagePath);

                % preprocess the image: convert to grayscale and resize
                if isstruct(img)
                    img = img.cdata; % if importing structural pngs
                end
                lum_diff = mean(mean(img, [1 2])) - desired_lum; % how far image is from desired luminance
                im_norm = img - lum_diff; % normalize luminance
                if size(im_norm,3) > 2 % for rgb images
                    im_grey = 0.2989 * im_norm(:,:,1) + 0.5870 * im_norm(:,:,2)...
                        + 0.1140 * im_norm(:,:,3); % convert to greyscale (rgb2grey doesn't work for 4pg tiff)
                else
                    im_grey = uint8(im_norm); % convert to image format
                end
                rescale_factor = min_imsize/min(size(im_grey)); % factor to rescale by
                im_rescaled = imresize(im_grey,rescale_factor); % rescale
                im_cropped = im_rescaled(1:min_imsize,1:min_imsize); % crop
                processedImages(j,:) = double(im_cropped(:)'); % store
            end
        end

        function getClassification(obj,processedImages)
            [obj.netLabels, score2] = obj.trainedNet.classify(processedImages); % run net
            obj.netLabels = regexprep(cellstr(num2str(obj.netLabels)),{'1','4','3','2'},...
                obj.class_opts); % transform numerical to strings
            obj.finalLabels = obj.netLabels; % set final labels to be based in net labels
            obj.labelProbabilities = [score2(:,1),score2(:,end),score2(:,2:end-1)]; % switch 2nd and last dims
            [obj.testFolder,~,~] = fileparts(obj.testFolder); % change test folder back to base directory
        end

        % Run class independent of GUI
        function run(obj)
            obj.getTestFolder();
            obj.setNet();
            obj.preprocessImages();
            obj.getClassification();
        end
    end
end