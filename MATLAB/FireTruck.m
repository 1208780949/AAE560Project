classdef FireTruck < handle
    properties
        Location %spawn location (city center)
        TargetLocation %initial target location of fire grid
        Speed = 15 % [m/s]
        Status % 'Targeting', 'Extinguishing', 'Returning', 'Idle'
        DispatchDelay % [seconds]
        TimeSinceDispatched % [seconds]
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
            obj.TimeSinceDispatched = obj.TimeSinceDispatched + dt; %update time waited

            if obj.TimeSinceDispatched < obj.DispatchDelay %truck waits at city center until dispatch time exceeds response time for corresponding response zone
                return % Still waiting at station
            end

            direction = obj.TargetLocation - obj.Location; %determine direction toward target
            distance = norm(direction); %determine remaining distance in target direction

            if distance < 1e-3 
                obj.Location = obj.TargetLocation; %simple "collision" criteria for when truck arrives at target
            else
                step = obj.Speed * dt; %determine location step between time steps
                if step >= distance 
                    obj.Location = obj.TargetLocation;
                else
                    direction = direction / distance; %update direction
                    obj.Location = obj.Location + direction * step; %update distance
                end
            end
        end

        %function to signal truck has arrived at target
        function arrived = isAtTarget(obj)
            arrived = norm(obj.Location - obj.TargetLocation) < 1;
        end
        
        %function to search for nearby fires in the case that original fire
        %grid is removed by the time it arrives at destination
        function found = findNearbyFire(obj, fireObj, searchRadius)
            % Try to find nearby fire within searchRadius [m]
            found = false;

            for i = 1:size(fireObj.firePoints,2)
                gridX = fireObj.firePoints(1,i);
                gridY = fireObj.firePoints(2,i);
                firePos = fireObj.getGridCenterPoint(gridX, gridY);

                dist = norm(firePos - obj.Location);

                if dist <= searchRadius
                    obj.TargetLocation = firePos;
                    found = true;
                    %debugging... fprintf('FireTruck found nearby fire at (%.1f, %.1f)\n', firePos(1), firePos(2));
                    return
                end
            end
        end
    end
end
