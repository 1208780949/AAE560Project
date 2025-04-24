classdef Base < handle
    properties
        x % base x position in m
        y % base y position in m
        idleDrones % a list of drones from this base
        activeDrones % list of drones performing duty
        fires % list of fires
        targetedFire % list of fire grid pts that has already been targeted
    end

    methods
        function obj = Base(x, y, drones)
            obj.x = x;
            obj.y = y;
            obj.idleDrones = drones;
            obj.activeDrones = Drone.empty(0, length(drones));
        end

        % update list of fires
        function setFire(obj, fire)
            obj.fires = [obj.fires fire];
        end

        function update(obj)

            stateChangeDrones = Drone.empty(0, 0);

            for i = 1:length(obj.fires)

                fire = obj.fires(i);

                for j = 1:fire.getNumPoint

                    if ismember(j, obj.targetedFire)
                        % if this grid point has already been targeted by a
                        % drone, skip this fire
                        continue
                    end
                    firePoint = fire.firePoints(:,j);

                    drone = obj.idleDrones(1);
                    gridCenter = fire.getGridCenterPoint(firePoint(1), firePoint(2));
                    drone.statusChangeFlight2Target(gridCenter(1), gridCenter(2));
                    obj.activeDrones = [obj.activeDrones drone];
                    stateChangeDrones = [stateChangeDrones drone];
                    obj.targetedFire = [obj.targetedFire j];
                end
            end
            
            if ~isempty(stateChangeDrones)
                obj.idleDrones(obj.idleDrones == stateChangeDrones) = [];
            end

        end
    end
end