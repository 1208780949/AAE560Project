import numpy as np

from humans import Employee, Customer


class SendingFacility:

    def __init__(self, employees: list[Employee], drones, x, y):
        self.pendingDeliveries = []  # delivery that has not been started
        self.activeDeliveries = []  # delivery in progress
        self.idlingDrones = []  # idling drones
        self.activeDrones = []  # active drones

        self.employees = employees  # employees working at the facility
        self.drones = drones.copy()  # drones belonging to this facility
        self.idlingDrones = drones.copy()  # set all drones to be idling as initial condition
        self.x = x  # x location of the facility in m
        self.y = y  # y location of the facility in m

        for i in range(0, len(drones)):
            drones[i].update_position(x, y)

    def request_delivery(self, dest):
        self.pendingDeliveries.append(dest)

    def update(self):

        # find free employee
        freeEmployee = []
        for i in range(0, len(self.employees)):
            if self.employees[i].isFree:
                freeEmployee.append(self.employees[i])

        if len(self.pendingDeliveries) != 0 and len(self.idlingDrones) != 0 and len(freeEmployee) != 0:
            # if there are pending deliveries and idling drones, start delivery
            assignedDrone = self.idlingDrones[0]
            assignedDest = self.pendingDeliveries[0]
            del self.idlingDrones[0]
            del self.pendingDeliveries[0]
            self.activeDrones.append(assignedDrone)
            self.activeDeliveries.append(assignedDest)
            assignedDrone.loading(assignedDest, freeEmployee[0])

    def job_complete(self, drone):
        self.activeDrones.remove(drone)
        self.idlingDrones.append(drone)
        self.activeDeliveries.remove(drone.job)
        self.update()


class Destination:

    def __init__(self, min_request_time, max_request_time, x, y, seed, facility, customer: Customer):
        self.nextRequestTime = 0  # next time a request is going to be made
        self.hasActiveRequest = False  # if the building has an active request
        self.minRequestTime = min_request_time  # max time between requests
        self.maxRequestTime = max_request_time  # min time between requests
        self.x = x  # x location of the destination in m
        self.y = y  # y location of the destination in m
        self.rng = np.random.RandomState(seed)
        self.nextRequestTime = self.rng.randint(0, min_request_time)
        self.facility = facility  # the facility that the building is connected to
        self.customer = customer

    # active request if nextRequestTime is reached
    # t = current time
    def request_update(self, t):
        if t > self.nextRequestTime and not self.hasActiveRequest:
            self.hasActiveRequest = True
            self.facility.request_delivery(self)
            self.nextRequestTime += self.rng.randint(self.minRequestTime, self.maxRequestTime)


class Airport:

    def __init__(self, x1, y1, x2, y2, rwy_length, seed, min_wind_shift, max_wind_shift, simulation_manager):
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
        self.rng = np.random.RandomState(seed)
        self.opsDirection = self.rng.randint(1, 3)  # which way traffic is flowing. 1 means flowing from 1 to 2, 2 means flowing from 2 to 1
        self.nextWindChange = self.rng.randint(min_wind_shift, max_wind_shift)
        self.minWindShift = min_wind_shift
        self.maxWindShift = max_wind_shift
        self.rwyLength = rwy_length
        self.simulationManager = simulation_manager

    def approach_end_closure(self):
        appr_x = self.x1 if self.opsDirection == 1 else self.x2
        appr_y = self.y1 if self.opsDirection == 1 else self.y2
        dep_x = self.x2 if self.opsDirection == 1 else self.x1
        dep_y = self.y2 if self.opsDirection == 1 else self.y1

        # 1 mile to the left of the runway
        ax = -(dep_y - appr_y) / self.rwyLength * 1852 + appr_x
        ay = (dep_x - appr_x) / self.rwyLength * 1852 + appr_y

        # 1 mile to the right of the runway
        bx = (dep_y - appr_y) / self.rwyLength * 1852 + appr_x
        by = -(dep_x - appr_x) / self.rwyLength * 1852 + appr_y

        # 5 miles final, 1 mile offset to the right
        cx = bx + (appr_x - dep_x) / self.rwyLength * 1852 * 5
        cy = by + (appr_y - dep_y) / self.rwyLength * 1852 * 5

        return [[ax, ay], [bx, by], [cx, cy]]

    def departure_end_closure(self):

        appr_x = self.x1 if self.opsDirection == 1 else self.x2
        appr_y = self.y1 if self.opsDirection == 1 else self.y2
        dep_x = self.x2 if self.opsDirection == 1 else self.x1
        dep_y = self.y2 if self.opsDirection == 1 else self.y1

        # 1 mile to the left of the runway
        ax = -(dep_y - appr_y) / self.rwyLength * 1852 + appr_x
        ay = (dep_x - appr_x) / self.rwyLength * 1852 + appr_y

        # 1 mile to the right of the runway
        bx = (dep_y - appr_y) / self.rwyLength * 1852 + appr_x
        by = -(dep_x - appr_x) / self.rwyLength * 1852 + appr_y

        # 3 extended centerline on departure end, 1 mile offset to the right
        cx = bx + (dep_x - appr_x) / self.rwyLength * 1852 * 3
        cy = by + (dep_y - appr_y) / self.rwyLength * 1852 * 3

        return [[ax, ay], [bx, by], [cx, cy]]

    def update(self):
        if self.simulationManager.currentTime >= self.nextWindChange:
            self.opsDirection = 1 if self.opsDirection == 2 else 2
            self.nextWindChange += self.rng.randint(self.minWindShift, self.maxWindShift)