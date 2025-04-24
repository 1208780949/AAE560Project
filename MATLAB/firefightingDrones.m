clc
clear
close all

% ---------------------
%  simulation settings
% ---------------------

% fire spread need to be simulated in in a discretized domain
fireGridX = 100; % number of grid points in x direction
fireGridY = 100; % number of grid points in y direction

mapSizeX = 20000; % m
mapSizeY = 20000; % m

numBases = 1; % number of bases
numDronesPerBase = 10; % number of drones per base

droneSpd = 50; % drone speed in m/s

randNumber = rng(45325405, "twister"); % random number generator to make things repeatable

timeStep = 1;
finalTime = 1000;

% ----------------
%  initialization
% ----------------

gridResX = mapSizeX / fireGridX; % m/grid
gridResY = mapSizeY / fireGridY; % m/grid
halfGridResX = gridResX / 2; % calculating here to prevent looping through the same calc downstream
halfGridResY = gridResY / 2;

bases = Base.empty(0, numBases);

for i = 1:numBases
    drones = Drone.empty(0, numDronesPerBase);

    % generating drones
    for j = 1:numDronesPerBase
        drones(j) = Drone(droneSpd, timeStep);
    end

    % generating base
    xPos = rand(1,1);
    yPos = rand(1,1);

    base = Base(xPos * mapSizeX, yPos * mapSizeY, drones);
    bases(i) = base;

    % assign drone to base
    for j = 1:numDronesPerBase
        drones(j).setBase(base);
    end
end

fireStartX = rand(1,1) * mapSizeX; % fire start location x, can be size (1,[1,inf))
fireStartY = rand(1,1) * mapSizeY; % fire start location y, can be size (1,[1,inf))
fire = Fire(fireStartX, fireStartY, fireGridX, fireGridY, mapSizeX, mapSizeY, timeStep);

base.setFire(fire)

% --------------------
%  running simulation
% --------------------

for i = timeStep:timeStep:finalTime

    fire.fireSpread();
    for j = 1:numBases
        bases(j).update()
        for k = 1:length(bases(j).activeDrones)
            bases(j).activeDrones(k).update();
        end
    end

    if fire.getNumPoint == 0
        % fire extinguished
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

    for j = 1:numBases
        
        plot(bases(j).x, bases(j).y, "o", "Color", "blue", "MarkerSize", 5)
        
        for k = 1:length(bases(j).activeDrones)
            drone = bases(j).activeDrones(k);
            plot(drone.x, drone.y, "x", "Color", "black", "MarkerSize", 2)
        end
    end

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

    pbaspect([1 1 1])

end
