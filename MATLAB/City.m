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
        ZoneRadii =  [1000, 2500, 4500];%array of zone radii to determine truck response time and probability [m]
        ZoneSpeeds = [10, 15, 20];
        ZoneDelays = [50 100 200];
        FireTrucks %allow city to store and determine firetruck data
        MaxTruckGroups = 3; % Maximum number of trucks that can be deployed
        TotalFuelUsed = 0; % total fuel used across all trucks for calculating cost [Liters]
        FuelCost = 0.80; % [$/Liter] centralized fuel price, from the average diesel price per gallon in Tippecanoe county
        TotalFuelCost = 0; % [$] total cost across all trucks
        FireManager %allow the ability to pull fire data from the fire manager
        TruckUnitCost = 800000; % USD per individual truck
        TotalUpfrontCost = 0;   % Total capital cost of all truck groups
        TotalWaterCost = 0;
        TotalCost;
    end

    methods
        %constructor function upon city creation
        function obj = City(mapSizeX, mapSizeY, fireManager)
            obj.MapSizeX = mapSizeX;
            obj.MapSizeY = mapSizeY;
            obj.FireTrucks = {};
            [obj.XRoads, obj.YRoads, obj.RoadVertices] = generateRoads(mapSizeX, mapSizeY, obj.BlockSize);
            obj.CenterLocation = [mapSizeX/2, mapSizeY/2]; %set location of city center 
            obj.FireManager = fireManager;
        end

        %function to listen to signal emitted from Fire.m when a new fire is created
        function attachFireListener(obj, fireObj)
            addlistener(fireObj, 'FireStarted', @(src, event) obj.handleFireStarted(event));
            addlistener(fireObj, 'FireExtinguished', @(src, event) obj.handleFireExtinguished(event));
        end

        %function that responds to "FireStarted" signal
        function handleFireStarted(obj, event)
            % Only proceed if we have room for more trucks
            maxToAssign = obj.MaxTruckGroups - length(obj.FireTrucks);
            if maxToAssign <= 0
                return
            end

            % Find all unassigned fires
            fireObj = event.Source;
            unassignedFires = struct('GridIndex', {}, 'Location', {}, 'Distance', {});
            for i = 1:size(fireObj.firePoints, 2)
                fx = fireObj.firePoints(1, i);
                fy = fireObj.firePoints(2, i);
                idx = obj.FireManager.getIndexFromPoint(fx, fy);
                if all(~obj.FireManager.isAssigned(idx))
                    loc = fireObj.getGridCenterPoint(fx, fy);
                    dist = norm(loc - obj.CenterLocation); % or use truck.Location if needed
                    unassignedFires(end+1).GridIndex = idx;
                    unassignedFires(end).Location = loc;
                    unassignedFires(end).Distance = dist;
                end
            end
            
            % Sort by proximity to city center
            if isempty(unassignedFires)
                return
            end
            [~, order] = sort([unassignedFires.Distance]);
            unassignedFires = unassignedFires(order);
            
            % Assign trucks to the top N unassigned fires
            for i = 1:min(maxToAssign, length(unassignedFires))
                fire = unassignedFires(i);
                [zoneIdx, ~] = obj.getZone(fire.Location);
                if zoneIdx > length(obj.ZoneDelays)
                    delay = obj.ZoneDelays(end) + 5;
                else
                    delay = obj.ZoneDelays(zoneIdx);
                end
            
                truck = FireTruck(obj.CenterLocation, fire.Location, delay);
                truck.TargetGridIndex = fire.GridIndex;
                obj.FireManager.addAssignment(fire.GridIndex);
                obj.addFireTruck(truck);
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
                                    truck.TargetLocation = obj.CenterLocation;
                                    truck.Status = 'Returning';
                                    truck.TargetGridIndex = [];
                                else
                                    truck.TargetLocation = obj.CenterLocation;
                                    truck.Status = 'Returning';
                                end
                            end

                        case 'Returning'
                            if norm(truck.Location - obj.CenterLocation) < 5
                               truck.Status = 'Refueling';
                               truck.RefuelTimer = 0;
                               fuelNeeded = truck.FuelCapacity - truck.FuelRemaining;
                               truck.RefuelTime = (fuelNeeded / truck.RefuelRate) + 30*8; %30 seconds to account for time to refill completely empty water tank
                            end

                        case 'Refueling'
                            truck.RefuelTimer = truck.RefuelTimer + dt;
                            if truck.RefuelTimer >= truck.RefuelTime
                                truck.refuel();
                                obj.TotalFuelUsed = obj.TotalFuelUsed + truck.FuelUsed;
                                obj.TotalFuelCost = obj.TotalFuelCost + truck.FuelUsed * obj.FuelCost;
                                obj.TotalWaterCost = obj.TotalWaterCost + truck.WaterCapacity * truck.WaterCostRate;
                                truck.Status = 'Idle';
                                truck.TargetGridIndex = []; 
                            end
                    end
                end
            end

            % Assign idle trucks to closest unassigned fires (city-center priority)
            unassignedFires = struct('GridIndex', {}, 'Location', {}, 'Distance', {});
            for i = 1:size(fireObj.firePoints, 2)
                fx = fireObj.firePoints(1, i);
                fy = fireObj.firePoints(2, i);
                idx = [fx; fy];
                if all(~obj.FireManager.isAssigned(idx))
                    loc = fireObj.getGridCenterPoint(fx, fy);
                    dist = norm(loc - obj.CenterLocation);
                    unassignedFires(end+1).GridIndex = idx;
                    unassignedFires(end).Location = loc;
                    unassignedFires(end).Distance = dist;
                end
            end

            % Sort fire grid points by distance to city center
            [~, order] = sort([unassignedFires.Distance]);
            unassignedFires = unassignedFires(order);

            % Assign fires to idle trucks
            fireIdx = 1;
            for i = 1:length(obj.FireTrucks)
                truck = obj.FireTrucks{i};
                if strcmp(truck.Status, 'Idle') && fireIdx <= length(unassignedFires)
                    target = unassignedFires(fireIdx);
                    truck.Status = 'Targeting';
                    truck.ExtinguishTimer = 0;
                    truck.TargetLocation = target.Location;
                    truck.TargetGridIndex = target.GridIndex;
                    obj.FireManager.addAssignment(target.GridIndex);
                    fireIdx = fireIdx + 1;
                end
            end
        end


        function calculateTotalUpfrontCost(obj)
                totalTrucks = 0;
                for i = 1:length(obj.FireTrucks)
                    totalTrucks = totalTrucks + obj.FireTrucks{i}.TrucksPerGroup;
                end
                obj.TotalUpfrontCost = totalTrucks * obj.TruckUnitCost;
        end

        function printCostSummary(obj)
            % Per-unit costs
            upfrontPerTruck = 800000; % USD per individual truck
            fuelRate = obj.FuelCost; % $/L
            waterRate = 0.0150643;   % $/L
        
            % Total individual trucks
            trucksPerGroup = obj.FireTrucks{1}.TrucksPerGroup;
            totalTrucks = length(obj.FireTrucks) * trucksPerGroup;
            totalUpfrontCost = upfrontPerTruck * totalTrucks;
        
            % Account for remaining fuel/water that wasn't restored
            unreturnedFuel = 0;
            unreturnedWater = 0;
            for i = 1:length(obj.FireTrucks)
                truck = obj.FireTrucks{i};
                unreturnedFuel = unreturnedFuel + (truck.FuelCapacity - truck.FuelRemaining);
                unreturnedWater = unreturnedWater + (truck.WaterCapacity - truck.WaterRemaining);
            end
        
            % Add missing fuel/water cost to totals
            finalFuelUsed = obj.TotalFuelUsed + unreturnedFuel;
            finalFuelCost = finalFuelUsed * fuelRate;
        
            finalWaterCost = obj.TotalWaterCost + (unreturnedWater * waterRate);
        
            % Print summary
            disp("---Fire Trucks---")
            fprintf('Upfront truck cost:      $%.2f (%d trucks @ $%d each)\n', ...
                totalUpfrontCost, totalTrucks, upfrontPerTruck);
            fprintf('Total fuel used:          %.2f L — Fuel Cost: $%.2f\n', ...
                finalFuelUsed, finalFuelCost);
            fprintf('Total water cost:        $%.2f\n', finalWaterCost);
            obj.TotalCost = totalUpfrontCost + finalFuelCost + finalWaterCost;
            fprintf('TOTAL COST:              $%.2f\n', obj.TotalCost);
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

   
