classdef EstrousResNet50 < EstrousNet
    properties
    end

    methods
        function obj = EstrousResNet50()
            obj = obj@EstrousNet(resnet50);
        end

        function removeFinalLayers(obj)
            % remove layers from pretrained net
            obj.lgraph = obj.lgraph.removeLayers({'fc1000','fc1000_softmax','ClassificationLayer_fc1000'});
        end
    end
end