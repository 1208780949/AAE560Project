import numpy as np


class Employee:

    def __init__(self, simulation_manager):
        self.loadingTime = simulation_manager.loadingTime  # time in seconds it takes for the employee to load a package
        self.isFree = True  # is this employee working


class Customer:

    def __init__(self, simulation_manager, seed):
        self.minUnloadingTime = simulation_manager.minUnloadingTime
        self.maxUnloadingTime = simulation_manager.maxUnloadingTime
        self.rng = np.random.RandomState(seed)

    def get_unloading_time(self):
        return self.rng.randint(self.minUnloadingTime, self.maxUnloadingTime)