classdef Base < handle
    % fire retardant cost: $3/gal = $0.727/kg
    % https://www.frontlinewildfire.com/wildfire-news-and-resources/aerial-wildfire-fighting-how-effective-is-it/
    %
    % Electricity cost in CA: 26.84 cents/kWh
    % https://www.electricchoice.com/electricity-prices-by-state/

    properties
        x % base x position in m
        y % base y position in m
        idleDrones % a list of idling drones from this base (idle really mean ready for mission)
        activeDrones % list of drones performing some sort of action
        activeToIdleDrones % a list of drones that need to go from active to idle in the next time step
        fires % list of fires
        targetedFire % list of fire grid pts that has already been targeted (local)
        currentTime % current time of simulation
        powerUsed = 0 % total power consumption in watt-hour
        retardantUsed = 0 % total retardant used in kg
        upfrontCost = 0 % cost for equipment in USD

        % cost
        fireRetardantCost = 0.727; % fire retardant cost $/kg
        elecCost = 0.02684; % $/kWh

        FireManager % shared fire assignment tracker
    end

    methods
        % constructor
        % x: base x position in m
        % y: base y position in m
        % drones: list of drones belonging to this base
        function obj = Base(x, y, drones, fireManager)
            obj.x = x;
            obj.y = y;
            obj.idleDrones = drones;
            obj.activeDrones = Drone.empty(0, length(drones));
            obj.FireManager = fireManager;
            obj.targetedFire = []; % still used locally for fire index management
        end

        % update list of fires
        function setFire(obj, fire)
            obj.fires = [obj.fires fire];
        end

        % update the base: responsible for mission assignment
        function update(obj, currentTime)
            obj.currentTime = currentTime;

            % move drones from activeToIdle to idle
            if ~isempty(obj.activeToIdleDrones)
                for i = 1:length(obj.activeToIdleDrones)
                    obj.activeDrones(obj.activeDrones == obj.activeToIdleDrones(i)) = [];
                end
                obj.idleDrones = [obj.idleDrones obj.activeToIdleDrones];
                obj.activeToIdleDrones = [];
            end

            % ** drone job assignment (make this the last action) **

            % if there are no more idle drones left, skip task assignment            
            if isempty(obj.idleDrones)
                return
            end

            stateChangeDrones = Drone.empty(0, 0);

            for i = 1:length(obj.fires)
                fire = obj.fires(i);

                for j = 1:fire.getNumPoint
                    firePoint = fire.firePoints(:,j);
                    gridIndex = [firePoint(1); firePoint(2)];

                   % if this grid point has already been targeted by a
                   % drone, skip this fire
                    if obj.FireManager.isAssigned(gridIndex)
                        continue
                    end

                    if length(stateChangeDrones) >= length(obj.idleDrones)
                        break
                    end

                    drone = obj.idleDrones(length(stateChangeDrones) + 1);
                    gridCenter = fire.getGridCenterPoint(firePoint(1), firePoint(2));
                    drone.statusChangeFlight2Target(gridCenter(1), gridCenter(2), fire, j);

                    obj.activeDrones = [obj.activeDrones drone];
                    stateChangeDrones = [stateChangeDrones drone];
                    obj.FireManager.addAssignment(gridIndex);
                    obj.targetedFire = [obj.targetedFire j];
                end
            end

            if ~isempty(stateChangeDrones)
                for i = 1:length(stateChangeDrones)
                    obj.idleDrones(obj.idleDrones == stateChangeDrones(i)) = [];
                end
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
            for i = 1:length(obj.activeDrones)
                drone = obj.activeDrones(i);
                if drone.targetFireIndex > index
                    drone.targetFireIndex = drone.targetFireIndex - 1;
                end
            end
        end

        % a drone has finished its mission and charging
        % it can be considered idle again
        function droneReady(obj, drone)
            obj.activeToIdleDrones = [obj.activeToIdleDrones drone];
        end

        function cost = getRetardantCost(obj)
            cost = obj.retardantUsed * obj.fireRetardantCost;
        end

        function cost = getElecCost(obj)
            cost = obj.powerUsed / 1000 * obj.elecCost;
        end

        function cost = getOperationalCost(obj)
            cost = obj.getRetardantCost() + obj.getElecCost();
        end

        function cost = getTotalCost(obj)
            cost = obj.getOperationalCost + obj.upfrontCost;
        end
    end
end
