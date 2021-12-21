classdef EstrousInceptionNet < EstrousNet
    properties
    end

    methods
        function obj = EstrousInceptionNet()
            obj = obj@EstrousNet(inceptionv3);
        end

        function removeFinalLayers(obj)
            obj.lgraph = obj.lgraph.removeLayers({'predictions','predictions_softmax','ClassificationLayer_predictions'});
        end
    end
end