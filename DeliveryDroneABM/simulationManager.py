class SimulationManager:

    def __init__(self, max_time, time_step):
        self.loadingTime = 60  # loading time per package
        self.maxUnloadingTime = 360  # maximum unloading time per package, simulating client not paying attention or is new drone delivery system
        self.minUnloadingTime = 60  # minimum unloading time per package

        self.maxTime = max_time, time_step
        self.timeStep = time_step
        self.currentTime = 0