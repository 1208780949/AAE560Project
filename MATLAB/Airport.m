classdef Airport < handle
    properties
        x % base x position in m
        y % base y position in m
        idleHelicopters % a list of idling drones from this base (idle really mean ready for mission)
        activeHelicopters % list of drones performing some sort of action
        activeToIdleHelis % a list of drones that need to go from active to idle in the next time step
        fires % list of fires
        targetedFire % list of fire grid pts that has already been targeted
        currentTime % current time of simulation
        powerUsed = 0 % total power consumption in watt-hour
        retardantUsed = 0 % total retardant used in kg
        upfrontCost = 0 % cost for equipment in USD
    end

    methods
        % constructor
        % x: base x position in m
        % y: base y position in m
        % drones: list of drones belonging to this base
        function obj = Airport(x, y, helicopters)
            obj.x = x;
            obj.y = y;
            obj.idleHelicopters = helicopters;
            obj.activeHelicopters = Helicopter.empty(0, length(helicopters));
        end

        % update list of fires
        function setFire(obj, fire)
            obj.fires = [obj.fires fire];
        end

        % update the base
        % responsible for mission assignment
        function update(obj, currentTime)

            % update time
            obj.currentTime = currentTime;

            % ** turn applicable active drones to idle drones **

            if ~isempty(obj.activeToIdleHelis)
                obj.activeHelicopters(obj.activeHelicopters == obj.activeToIdleHelis) = [];
                obj.idleHelicopters = [obj.idleHelicopters obj.activeToIdleHelis];
                obj.activeToIdleHelis = [];
            end

            % ** drone job assignment (make this the last action) **

            % if there are no more idle drones left, skip task assignment
            if isempty(obj.idleHelicopters)
                return
            end

            stateChangeHelis = Helicopter.empty(0, 0);

            for i = 1:length(obj.fires)

                fire = obj.fires(i);

                for j = 1:fire.getNumPoint

                    if ismember(j, obj.targetedFire)
                        % if this grid point has already been targeted by a
                        % drone, skip this fire
                        continue
                    end

                    if length(stateChangeHelis) >= length(obj.idleHelicopters)
                        break
                    end

                    firePoint = fire.firePoints(:,j);

                    drone = obj.idleHelicopters(length(stateChangeHelis) + 1);
                    gridCenter = fire.getGridCenterPoint(firePoint(1), firePoint(2));
                    drone.statusChangeFlight2Prep(fire, j, gridCenter(1), gridCenter(2));
                    obj.activeHelicopters = [obj.activeHelicopters drone];
                    stateChangeHelis = [stateChangeHelis drone];
                    obj.targetedFire = [obj.targetedFire j];
                end
            end
            
            if ~isempty(stateChangeHelis)
                obj.idleHelicopters(obj.idleHelicopters == stateChangeHelis) = [];
            end

        end
    
        % fire extinguished. Remove the index from targetedFire array
        function fireExtinguished(obj, index)
            [~, loc] = ismember(index, obj.targetedFire);
            obj.targetedFire(loc) = [];

            % update target list here
            for i = 1:length(obj.targetedFire)
                j = obj.targetedFire(i);
                if j > index
                    obj.targetedFire(i) = obj.targetedFire(i) - 1;
                end
            end

            % update the target list tracked by the drone
            for i = 1:length(obj.activeHelicopters)
                drone = obj.activeHelicopters(i);
                if drone.targetFireIndex > index
                    drone.targetFireIndex = drone.targetFireIndex - 1;
                end
            end
        end
    
        % a drone has finished its mission and charging
        % it can be considered idle again
        function droneReady(obj, drone)
            obj.activeToIdleHelis = [obj.activeToIdleHelis drone];
        end
    end
end