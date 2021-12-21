classdef EstrousNet < handle
    properties
        net
        lgraph
    end
    
    methods
        function obj = EstrousNet(net)
            obj.net = net;
            if length(net.Layers) == 47 % vgg19 layer input requires different indexing
                obj.lgraph = layerGraph(obj.net.Layers);
            else
                obj.lgraph = layerGraph(obj.net);
            end
            obj.removeFinalLayers();
        end

        function removeFinalLayers(obj)
            %overloaded in subclasses
        end

        function addNewLayers(obj, numClasses)
            % add in our layers here
            fcLayer = fullyConnectedLayer(numClasses,'Name','fc','WeightLearnRateFactor',10,'BiasLearnRateFactor',10);
            smLayer = softmaxLayer('Name', 'softmax');
            cLayer = classificationLayer('Name', 'output');
            obj.lgraph = obj.lgraph.addLayers(cat(2, fcLayer, smLayer, cLayer));
            if strcmp(cell2mat(obj.net.OutputNames),'ClassificationLayer_Logits') % adjust for classification layer type
                obj.lgraph = obj.lgraph.connectLayers('global_average_pooling2d_1', 'fc'); % for mobilenetv2
            elseif length(obj.net.Layers) == 47 % for vgg19
                obj.lgraph = obj.lgraph.connectLayers('drop7', 'fc');
            else
                obj.lgraph = obj.lgraph.connectLayers('avg_pool', 'fc');
            end
        end

         function out = getNet(obj)
            out = obj.net;
        end

        function out = getLGraph(obj)
            out = obj.lgraph();
        end

        function out = getInputSize(obj)
            % get input size of net to resize images as necessary 
            inputSize = obj.net.Layers(1).InputSize;
            out = inputSize(1:2);
        end
    end
end