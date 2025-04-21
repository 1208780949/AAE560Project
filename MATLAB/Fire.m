classdef Fire < handle
    properties
        x = [] % list of fire x grid point
        y = [] % list of fire y grid point
        temp = [] % list of fire temperature
        gridSizeX % size of the grid in x
        gridSizeY % size of the grid in y
    end

    methods
        function obj = Fire(x, y, temp, gridSizeX, gridSizeY)
            obj.temp = temp;
            obj.gridSizeX = gridSizeX;
            obj.gridSizeY = gridSizeY;

            initialX = x / gridSizeX;
            initialY = y / gridSizeY;

            obj.x = initialX;
            obj.y = initialY;
        end

        % return the number of grid points the fire occupies
        function numPoint = getNumPoint(obj)
            numPoint = length(obj.x);
        end
    end
end