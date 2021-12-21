classdef EstrousVGGNet < EstrousNet
    properties
    end

    methods
        function obj = EstrousVGGNet()
           obj = obj@EstrousNet(vgg19);
        end

        function removeFinalLayers(obj)
            obj.lgraph = obj.lgraph.removeLayers({'fc8','prob','output'}); % remove final layers; must change for new net
        end
    end
end