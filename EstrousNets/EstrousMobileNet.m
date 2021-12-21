classdef EstrousMobileNet < EstrousNet
    properties
    end

    methods
        function obj = EstrousMobileNet()
            obj = obj@EstrousNet(mobilenetv2);
        end

        function removeFinalLayers(obj)
            obj.lgraph = obj.lgraph.removeLayers({'Logits','Logits_softmax','ClassificationLayer_Logits'});
        end
    end
end