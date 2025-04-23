classdef Fire < handle
    properties
        firePoints = [] % list of fire grid point
        gridPtsX % number of grid points in x
        gridPtsY % number of grid points in y
        gridResX % distance per cell in x in m
        gridResY % distance per cell in y in m
        timeStep % size of time step in s

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

            for i = 1:length(obj.firePoints(1,:))
                rn = rand(1,8); % rng used to decide fire spread

                thisX = obj.firePoints(1, i);
                thisY = obj.firePoints(2, i);

                xLeft = thisX - 1;
                xRight = thisX + 1;
                yTop = thisY + 1;
                yBottom = thisY - 1;

                % grid point to the right
                if thisX < obj.gridPtsX
                    if rn(1) <= obj.spreadProbX && ~obj.hasExistingFire(prospFire, xRight, thisY)
                        prospFire = [prospFire, [xRight; thisY]];
                    end

                    % grid point to the top right
                    if thisY < obj.gridPtsY 
                        if rn(2) <= obj.spreadProbDiag && ~obj.hasExistingFire(prospFire, xRight, yTop)
                            prospFire = [prospFire, [xRight; yTop]];
                        end
                    end

                    % grid point to the bottom right
                    if thisY > 1
                        if rn(3) <= obj.spreadProbDiag && ~obj.hasExistingFire(prospFire, xRight, yBottom)
                            prospFire = [prospFire, [xRight; yBottom]];
                        end
                    end
                end
                
                % grid point to the left
                if thisX > 1
                    if rn(4) <= obj.spreadProbX && ~obj.hasExistingFire(prospFire, xLeft, thisY)
                        prospFire = [prospFire, [xLeft; thisY]];
                    end

                    % grid point to the top left
                    if thisY < obj.gridPtsY
                        if rn(5) <= obj.spreadProbDiag && ~obj.hasExistingFire(prospFire, xLeft, yTop)
                            prospFire = [prospFire, [xLeft; yTop]];
                        end
                    end

                    % grid point to the bottom left
                    if thisY > 1
                        if rn(6) <= obj.spreadProbDiag && ~obj.hasExistingFire(prospFire, xLeft, yBottom)
                            prospFire = [prospFire, [xLeft; yBottom]];
                        end
                    end
                end

                % grid point above
                if thisY < obj.gridPtsY
                    if rn(7) <= obj.spreadProbY && ~obj.hasExistingFire(prospFire, thisX, yTop)
                        prospFire = [prospFire, [thisX; yTop]];
                    end
                end

                % grid point below
                if thisY > 1
                    if rn(8) <= obj.spreadProbY && ~obj.hasExistingFire(prospFire, thisX, yBottom)
                        prospFire = [prospFire, [thisX; yBottom]];
                    end
                end
            end
        
            % Update existing fire
            % Doing this outside of the loop to prevent fire from spread
            % everywhere in 1 time step
            % This makes spreading to a grid surround by existing fire more
            % likely
            obj.firePoints = prospFire;
        end

        % checks if a point given by (x,y) already has existing fire
        function result = hasExistingFire(obj, fire, x, y)
            result = 0;

            for i = 1:length(fire(1,:))
                thisColumn = fire(:,i);
                if thisColumn == [x;y]
                    result = 1;
                    break
                end
            end

        end
    end
end