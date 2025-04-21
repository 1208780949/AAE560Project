import math

import numpy as np

from buildings import SendingFacility, Airport
from simulationManager import *


class Drone:

    def __init__(self, simulation_manager: SimulationManager, max_speed, airport_traffic):
        self.x = 0
        self.y = 0
        self.target = None
        self.job = None
        self.taskCompleteTime = -1.0
        self.status = "idling"
        self.base = None  # which delivery center this drone belongs to
        self.employee = None  # the employee loading on this drone
        self.airportTraffic = airport_traffic

        self.simulationManager = simulation_manager
        self.maxSpeed = max_speed  # max speed of the drones in m/s

    def set_base(self, base: SendingFacility):
        self.base = base

    def update_position(self, x, y):
        self.x = x
        self.y = y

    def loading(self, target, employee):
        self.job = target
        self.target = target
        self.taskCompleteTime = self.simulationManager.currentTime + self.simulationManager.loadingTime
        self.status = "loading"
        self.employee = employee
        self.employee.isFree = False

    def flight(self):
        # calculate new position after traveling
        dx = self.target.x - self.x
        dy = self.target.y - self.y
        dist = math.sqrt(dx**2 + dy**2)
        travel_dist = self.maxSpeed * self.simulationManager.timeStep
        ratio = travel_dist / dist
        new_x = self.x + dx * ratio
        new_y = self.y + dy * ratio

        # handling airspace closure due to landing and departing airport traffic
        # for landing traffic, 5 mile final to approach end of runway is closed if there are planes within
        # 8 mile final. The closure area is 2 miles wide
        # for departing traffic, approach end of the runway to 3 miles extended centerline from departure end is closed
        # if there are planes departing. The closure area is 2 miles wide
        freeze = False

        if self.airportTraffic.departingTraffic > 0:
            closure = self.airportTraffic.airport.departure_end_closure()
            inside_closure_now = self.inside_rectangle(closure[0][0], closure[0][1], closure[1][0], closure[1][1], closure[2][0], closure[2][1], self.x, self.y)
            inside_closure_next = self.inside_rectangle(closure[0][0], closure[0][1], closure[1][0], closure[1][1], closure[2][0], closure[2][1], new_x, new_y)
            if not inside_closure_now and inside_closure_next:
                freeze = True

        if self.airportTraffic.landingTraffic > 0:
            closure = self.airportTraffic.airport.approach_end_closure()
            inside_closure_now = self.inside_rectangle(closure[0][0], closure[0][1], closure[1][0], closure[1][1], closure[2][0], closure[2][1], self.x, self.y)
            inside_closure_next = self.inside_rectangle(closure[0][0], closure[0][1], closure[1][0], closure[1][1], closure[2][0], closure[2][1], new_x, new_y)
            if not inside_closure_now and inside_closure_next:
                freeze = True

        # if new position ends up in an overshoot, snap the drone to destination
        if (self.target.x - new_x) * dx < 0:
            new_x = self.target.x
            new_y = self.target.y
            self.unloading() if self.status == "delivering" else self.job_complete()

        if not freeze:
            self.update_position(new_x, new_y)

    def unloading(self):
        self.status = "unloading"
        self.taskCompleteTime = self.simulationManager.currentTime + self.target.customer.get_unloading_time()
        self.target = self.base

    def job_complete(self):
        self.status = "idling"
        self.target = None
        self.base.job_complete(self)

    def update(self):
        if self.status == "loading":
            if self.simulationManager.currentTime > self.taskCompleteTime:
                self.status = "delivering"
                self.flight()
                self.taskCompleteTime = -1.0
                self.employee.isFree = True
                self.employee = None
        elif self.status == "delivering" or self.status == "returning":
            self.flight()
        elif self.status == "unloading":
            if self.simulationManager.currentTime > self.taskCompleteTime:
                self.status = "returning"
                self.flight()
                self.taskCompleteTime = -1.0
                self.job.hasActiveRequest = False

    def inside_rectangle(self, ax, ay, bx, by, cx, cy, px, py):
        w = (bx - ax) * (px - ax) + (by - ay) * (py - ay)
        x = (bx - ax)**2 + (by - ay)**2
        y = (cx - bx) * (px - bx) + (cy - by) * (py - by)
        z = (cx - bx)**2 + (cy - by)**2

        return 0 <= w <= x and 0 <= y <= z


class AirportTraffic:

    def __init__(self, density, seed, simulation_manager: SimulationManager, airport: Airport):
        self.trafficDensity = density  # one takeoff or landing per this many seconds
        self.rng = np.random.RandomState(seed)
        self.nextTrafficInjection = 0
        self.simulationManager = simulation_manager
        self.airport = airport
        self.relevantTraffic = []
        self.departingTraffic = 0
        self.landingTraffic = 0
        self.departingTrafficSpawnTime = -1
        self.invisibleTraffic = []  # used for traffic on takeoff roll. They are relevant, but should not be visible

    def random_traffic(self):
        coin_flip = self.rng.randint(0, 2)
        if coin_flip == 0:
            return "landing"
        else:
            return "takeoff"

    def random_speed(self):
        # generate a random number between 0-1 to scale vref or v2
        return self.rng.random(1)

    def update(self):

        self.landingTraffic = 0
        for traffic in self.relevantTraffic:
            traffic.flight()
            if not traffic.isRelevant:
                self.relevantTraffic.remove(traffic)
                if type(traffic) is DepartingTraffic:
                    self.departingTraffic -= 1

            # only traffic within 8 mile final as landing traffic for airspace closure purposes
            if type(traffic) is LandingTraffic:
                final_dist = math.sqrt((traffic.x - traffic.targetX)**2 + (traffic.y - traffic.targetY)**2)
                if final_dist < 14816:
                    # have to go with this rather inefficient approach, because there is an edge case where a plane
                    # could not be removed if one is added at the same time
                    self.landingTraffic += 1

        if self.simulationManager.currentTime >= self.nextTrafficInjection:
            # traffic injection
            self.nextTrafficInjection += self.trafficDensity
            traffic_type = self.random_traffic()
            if traffic_type == "takeoff":
                self.departingTraffic += 1
                # 45 seconds from departing traffic appearing to appear at the departure
                # end of the runway to simulate takeoff roll
                self.departingTrafficSpawnTime = self.simulationManager.currentTime + 45
            else:
                speed_scale = self.random_speed()
                traffic = LandingTraffic(self.airport, speed_scale, self.simulationManager)
                self.relevantTraffic.append(traffic)

        if self.simulationManager.currentTime >= self.departingTrafficSpawnTime != -1:
            speed_scale = self.random_speed()
            traffic = DepartingTraffic(self.airport, speed_scale, self.simulationManager)
            self.relevantTraffic.append(traffic)
            self.departingTrafficSpawnTime = -1


class Airplane:

    def __init__(self, speed, altitude, x, y, vertical_speed, simulation_manager: SimulationManager, target_x, target_y, max_altitude):
        self.speed = speed
        self.altitude = altitude
        self.x = x
        self.y = y
        self.verticalSpeed = vertical_speed
        self.simulationManager = simulation_manager
        self.isRelevant = True
        self.targetX = target_x
        self.targetY = target_y
        self.maxAltitude = max_altitude

    def flight(self):
        # calculate new position after traveling
        dx = self.targetX - self.x
        dy = self.targetY - self.y
        dist = math.sqrt(dx ** 2 + dy ** 2)
        travel_dist = self.speed * self.simulationManager.timeStep
        ratio = travel_dist / dist
        new_x = self.x + dx * ratio
        new_y = self.y + dy * ratio

        if self.verticalSpeed < 0:
            # landing
            if (self.targetX - new_x) * dx < 0:
                self.isRelevant = False
        else:
            # departing
            if self.altitude > self.maxAltitude:
                self.isRelevant = False

        self.x = new_x
        self.y = new_y
        self.altitude += self.verticalSpeed * self.simulationManager.timeStep


class LandingTraffic(Airplane):

    finalDistance = 18520  # 10 mile final in m
    initAltitude = 970.59207232116  # standard 3 deg glide at 10 mile final in m
    maxVref = 77.1667  # 150 kts in m/s
    minVref = 61.7333  # 120 kts in m/s

    def __init__(self, airport: Airport, speed_scale, simulation_manager: SimulationManager):
        rwy_norm_delta_x = (airport.x2 - airport.x1) / airport.rwyLength
        rwy_norm_delta_y = (airport.y2 - airport.y1) / airport.rwyLength
        if airport.opsDirection == 1:
            init_x = -rwy_norm_delta_x * self.finalDistance + airport.x1
            init_y = -rwy_norm_delta_y * self.finalDistance + airport.y1
            target_x = airport.x1
            target_y = airport.y1
        else:
            init_x = rwy_norm_delta_x * self.finalDistance + airport.x2
            init_y = rwy_norm_delta_y * self.finalDistance + airport.y2
            target_x = airport.x2
            target_y = airport.y2
        vref = speed_scale * (self.maxVref - self.minVref) + self.minVref
        appr_time = self.finalDistance / vref
        vertical_speed = -self.initAltitude / appr_time
        Airplane.__init__(self, vref, self.initAltitude, init_x, init_y, vertical_speed, simulation_manager, target_x, target_y, 0)


class DepartingTraffic(Airplane):

    finalAltitude = 457.2  # beyond 1500 ft, the traffic will no longer be relevant as separation will be >1000 ft
    maxV2 = 82.3111  # 160 kts in m/s
    minV2 = 66.8778  # 130 kts in m/s
    verticalSpeed = 10.16  # 2000 ft/min in m/s

    def __init__(self, airport: Airport, speed_scale, simulation_manager: SimulationManager):
        rwy_norm_delta_x = (airport.x2 - airport.x1) / airport.rwyLength
        rwy_norm_delta_y = (airport.y2 - airport.y1) / airport.rwyLength
        if airport.opsDirection == 1:
            init_x = airport.x2
            init_y = airport.y2
            target_x = rwy_norm_delta_x * 100000 + airport.x2
            target_y = rwy_norm_delta_y * 100000 + airport.y2
        else:
            init_x = airport.x1
            init_y = airport.y1
            target_x = -rwy_norm_delta_x * 100000 + airport.x1
            target_y = -rwy_norm_delta_x * 100000 + airport.y1
        v2 = speed_scale * (self.maxV2 - self.minV2) + self.minV2
        initAlt = 15.24  # 50 ft initial altitude at departure end of the runway. Minimum climb gradient allowed in most airline performance calculators
        Airplane.__init__(self, v2, initAlt, init_x, init_y, self.verticalSpeed, simulation_manager, target_x, target_y, self.finalAltitude)
