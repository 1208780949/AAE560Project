from buildings import *
from humans import *
from aircraft import *
from matplotlib import pylab as plt
from matplotlib import animation
from simulationManager import *
import numpy as np

mapX = 20000  # size of the map in x in m
mapY = 20000  # size of the map in y in m
droneSpeed = 26.8224  # drone speed in m/s (60 mph)
maxRequestTime = 7200  # maximum time in between requests
minRequestTime = 3600  # minimum time in between requests
maxTime = 50000  # simulation end time in seconds
timeStep = 1.0  # time step in seconds
airportTrafficDensity = 120  # one flight every this many seconds
minWindShift = 7200  # minimum time between an ops direction change occurring at airport
maxWindShift = 36000  # maximum time between an ops direction change occurring at airport

# ----------------
#  initialization
# ----------------

numFacilities = 2  # number of facilities
numEmployeesPerFacility = 2  # number of employees per facility
numDronesPerFacility = 8  # number of drones per facility
numDestination = 80  # number of destination per facility
destinations = []
facilities = []
rng1 = np.random.RandomState(5738431)
rng2 = np.random.RandomState(3191933)
rng3 = np.random.RandomState(6838294)
rng4 = np.random.RandomState(1589563)  # airport RNG

sim = SimulationManager(maxTime, timeStep)

# initialize airport and its traffic
x1 = rng4.randint(0, mapX)
y1 = rng4.randint(0, mapY)
rwyHdg = rng4.randint(0, 359) * (math.pi / 180)  # cartesian direction in rad, not cardinal direction
rwyLength = 10000 * 0.3048  # RWY length in meters
x2 = rwyLength * math.cos(rwyHdg) + x1
y2 = rwyLength * math.sin(rwyHdg) + y1
airport = Airport(x1, y1, x2, y2, rwyLength, rng4.randint(0, 1000000), minWindShift, maxWindShift, sim)
airportTraffic = AirportTraffic(airportTrafficDensity, rng4.randint(0, 100000), sim, airport)

# initialize facilities
for i in range(0, numFacilities):
    employees = []
    drones = []
    for j in range(0, numEmployeesPerFacility):
        employees.append(Employee(sim))
    for j in range(0, numDronesPerFacility):
        drones.append(Drone(sim, droneSpeed, airportTraffic))

    xPos = rng1.randint(0, mapX)
    yPos = rng1.randint(0, mapY)

    fac = SendingFacility(employees, drones, xPos, yPos)
    facilities.append(fac)

    # set drone facility
    for j in range(0, numDronesPerFacility):
        drones[j].set_base(fac)

# initialize destinations
for i in range(0, numDestination):
    xPos = rng1.randint(0, mapX)
    yPos = rng1.randint(0, mapY)

    # iterate through facilities to find the closest
    closestFacility = None
    closestDist = math.sqrt(mapX**2 + mapY**2)
    for j in range(0, numFacilities):
        fac = facilities[j]
        dist = math.sqrt((xPos - fac.x)**2 + (yPos - fac.y)**2)
        if dist < closestDist:
            closestFacility = fac
            closestDist = dist

    # initialize customer at the destinations
    customer = Customer(sim, rng3.randint(0, 100000))

    destinations.append(Destination(minRequestTime, maxRequestTime, xPos, yPos, rng2.randint(0, 100000), closestFacility, customer))

# --------------------
#  run the simulation
# --------------------

animateSimulation = False

if animateSimulation:
    fig, ax = plt.subplots()

    def animate(i):
        ax.clear()
        ax.plot([airport.x1, airport.x2], [airport.y1, airport.y2])

        # print(str(len(facilities[0].pendingDeliveries)) + " " + str(len(facilities[1].pendingDeliveries)))
        # print(airport.opsDirection)

        # update drones
        for facility in facilities:
            ax.plot(facility.x,facility.y, "o", color="red")
            facility.update()
            for drone in facility.drones:
                drone.update()
                if drone.status != "idling":
                    ax.plot(drone.x, drone.y, "x", color="black")

        # update destination
        for dest in destinations:
            dest.request_update(i * timeStep)
            color = "blue" if dest.hasActiveRequest else "black"
            ax.plot(dest.x, dest.y, "o", color=color)

        # update airport traffic
        airport.update()
        airportTraffic.update()
        for traffic in airportTraffic.relevantTraffic:
            ax.plot(traffic.x, traffic.y, "+", color="Red")

        # enforce plot limit
        # plt.axis("equal")
        ax.set_xlim(0, mapX)
        ax.set_ylim(0, mapY)

        # update simulation time
        sim.currentTime = i * timeStep


    a = animation.FuncAnimation(fig, animate, frames=int(maxTime / timeStep), interval=100)
    plt.show()

else:

    loggingRate = 100  # 1 data point every 10 seconds
    idlingDrones = []
    loadingDrones = []
    deliveringDrones = []
    unloadingDrones = []
    returningDrones = []
    activeDrones = []
    activeRequests = []
    pendingRequests = []
    freeEmployees = []
    time = []

    while sim.currentTime <= maxTime:
        # print(str(len(facilities[0].pendingDeliveries)) + " " + str(len(facilities[1].pendingDeliveries)))
        # print(airport.opsDirection)

        logThis = sim.currentTime % loggingRate == 0

        numIdling = 0
        numLoading = 0
        numDelivering = 0
        numUnloading = 0
        numReturning = 0
        numActiveRequests = 0
        numPendingRequest = 0
        numFreeEmployee = 0

        # update drones
        for facility in facilities:
            facility.update()
            freeEmployThisFacility = 0
            if logThis:
                numActiveRequests += len(facility.activeDeliveries)
                numPendingRequest += len(facility.pendingDeliveries)
                for i in range(0, len(facility.employees)):
                    if facility.employees[i].isFree:
                        numFreeEmployee += 1

            for drone in facility.drones:
                drone.update()
                if logThis:
                    if drone.status == "idling":
                        numIdling += 1
                    elif drone.status == "loading":
                        numLoading += 1
                    elif drone.status == "delivering":
                        numDelivering += 1
                    elif drone.status == "unloading":
                        numUnloading += 1
                    elif drone.status == "returning":
                        numReturning += 1

        if logThis:
            idlingDrones.append(numIdling)
            loadingDrones.append(numLoading)
            deliveringDrones.append(numDelivering)
            unloadingDrones.append(numUnloading)
            returningDrones.append(numReturning)
            activeDrones.append(numLoading + numDelivering + numUnloading + numReturning)
            activeRequests.append(numActiveRequests)
            pendingRequests.append(numPendingRequest)
            freeEmployees.append(numFreeEmployee)
            time.append(sim.currentTime)

        # update destination
        for dest in destinations:
            dest.request_update(sim.currentTime)

        # update airport traffic
        airport.update()
        airportTraffic.update()

        # update simulation time
        sim.currentTime += timeStep

    print("Average number of idling drones: " + str(np.average(idlingDrones)))
    print("Average number of active drones: " + str(np.average(activeRequests)))
    print("Average number of pending requests: " + str(np.average(pendingRequests)))
    print("Average number of active requests: " + str(np.average(activeRequests)))
    print("Average number of free employees: " + str(np.average(freeEmployees)))

    plt.figure(0)
    plt.plot(time, idlingDrones)
    plt.plot(time, loadingDrones)
    plt.plot(time, deliveringDrones)
    plt.plot(time, unloadingDrones)
    plt.plot(time, returningDrones)
    plt.legend(["Idling", "Loading", "Delivering", "Unloading", "Returning"])
    plt.xlabel("Time (s)")
    plt.ylabel("Number of Drones")
    plt.title("Drone Status Plot")

    plt.figure(1)
    plt.plot(time, idlingDrones)
    plt.plot(time, activeDrones)
    plt.legend(["Idling", "Active"])
    plt.xlabel("Time (s)")
    plt.ylabel("Number of Drones")
    plt.title("Drone Status Plot")

    plt.figure(2)
    plt.plot(time, activeRequests)
    plt.plot(time, pendingRequests)
    plt.legend(["Active", "Pending"])
    plt.xlabel("Time (s)")
    plt.ylabel("Number of Requests")
    plt.title("Request Plot")

    plt.figure(3)
    plt.plot(time, freeEmployees)
    plt.xlabel("Time (s)")
    plt.ylabel("Number of Free Employees")
    plt.title("Employee Plot")
    plt.show()
