classdef DAGnetwork
    properties
        Model
        Layers
        Connections
    end
    
    methods
        % Constructor
        function obj = DAGnetwork(model, dag)
            if nargin > 0
                obj.Model = model;
                obj.Layers = dag.Layers; 
                obj.Connections = dag.Connections; 
            end
        end
        
        % Get classifications
        function [labels,score] = classify(obj, data)
            [labels,score] = predict(obj.Model, data);
        end
        
        % Display layers
        function disp(obj)
            disp('Custom DAGNetwork:');
            disp('Layers:');
            disp(obj.Layers);
            disp('Connections:');
            disp(obj.Connections);
        end
    end
end