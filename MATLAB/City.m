classdef City < handle
    properties
        MapSizeX %takes mapsize as an input
        MapSizeY %takes mapsize as an input
        BlockSize = 400; % block size, can be modified later. determines vertex density and city limit size
        XRoads %roads traveling west to east
        YRoads %roads traveling north to south
        RoadVertices %intersection of roads to be used to determine fire extinguish probability
        AirportLocation %location of airport within city
        CenterLocation %center location of the city
        ZoneRadii %array of zone radii to determine truck response time and probability
        FireTrucks %allow city to store and determine firetruck data
        MaxFireTrucks = 15; % Maximum number of trucks that can be deployed
    end

    methods
        %constructor function upon city creation
        function obj = City(mapSizeX, mapSizeY)
            obj.MapSizeX = mapSizeX;
            obj.MapSizeY = mapSizeY;
            obj.BlockSize = 400;
            obj.FireTrucks = {}; % empty cell array

            %I created this external generateRoads function prior to creating the city
            %class and kept it this way because the function is so long. I
            %can include it in the class itself if needed
            [obj.XRoads, obj.YRoads, obj.RoadVertices] = generateRoads(mapSizeX, mapSizeY, obj.BlockSize); %generate the city grid assuming location is at map center
            obj.CenterLocation = [mapSizeX/2, mapSizeY/2];%set location of city center 
            obj.ZoneRadii = [1000, 2500, 4500];%defines different city response zone radii
        end

        %function to listen to signal emitted from Fire.m when a new fire
        %is created
        function attachFireListener(obj, fireObj)
            addlistener(fireObj, 'FireStarted', @(src, event) obj.handleFireStarted(event));
        end

        %function that responds to "FireStarted" signal
        function handleFireStarted(obj, event)
            fireLocation = event.Location; %read in the location data emitted by Fire.m event signal

            [zoneIdx, distanceFromCenter] = obj.getZone(fireLocation); %plot the fire location and determine what response zone it's in

            delayPerZone = [0.1, 0.25, 0.5]; %response delay times for each city zone in [minutes]
            if zoneIdx <= length(delayPerZone) %set the delay time depending on what zone the fire grid is in
                delay = delayPerZone(zoneIdx);
            else
                delay = delayPerZone(end) + .1;% if the fire is located in the outermost ring to the edge of the display, add an additional delay
            end

            dispatchDelay = delay * 60; % convert mins to [seconds]

            if length(obj.FireTrucks) < obj.MaxFireTrucks % check to see if the currently dispatched trucks exceeds the total limit available
                truck = FireTruck(obj.CenterLocation, fireLocation, dispatchDelay); %if truck is available, dispatch to fire grid loc
                obj.addFireTruck(truck); %call helper function to append truck to list of dispatched trucks

                %debugging... %fprintf('Created FireTruck toward (%.1f, %.1f), delay %.1f sec. Total trucks: %d\n', ...
                    %fireLocation(1), fireLocation(2), dispatchDelay, length(obj.FireTrucks));
            else
                %debugging... %fprintf('No available FireTrucks for fire at (%.1f, %.1f). Max trucks deployed.\n', ...
                    %fireLocation(1), fireLocation(2));
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

        %added this function in which will eventually check if a fire grid
        %is near any city vertex points to determine extinguish probability
        function nearbyVertices = getVerticesNearLocation(obj, location, radius)
            diffs = obj.RoadVertices - location;
            distances = sqrt(sum(diffs.^2, 2));
            nearbyVertices = obj.RoadVertices(distances <= radius, :);
        end

        %function for firetruck targeting behavior
        function update(obj, fireObj, dt)
            for i = length(obj.FireTrucks):-1:1 %this loops backwards to remove trucks properly
                truck = obj.FireTrucks{i};

                % state machine for FireTruck
                if ~truck.isAtTarget()
                    truck.moveTowardTarget(dt);
                else
                    if strcmp(truck.Status, 'Targeting')
                        % Arrived at fire
                        fireObj.extinguish(truck.TargetLocation(1), truck.TargetLocation(2));
                        truck.Status = 'Extinguishing';
                        %debugging... %fprintf('FireTruck extinguished fire at (%.1f, %.1f)\n', truck.TargetLocation(1), truck.TargetLocation(2));
                    elseif strcmp(truck.Status, 'Extinguishing')
                        % Search for new fire nearby
                        foundFire = truck.findNearbyFire(fireObj, 200); % search within 200m
                        if foundFire
                            truck.Status = 'Targeting';
                        else
                            % No more nearby fires
                            truck.TargetLocation = obj.CenterLocation;
                            truck.Status = 'Returning';
                           %debugging fprintf('Truck returning to city center.\n');
                        end
                    elseif strcmp(truck.Status, 'Returning')
                        if norm(truck.Location - obj.CenterLocation) < 5
                            %debugging fprintf('Truck arrived at city center. Remove from active list.\n');
                            obj.FireTrucks(i) = []; % remove from active trucks
                        end
                    end
                end
            end
        end

        %plot the city grid, fire points, and truck location
        function plotCityStatus(obj, fireObj)
            
            plot(obj.XRoads, obj.YRoads, 'k-', 'LineWidth', 0.5); %plot city grid
            hold on;
            scatter(obj.RoadVertices(:,1), obj.RoadVertices(:,2), 25, [0.5 0.5 0.5], 'filled', 'MarkerFaceAlpha', 0.3); %plot road vertices

            colors = [0 1 0; 1 0.65 0; 1 0 0];%set colors for response zones
            for i = 1:length(obj.ZoneRadii) %plot response zones
                viscircles(obj.CenterLocation, obj.ZoneRadii(i), 'LineStyle', '--', 'LineWidth', 0.5, 'Color', colors(i,:));
                hold on;
            end

                %currently plotting this to ensure City.m is reading in the
                %Fire.m grid location signal properly. Should overlay on
                %existing grid points (can remove later)
            for i = 1:size(fireObj.firePoints,2)
                gridX = fireObj.firePoints(1,i);
                gridY = fireObj.firePoints(2,i);
                pos = fireObj.getGridCenterPoint(gridX, gridY);
                plot(pos(1), pos(2), 'r*', 'MarkerSize', 10);
                hold on;
            end

            %plot fire truck location and status color depending on state
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
