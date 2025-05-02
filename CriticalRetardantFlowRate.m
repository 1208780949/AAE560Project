clc
clear
close all

% Calculate critical flow rate of retardant required to extinguish fire
%
% Based on:
% https://www.diva-portal.org/smash/get/diva2:588138/FULLTEXT01.pdf
% with high intensity fire with flame length of 4m, which was assumed in
% fire propagation model.
% This model calculate critical flow rate for water.
% 
% This paper provides effectiveness of water vs. fire retardant:
% https://link.springer.com/article/10.1007/s10694-023-01381-z
% Water was about 2x less efficient at extingishing fire than fire
% retardant on a peat field
%
% Fire retardant assumed is the FIRE-TROL 931 at 20% concentration.
% Average density: 1.09 kg/m^3
% https://www.perimeter-solutions.com/wp-content/uploads/2024/06/PERI2643-FIRETROL931_Letter_v1.5.pdf
% 
% A similar mixture is used by US Forset Service:
% https://www.fs.usda.gov/t-d/programs/wfcs/documents/ret_can.pdf

lf = 4; % flame length in m
i = (lf/0.0255)^1.5; % fire intensity
d = i / 2000; % depth of active combustion
q = 0.27 * i / (2 * lf + d); % minimum heat flux that will sustain fire
mcr0 = 12.9e-3; % critical water application rate with no external heat flux
etaWater = 0.7; % water application efficiency
lv = 104.98; % enthalpy of water at 25C in kg/kj
mcr = mcr0 + q / (etaWater * lv); % critical water application rate in kg/m2/s

% assuming 10000 m^2 grid
mcrGrid = mcr * 10000;

% assume the drones can delivery their payload in 10s
mWater = mcrGrid * 10;

% fire retardand is twice more efficiency
wRet = mWater / 2;

% each drone can carry 15.9 kg of payload
numDrones = wRet / 15.9;

disp("Each grid point needs " + wRet + " kg of fire retardant")
disp("Number of grid needed at each grid point: " + ceil(numDrones))
