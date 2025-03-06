classdef EstrousNetTrainer < handle
    %% EstrusNetTrainer.m
    %-------------------------------------------------------------------------%
    %   This class uses a transfer learning algorithm to identify the four
    %   different stages of the rodent estrous cycle. The base architecture is
    %   modular, and can be prespecified by the user. 
    %
    %   Notes:
    %
    %   'getData' When pulling images from files, images must be sorted into
    %    folders by class name. Intermediate categories may be added if they
    %    correspond with a new training set. Training and validation
    %    directories defined in getTrainFolder and getValidationFolder,
    %    respectively.
    %
    %   'setNetwork' Preset to ResNet50 for highest accuracy, but
    %    inceptionv3, mobilenetv2, and vgg-16 are also accepted. 
    %
    %   'getAugmentedDS' Relevant augmentation parameters included (Rotation, 
    %    X and Y Reflection, Scaling, and Translation). More or less 
    %    augmentation may be used for greater efficacy or efficiency, 
    %    respectively. Options specified via EstrousNetGUI.mlapp. 
    %
    %   'setTrainingOptions' Solver automatically adjusts learning rate. Higher
    %    initial learning rates reduce accuracy in ResNet50. Epoch number small
    %    due to large amount of data; adjust to optimize.
    %
    %
    %   Written by Nora Wolcott May 2020
    %   Last updated 08/2021
    %-------------------------------------------------------------------------%
    properties
        trainFolder
        validationFolder
        trainingDS
        validationDS
        
        net
        options
        trainedNet
        
        augmenter_opts
    end
    
    methods
        
        %% Instantiate the object
        function obj = EstrousNetTrainer()
        end
        
        function getTrainFolder(obj,trainFolder)
            if nargin < 2 || isempty(trainFolder)
                fprintf('Choose your folder containing training data: \n')
                obj.trainFolder = uigetdir('','Select training folder');
            end
        end
        
        function getValidationFolder(obj, validationFolder)
            if nargin < 2 || isempty(validationFolder)
                fprintf('Choose your folder containing validation data: \n')
                [basedir,~,~] = fileparts(obj.trainFolder);
                obj.validationFolder = uigetdir(basedir,'Select validation folder');
            end
            
            [obj.trainingDS, obj.validationDS] = obj.getData(obj.trainFolder,obj.validationFolder);
        end
        
        function [trainingDS, validationDS] = getData(obj, trainFolder, validationFolder)
            % Get raw data from files
            subfolders = dir(fullfile(trainFolder,'*'));
            classes = {subfolders(3:end).name}; % labels from subfolder names
            trainingDS = imageDatastore(fullfile(trainFolder, classes), 'LabelSource', 'foldernames');
            validationDS = imageDatastore(fullfile(validationFolder, classes), 'LabelSource', 'foldername');
        end
        
        %% Specify the pretrained network
        function setNetwork(obj, network_choice)
            if nargin < 2 || isempty(network_choice)
                network_choice = obj.queryNetwork({'resnet50', 'inceptionv3', 'vgg19','mobilenetv2'});
            end
            
            % choose your network
            switch network_choice
                case 'resnet50'
                    network = EstrousResNet50();
                case 'inceptionv3'
                    network = EstrousInceptionNet();
                case 'vgg19'
                    network = EstrousVGGNet();
                case 'mobilenetv2'
                    network = EstrousMobileNet();
                otherwise
                    error(sprintf('''%s'' is not yet integrated.'), network_choice)
            end
            
            fprintf('Using ''%s''\n', network_choice)
            obj.net = network; % old layers are automatically removed
            numClasses = numel(categories(obj.trainingDS.Labels));
            obj.net.addNewLayers(numClasses);  % this is so you can pass in classes
        end
        
        function out = queryNetwork(obj, networks)
            idx = listdlg('PromptString', 'Choose your network:', 'SelectionMode', 'single', 'ListString', networks);
            out = networks{idx};
        end
        
        function out =  getAugmentedDS(obj, input_ds)
            % augmenter parameter input specified in
            % EstrousNetTrainNewNet.mlapp
             imageAugmenter = imageDataAugmenter( ...
                'RandXReflection', obj.augmenter_opts.ref_inpt, ...
                'RandYReflection',obj.augmenter_opts.ref_inpt,...
                'RandXScale',obj.augmenter_opts.scale_inpt,...
                'RandYScale',obj.augmenter_opts.scale_inpt,...
                'RandRotation',obj.augmenter_opts.rot_inpt,...
                'RandXTranslation',obj.augmenter_opts.trans_inpt, ...
                'RandYTranslation',obj.augmenter_opts.trans_inpt);
            
            out = augmentedImageDatastore(obj.net.getInputSize(), input_ds,...
                'DataAugmentation',imageAugmenter);
        end
        
        function setAugmentationOptions(obj, augmenter_opts)
            obj.augmenter_opts = augmenter_opts;
        end
        
        %% Set training options
        % Adjust settings based on network preference
        % Current best opts determined by bayesian optimization in ResNet50
        function setTrainingOptions(obj, force_gpu)
            if nargin < 2 || isempty(force_gpu)
                force_gpu = false;
            end
            
            % check to see if GPU is available for training
            useGPU = obj.checkGPU(force_gpu);
            
            switch useGPU
                case true
                    ex_env = 'gpu';
                case false
                    ex_env = 'cpu';
            end
            
            fprintf('Augmenting datastore...\n')
            
            obj.options = trainingOptions('rmsprop', ...
                'InitialLearnRate',1e-5, ... %% 1e-7
                'SquaredGradientDecayFactor',0.99, ... 
                'MaxEpochs',3, ...
                'MiniBatchSize',32, ... 
                'Plots','training-progress', ...
                'ValidationData', obj.getAugmentedDS(obj.validationDS), ...
                'ExecutionEnvironment', ex_env, ...
                'Shuffle','every-epoch');
            
            %                 'LearnRateSchedule','piecewise', ... 
%                 'LearnRateDropFactor',0.1, ... 
%                 'LearnRateDropPeriod',1, ... %% learning rate reduced by a factor of 0.1 every epoch
        end
        
        %% Train network
        function out = train(obj, save_flag)
            if nargin < 2 || isempty(save_flag)
                save_flag = true;
            end
            disp('Training network...')
            [out,info] = trainNetwork(obj.getAugmentedDS(obj.trainingDS), obj.net.getLGraph(), obj.options);
            obj.trainedNet = out;
            
            if save_flag
                trainedNet = obj.trainedNet;
                save(strcat(date, '_trainedNet.mat'), 'trainedNet');
                save(strcat(date, '_netInfo.mat'), 'info');
            end
        end
        
        
        function out = checkGPU(obj, force_gpu)
            isgpu = gpuDeviceCount(); % see if device has a gpu
            
            if isgpu > 0
                gpu = gpuDevice();
                
                if isempty(gpu)
                    fprintf('No GPU detected, using CPU only.\n')
                    out = false;
                    return
                end
                
                if force_gpu
                    fprintf('Forcing GPU (not recommended).')
                    out = true;
                    % check if GPU has requisite storage space 
                elseif gpu.AvailableMemory < 4e09
                    fprintf('GPU detected but not powerful enough to use. If you want to use this GPU, force GPU usage (obj.setTrainingOptions(true)).\n')
                    out = false;
                else
                    fprintf('GPU detected and will be used.\n')
                    out = true;
                    
                end
            else
                out = false;
            end
        end
    end
end