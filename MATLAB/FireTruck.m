classdef FireTruck < handle
    properties
        % based on 2025 Spartan Water Tender

        TrucksPerGroup = 8; % number of actual trucks represented by this object

        Location % spawn location (city center)
        TargetLocation % initial target location of fire grid
        TargetGridIndex % [gridX, gridY] index of the assigned fire grid
        Speed % [m/s]
        Status % 'Targeting', 'Extinguishing', 'Returning', 'Refueling'
        DispatchDelay % [seconds]
        TimeSinceDispatched % [seconds]

        FuelCapacity
        FuelRemaining
        FuelConsumptionRate % [Liters/m] fuel usage per meter traveled (~4 mpg)
        FuelUsed = 0 % [Liters] cumulative fuel used by this truck
        RefuelCost = 0 % [USD] cumulative refuel cost

        WaterCapacity
        WaterRemaining
        WaterUsagePerGrid % [Liters/fire extinguished]
        WaterCostRate = 0.0150643; % [$/L] water cost for commercial use in Indiana converted from $/1000gal to $/L
        WaterRefillCost = 0; % [$] total cost of water refills
        
        PumpRate = 63.1 % [L/s]
        ExtinguishTime % [seconds]
        ExtinguishTimer = 0 % [seconds]

        RefuelRate = 50 %[L/s]
        RefuelTime % [seconds]
        RefuelTimer = 0 % [seconds]

    end

    methods
        % constructor function for FireTruck creation
        function obj = FireTruck(startLocation, targetLocation, dispatchDelay)
            obj.Location = startLocation;
            obj.TargetLocation = targetLocation;
            obj.Status = 'Targeting';
            obj.DispatchDelay = dispatchDelay;
            obj.TimeSinceDispatched = 0;

            % Scale properties according to TrucksPerGroup
            obj.FuelCapacity = 245 * obj.TrucksPerGroup;
            obj.FuelRemaining = obj.FuelCapacity;
            obj.FuelConsumptionRate = 58.79e-5 * obj.TrucksPerGroup; % ~4 mpg
            obj.WaterCapacity = 3785 * obj.TrucksPerGroup;
            obj.WaterRemaining = obj.WaterCapacity;
            obj.WaterUsagePerGrid = obj.WaterCapacity; % all water used per fire grid
            obj.ExtinguishTime = obj.WaterCapacity/(obj.TrucksPerGroup*obj.PumpRate);
        end

        % move truck toward fire grid target determined by City.m
        function moveTowardTarget(obj, dt)
            obj.TimeSinceDispatched = obj.TimeSinceDispatched + dt;

            if obj.TimeSinceDispatched < obj.DispatchDelay
                return
            end

            direction = obj.TargetLocation - obj.Location;
            distance = norm(direction);

            if distance < 1e-3
                obj.Location = obj.TargetLocation;
            else
                step = obj.Speed * dt;
                if step >= distance
                    moveDist = distance;
                    obj.Location = obj.TargetLocation;
                else
                    direction = direction / distance;
                    moveDist = step;
                    obj.Location = obj.Location + direction * moveDist;
                end

                % update fuel usage
                fuelUsedNow = moveDist * obj.FuelConsumptionRate;
                obj.FuelRemaining = obj.FuelRemaining - fuelUsedNow;
                obj.FuelUsed = obj.FuelUsed + fuelUsedNow;

                if obj.FuelRemaining <= 0
                    obj.FuelRemaining = 0;
                    obj.TargetLocation = obj.Location;
                    obj.Status = 'Returning';
                end
            end
        end

        % check if truck has arrived at its target
        function arrived = isAtTarget(obj)
            arrived = norm(obj.Location - obj.TargetLocation) < 1;
        end

        % search for nearby fire grid points
        function found = findNearbyFire(obj, fireObj, searchRadius)
            found = false;
            for i = 1:size(fireObj.firePoints,2)
                gridX = fireObj.firePoints(1,i);
                gridY = fireObj.firePoints(2,i);
                firePos = fireObj.getGridCenterPoint(gridX, gridY);

                dist = norm(firePos - obj.Location);
                if dist <= searchRadius
                    obj.TargetLocation = firePos;
                    obj.TargetGridIndex = [gridX, gridY];
                    found = true;
                    return
                end
            end
        end

        % refuel and refill water
            function refuel(obj)
                obj.FuelRemaining = obj.FuelCapacity;
                obj.WaterRemaining = obj.WaterCapacity;
                obj.WaterRefillCost = obj.WaterRefillCost + obj.WaterCapacity * obj.WaterCostRate;
                obj.RefuelTimer = 0;
            end

        % update truck speed depending on city zone
        function updateSpeedBasedOnZone(obj, city)
            [zoneIdx, ~] = city.getZone(obj.Location);

            if zoneIdx <= length(city.ZoneSpeeds)
                obj.Speed = city.ZoneSpeeds(zoneIdx);
            else
                obj.Speed = 25;
            end
        end
    end
end
