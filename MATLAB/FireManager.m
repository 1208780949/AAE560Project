classdef FireManager < handle
    properties
        AssignedFireIndices = []; % List of scalar linear indices (from x, y)
        GridX = 100; % Number of grid points in X
        GridY = 100; % Number of grid points in Y
    end

    methods
        % Check if a linear index is already assigned
        function assigned = isAssigned(obj, index)
            if numel(index) == 2
                index = obj.getIndexFromPoint(index(1), index(2));
            end
            assigned = ismember(index, obj.AssignedFireIndices);
        end

        % Add linear index to assigned list
        function addAssignment(obj, index)
            if numel(index) == 2
                index = obj.getIndexFromPoint(index(1), index(2));
            end
            if ~obj.isAssigned(index)
                obj.AssignedFireIndices = [obj.AssignedFireIndices; index];
            end
        end

        % Remove linear index from assigned list
        function removeAssignment(obj, index)
            if numel(index) == 2
                index = obj.getIndexFromPoint(index(1), index(2));
            end
            obj.AssignedFireIndices = setdiff(obj.AssignedFireIndices, index);
        end

        % Convert grid coordinates to linear index
        function index = getIndexFromPoint(obj, x, y)
            index = (y - 1) * obj.GridX + x;
        end

        % Optional: set grid size for conversion
        function setGridSize(obj, gridX, gridY)
            obj.GridX = gridX;
            obj.GridY = gridY;
        end
    end
end
