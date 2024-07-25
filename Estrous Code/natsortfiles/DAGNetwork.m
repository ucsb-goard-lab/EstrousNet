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
        
        % Predict method to mimic DAGNetwork
        function labels = classify(obj, data)
            labels = predict(obj.Model, data);
        end
        
        % Display method to mimic DAGNetwork display
        function disp(obj)
            disp('Custom DAGNetwork for KNN Model:');
            disp('Layers:');
            disp(obj.Layers);
            disp('Connections:');
            disp(obj.Connections);
        end
    end
end