classdef Drone < handle
    properties
        x = 0;
        y = 0;
        maxSpd % max speed in m/s
        targetX % the target the drone is heading to
        targetY % the target the drone is heading to
        base % base of the drone 
        status = "idle" % status of the drone, possible status include: idle, flight2target
        timeStep % time step size in s
    end

    methods
        function obj = Drone(maxSpd, timeStep)
            obj.maxSpd = maxSpd;
            obj.timeStep = timeStep;
        end

        % assign the drone to a base when it is instantiated
        % do not use in other circumstances 
        function setBase(obj, base)
            obj.base = base;

            % set drone's position to base position
            obj.x = base.x;
            obj.y = base.y;
        end

        function update(obj)
            if obj.status == "idle"
                return
            elseif obj.status == "flight2target"
                dx = obj.targetX - obj.x;
                dy = obj.targetY - obj.y;
                dist = sqrt(dx^2 + dy^2);
                travelDist = obj.maxSpd * obj.timeStep;
                ratio = travelDist / dist;
                newX = obj.x + dx * ratio;
                newY = obj.y + dy * ratio;

                % if the new position ends up in an overshoot, snap the
                % drone to target position
                if (obj.targetX - newX) * dx < 0
                    newX = obj.targetX;
                    newY = obj.targetY;
                    if obj.status == "flight2target"
                        obj.status = "extinguishing";
                    end
                end

                % update position
                obj.x = newX;
                obj.y = newY;
            end
        end

        function flight(obj)
        end

        function statusChangeFlight2Target(obj, targetX, targetY)
            obj.status = "flight2target";
            obj.targetX = targetX;
            obj.targetY = targetY;
        end
    end
end