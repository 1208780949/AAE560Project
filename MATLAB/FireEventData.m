classdef FireEventData < event.EventData
    properties
        Location   % [x, y] coordinates of generated fire grid
        GridIndex  % [i, j] index in the fire grid
    end

    methods
        % constructor accepting location and grid index
        function data = FireEventData(location, gridIndex)
            data.Location = location;
            data.GridIndex = gridIndex;
        end
    end
end
