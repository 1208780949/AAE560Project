classdef Airport < handle
    properties
        x % base x position in m
        y % base y position in m
        idleHelicopters % a list of idling drones from this base (idle really mean ready for mission)
        activeHelicopters % list of drones performing some sort of action
        activeToIdleHelis % a list of drones that need to go from active to idle in the next time step
        fires % list of fires
        currentTime % current time of simulation
        fuelUsed = 0 % total power consumption in watt-hour
        operationalCost = 0 % total retardant used in kg
        upfrontCost = 0 % cost for equipment in USD
        FireManager % reference to the centralized FireManager
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

        % set the shared FireManager
        function setFireManager(obj, fm)
            obj.FireManager = fm;
        end

        % update the base
        % responsible for mission assignment
        function update(obj, currentTime)

            % update time
            obj.currentTime = currentTime;

            % ** turn applicable active drones to idle drones **

            if ~isempty(obj.activeToIdleHelis)
                for i = 1:length(obj.activeToIdleHelis)
                    obj.activeHelicopters(obj.activeHelicopters == obj.activeToIdleHelis(i)) = [];
                end
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

                    firePoint = fire.firePoints(:,j);
                    idx = obj.FireManager.getIndexFromPoint(firePoint(1), firePoint(2));

                    if obj.FireManager.isAssigned(idx)
                        continue
                    end

                    if length(stateChangeHelis) >= length(obj.idleHelicopters)
                        break
                    end

                    drone = obj.idleHelicopters(length(stateChangeHelis) + 1);
                    gridCenter = fire.getGridCenterPoint(firePoint(1), firePoint(2));
                    drone.statusChangeFlight2Prep(fire, idx, gridCenter(1), gridCenter(2));
                    obj.activeHelicopters = [obj.activeHelicopters drone];
                    stateChangeHelis = [stateChangeHelis drone];
                    obj.FireManager.addAssignment(idx);
                end
            end

            if ~isempty(stateChangeHelis)
                for i = 1:length(stateChangeHelis)
                    obj.idleHelicopters(obj.idleHelicopters == stateChangeHelis(i)) = [];
                end
            end

        end

        % fire extinguished
        function fireExtinguished(obj, ~)
            % FireManager now handles all targeting status
        end

        % a drone has finished its mission and charging
        % it can be considered idle again
        function heliReady(obj, helicopter)
            obj.activeToIdleHelis = [obj.activeToIdleHelis helicopter];
        end
    end
end
