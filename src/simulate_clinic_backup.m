% SIMULATE_CLINIC_BACKUP Simulates EV-based clinic backup for one scenario, hour by hour.
% EVs are assigned to houses and charge using solar, discharge at clinic, and recharge station battery if idle.

function result = simulate_clinic_backup(EVB, N_EVs, travel_km, month, trace_station_SOC, station_capacity, clinicFile, solarFile, params)
%SIMULATE_CLINIC_BACKUP Simulate EV-based clinic backup for one scenario.
%
%   RESULT = SIMULATE_CLINIC_BACKUP(EVB, N_EVS, TRAVEL_KM, MONTH,
%   TRACE_STATION_SOC, STATION_CAPACITY, CLINICFILE, SOLARFILE, PARAMS)
%   simulates a clinic supplied over 30 days by a fleet of electric
%   vehicles, a stationary battery and household solar generation, and
%   compares the outcome against diesel generation.
%
%   Vehicles discharge at the clinic until they can no longer cover the
%   return trip, then drive to an assigned household, recharge from that
%   household's surplus solar, and return. Idle vehicles with spare energy
%   charge the stationary battery. The clinic load in a given hour is
%   supplied only if it can be met in full.
%
%   Inputs
%     EVB               Usable vehicle battery capacity, in kWh. The
%                       interface offers 60 and 100.
%
%     N_EVS             Number of vehicles in the fleet. Vehicles are
%                       assigned to households in rotation, so a fleet
%                       larger than the number of household solar profiles
%                       shares charging points.
%
%     TRAVEL_KM         ONE-WAY distance between the clinic and a
%                       household, in km. Sets the energy each vehicle
%                       must reserve and the hours it is away.
%
%     MONTH             Month to simulate, 1 for January to 12 for
%                       December. A fixed 30 day window starting on the
%                       first day of that month is simulated.
%
%     TRACE_STATION_SOC Optional, default FALSE. When TRUE, the hourly
%                       stationary battery state of charge is returned in
%                       RESULT.Station_SOC_Trace. Set FALSE for batch runs.
%
%     STATION_CAPACITY  Optional, default 100. Stationary battery capacity
%                       at the clinic, in kWh.
%
%     CLINICFILE        Optional path to the clinic load file. Must hold a
%                       variable CLINIC_LOAD_SCALED with a full year of
%                       hourly values in kWh, or exactly one numeric
%                       variable. Defaults to clinic_load_scaled.mat in the
%                       current folder.
%
%     SOLARFILE         Optional path to the household solar surplus file.
%                       Must hold HOURLY_EXCESS_60, a matrix of 8760 hours
%                       by number of households, in kWh, or exactly one
%                       numeric variable. Defaults to
%                       hourly_excess_EVcharging_60houses.mat.
%
%     PARAMS            Optional. Cost and assumption constants, as
%                       returned by EVEN_PARAMETERS.
%
%   Output fields (RESULT)
%     Total_Demand_KWh / Total_Demand_kWh  Clinic demand over 30 days, kWh.
%     Total_Delivered_KWh                  Energy delivered to the clinic, kWh.
%     Total_Unmet_kWh                      Demand not met, kWh.
%     Unserved_Hours                       Hours with no supply at all.
%     Hourly_Load                          Clinic demand per hour, 720x1, kWh.
%     Supplied_Load_Hourly                 Energy delivered per hour, kWh.
%     unmet_Load                           Shortfall per hour, kWh.
%     EV_Eff_Losses_kWh                    Charge and discharge losses, kWh.
%     Total_Travel_Energy_kWh              Energy used driving, kWh.
%     Station_Charge_kWh                   Energy into the stationary battery, kWh.
%     Station_Discharge_kWh                Energy out of it, kWh.
%     EV_SOC_Trace                         Per-vehicle state of charge per hour.
%     Station_SOC_Trace                    Present only if TRACE_STATION_SOC.
%     Diesel_Hybrid_*                      Diesel covering only the shortfall
%                                          left by the vehicles: _Fuel_L,
%                                          _CO2_kg, _Cost_SEK.
%     Diesel_FullLoad_*                    Diesel covering the entire clinic
%                                          load, as the do-nothing baseline.
%     Diesel_SameEV_*                      Diesel delivering the same energy
%                                          the vehicles delivered, for a
%                                          like-for-like comparison.
%     Month, EVB_kWh, Num_EVs, Travel_km, Station_kWh
%                                          The scenario that produced this result.
%
%   Supply availability is not returned directly. Compute it as
%   100 * RESULT.Total_Delivered_KWh / RESULT.Total_Demand_kWh.
%
%   Example
%     r = simulate_clinic_backup(60, 12, 10, 6, false, 100, ...
%             'input_files/critical_infrastructure/clinic_load_scaled.mat', ...
%             'input_files/critical_infrastructure/hourly_excess_EVcharging_60houses.mat');
%     fprintf('%.0f of %.0f kWh delivered, %.0f kg CO2\n', ...
%         r.Total_Delivered_KWh, r.Total_Demand_kWh, r.Diesel_Hybrid_CO2_kg);
%
%   See also V2H_ECONOMICSIMULATOR_HOURLYSOC, EVEN_RUN_SCENARIO.

% If the optional argument for SOC tracing is not provided, default to false
if nargin < 5 || isempty(trace_station_SOC)
    trace_station_SOC = false;
end
if nargin < 6 || isempty(station_capacity)
    station_capacity = 100;  % Default value if not provided
end
if nargin < 7 || isempty(clinicFile)
    clinicFile = 'clinic_load_scaled.mat';
end
if nargin < 8 || isempty(solarFile)
    solarFile = 'hourly_excess_EVcharging_60houses.mat';
end
if nargin < 9 || isempty(params)
    params = even_parameters();
end

% Load clinic load and solar availability data
data = load(clinicFile);                                   % Load hourly clinic load
if isfield(data,'clinic_load_scaled')
    clinic_hourly_scaled = data.clinic_load_scaled;
else
    fn = fieldnames(data);
    numericFields = fn(structfun(@isnumeric, data));
    if numel(numericFields) ~= 1
        error('simulate_clinic_backup:BadClinicFile', ...
            ['The clinic load file must contain a variable named clinic_load_scaled, ' ...
             'or exactly one numeric variable. File: %s'], clinicFile);
    end
    clinic_hourly_scaled = data.(numericFields{1});
end

solarData = load(solarFile);                               % Hourly excess solar per household
if isfield(solarData,'hourly_excess_60')
    hourly_excess = solarData.hourly_excess_60;
else
    fn = fieldnames(solarData);
    numericFields = fn(structfun(@isnumeric, solarData));
    if numel(numericFields) ~= 1
        error('simulate_clinic_backup:BadSolarFile', ...
            ['The solar file must contain a variable named hourly_excess_60, ' ...
             'or exactly one numeric variable. File: %s'], solarFile);
    end
    hourly_excess = solarData.(numericFields{1});
end

% The month window below indexes a full calendar year of hourly values.
if numel(clinic_hourly_scaled) < 8736
    error('simulate_clinic_backup:ShortClinicProfile', ...
        'The clinic load profile has %d values; a full year of hourly data is required.', ...
        numel(clinic_hourly_scaled));
end
if size(hourly_excess,1) < 8736
    error('simulate_clinic_backup:ShortSolarProfile', ...
        'The solar profile has %d rows; a full year of hourly data is required.', ...
        size(hourly_excess,1));
end

% Set constants for EVs and station battery system
SoCEVBmin = params.clinic.EV_SOC_min;                      % Minimum allowed SOC for EV (must preserve travel energy)
EV_travel_per_km = params.clinic.travel_energy_kWh_per_km; % Energy needed per km for travel
EV_travel = EV_travel_per_km * travel_km;                  % Total energy needed one-way
travel_time = ceil(travel_km / params.clinic.vehicle_speed_kmph); % Travel time in hours

                                                            % Station battery capacity (kWh)
station_max_power = params.clinic.station_max_power_kW;    % Max charging/discharging rate (kW)
station_SOC = params.clinic.station_SOC_initial;           % Initial SOC
station_SOC_min = params.clinic.station_SOC_min;           % Minimum SOC threshold

EV_efficiency = params.clinic.EV_efficiency;               % Round-trip efficiency for EV charge/discharge
EV_max_power = params.clinic.EV_max_power_kW;              % Max discharge power per EV (kW)

% Select hourly indices corresponding to the given month (30-day window)
days_in_month = [31,28,31,30,31,30,31,31,30,31,30,31];
start_day = [1, cumsum(days_in_month(1:end-1)) + 1];
d1 = start_day(month);                                     % First day of the month
d2 = d1 + 29;                                              % Simulate for 30 days
hourly_idx = (d1 - 1) * 24 + 1 : d2 * 24;                  % Hourly index for 30 days
hourly_load = clinic_hourly_scaled(hourly_idx);           % Extract clinic load
hourly_excess = hourly_excess(hourly_idx, :);             % Extract solar data

% Initialize EV states
EV_SOC = params.clinic.EV_SOC_initial * ones(1, N_EVs);    % EV initial SOC
EV_status = zeros(1, N_EVs);                              % EV states (0=clinic, 1=to home, 2=charging, 3=returning)
EV_timer = zeros(1, N_EVs);                               % Travel or charging timer
EV_home = zeros(1, N_EVs);                                % Assigned house index per EV, initilly all 0

% Initialize tracking variables
hourly_supplied_load = zeros(length(hourly_load), 1);     % Track clinic load met per hour
total_travel_energy = 0;                                  % Total EV travel energy consumption
station_discharge_kWh = 0;                                % Total energy from station battery
ev_losses_kWh = 0;                                        % Total energy lost due to EV inefficiency
station_charge_kWh = 0;                                   % Total solar energy stored in station battery
station_SOC_trace = [];                                   % Optional SOC trace of station battery
EV_SOC_trace = zeros(length(hourly_load), N_EVs);         % SOC of each EV over time

% ---- MAIN SIMULATION LOOP ----
for h = 1:length(hourly_load)
    required_energy = hourly_load(h);                     % Clinic demand this hour
    available_energy = 0;                                 % Reset energy supply counter

    % Calculate total energy available from EVs at clinic
    for ev = 1:N_EVs
        if EV_status(ev) == 0
            usable_energy = (EV_SOC(ev) - SoCEVBmin) * EVB - EV_travel;
            available_energy = available_energy + max(0, min(EV_max_power, usable_energy));
        end
    end

    % Add station battery's available discharge capacity. A capacity of 0
    % means no station battery, so it contributes nothing.
    if station_capacity > 0
        available_energy = available_energy + min(station_max_power, (station_SOC - station_SOC_min) * station_capacity);
    end

    % Only proceed to supply load if it can be fully met
    if available_energy >= required_energy
        energy_supplied = 0;

        % EVs discharge to supply the load
        for ev = 1:N_EVs
            if EV_status(ev) == 0
                usable_energy = (EV_SOC(ev) - SoCEVBmin) * EVB - EV_travel;
                discharge_power = min(EV_max_power, usable_energy);
                if discharge_power > 0 && energy_supplied < required_energy
                    deliver = min(discharge_power, required_energy - energy_supplied);
                    EV_SOC(ev) = EV_SOC(ev) - deliver / (EVB * EV_efficiency);
                    ev_losses_kWh = ev_losses_kWh + deliver * (1 - EV_efficiency);
                    energy_supplied = energy_supplied + deliver;

                    % If now insufficient for return trip, EV leaves for home
                    usable_energy_after = (EV_SOC(ev) - SoCEVBmin) * EVB - EV_travel;
                    % if usable_energy_after <= 0
                    %     EV_status(ev) = 1;
                    %     EV_timer(ev) = travel_time;
                    % end
if usable_energy_after <= 0
    EV_SOC(ev) = EV_SOC(ev) - EV_travel / EVB;
    EV_SOC(ev) = max(EV_SOC(ev), 0);

    EV_status(ev) = 1;
    EV_timer(ev) = travel_time;
end
                end
            end
        end

        % Use station battery if EVs alone are insufficient
        if energy_supplied < required_energy && station_capacity > 0
            usable_bs = min(station_max_power, (station_SOC - station_SOC_min) * station_capacity);
            bs_deliver = min(usable_bs, required_energy - energy_supplied);
            station_SOC = station_SOC - bs_deliver / station_capacity;
            station_discharge_kWh = station_discharge_kWh + bs_deliver;
            energy_supplied = energy_supplied + bs_deliver;
        end

        % Record the total energy delivered this hour
        hourly_supplied_load(h) = energy_supplied;
    end

    % ---- Update EV travel/charging/return ----
    for ev = 1:N_EVs
        if EV_timer(ev) > 0
            EV_timer(ev) = EV_timer(ev) - 1;
        else
            switch EV_status(ev)
                case 1  % Reached home, check solar to charge
                    assigned_house = mod(ev - 1, size(hourly_excess, 2)) + 1;
                    if hourly_excess(h, assigned_house) > 0
                        EV_home(ev) = assigned_house;
                        EV_status(ev) = 2;
                    end
                case 2  % Charging from assigned house
                    house_idx = EV_home(ev);
                    solar_avail = hourly_excess(h, house_idx);
                    if solar_avail > 0
                        charge_possible = min(EVB * (1 - EV_SOC(ev)), solar_avail * EV_efficiency);
                        energy_from_solar = charge_possible / EV_efficiency;
                        EV_SOC(ev) = EV_SOC(ev) + charge_possible / EVB;
                        ev_losses_kWh = ev_losses_kWh + energy_from_solar * (1 - EV_efficiency);
                        station_charge_kWh = station_charge_kWh + energy_from_solar;
                        % if EV_SOC(ev) >= 1.0
                        %     EV_status(ev) = 3;
                        %     EV_timer(ev) = travel_time;
                        % end
if EV_SOC(ev) >= 1.0
    EV_SOC(ev) = EV_SOC(ev) - EV_travel / EVB;
    EV_SOC(ev) = max(EV_SOC(ev), 0);

    EV_status(ev) = 3;
    EV_timer(ev) = travel_time;
end

                    end
                case 3  % Return to clinic complete
                    EV_status(ev) = 0;
                    total_travel_energy = total_travel_energy + 2 * EV_travel;
            end
        end
    end

    % Check for idle EVs that need charging and send them home
    for ev = 1:N_EVs
        if EV_status(ev) == 0
            usable_energy = (EV_SOC(ev) - SoCEVBmin) * EVB - EV_travel;
            if usable_energy <= 0
                EV_status(ev) = 1;
                EV_timer(ev) = travel_time;
            end
        end
    end

    % Idle EVs at clinic charge station battery if possible
    for ev = find(EV_status == 0)
        usable_energy = (EV_SOC(ev) - SoCEVBmin) * EVB - EV_travel;
        if usable_energy > 0 && station_SOC < 1.0 && station_capacity > 0
            charge_energy = min([station_max_power, usable_energy, (1.0 - station_SOC) * station_capacity]);
            EV_SOC(ev) = EV_SOC(ev) - charge_energy / (EVB * EV_efficiency);
            station_SOC = station_SOC + charge_energy / station_capacity;
            ev_losses_kWh = ev_losses_kWh + charge_energy * (1 - EV_efficiency);
            station_charge_kWh = station_charge_kWh + charge_energy;
        end
    end

    % Log hourly values if enabled
    if trace_station_SOC
        station_SOC_trace(h) = station_SOC;
    end
    EV_SOC_trace(h, :) = EV_SOC;
end

% ---- Compile and return results ----
result = struct();
result.Month = month;
result.EVB_kWh = EVB;
result.Num_EVs = N_EVs;
result.Travel_km = travel_km;
result.Station_kWh = station_capacity;
result.Total_Unmet_kWh = sum(hourly_load) - sum(hourly_supplied_load);
result.Total_Delivered_KWh = sum(hourly_supplied_load);
result.Unserved_Hours = sum(hourly_supplied_load == 0);
result.Total_Travel_Energy_kWh = total_travel_energy;
result.Station_Discharge_kWh = station_discharge_kWh;
result.Station_Charge_kWh = station_charge_kWh;
result.Supplied_Load_Hourly = hourly_supplied_load;
result.Supply_Availability_kWh = sum(hourly_supplied_load);
result.EV_SOC_Trace = EV_SOC_trace;
result.EV_Eff_Losses_kWh = ev_losses_kWh;
result.Total_Demand_kWh = sum(hourly_load);
result.Hourly_Load = hourly_load;
result.unmet_Load = hourly_load'-hourly_supplied_load;
result.hourly_excess_all=hourly_excess;

%% for diesel
% ---- Diesel generator comparison ----

generator_rating_kW = params.clinic.generator_rating_kW;   % Reference generator rating
CO2_factor = params.clinic.CO2_kg_per_L;                   % kg CO2 per litre diesel
diesel_price = params.clinic.diesel_price_SEK_per_L;       % SEK per litre diesel

% Generator fuel curve
load_points = params.clinic.fuel_curve_load_fraction;
fuel_points = params.clinic.fuel_curve_L_per_hour;         % L/hour

% Case 1: diesel supplies same hourly energy as EV system
diesel_same_EV_load = hourly_supplied_load;

% Case 2: diesel supplies full clinic load
diesel_full_load = hourly_load(:);

% Case 3: hybrid, EV first and diesel supplies remaining unmet load
diesel_hybrid_load = max(hourly_load(:) - hourly_supplied_load, 0);

% Calculate diesel cases
[result.Diesel_SameEV_Fuel_L, result.Diesel_SameEV_CO2_kg, result.Diesel_SameEV_Cost_SEK] = ...
    diesel_simple(diesel_same_EV_load, generator_rating_kW, load_points, fuel_points, CO2_factor, diesel_price);

[result.Diesel_FullLoad_Fuel_L, result.Diesel_FullLoad_CO2_kg, result.Diesel_FullLoad_Cost_SEK] = ...
    diesel_simple(diesel_full_load, generator_rating_kW, load_points, fuel_points, CO2_factor, diesel_price);

[result.Diesel_Hybrid_Fuel_L, result.Diesel_Hybrid_CO2_kg, result.Diesel_Hybrid_Cost_SEK] = ...
    diesel_simple(diesel_hybrid_load, generator_rating_kW, load_points, fuel_points, CO2_factor, diesel_price);
%%

if trace_station_SOC
    result.Station_SOC_Trace = station_SOC_trace;
end

end
function [fuel_L, CO2_kg, cost_SEK] = diesel_simple(hourly_load, generator_rating_kW, load_points, fuel_points, CO2_factor, diesel_price)

hourly_load = hourly_load(:);

load_fraction = hourly_load / generator_rating_kW;
load_fraction(load_fraction > 1) = 1;

fuel_hourly = interp1(load_points, fuel_points, load_fraction, 'linear');

fuel_hourly(hourly_load == 0) = 0;

fuel_L = sum(fuel_hourly);
CO2_kg = fuel_L * CO2_factor;
cost_SEK = fuel_L * diesel_price;

end