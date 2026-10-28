function results = V2H_EconomicSimulator_HourlySOC(ownership, battery_kWh, load_profile, outage_days, distance_km, params)
%V2H_ECONOMICSIMULATOR_HOURLYSOC Household vehicle-to-home backup simulation.
%
%   RESULTS = V2H_ECONOMICSIMULATOR_HOURLYSOC(OWNERSHIP, BATTERY_KWH,
%   LOAD_PROFILE, OUTAGE_DAYS, DISTANCE_KM) simulates one household
%   supplied by a single electric vehicle during a grid outage, hour by
%   hour, and returns technical and economic results.
%
%   The vehicle discharges to the household until its state of charge
%   reaches the minimum. It then drives to a charging point, recharges,
%   and returns; the household is unsupplied for the duration of that
%   round trip. Only one recharge trip is made per day.
%
%   Inputs
%     OWNERSHIP     Who provides the vehicle. One of:
%                     'Personal'              the household's own vehicle.
%                                             Battery wear is charged to
%                                             the household; no hire fee.
%                     'Hired'                 a rented vehicle. A daily
%                                             hire fee applies; wear is not
%                                             charged to the household.
%                     '3rd Party with Driver' a rented vehicle with a
%                                             driver. Hire fee plus a
%                                             call-out fee and an hourly
%                                             driver rate per recharge trip.
%                   The string must match exactly.
%
%     BATTERY_KWH   Usable vehicle battery capacity, in kWh. Any positive
%                   value; the interface offers 60, 77 and 100.
%
%     LOAD_PROFILE  Household demand for ONE day: a vector of 24 hourly
%                   values in kWh. The profile is repeated for each day of
%                   the outage, so a longer vector simulates a
%                   correspondingly longer period.
%
%     OUTAGE_DAYS   Outage duration in whole days. Sets both the simulated
%                   horizon and the compensation received.
%
%     DISTANCE_KM   ONE-WAY distance from the household to the charging
%                   point, in km. Determines both the energy reserved for
%                   travel and the hours the vehicle is away.
%
%     PARAMS        Optional. Cost and assumption constants, as returned by
%                   EVEN_PARAMETERS. Omitted means the defaults in that
%                   file are used.
%
%   Output fields (RESULTS)
%     supply_availability                Fraction of demand met, 0 to 1.
%                                        Multiply by 100 for a percentage.
%     total_energy_demand                Total household demand, kWh.
%     total_energy_supplied              Energy delivered by the vehicle, kWh.
%     energy_loss_kWh                    Charging and travel losses, kWh.
%     charge_cycles_used                 Number of recharge trips made.
%     ev_unavailable_time                Hours the household was unsupplied.
%     soc_profile                        Vehicle state of charge per hour, %.
%     unserved_load_profile              Unmet demand per hour, kWh.
%     total_cost                         All costs combined, SEK.
%     total_cost_per_kWh                 Total cost per kWh delivered, SEK.
%     driver_cost                        Driver call-out and hourly cost, SEK.
%     hire_cost                          Vehicle hire cost, SEK.
%     compensation_received              Statutory outage compensation, SEK.
%     additional_cost_after_compensation Total cost minus compensation, SEK.
%
%   Example
%     S = load('input_files/household/Loadprofile_35.mat');
%     r = V2H_EconomicSimulator_HourlySOC('Personal', 77, S.load_profile(:).', 2, 10);
%     fprintf('%.1f %% of demand met at %.2f SEK/kWh\n', ...
%         100*r.supply_availability, r.total_cost_per_kWh);
%
%   See also SIMULATE_CLINIC_BACKUP, EVEN_RUN_SCENARIO, EVEN_PARAMETERS.

% ==== Constants ====
if nargin < 6 || isempty(params)
    params = even_parameters();
end
EFFICIENCY               = params.v2h.efficiency;
CHARGING_COST_PER_KWH    = params.v2h.charging_cost_SEK_per_kWh;
DEGRADATION_COST_PER_KWH = params.v2h.degradation_cost_SEK_per_kWh;
TRAVEL_ENERGY_PER_KM     = params.v2h.travel_energy_kWh_per_km;
DRIVER_HOURLY_COST       = params.v2h.driver_hourly_cost_SEK;
HIRE_COST_PER_DAY        = params.v2h.hire_cost_SEK_per_day;
VEHICLE_SPEED_KMPH       = params.v2h.vehicle_speed_kmph;
CHARGING_DURATION_HR     = params.v2h.charging_duration_hr;
INITIAL_SOC              = params.v2h.initial_SOC_pct;
MIN_SOC                  = params.v2h.min_SOC_pct;
DRIVER_FX_COST           = params.v2h.driver_fixed_cost_SEK;
COMPENSATION_PER_DAY     = params.v2h.compensation_SEK_per_day;

% ==== Setup ====
travel_energy_oneway = distance_km * TRAVEL_ENERGY_PER_KM;
travel_energy_roundtrip = 2 * travel_energy_oneway;
travel_time_hr = 2 * distance_km / VEHICLE_SPEED_KMPH;

load_profile = repmat(load_profile, 1, outage_days);
total_hours = length(load_profile);

battery_capacity = battery_kWh;
soc = INITIAL_SOC;
ev_unavailable_hours = 0;
charge_cycles = 0;
energy_supplied = 0;
unmet_load = 0;
charging_today = false;
cumulative_downtime = 0;

% Initialize profiles
soc_profile = zeros(1, total_hours);
unserved_load_profile = zeros(1, total_hours);

% ==== Simulation loop ====
for t = 1:total_hours
    hour_load = load_profile(t);

    if mod(t-1, 24) == 0
        charging_today = false;
    end

    %log unmet load and time during charging period
    if ev_unavailable_hours > 0
        unmet_load = unmet_load + hour_load;
        unserved_load_profile(t) = hour_load;
        cumulative_downtime = cumulative_downtime + 1;
        ev_unavailable_hours = ev_unavailable_hours - 1;
        soc_profile(t) = soc_profile(t-1);
        continue;
    end

    usable_energy_kWh = (((soc - MIN_SOC) / 100) * battery_capacity) - travel_energy_oneway;

    if usable_energy_kWh < hour_load && ~charging_today
        charge_cycles = charge_cycles + 1;
        ev_unavailable_hours = ceil(travel_time_hr + CHARGING_DURATION_HR) - 1;
        charging_today = true;

        if t > 1
            soc_profile(t) = soc_profile(t-1);
        else
            soc_profile(t) = INITIAL_SOC;   % recharge trip needed in the first hour
        end
        available_energy_after_travel = battery_capacity - travel_energy_oneway;
        soc = (available_energy_after_travel / battery_capacity) * 100;

        unmet_load = unmet_load + hour_load;
        unserved_load_profile(t) = hour_load;
        cumulative_downtime = cumulative_downtime + 1;
        continue;
    end

    if usable_energy_kWh >= hour_load
        energy_supplied = energy_supplied + hour_load;
        soc = soc - (hour_load / battery_capacity) * 100;
        soc_profile(t) = soc;
    else
        unmet_load = unmet_load + hour_load;
        unserved_load_profile(t) = hour_load;
        cumulative_downtime = cumulative_downtime + 1;
        soc_profile(t) = soc;
    end
end

% ==== Post-calculation ====
total_demand = sum(load_profile);
supply_availability = energy_supplied / total_demand;
total_energy_used = energy_supplied + (charge_cycles * travel_energy_roundtrip);
charging_energy_input = total_energy_used / EFFICIENCY;
charging_cost = charging_energy_input * CHARGING_COST_PER_KWH;

if strcmpi(ownership, 'Personal')
    degradation_cost = energy_supplied * DEGRADATION_COST_PER_KWH;
else
    degradation_cost = 0;
end

travel_cost = charge_cycles * travel_energy_roundtrip / EFFICIENCY * CHARGING_COST_PER_KWH;

if ~strcmpi(ownership, 'Personal')
    hire_cost = outage_days * HIRE_COST_PER_DAY;
else
    hire_cost = 0;
end

if strcmpi(ownership, '3rd Party with Driver')
    driver_cost = DRIVER_FX_COST + charge_cycles * (travel_time_hr + CHARGING_DURATION_HR) * DRIVER_HOURLY_COST;
else
    driver_cost = 0;
end

total_cost = charging_cost + degradation_cost + travel_cost + hire_cost + driver_cost;
if energy_supplied > 0
    cost_per_kWh = total_cost / energy_supplied;
else
    cost_per_kWh = NaN;   % undefined when nothing was delivered
end

% Outage compensation scales with the number of interrupted days. The
% original model defined 1200 SEK for one day and 2400 SEK for two days;
% this expression reproduces both values exactly and extends the same rate
% to longer outages instead of returning zero.
compensation = COMPENSATION_PER_DAY * outage_days;

additional_cost = total_cost - compensation;

% ==== Results ====
results.total_cost_per_kWh = cost_per_kWh;
results.total_cost = total_cost;
results.driver_cost = driver_cost;
results.hire_cost = hire_cost;
results.supply_availability = supply_availability;
results.energy_loss_kWh = charging_energy_input - energy_supplied;
results.charge_cycles_used = charge_cycles;
results.ev_unavailable_time = cumulative_downtime;
results.compensation_received = compensation;
results.additional_cost_after_compensation = additional_cost;
results.total_energy_demand = total_demand;
results.total_energy_supplied = energy_supplied;
results.soc_profile = soc_profile;
results.unserved_load_profile = unserved_load_profile;

end
