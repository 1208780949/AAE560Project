clc
clear
close all

% ---------------------
%  simulation settings
% ---------------------

% do not change grid size or domain size without updating drone cluster
% size
%
% fire spread need to be simulated in in a discretized domain
fireGridX = 100; % number of grid points in x direction
fireGridY = 100; % number of grid points in y direction

% size of domain
mapSizeX = 10000; % m
mapSizeY = 10000; % m

numBases = 1; % number of bases
numDronesPerBase = 10; % number of drones per base
numHelicopters = 10; % number of helicopter fleets

randNumber = rng(45325405, "twister"); % random number generator to make things repeatable

timeStep = 1;
finalTime = 2000;

enableDrone = 1;
enableHelicopter = 0;

baseX = [1.3442e3]; % base x locations
baseY = [6.5729e3]; % base y locations

% ----------------
%  initialization
% ----------------

gridResX = mapSizeX / fireGridX; % m/grid
gridResY = mapSizeY / fireGridY; % m/grid
halfGridResX = gridResX / 2; % calculating here to prevent looping through the same calc downstream
halfGridResY = gridResY / 2;

fireStartX = [800, 900, 800, 900];
fireStartY = [9900, 9900, 9800, 9800];
% fireStartX = rand(1,1) * mapSizeX; % fire start location x, can be size (1,[1,inf))
% fireStartY = rand(1,1) * mapSizeY; % fire start location y, can be size (1,[1,inf))
fire = Fire(fireStartX, fireStartY, fireGridX, fireGridY, mapSizeX, mapSizeY, timeStep);

lakeX = 9000;
lakeY = 9000;
borderX = [8500, 8500, 11000, 11000];
borderY = [11000, 8500, 8500, 11000];
lake = Lake(lakeX ,lakeY, borderX, borderY);

if enableDrone
    bases = Base.empty(0, numBases);
    
    for i = 1:numBases
        drones = Drone.empty(0, numDronesPerBase);
    
        % generating drones
        for j = 1:numDronesPerBase
            drones(j) = Drone(timeStep);
        end
   
        % generating bases
        base = Base(baseX(i), baseY(i), drones);
        bases(i) = base;
    
        % assign drone to base
        for j = 1:numDronesPerBase
            drones(j).setBase(base);
        end

        base(i).setFire(fire)
    end
else
    numBases = 0;
end

if enableHelicopter
    helicopters = Helicopter.empty(0, numHelicopters);

    for i = 1:numHelicopters
        helicopters(i) = Helicopter(timeStep, lakeX, lakeY);
    end

    airport = Airport(mapSizeX/2, 6000, helicopters);
    airport.setFire(fire)

    for i = 1:numHelicopters
        helicopters(i).setAirport(airport)
    end
end

% --------------------
%  running simulation
% --------------------

for i = 1:timeStep:finalTime

    fire.fireSpread();

    for j = 1:numBases
        bases(j).update(i)
        for k = 1:length(bases(j).activeDrones)
            bases(j).activeDrones(k).update();
        end
    end

    if enableHelicopter
        airport.update(i)
        for j = 1:length(airport.activeHelicopters)
            airport.activeHelicopters(j).update();
        end
    end

    if fire.getNumPoint == 0
        % fire extinguished
        disp("Fire Extinguished")
        break
    end

    for j = 1:fire.getNumPoint
        
    end

    % -----------
    %  rendering
    % -----------
    
    figure(1)
    clf
    hold on
    xlim([0 mapSizeX])
    ylim([0 mapSizeY])

    % draw lake
    fill(lake.borderX, lake.borderY, "b")

    for j = 1:fire.getNumPoint
        x = fire.firePoints(1,j);
        y = fire.firePoints(2,j);

        xCenter = gridResX * x;
        yCenter = gridResY * y;
        xi = xCenter - halfGridResX;
        xf = xCenter + halfGridResX;
        yi = yCenter - halfGridResY;
        yf = yCenter + halfGridResY;

        fill([xi xf xf xi], [yi yi yf yf], "r")
    end

    for j = 1:numBases
        plot(bases(j).x, bases(j).y, "o", "Color", "blue", "MarkerSize", 5)
        for k = 1:length(bases(j).activeDrones)
            drone = bases(j).activeDrones(k);
            plot(drone.x, drone.y, "x", "Color", "black", "MarkerSize", 3)
        end
    end

    if enableHelicopter
        plot(airport.x, airport.y, "o", "Color", "blue", "MarkerSize", 10)
        for j = 1:length(airport.activeHelicopters)
            heli = airport.activeHelicopters(j);
            plot(heli.x, heli.y, "x", "Color", "black", "MarkerSize", 6)
        end
    end

    pbaspect([1 1 1])

end

% final cost tally
% drones
if enableDrone

    for i = 1:numBases
        for j = 1:length(bases(i).activeDrones)
            bases(i).activeDrones(j).finalTally();
        end
    end

    disp("")
    disp("---Drones---")
    fprintf("Upfront Cost for Drones: %s $\n", regexprep(sprintf("%.2f", bases(1).upfrontCost),'(?<!\.\d*)\d{1,3}(?=(\d{3})+\>)','$&,'))
    fprintf("Fire Retardant Used: %s kg\n", regexprep(sprintf("%.2f", bases(1).retardantUsed),'(?<!\.\d*)\d{1,3}(?=(\d{3})+\>)','$&,'))
    fprintf("Fire Retardant Cost: %s $\n", regexprep(sprintf("%.2f", bases(1).getRetardantCost()),'(?<!\.\d*)\d{1,3}(?=(\d{3})+\>)','$&,'))
    fprintf("Electricity Used: %s kWh\n", regexprep(sprintf("%.2f", bases(1).powerUsed/1000),'(?<!\.\d*)\d{1,3}(?=(\d{3})+\>)','$&,'))
    fprintf("Electricity Cost: %s $\n", regexprep(sprintf("%.2f", bases(1).getElecCost()),'(?<!\.\d*)\d{1,3}(?=(\d{3})+\>)','$&,'))
    fprintf("Operational Cost: %s $\n", regexprep(sprintf("%.2f", bases(1).getOperationalCost()),'(?<!\.\d*)\d{1,3}(?=(\d{3})+\>)','$&,'))
    fprintf("Total Cost: %s $\n", regexprep(sprintf("%.2f", bases(1).getTotalCost()),'(?<!\.\d*)\d{1,3}(?=(\d{3})+\>)','$&,'))
end

% helicopters
if enableHelicopter

    for i = 1:length(airport.activeHelicopters)
        airport.activeHelicopters(i).finalTally()
    end

    disp("")
    disp("---Helicopters---")
    fprintf("Upfront Cost for Helicopters: %s $\n", regexprep(sprintf("%.2f", airport.upfrontCost),'(?<!\.\d*)\d{1,3}(?=(\d{3})+\>)','$&,'))
    fprintf("JetA Used: %s kg\n", regexprep(sprintf("%.2f", airport.fuelUsed),'(?<!\.\d*)\d{1,3}(?=(\d{3})+\>)','$&,'))
    fprintf("Operational Cost: %s $\n", regexprep(sprintf("%.2f", airport.operationalCost),'(?<!\.\d*)\d{1,3}(?=(\d{3})+\>)','$&,'))
    fprintf("Total Cost: %s $\n", regexprep(sprintf("%.2f", airport.operationalCost + airport.upfrontCost),'(?<!\.\d*)\d{1,3}(?=(\d{3})+\>)','$&,'))
end