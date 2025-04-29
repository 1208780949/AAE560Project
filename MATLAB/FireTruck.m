classdef FireTruck < handle
    properties
        Location %spawn location (city center)
        TargetLocation %initial target location of fire grid
        Speed % [m/s]
        Status % 'Targeting', 'Extinguishing', 'Returning', 'Refueling'
        DispatchDelay % [seconds]
        TimeSinceDispatched % [seconds]

        FuelCapacity = 245*11 % [Liters] max fuel capacity
        FuelRemaining = 245*11 % [Liters] remaining fuel
        FuelConsumptionRate = (58.79E-5)*11 % [Liters/m] fuel usage per meter traveled (~4 mpg)
        FuelUsed = 0 % [Liters] cumulative fuel used by this truck
        RefuelCost = 0 % [USD] cumulative refuel cost

        WaterCapacity = 3785*11 % [Liters] total water capacity
        WaterRemaining = 3785*11 % [Liters] remaining water
        WaterUsagePerGrid = 40800 % [Liters/fire extinguished]

        ExtinguishTime = 30 % [seconds] time to extinguish each fire grid
        ExtinguishTimer = 0 % [seconds]

        RefuelTime = 20 % [seconds]
        RefuelTimer = 0 % [seconds]
    end

    methods

        %constructor function for FireTruck creation
        function obj = FireTruck(startLocation, targetLocation, dispatchDelay)
            obj.Location = startLocation;
            obj.TargetLocation = targetLocation;
            obj.Status = 'Targeting';
            obj.DispatchDelay = dispatchDelay;
            obj.TimeSinceDispatched = 0;
        end

        %move truck toward fire grid target determined by City.m
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

                %update fuel usage
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

        %check if truck has arrived at its target
        function arrived = isAtTarget(obj)
            arrived = norm(obj.Location - obj.TargetLocation) < 1;
        end

        %search for nearby fire grid points
        function found = findNearbyFire(obj, fireObj, searchRadius)
            found = false;
            for i = 1:size(fireObj.firePoints,2)
                gridX = fireObj.firePoints(1,i);
                gridY = fireObj.firePoints(2,i);
                firePos = fireObj.getGridCenterPoint(gridX, gridY);

                dist = norm(firePos - obj.Location);
                if dist <= searchRadius
                    obj.TargetLocation = firePos;
                    found = true;
                    return
                end
            end
        end

        %refuel and refill water
        function refuel(obj)
            obj.FuelRemaining = obj.FuelCapacity;
            obj.WaterRemaining = obj.WaterCapacity;
            obj.RefuelTimer = 0;
        end

        %update truck speed depending on city zone
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
