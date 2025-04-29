classdef City < handle
    properties
        MapSizeX %takes mapsize as an input [m]
        MapSizeY %takes mapsize as an input [m]
        BlockSize = 400; % block size, can be modified later. determines vertex density and city limit size
        XRoads %roads traveling west to east
        YRoads %roads traveling north to south
        RoadVertices %intersection of roads to be used to determine fire extinguish probability
        AirportLocation %location of airport within city
        CenterLocation %center location of the city
        ZoneRadii %array of zone radii to determine truck response time and probability [m]
        ZoneSpeeds = [10, 15, 20]; % zone-based speed values from center outward [m/s]
        FireTrucks %allow city to store and determine firetruck data
        MaxFireTrucks = 2; % Maximum number of trucks that can be deployed
        TotalFuelUsed = 0; % total fuel used across all trucks for calculating cost [Liters]
        FuelCost = 0.80; % [$/Liter] centralized fuel price, from the average diesel price per gallon in Tippecanoe county
        TotalFuelCost = 0;       % [$] total cost across all trucks

    end

    methods
        %constructor function upon city creation
        function obj = City(mapSizeX, mapSizeY)
            obj.MapSizeX = mapSizeX;
            obj.MapSizeY = mapSizeY;
            obj.BlockSize = 400;
            obj.FireTrucks = {}; % empty cell array

            [obj.XRoads, obj.YRoads, obj.RoadVertices] = generateRoads(mapSizeX, mapSizeY, obj.BlockSize); %generate the city grid assuming location is at map center
            obj.CenterLocation = [mapSizeX/2, mapSizeY/2];%set location of city center 
            obj.ZoneRadii = [1000, 2500, 4500];%defines different city response zone radii
        end

        %function to listen to signal emitted from Fire.m when a new fire is created
        function attachFireListener(obj, fireObj)
            addlistener(fireObj, 'FireStarted', @(src, event) obj.handleFireStarted(event));
        end

        %function that responds to "FireStarted" signal
        function handleFireStarted(obj, event)
            fireLocation = event.Location;

            [zoneIdx, distanceFromCenter] = obj.getZone(fireLocation);

            delayPerZone = [0.1, 0.25, 0.5]; % response delay times for each city zone in [minutes]
            if zoneIdx <= length(delayPerZone)
                delay = delayPerZone(zoneIdx);
            else
                delay = delayPerZone(end) + .1;
            end

            dispatchDelay = delay * 60; % convert mins to [seconds]

            if length(obj.FireTrucks) < obj.MaxFireTrucks
                truck = FireTruck(obj.CenterLocation, fireLocation, dispatchDelay);
                obj.addFireTruck(truck);
            end
        end

        %separate function to ensure truck is appended to dispatch list
        function addFireTruck(obj, truck)
            obj.FireTrucks = [obj.FireTrucks, {truck}];
        end

        %send truck to nearest fire grid
        function [zoneIdx, distanceFromCenter] = getZone(obj, location)
            diff = location - obj.CenterLocation;
            distanceFromCenter = sqrt(sum(diff.^2));
            zoneIdx = find(obj.ZoneRadii >= distanceFromCenter, 1, 'first');
            if isempty(zoneIdx)
                zoneIdx = length(obj.ZoneRadii) + 1;
            end
        end

        %check if a fire grid is near any city vertex points to determine extinguish probability
        function nearbyVertices = getVerticesNearLocation(obj, location, radius)
            diffs = obj.RoadVertices - location;
            distances = sqrt(sum(diffs.^2, 2));
            nearbyVertices = obj.RoadVertices(distances <= radius, :);
        end

        %function for firetruck targeting behavior
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

                            foundFire = truck.findNearbyFire(fireObj, 200);
                            if foundFire
                                truck.Status = 'Targeting';
                                truck.ExtinguishTimer = 0;
                            else
                                truck.TargetLocation = obj.CenterLocation;
                                truck.Status = 'Returning';
                            end
                        else
                            % not enough water left to extinguish
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
                        obj.FireTrucks(i) = [];
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

            for i = 1:length(obj.FireTrucks)
                truck = obj.FireTrucks{i};
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
