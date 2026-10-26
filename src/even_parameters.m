function P = even_parameters()
%EVEN_PARAMETERS Economic, emission and assumption constants for EVEN.
%
%   P = EVEN_PARAMETERS() returns a struct holding every constant that
%   encodes a regional or contextual assumption. All values below are for
%   the Swedish case study. To adapt the suite to another country or price
%   year, edit this file only; no simulation logic needs to change.
%
%   The engines call this function themselves, so editing a value here
%   changes every module consistently. Each engine also accepts a parameter
%   struct as an optional final argument, which allows a scenario to
%   override individual values without editing this file:
%
%       P = even_parameters();
%       P.v2h.charging_cost_SEK_per_kWh = 3.20;
%       r = V2H_EconomicSimulator_HourlySOC('Personal', 77, L, 2, 10, P);
%
%   Currency: Swedish krona (SEK). Energy: kWh. Mass: kg.

%% ---------------------------------------------------------------------
%  Household vehicle-to-home module
%  Used by V2H_EconomicSimulator_HourlySOC.m
% ----------------------------------------------------------------------

% Retail electricity price paid to recharge the vehicle.
P.v2h.charging_cost_SEK_per_kWh = 5.69;

% Cost attributed to battery wear per kWh delivered to the household.
% Applied to personally owned vehicles only.
P.v2h.degradation_cost_SEK_per_kWh = 0.30;

% Paid to a third-party driver, per hour of travel and charging.
P.v2h.driver_hourly_cost_SEK = 400;

% Fixed call-out fee for a third-party driver, per outage.
P.v2h.driver_fixed_cost_SEK = 500;

% Daily rental cost for a hired or third-party vehicle.
P.v2h.hire_cost_SEK_per_day = 1000;

% Regulated outage compensation received by the household, per day.
% The Swedish scheme gives 1200 SEK for the first day; this rate is
% applied to each further day as well.
P.v2h.compensation_SEK_per_day = 1200;

% Round-trip efficiency of vehicle charging and discharging.
P.v2h.efficiency = 0.85;

% Vehicle energy consumption while driving.
P.v2h.travel_energy_kWh_per_km = 0.2;

% Average speed assumed when computing travel time.
P.v2h.vehicle_speed_kmph = 50;

% Time the vehicle spends at the charging point per recharge trip.
P.v2h.charging_duration_hr = 1;

% State of charge at the start of the outage, and the floor below which
% the vehicle will not discharge, both in percent.
P.v2h.initial_SOC_pct = 100;
P.v2h.min_SOC_pct = 50;

%% ---------------------------------------------------------------------
%  Critical infrastructure module
%  Used by simulate_clinic_backup.m and Clinic_Backup_GUI_App.m
% ----------------------------------------------------------------------

% Levelised cost of the solar energy used to charge the fleet.
P.clinic.solar_LCOE_SEK_per_kWh = 1.02;

% Battery wear cost per kWh delivered to the clinic.
P.clinic.degradation_cost_SEK_per_kWh = 0.30;

% Diesel pump price.
P.clinic.diesel_price_SEK_per_L = 22;

% Combustion emission factor for diesel.
P.clinic.CO2_kg_per_L = 2.68;

% Reference generator used for the diesel comparison: a 25 kW unit, with
% its fuel curve given as load fraction against fuel use in litres/hour.
P.clinic.generator_rating_kW = 25;
P.clinic.fuel_curve_load_fraction = [0, 0.50, 0.75, 1.00];
P.clinic.fuel_curve_L_per_hour    = [0, 5.1,  6.6,  9.3];

% Round-trip efficiency of vehicle charging and discharging.
P.clinic.EV_efficiency = 0.92;

% Vehicle energy consumption while driving.
P.clinic.travel_energy_kWh_per_km = 0.2;

% Average speed assumed when computing travel time.
P.clinic.vehicle_speed_kmph = 40;

% Minimum vehicle state of charge, as a fraction.
P.clinic.EV_SOC_min = 0.2;

% Initial vehicle state of charge, as a fraction.
P.clinic.EV_SOC_initial = 0.8;

% Maximum discharge power of a single vehicle, in kW.
P.clinic.EV_max_power_kW = 11;

% Stationary battery limits: maximum charge and discharge power in kW,
% initial state of charge, and the floor below which it will not discharge.
P.clinic.station_max_power_kW = 20;
P.clinic.station_SOC_initial = 0.8;
P.clinic.station_SOC_min = 0.2;

%% ---------------------------------------------------------------------
%  Community microgrid module
%  Used by even_annual_simulation.m
% ----------------------------------------------------------------------

% Total households in the case municipality, used to convert the EV
% penetration level into a number of participating households. Note that
% the engine derives this from the width of the load file, so this value
% documents the full dataset rather than driving the simulation.
P.community.total_households_reference = 5357;

% Round-trip battery efficiencies.
P.community.MG_battery_efficiency = 0.9;
P.community.HH_battery_efficiency = 0.9;
P.community.EV_battery_efficiency = 0.9;

% Minimum states of charge, as fractions.
P.community.MG_SOC_min = 0.2;
P.community.HH_SOC_min = 0.2;
P.community.EV_SOC_min = 0.2;

% Initial states of charge, as fractions.
P.community.MG_SOC_initial = 0.5;
P.community.HH_SOC_initial = 0.8;

% Microgrid battery charge limit as a fraction of its capacity, and its
% discharge limit in kW.
P.community.MG_charge_limit_fraction = 0.5;
P.community.MG_discharge_limit_kW = 500;

% Household battery capacity in kWh, and its charge and discharge limits
% in kW.
P.community.HH_battery_kWh = 5;
P.community.HH_charge_limit_kW = 1;
P.community.HH_discharge_limit_kW = 2;

% Maximum vehicle charge and discharge power in kW.
P.community.EV_power_limit_kW = 11;

% Daily vehicle energy use for ordinary driving, and for the round trip
% between a household and the microgrid.
P.community.EV_travel_kWh_per_day = 2.48;
P.community.EV_travel_to_MG_kWh = 2*0.609;

end
