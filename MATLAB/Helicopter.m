classdef Helicopter < handle
    % Helicopters are assumed to the CH-47 Chinook
    % https://www.nifc.gov/resources/aircraft/helicopters
    %
    % The Chinook has an hourly operating cost of $7,724.87 and consumes
    % 405 gal/hr. That is $2.15 and per second and 0.344 kg/s 
    % https://www.fs.usda.gov/sites/default/files/2020-02/flt_chrt_awarded_2018-2021.pdf
    %
    % The useful load of the Chinook is 27,700 lb, fuel capacity 1080
    % gal, and a maximum speed of 170 KTAS (87 m/s).
    % https://www.boeing.com/defense/ch-47-chinook#technical-specifications
    %
    % Assume the crew and the firefighting equipment together weight 1000
    % lbs. That means remaining useful load becomes 26,700 lb or 12,110 kg.
    %
    % JetA has a density of around 808 kg/m3. Meaning the chinook can carry
    % 3300 kg of fuel. That is a payload capacity of 8811 kg at maximum
    % fuel.
    % https://www.exxonmobil.com/en-bd/commercial-fuel/pds/gl-xx-jetfuel-series
    %
    % High end of water scoop rate estimate is 334 kg/s, and the water
    % cannon flow rate is 1136 kg/s on S-64. We will assume the Chinook is
    % similar.
    % https://ericksoninc.com/aviation-services/aerial-firefighting/#:~:text=The%20S%2D64%20Air%20Crane%C2%AE%20helicopters%20are%20fixed,saltwater%20in%20as%20little%20as%2030%20seconds.
    % 
    % We will assume that the crew need 10 minutes to be briefed and get 
    % the helicopter into the air.
    %
    % Refueling is assumed to be done by the Westmor truck, offering up to 
    % 300GPM refueling rate. That is 15.3 kg/s.
    % https://westmor-ind.com/aviation/aviation-refuelers/
    %
    % A single Chinook costs $64.75 million.
    % https://billingsflyingservice.com/chinook-helicopter-for-sale/

    properties
        % helicopter properties
        maxSpd = 87 % max speed in m/s
        scoopRate = 334; % kg/s of water scoop rate
        waterCannonFlowRate = 1136; % water cannon flow rate when extinguishing fire in kg/s
        timeStep % time step size in s
        airport % base of the helicopter 
        fleetSize = 10; % each fleet consist of this many helicopters
        fuelTankSize = 3300; % can carry up to 3300 kg of fuel
        fuelFlow = 0.344 % fuel flow in kg/s
        refuelRate = 15.3; % kg/s
        usefulLoad = 12100; % useful load minus crew and equipment weight kg
        upfrontCost = 64750000; % 1x helicotper
        crewPrepTime = 600; % seconds
        waterRequired = 8.1652e+04; % this much water is required to extinguish 1 grid of fire
        operatingCost = 2.15; % cost of operation per second
        minimumFuel % minimum fuel that will cause the helicopter to return to airport
        
        % status
        x = 0;
        y = 0;
        status = "idle" % status of the drone, possible status include: idle, flight2target, extinguishing, return2base, refueling, and crashed.
        currentFuel % battery remaining in amp-hour
        statusStartTime % when status changed to the current status
        currentWater = 0; % amount of water in the helicopter
        firstMission = 1; % first mission of the day. Used to signal when crew prep is needed.

        % mission
        targetX % the target the drone is heading to
        targetY % the target the drone is heading to
        taskFinishTime % the time for when a task will be finished for time based tasks (like extinguishing) 
        targetFire % the fire object that the drone is targeting
        targetFireIndex % the index of target fire. Only keeping track to that the base knows which fire has been extinguished
        lakeX % water refill point
        lakeY % water refill point
        extinguishingProgress = 0 % fire extinguishing progress
        fireX % target fire x position
        fireY % target fire y position
    end

    methods
        function obj = Helicopter(timeStep, lakeX, lakeY)
            obj.timeStep = timeStep;
            obj.currentFuel = obj.fuelTankSize;
            obj.lakeX = lakeX;
            obj.lakeY = lakeY;
            obj.minimumFuel = obj.fuelFlow * 1800; % 30 minutes of minimum fuel
        end

        % assign the drone to a base when it is instantiated
        % do not use in other circumstances 
        function setAirport(obj, airport)
            obj.airport = airport;

            % set drone's position to base position
            obj.x = airport.x;
            obj.y = airport.y;

            % track upfront cost
            airport.upfrontCost = airport.upfrontCost + obj.upfrontCost * obj.fleetSize;
        end

        % update the drone
        % if it's idling, do nothing
        % if it's flight2target or return2base, update position
        % if it's extinguishing, continue to extinguish until done then fly
        % home
        function update(obj)
            if obj.status == "idle"
                return
            elseif obj.status == "flight2refill" || obj.status == "flight2target" || obj.status == "return2base"
                % calculate new position of the drone if it keeps flying
                dx = obj.targetX - obj.x;
                dy = obj.targetY - obj.y;
                dist = sqrt(dx^2 + dy^2);
                travelDist = obj.maxSpd * obj.timeStep;
                ratio = travelDist / dist;
                newX = obj.x + dx * ratio;
                newY = obj.y + dy * ratio;

                % if the new position ends up in an overshoot, snap the
                % drone to target position
                if (obj.targetX - newX) * dx < 0
                    newX = obj.targetX;
                    newY = obj.targetY;

                    % update fuel
                    timeSpent = obj.airport.currentTime - obj.statusStartTime;
                    obj.currentFuel = obj.currentFuel - timeSpent * obj.fuelFlow;

                    if obj.currentFuel <= obj.minimumFuel
                        % switch to return home status
                        obj.status = "return2base";
                        obj.targetX = obj.airport.x;
                        obj.targetY = obj.airport.y;
                        obj.statusStartTime = obj.airport.currentTime;
                        return
                    end

                    if obj.status == "flight2target"
                        % switch to extinguishing
                        obj.status = "extinguishing";
                        obj.taskFinishTime = obj.airport.currentTime + obj.currentWater / obj.waterCannonFlowRate;
                        obj.statusStartTime = obj.airport.currentTime;
                    elseif obj.status == "return2base"
                        % go to charge
                        obj.status = "refueling";
                        obj.taskFinishTime = (obj.fuelTankSize - obj.currentFuel) / obj.refuelRate * obj.fleetSize + obj.airport.currentTime;
                        obj.airport.powerUsed = obj.airport.powerUsed + (obj.fuelTankSize - obj.currentFuel);
                    elseif obj.status == "flight2refill"
                        % go to refilling
                        obj.status = "refilling";
                        waterToAdd = obj.usefulLoad - obj.currentFuel - obj.currentWater;
                        obj.taskFinishTime = waterToAdd / obj.scoopRate;
                        obj.statusStartTime = obj.airport.currentTime;
                    end
                end

                % update position
                obj.x = newX;
                obj.y = newY;

            elseif obj.status == "extinguishing"

                obj.extinguishingProgress = obj.extinguishingProgress + (obj.currentWater * obj.fleetSize);
                obj.currentWater = 0;

                if obj.extinguishingProgress >= obj.waterRequired
                    % if fire is extinguished, go back home
                    obj.targetFire.extinguish(obj.targetX, obj.targetY)
                    obj.status = "return2base";
                    obj.targetX = obj.airport.x;
                    obj.targetY = obj.airport.y;
                    obj.targetFire = [];
                    obj.statusStartTime = obj.airport.currentTime;
                    obj.extinguishingProgress = 0;

                    % let base know
                    obj.airport.fireExtinguished(obj.targetFireIndex);
                else
                    % go to the lake to refill water
                    obj.status = "flight2refill";
                    obj.targetX = obj.lakeX;
                    obj.targetY = obj.lakeY;
                    obj.statusStartTime = obj.airport.currentTime;
                end
                
                % update fuel
                obj.currentFuel = obj.currentFuel - (obj.airport.currentTime - obj.statusStartTime) * obj.fuelFlow;

            elseif obj.status == "refueling"

                if obj.airport.currentTime > obj.taskFinishTime
                    % going to idle
                    obj.status = "idle";
                    obj.currentFuel = obj.fuelTankSize;
                    obj.airport.heliReady(obj);
                end

            elseif obj.status == "refilling"

                if obj.airport.currentTime > obj.taskFinishTime
                    % go to flight2target
                    obj.status = "flight2target";
                    obj.targetX = obj.fireX;
                    obj.targetY = obj.fireY;

                    % update fuel and water
                    obj.currentWater = obj.usefulLoad - obj.currentFuel;
                    obj.currentFuel = obj.currentFuel - (obj.airport.currentTime - obj.statusStartTime) * obj.fuelFlow;

                    obj.statusStartTime = obj.airport.currentTime;
                end

            elseif obj.status == "crewPrep"

                if obj.airport.currentTime > obj.taskFinishTime
                    % go to flight2refill
                    obj.status = "flight2refill";
                    obj.statusStartTime = obj.airport.currentTime;
                end

            end
        end

        % drone has just been given a job
        function statusChangeFlight2Prep(obj, fire, index, fireX, fireY)

            if obj.firstMission
                obj.status = "crewPrep";
                obj.firstMission = 0;
            else
                obj.status = "flight2refill";
            end
            obj.targetX = obj.lakeX;
            obj.targetY = obj.lakeY;
            obj.targetFire = fire;
            obj.targetFireIndex = index;
            obj.taskFinishTime = obj.airport.currentTime + obj.crewPrepTime;
            obj.fireX = fireX;
            obj.fireY = fireY;
        end
    end
end