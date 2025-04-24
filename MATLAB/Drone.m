classdef Drone < handle
    % drones are assumed to be Alta X
    % https://freefly-prod.s3-us-west-2.amazonaws.com/support/alta-x-brochure-v2.pdf
    % https://freefly.gitbook.io/freefly-public/products/alta-x/untitled-3/performance-specs
    %
    % They are already in use for aerial ignition with US Forest Service
    % https://www.fs.usda.gov/inside-fs/delivering-mission/deliver/drones-help-make-fighting-fires-safer-cheaper-better
    %
    % max payload: 15.9 kg
    % flight time at max payload: 10.75 minutes
    % flight time when empty: 50 minutes
    % max speed: 20 m/s
    % battery capacity: 32 Amp-Hour

    properties
        x = 0;
        y = 0;
        maxSpd % max speed in m/s
        targetX % the target the drone is heading to
        targetY % the target the drone is heading to
        base % base of the drone 
        status = "idle" % status of the drone, possible status include: idle, flight2target, extinguishing, return2base
        timeStep % time step size in s
        size = 2568; % each drone object represents 2568 drones, the minimum required to extinguish fire at 1 grid point
        taskFinishTime % the time for when a task will be finished for time based tasks (like extinguishing)
        extinguishTime % time it takes to extinguish a grid point of fire
        targetFire % the fire object that the drone is targeting
        targetFireIndex % the index of target fire. Only keeping track to that the base knows which fire has been extinguished
    end

    methods
        function obj = Drone(maxSpd, timeStep, extinguishTime)
            obj.maxSpd = maxSpd;
            obj.timeStep = timeStep;
            obj.extinguishTime = extinguishTime;
        end

        % assign the drone to a base when it is instantiated
        % do not use in other circumstances 
        function setBase(obj, base)
            obj.base = base;

            % set drone's position to base position
            obj.x = base.x;
            obj.y = base.y;
        end

        % update the drone
        % if it's idling, do nothing
        % if it's flight2target or return2base, update position
        % if it's extinguishing, continue to extinguish until done then fly
        % home
        function update(obj)
            if obj.status == "idle"
                return
            elseif obj.status == "flight2target" || obj.status == "return2base"
                % calculate new position of the drone if it keeps flying
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
                        obj.taskFinishTime = obj.base.currentTime + 10;
                    elseif obj.status == "return2base"
                        obj.status = "charging";
                    end
                end

                % update position
                obj.x = newX;
                obj.y = newY;

            elseif obj.status == "extinguishing"
                
                if obj.base.currentTime > obj.taskFinishTime
                    obj.targetFire.extinguish(obj.targetX, obj.targetY)
                    obj.status = "return2base";
                    obj.targetX = obj.base.x;
                    obj.targetY = obj.base.y;
                    obj.targetFire = [];

                    obj.base.fireExtinguished(obj.targetFireIndex);
                end

            end
        end

        % drone has just been given a job
        function statusChangeFlight2Target(obj, targetX, targetY, fire, index)
            obj.status = "flight2target";
            obj.targetX = targetX;
            obj.targetY = targetY;
            obj.targetFire = fire;
            obj.targetFireIndex = index;
        end
    end
end