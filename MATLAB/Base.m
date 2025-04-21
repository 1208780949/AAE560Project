classdef Base < handle
    properties
        x % base x position in m
        y % base y position in m
        drones % a list of drones from this base
    end

    methods
        function obj = Base(x, y, drones)
            obj.x = x;
            obj.y = y;
            obj.drones = drones;
        end
    end
end