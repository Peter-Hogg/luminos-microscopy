classdef Sutter_MP285A_Initializer < Linear_Controller_Initializer
    properties
        COMPORT string
    end
    methods
        function obj = Sutter_MP285A_Initializer()
            obj@Linear_Controller_Initializer();
        end
    end
end
