classdef Fire < handle
    properties
        firePoints = [] % list of fire grid point
        gridPtsX % number of grid points in x
        gridPtsY % number of grid points in y
        gridResX % distance per cell in x in m
        gridResY % distance per cell in y in m
        timeStep % size of time step in s
        grid % the grid of fire. 1 is on fire, 0 is not on fire

        % fire spread rate is based on:
        % https://ieeexplore.ieee.org/abstract/document/10416753?casa_token=6eWDrxQJJHAAAAAA:CEOCSbMLGT7UQrlsp3Gd5ybTtXECO3UZy2Qw3PyliRYWEVJHOle7f9_3I2cFqnd1LLpvKWLScIw
        fireSpreadRate = (259.833 * 4^2.174) / (18600 * 4) % fire spread rate in m/s
        spreadProbX % spreading probability in x direction
        spreadProbY % spreading probability in y direction
        spreadProbDiag % diagonal spreading probability
    end

    methods
        % x: fire start location(s) in x
        % y: fire start location(s) in y
        % gridPtsX: number of grid points in x
        % gridPtsY: number of grid points in y
        % domainX: size of the domain in x in meters
        % domainY: size of the domain in y in meters
        % timeStep: time step size in s
        function obj = Fire(x, y, gridPtsX, gridPtsY, domainX, domainY, timeStep)
            obj.gridPtsX = gridPtsX;
            obj.gridPtsY = gridPtsY;
            obj.timeStep = timeStep;

            % grid resolution
            obj.gridResX = domainX / gridPtsX;
            obj.gridResY = domainY / gridPtsY;

            % the initial grid point that the fire occupies
            obj.firePoints(1,1) = round(x ./ domainX * gridPtsX);
            obj.firePoints(2,1) = round(y ./ domainY * gridPtsY);

            % fire spread probability
            % If time step is large, spread probability proportionately
            % increases to keep spread rate consistent.
            % If grid size is large, spread probability proportionately
            % reduces to keep spread rate consistent.
            obj.spreadProbX = timeStep * obj.fireSpreadRate / obj.gridResX;
            obj.spreadProbY = timeStep * obj.fireSpreadRate / obj.gridResY;
            obj.spreadProbDiag = timeStep * obj.fireSpreadRate / sqrt(obj.gridResX^2 + obj.gridResY^2);

            % grid generation and inserting initial fire
            obj.grid = zeros(gridPtsY, gridPtsX);
            obj.grid(gridPtsY - round(y ./ domainY * gridPtsY), round(x ./ domainY * gridPtsY))
        end

        % return the number of grid points the fire occupies
        function numPoint = getNumPoint(obj)
            numPoint = length(obj.firePoints(1,:));
        end

        function fireSpread(obj)
            % Fire spread simulation is modified based on an ABM approach as
            % suggested by https://ieeexplore.ieee.org/abstract/document/10132476.
            % This paper does not claim the accuracy of the model, but
            % it's simply enough for the purpose of modeling firefighting
            % drones.
            % 
            % Modification include:
            %  - Instead of using a forest map, we use a continuous forest.
            %  - Instead of using a random spread rate, we use a validated
            %    spread rate.

            prospFire = obj.firePoints; % all fire locations after combining the new ones
            prospGrid = obj.grid; 

            for i = 1:length(obj.firePoints(1,:))
                rn = rand(1,8); % rng used to decide fire spread

                xThis = obj.firePoints(1, i);
                yThis = obj.firePoints(2, i);

                xLeft = xThis - 1;
                xRight = xThis + 1;
                yTop = yThis - 1;
                yBottom = yThis + 1;

                % grid point to the right
                if rn(1) <= obj.spreadProbX
                    if xThis < obj.gridPtsX
                        if prospGrid(yThis, xRight) == 0
                            prospFire = [prospFire, [xRight; yThis]];
                            prospGrid(yThis, xRight) = 1;
                        end
                    end
                end

                % grid point to the bottom right
                if rn(2) <= obj.spreadProbDiag
                    if xThis < obj.gridPtsX && yThis < obj.gridPtsY
                        if prospGrid(yBottom, xRight) == 0
                            prospFire = [prospFire, [xRight; yBottom]];
                            prospGrid(yBottom, xRight) = 1;
                        end
                    end
                end

                % grid point to the bottom
                if rn(3) <= obj.spreadProbY
                    if yThis < obj.gridPtsY
                        if prospGrid(yBottom, xThis) == 0
                            prospFire = [prospFire, [xThis; yBottom]];
                            prospGrid(yBottom, xThis) = 1;
                        end
                    end
                end

                % grid point to the bottom left
                if rn(4) <= obj.spreadProbDiag
                    if yThis < obj.gridPtsY && xThis > 1
                        if prospGrid(yBottom, xLeft) == 0
                            prospFire = [prospFire, [xLeft; yBottom]];
                            prospGrid(yBottom, xLeft) = 1;
                        end
                    end
                end

                % grid point to the left
                if rn(5) <= obj.spreadProbX
                    if xThis > 1
                        if prospGrid(yThis, xLeft) == 0
                            prospFire = [prospFire, [xLeft; yThis]];
                            prospGrid(yThis, xLeft) = 1;
                        end
                    end
                end

                % grid point to the top eft
                if rn(6) <= obj.spreadProbDiag
                    if yThis > 1 && xThis > 1
                        if prospGrid(yTop, xLeft) == 0
                            prospFire = [prospFire, [xLeft; yTop]];
                            prospGrid(yTop, xLeft) = 1;
                        end
                    end
                end

                % grid point to the top
                if rn(7) <= obj.spreadProbY
                    if yThis > 1
                        if prospGrid(yTop, xThis) == 0
                            prospFire = [prospFire, [xThis; yTop]];
                            prospGrid(yTop, xThis) = 1;
                        end
                    end
                end

                % grid point to the top right
                if rn(8) <= obj.spreadProbDiag
                    if yThis > 1 && xThis < obj.gridPtsX
                        if prospGrid(yTop, xRight) == 0
                            prospFire = [prospFire, [xRight; yTop]];
                            prospGrid(yTop, xRight) = 1;
                        end
                    end
                end

            end
        
            % Update existing fire
            % Doing this outside of the loop to prevent fire from spread
            % everywhere in 1 time step
            % This makes spreading to a grid surround by existing fire more
            % likely
            obj.firePoints = prospFire;
            obj.grid = prospGrid;
        end
    
        function center = getGridCenterPoint(obj, x, y)
            center = [x * obj.gridResX, y * obj.gridResY];
        end
    end
end