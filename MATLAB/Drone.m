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
    % battery capacity: 32 Amp-Hour (2x16)
    %  - 0.0496124031 Amp-Hour/s with max payload
    %  - 0.01066666666 Amp-Hour/s with no payload
    %
    % Fast charger is available that charges at 800W
    % 32 Amp-Hour at 44.4 V is 1420.8 Watt-Hour
    % Therefore, empty battery will take 106.56 minutes to charge.
    % That is 0.005 amp-hour/sec.


    properties
        % drone properties
        maxSpd = 20 % max speed in m/s
        extinguishTime = 10% time it takes to extinguish a grid point of fire
        timeStep % time step size in s
        base % base of the drone 
        swarmSize = 2568; % each drone object represents 2568 drones, the minimum required to extinguish fire at 1 grid point
        batterySize = 32; % amp-hour
        battConsMaxPayload = 0.0496124031; % battery consumption in amp-hour/s with max payload
        battConsNoPayload = 0.01066666666; % battery consumption in amp-hour/s with no payload
        chargeRate = 0.005; % amp-hour/sec
        batteryVoltage = 44.4; % volts
        batteryInstallTime = 120; % assume that it 60 seconds to uninstall and install the battery 
        maxPayload = 15.9; % kg
        upfrontCost = 28150 + 690 * 2 + 1150; % 1x drone - $28150, 2x 16 Ah batteries - $690x2, 1x charging station - $1150
        
        % status
        x = 0;
        y = 0;
        status = "idle" % status of the drone, possible status include: idle, flight2target, extinguishing, return2base, charging, and crashed.
        currentBattery % battery remaining in amp-hour
        statusStartTime % when status changed to the current status

        % mission
        targetX % the target the drone is heading to
        targetY % the target the drone is heading to
        taskFinishTime % the time for when a task will be finished for time based tasks (like extinguishing) 
        targetFire % the fire object that the drone is targeting
        targetFireIndex % the index of target fire. Only keeping track to that the base knows which fire has been extinguished
    end

    methods
        function obj = Drone(timeStep)
            obj.timeStep = timeStep;
            obj.currentBattery = obj.batterySize;
        end

        % assign the drone to a base when it is instantiated
        % do not use in other circumstances 
        function setBase(obj, base)
            obj.base = base;

            % set drone's position to base position
            obj.x = base.x;
            obj.y = base.y;

            % track upfront cost
            base.upfrontCost = base.upfrontCost + obj.upfrontCost * obj.swarmSize;
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
                        % update battery
                        timeSpent = obj.base.currentTime - obj.statusStartTime;
                        obj.currentBattery = obj.currentBattery - timeSpent * obj.battConsMaxPayload;
                        
                        % switch to extinguishing
                        obj.status = "extinguishing";
                        obj.taskFinishTime = obj.base.currentTime + 10;
                        obj.statusStartTime = obj.base.currentTime;
                    elseif obj.status == "return2base"
                        % battery remaining
                        timeSpent = obj.base.currentTime - obj.statusStartTime;
                        obj.currentBattery = obj.currentBattery - timeSpent * obj.battConsNoPayload;

                        % go to charge
                        obj.status = "charging";
                        obj.taskFinishTime = (obj.batterySize - obj.currentBattery) / obj.chargeRate + obj.batteryInstallTime + obj.base.currentTime;
                        obj.base.powerUsed = obj.base.powerUsed + (obj.batterySize - obj.currentBattery) * obj.batteryVoltage * obj.swarmSize;
                    end
                end

                % update position
                obj.x = newX;
                obj.y = newY;

            elseif obj.status == "extinguishing"
                
                if obj.base.currentTime > obj.taskFinishTime
                    % going back home
                    obj.targetFire.extinguish(obj.targetX, obj.targetY)
                    obj.status = "return2base";
                    obj.targetX = obj.base.x;
                    obj.targetY = obj.base.y;
                    obj.targetFire = [];
                    obj.statusStartTime = obj.base.currentTime;
                    
                    % let base know
                    obj.base.fireExtinguished(obj.targetFireIndex);

                    % update battery
                    % consumption rate is the average between max and no payload
                    obj.currentBattery = obj.currentBattery - 10 * ((obj.battConsMaxPayload + obj.battConsNoPayload) / 2);

                    % track total retardant dropped
                    obj.base.retardantUsed = obj.base.retardantUsed + obj.maxPayload * obj.swarmSize;
                end
                
            elseif obj.status == "charging"
                
                if obj.base.currentTime > obj.taskFinishTime
                    % going to idle
                    obj.status = "idle";
                    obj.currentBattery = obj.batterySize;
                    obj.base.droneReady(obj);
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
            obj.statusStartTime = obj.base.currentTime;
        end

        % include electricty used for in-progress flights at the end
        function finalTally(obj)
            if obj.status == "charging"
                return
            end

            obj.base.powerUsed = obj.base.powerUsed + (obj.batterySize - obj.currentBattery) * obj.batteryVoltage * obj.swarmSize;
        end
    end
end