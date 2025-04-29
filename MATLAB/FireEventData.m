classdef FireEventData < event.EventData
    properties
        Location % [x, y] coordinates of generated fire grid
    end

    methods
        %function to allow the fire to send the location during a
        %FireStarted event
        function data = FireEventData(location)
            data.Location = location;
        end
    end
end