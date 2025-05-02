classdef City < handle
    properties
        MapSizeX %takes mapsize as an input [m]
        MapSizeY %takes mapsize as an input [m]
        BlockSize = 400; % block size, can be modified later. determines vertex density and city limit size
        XRoads %roads traveling west to east
        YRoads %roads traveling north to south
        RoadVertices %intersection points, visual only now
        AirportLocation %location of airport within city
        CenterLocation %center location of the city
        ZoneRadii %array of zone radii to determine truck response time and probability [m]
        ZoneSpeeds = [10, 15, 20];
        ZoneDelays = [6, 15, 30];
        FireTrucks %allow city to store and determine firetruck data
        MaxFireTrucks = 5; % Maximum number of trucks that can be deployed
        TotalFuelUsed = 0; % total fuel used across all trucks for calculating cost [Liters]
        FuelCost = 0.80; % [$/Liter] centralized fuel price, from the average diesel price per gallon in Tippecanoe county
        TotalFuelCost = 0; % [$] total cost across all trucks
        FireManager %allow the ability to pull fire data from the fire manager
    end

    methods
        %constructor function upon city creation
        function obj = City(mapSizeX, mapSizeY, fireManager)
            obj.MapSizeX = mapSizeX;
            obj.MapSizeY = mapSizeY;
            obj.FireTrucks = {};
            [obj.XRoads, obj.YRoads, obj.RoadVertices] = generateRoads(mapSizeX, mapSizeY, obj.BlockSize);
            obj.CenterLocation = [mapSizeX/2, mapSizeY/2]; %set location of city center 
            obj.ZoneRadii = [1000, 2500, 4500]; %defines different city response zone radii 
            obj.FireManager = fireManager;
        end

        %function to listen to signal emitted from Fire.m when a new fire is created
        function attachFireListener(obj, fireObj)
            addlistener(fireObj, 'FireStarted', @(src, event) obj.handleFireStarted(event));
            addlistener(fireObj, 'FireExtinguished', @(src, event) obj.handleFireExtinguished(event));
        end

        %function that responds to "FireStarted" signal
        function handleFireStarted(obj, event)
            fireLocation = event.Location;
            gridIndex = event.GridIndex;

            [zoneIdx, ~] = obj.getZone(fireLocation);
            if zoneIdx > length(obj.ZoneDelays)
                delay = obj.ZoneDelays(end) + 5;
            else
                delay = obj.ZoneDelays(zoneIdx);
            end

            dispatchDelay = delay;

            if ~obj.FireManager.isAssigned(gridIndex) && length(obj.FireTrucks) < obj.MaxFireTrucks
                truck = FireTruck(obj.CenterLocation, fireLocation, dispatchDelay);
                truck.TargetGridIndex = gridIndex;
                obj.FireManager.addAssignment(gridIndex);
                obj.addFireTruck(truck);
            else
            end
        end
        
        %update list of target-able fire points on fire-point extinguish
        function handleFireExtinguished(obj, event)
            gridIndex = event.GridIndex;
            obj.FireManager.removeAssignment(gridIndex);
        end

        %separate function to ensure truck is appended to dispatch list
        function addFireTruck(obj, truck)
            obj.FireTrucks = [obj.FireTrucks, {truck}];
        end

        %gets resposne zone of targeted fire point
        function [zoneIdx, distanceFromCenter] = getZone(obj, location)
            diff = location - obj.CenterLocation;
            distanceFromCenter = sqrt(sum(diff.^2));
            zoneIdx = find(obj.ZoneRadii >= distanceFromCenter, 1, 'first');
            if isempty(zoneIdx)
                zoneIdx = length(obj.ZoneRadii) + 1;
            end
        end
        

        function [found, gridIndex, location] = findUnassignedNearbyFire(obj, truck, fireObj, radius)
            found = false;
            gridIndex = [];
            location = [];

            for i = 1:size(fireObj.firePoints, 2)
                fx = fireObj.firePoints(1,i);
                fy = fireObj.firePoints(2,i);
                fireLoc = fireObj.getGridCenterPoint(fx, fy);
                dist = norm(fireLoc - truck.Location);
                if dist <= radius
                    idx = [fx; fy];
                    assigned = obj.FireManager.isAssigned(idx);
                    assignedToThisTruck = isequal(truck.TargetGridIndex', idx);
                    if ~assigned || assignedToThisTruck
                        found = true;
                        gridIndex = idx;
                        location = fireLoc;
                        return
                    end
                end
            end
        end

        %updated state machine for firetruck targeting
        function update(obj, fireObj, dt)
            for i = length(obj.FireTrucks):-1:1
                truck = obj.FireTrucks{i};

                if ~truck.isAtTarget()
                    truck.updateSpeedBasedOnZone(obj);
                    truck.moveTowardTarget(dt);
                else
                    switch truck.Status

                        case 'Targeting'
                            truck.Status = 'Extinguishing';
                            truck.ExtinguishTimer = 0;

                        case 'Extinguishing'
                            truck.ExtinguishTimer = truck.ExtinguishTimer + dt;
                            if truck.ExtinguishTimer >= truck.ExtinguishTime
                                if truck.WaterRemaining >= truck.WaterUsagePerGrid
                                    fireObj.extinguish(truck.TargetLocation(1), truck.TargetLocation(2));
                                    truck.WaterRemaining = truck.WaterRemaining - truck.WaterUsagePerGrid;
                                    obj.FireManager.removeAssignment(truck.TargetGridIndex);
                                    [found, gridIndex, location] = obj.findUnassignedNearbyFire(truck, fireObj, 200);
                                    if found
                                        truck.Status = 'Targeting';
                                        truck.ExtinguishTimer = 0;
                                        truck.TargetLocation = location;
                                        truck.TargetGridIndex = gridIndex;
                                        obj.FireManager.addAssignment(gridIndex);
                                    else
                                        truck.TargetLocation = obj.CenterLocation;
                                        truck.Status = 'Returning';
                                        truck.TargetGridIndex = [];
                                    end
                                else
                                    truck.TargetLocation = obj.CenterLocation;
                                    truck.Status = 'Returning';
                                end
                            end

                        case 'Returning'
                            if norm(truck.Location - obj.CenterLocation) < 5
                                truck.Status = 'Refueling';
                                truck.RefuelTimer = 0;
                            end

                        case 'Refueling'
                            truck.RefuelTimer = truck.RefuelTimer + dt;
                            if truck.RefuelTimer >= truck.RefuelTime
                                truck.refuel();
                                obj.TotalFuelUsed = obj.TotalFuelUsed + truck.FuelUsed;
                                obj.TotalFuelCost = obj.TotalFuelCost + truck.FuelUsed * obj.FuelCost;
                                [found, gridIndex, location] = obj.findUnassignedNearbyFire(truck, fireObj, 200);

                                % Testing this chunk to see if this helps
                                % w/ retargeting behavior after refueling
                                if ~isempty(truck.TargetGridIndex)
                                    fireStillBurning = any(all(fireObj.firePoints' == truck.TargetGridIndex', 2));
                                    if fireStillBurning
                                        truck.Status = 'Targeting';
                                        truck.ExtinguishTimer = 0;
                                        truck.TargetLocation = fireObj.getGridCenterPoint(truck.TargetGridIndex(1), truck.TargetGridIndex(2));
                                        return
                                    end
                                end
                                if found %attempt to reassign target
                                    truck.Status = 'Targeting';
                                    truck.ExtinguishTimer = 0;
                                    truck.TargetLocation = location;
                                    truck.TargetGridIndex = gridIndex;
                                    obj.FireManager.addAssignment(gridIndex);
                                    truck.Status = 'Idle';
                                    truck.TargetGridIndex = []; 
                                else
                                    truck.Status = 'Idle'; %otherwise idle
                                end
                            end
                    end
                end
            end

            % Debug: Print all currently assigned fire grid points and who holds them
            %fprintf("[Debug] Assigned fire grid points and holders:\n");
            for i = 1:size(obj.FireManager.AssignedFireIndices, 1)
                idx = obj.FireManager.AssignedFireIndices(i,:);
                holder = 'Unclaimed';
                for t = 1:length(obj.FireTrucks)
                    truck = obj.FireTrucks{t};
                    if isequal(truck.TargetGridIndex', idx)
                        holder = sprintf('Truck %d', t);
                        break
                    end
                end
                %fprintf("  (%d, %d) — %s\n", idx(1), idx(2), holder);
                                % Pass 2: redeploy idle trucks to any unassigned fires
                for i = 1:length(obj.FireTrucks)
                    truck = obj.FireTrucks{i};
                    if strcmp(truck.Status, 'Idle')
                        [found, gridIndex, location] = obj.findUnassignedNearbyFire(truck, fireObj, Inf);
                        if found
                            truck.Status = 'Targeting';
                            truck.ExtinguishTimer = 0;
                            truck.TargetLocation = location;
                            truck.TargetGridIndex = gridIndex;
                            obj.FireManager.addAssignment(gridIndex);
                            %fprintf('[City] Redeploying idle Truck %d to (%d, %d)\n', i, gridIndex(1), gridIndex(2));
                        end
                    end
                end

            end
        end

        %plot the city grid, fire points, and truck location
        function plotCityStatus(obj, fireObj)
            plot(obj.XRoads, obj.YRoads, 'k-', 'LineWidth', 0.5);
            hold on;
            scatter(obj.RoadVertices(:,1), obj.RoadVertices(:,2), 25, [0.5 0.5 0.5], 'filled', 'MarkerFaceAlpha', 0.3);

            colors = [0 1 0; 1 0.65 0; 1 0 0];
            for i = 1:length(obj.ZoneRadii)
                viscircles(obj.CenterLocation, obj.ZoneRadii(i), 'LineStyle', '--', 'LineWidth', 0.5, 'Color', colors(i,:));
                hold on;
            end

            for i = 1:size(fireObj.firePoints,2)
                gridX = fireObj.firePoints(1,i);
                gridY = fireObj.firePoints(2,i);
                pos = fireObj.getGridCenterPoint(gridX, gridY);
                plot(pos(1), pos(2), 'r*', 'MarkerSize', 10);
                hold on;
            end

            %debugging... %fprintf("[Plot] %d firetrucks in city.\n", length(obj.FireTrucks));
            for i = 1:length(obj.FireTrucks)
                truck = obj.FireTrucks{i};
                %debugging... %fprintf("Truck %d — Status: %s, Location: (%.2f, %.2f)\n", i, truck.Status, truck.Location(1), truck.Location(2));
                if strcmp(truck.Status, 'Targeting')
                    plot(truck.Location(1), truck.Location(2), 'bo', 'MarkerSize', 8, 'MarkerFaceColor', 'b');
                elseif strcmp(truck.Status, 'Extinguishing')
                    plot(truck.Location(1), truck.Location(2), 'go', 'MarkerSize', 8, 'MarkerFaceColor', 'g');
                elseif strcmp(truck.Status, 'Returning')
                    plot(truck.Location(1), truck.Location(2), 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'k');
                end
                hold on;
            end
        end
        end
        end

   
