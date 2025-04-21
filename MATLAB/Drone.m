classdef Drone < handle
    properties
        x = 0;
        y = 0;
        maxSpd % max speed in m/s
        target % the target the drone is heading to
        base % base of the drone 
        status = "idle" % status of the drone, possible status include: idle (for now)
    end

    methods
        function obj = Drone(maxSpd)
            obj.maxSpd = maxSpd;
        end

        % assign the drone to a base when it is instantiated
        % do not use in other circumstances 
        function setBase(obj, base)
            obj.base = base;

            % set drone's position to base position
            obj.x = base.x;
            obj.y = base.y;
        end
    end
end