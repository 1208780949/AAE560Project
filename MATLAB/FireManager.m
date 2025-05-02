classdef FireManager < handle
    properties
        AssignedFireIndices = zeros(0,2);
    end

    methods
        %constructor for fire point manager list
        function assigned = isAssigned(obj, gridIndex)
            assigned = ismember(gridIndex', obj.AssignedFireIndices, 'rows');
            if assigned
            end
        end

        %get fire point index, add to assigned list
        function addAssignment(obj, gridIndex)
            if ~obj.isAssigned(gridIndex)
                obj.AssignedFireIndices = [obj.AssignedFireIndices; gridIndex'];
            end
        end

       %find points that have been extinguished that are marked as assigned
       function removeAssignment(obj, gridIndex)
        before = size(obj.AssignedFireIndices, 1);
        obj.AssignedFireIndices = setdiff(obj.AssignedFireIndices, gridIndex', 'rows');
        after = size(obj.AssignedFireIndices, 1);
    if before == after
    else
    end
end

    end
end
