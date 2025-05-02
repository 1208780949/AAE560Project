classdef Lake < handle
    properties
        x % the point helicopters target to refill water
        y % the point helicopters target to refill water
        borderX % lake shoreline
        borderY % lake shoreline
    end

    methods
        % x: fire start location(s) in x
        % y: fire start location(s) in y
        % gridPtsX: number of grid points in x
        % gridPtsY: number of grid points in y
        % domainX: size of the domain in x in meters
        % domainY: size of the domain in y in meters
        % timeStep: time step size in s
        function obj = Lake(x, y, borderX, borderY)
            obj.x = x;
            obj.y = y;
            obj.borderX = borderX;
            obj.borderY = borderY;
        end
    end
end