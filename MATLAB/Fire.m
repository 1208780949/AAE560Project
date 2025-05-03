classdef Fire < handle
    properties
        firePoints = [] % list of fire grid point
        domainX % size of the domain in x in m
        domainY % size of the domain in y in m
        gridPtsX % number of grid points in x
        gridPtsY % number of grid points in y
        gridResX % distance per cell in x in m
        gridResY % distance per cell in y in m
        timeStep % size of time step in s
        grid % the grid of fire. 1 is on fire, 0 is not on fire
        fuelAvailability = []; % grid of fuel availability, makes sure that fuel does not propagate to area that has already been burned too much

        % fire spread rate is based on:
        % https://ieeexplore.ieee.org/abstract/document/10416753?casa_token=6eWDrxQJJHAAAAAA:CEOCSbMLGT7UQrlsp3Gd5ybTtXECO3UZy2Qw3PyliRYWEVJHOle7f9_3I2cFqnd1LLpvKWLScIw
        fireSpreadRate = (259.833 * 4^2.174) / (18600 * 4) % fire spread rate in m/s
        spreadProbX % spreading probability in x direction
        spreadProbY % spreading probability in y direction
        spreadProbDiag % diagonal spreading probability
        spreadRateScaling = 0.5 % a scaling factor to customize spread rate
    end

    events
        FireStarted
        FireSpread
        FireExtinguished
    end

    methods
        function obj = Fire(x, y, gridPtsX, gridPtsY, domainX, domainY, timeStep)
            obj.domainX = domainX;
            obj.domainY = domainY;
            obj.gridPtsX = gridPtsX;
            obj.gridPtsY = gridPtsY;
            obj.timeStep = timeStep;

            obj.gridResX = domainX / gridPtsX;
            obj.gridResY = domainY / gridPtsY;

            for i = 1:length(x)
                obj.firePoints(1,i) = round(x(i) ./ domainX * gridPtsX);
                obj.firePoints(2,i) = round(y(i) ./ domainY * gridPtsY);
            end

            obj.spreadProbX = timeStep * obj.fireSpreadRate / obj.gridResX * obj.spreadRateScaling;
            obj.spreadProbY = timeStep * obj.fireSpreadRate / obj.gridResY * obj.spreadRateScaling;
            obj.spreadProbDiag = timeStep * obj.fireSpreadRate / sqrt(obj.gridResX^2 + obj.gridResY^2) * obj.spreadRateScaling;

            obj.grid = zeros(gridPtsY, gridPtsX);
            for i = 1:length(x)
                obj.grid(round(y(i) ./ domainY * gridPtsY), round(x(i) ./ domainY * gridPtsY)) = 1;
            end

            obj.fuelAvailability = ones(gridPtsY, gridPtsX);

            firstGridX = obj.firePoints(1,1);
            firstGridY = obj.firePoints(2,1);
            location = obj.getGridCenterPoint(firstGridX, firstGridY);
            notify(obj, 'FireStarted', FireEventData(location, [firstGridX; firstGridY]));
        end

        function numPoint = getNumPoint(obj)
            numPoint = length(obj.firePoints(1,:));
        end

        function fireSpread(obj)
            prospFire = obj.firePoints;
            prospGrid = obj.grid;
            newFire = false;

            for i = 1:length(obj.firePoints(1,:))
                rn = rand(1,8);

                xThis = obj.firePoints(1, i);
                yThis = obj.firePoints(2, i);

                xLeft = xThis - 1;
                xRight = xThis + 1;
                yTop = yThis - 1;
                yBottom = yThis + 1;

                if xThis < obj.gridPtsX
                    if rn(1) <= obj.spreadProbX * obj.fuelAvailability(yThis, xRight)
                        if prospGrid(yThis, xRight) == 0
                            prospFire = [prospFire, [xRight; yThis]];
                            prospGrid(yThis, xRight) = 1;
                            newFire = true;
                            location = obj.getGridCenterPoint(xRight, yThis);
                            notify(obj, 'FireStarted', FireEventData(location, [xRight; yThis]));
                        end
                    end
                end

                if xThis < obj.gridPtsX && yThis < obj.gridPtsY
                    if rn(2) <= obj.spreadProbDiag * obj.fuelAvailability(yBottom, xRight)
                        if prospGrid(yBottom, xRight) == 0
                            prospFire = [prospFire, [xRight; yBottom]];
                            prospGrid(yBottom, xRight) = 1;
                            newFire = true;
                            location = obj.getGridCenterPoint(xRight, yBottom);
                            notify(obj, 'FireStarted', FireEventData(location, [xRight; yBottom]));
                        end
                    end
                end

                if yThis < obj.gridPtsY
                    if rn(3) <= obj.spreadProbY * obj.fuelAvailability(yBottom, xThis)
                        if prospGrid(yBottom, xThis) == 0
                            prospFire = [prospFire, [xThis; yBottom]];
                            prospGrid(yBottom, xThis) = 1;
                            newFire = true;
                            location = obj.getGridCenterPoint(xThis, yBottom);
                            notify(obj, 'FireStarted', FireEventData(location, [xThis; yBottom]));
                        end
                    end
                end

                if yThis < obj.gridPtsY && xThis > 1
                    if rn(4) <= obj.spreadProbDiag * obj.fuelAvailability(yBottom, xLeft)
                        if prospGrid(yBottom, xLeft) == 0
                            prospFire = [prospFire, [xLeft; yBottom]];
                            prospGrid(yBottom, xLeft) = 1;
                            newFire = true;
                            location = obj.getGridCenterPoint(xLeft, yBottom);
                            notify(obj, 'FireStarted', FireEventData(location, [xLeft; yBottom]));
                        end
                    end
                end

                if xThis > 1
                    if rn(5) <= obj.spreadProbX * obj.fuelAvailability(yThis, xLeft)
                        if prospGrid(yThis, xLeft) == 0
                            prospFire = [prospFire, [xLeft; yThis]];
                            prospGrid(yThis, xLeft) = 1;
                            newFire = true;
                            location = obj.getGridCenterPoint(xLeft, yThis);
                            notify(obj, 'FireStarted', FireEventData(location, [xLeft; yThis]));
                        end
                    end
                end

                if yThis > 1 && xThis > 1
                    if rn(6) <= obj.spreadProbDiag * obj.fuelAvailability(yTop, xLeft)
                        if prospGrid(yTop, xLeft) == 0
                            prospFire = [prospFire, [xLeft; yTop]];
                            prospGrid(yTop, xLeft) = 1;
                            newFire = true;
                            location = obj.getGridCenterPoint(xLeft, yTop);
                            notify(obj, 'FireStarted', FireEventData(location, [xLeft; yTop]));
                        end
                    end
                end

                if yThis > 1
                    if rn(7) <= obj.spreadProbY * obj.fuelAvailability(yTop, xThis)
                        if prospGrid(yTop, xThis) == 0
                            prospFire = [prospFire, [xThis; yTop]];
                            prospGrid(yTop, xThis) = 1;
                            newFire = true;
                            location = obj.getGridCenterPoint(xThis, yTop);
                            notify(obj, 'FireStarted', FireEventData(location, [xThis; yTop]));
                        end
                    end
                end

                if yThis > 1 && xThis < obj.gridPtsX
                    if rn(8) <= obj.spreadProbDiag * obj.fuelAvailability(yTop, xRight)
                        if prospGrid(yTop, xRight) == 0
                            prospFire = [prospFire, [xRight; yTop]];
                            prospGrid(yTop, xRight) = 1;
                            newFire = true;
                            location = obj.getGridCenterPoint(xRight, yTop);
                            notify(obj, 'FireStarted', FireEventData(location, [xRight; yTop]));
                        end
                    end
                end

                obj.firePoints = prospFire;
                obj.grid = prospGrid;
            end
        end

        function center = getGridCenterPoint(obj, x, y)
            center = [x * obj.gridResX, y * obj.gridResY];
        end

        function extinguish(obj, x, y)
            gridX = round(x / obj.domainX * obj.gridPtsX);
            gridY = round(y / obj.domainY * obj.gridPtsY);
            obj.grid(gridY, gridX) = 0;
            for i = 1:length(obj.firePoints(1,:))
                col = obj.firePoints(:,i);
                if col == [gridX; gridY]
                    obj.firePoints(:,i) = [];
                    notify(obj, 'FireExtinguished', FireEventData([x, y], [gridX; gridY]));
                    break
                end
            end
            obj.fuelAvailability(gridY, gridX) = obj.fuelAvailability(gridY, gridX) * 0.1;
        end

        function idx = getGridIndexAt(obj, location)
            x = location(1);
            y = location(2);
            gridX = round(x / obj.domainX * obj.gridPtsX);
            gridY = round(y / obj.domainY * obj.gridPtsY);
            idx = [gridX; gridY];
        end

        % convert linear index to 2D grid index [x, y]
        function gridIndex = getGridIndexFromLinear(obj, linearIndex)
            [x, y] = ind2sub([obj.gridPtsX, obj.gridPtsY], linearIndex);
            gridIndex = [x, y];
        end
    end
end
