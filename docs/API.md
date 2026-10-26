# API reference

Three simulation engines, callable directly without the graphical interface. Each is also documented in MATLAB: `help V2H_EconomicSimulator_HourlySOC`, `help simulate_clinic_backup`, `help even_run_scenario`.

All energy is in kWh, all costs in SEK, all emissions in kg.

---

## `V2H_EconomicSimulator_HourlySOC`

One household supplied by one electric vehicle during a grid outage, simulated hour by hour.

```matlab
results = V2H_EconomicSimulator_HourlySOC(ownership, battery_kWh, load_profile, outage_days, distance_km)
results = V2H_EconomicSimulator_HourlySOC(..., params)
```

### How it works

The vehicle discharges to the household until its state of charge reaches the minimum. It then drives to a charging point, recharges, and returns; the household is unsupplied for the whole round trip. Only one recharge trip is made per day.

### Inputs

| Position | Name | Type | Meaning |
|---|---|---|---|
| 1 | `ownership` | char | Who provides the vehicle. See table below. Must match exactly. |
| 2 | `battery_kWh` | scalar | Usable vehicle battery capacity, kWh. The interface offers 60, 77, 100. |
| 3 | `load_profile` | vector | Household demand for **one day**: 24 hourly values in kWh. Repeated for each outage day. |
| 4 | `outage_days` | integer | Outage duration in whole days. Sets both the simulated horizon and the compensation. |
| 5 | `distance_km` | scalar | **One-way** distance to the charging point, km. Sets the energy reserved for travel and the hours away. |
| 6 | `params` | struct | Optional. Constants from `even_parameters()`. Omit for defaults. |

### Ownership models

| Value | Battery wear charged? | Hire fee? | Driver cost? |
|---|---|---|---|
| `'Personal'` | Yes, per kWh delivered | No | No |
| `'Hired'` | No | Yes, per day | No |
| `'3rd Party with Driver'` | No | Yes, per day | Yes: call-out fee plus hourly rate per recharge trip |

### Outputs

| Field | Meaning |
|---|---|
| `supply_availability` | Fraction of demand met, 0 to 1. Multiply by 100 for a percentage. |
| `total_energy_demand` | Total household demand over the outage, kWh. |
| `total_energy_supplied` | Energy delivered by the vehicle, kWh. |
| `energy_loss_kWh` | Charging and travel losses, kWh. |
| `charge_cycles_used` | Number of recharge trips made. |
| `ev_unavailable_time` | Hours the household was unsupplied. |
| `soc_profile` | Vehicle state of charge per hour, percent. |
| `unserved_load_profile` | Unmet demand per hour, kWh. |
| `total_cost` | All costs combined, SEK. |
| `total_cost_per_kWh` | Total cost per kWh delivered, SEK. |
| `driver_cost` | Driver call-out and hourly cost, SEK. Zero unless third party with driver. |
| `hire_cost` | Vehicle hire cost, SEK. Zero for a personal vehicle. |
| `compensation_received` | Statutory outage compensation, SEK. 1200 per day. |
| `additional_cost_after_compensation` | Total cost minus compensation, SEK. Negative means the household is better off. |

---

## `simulate_clinic_backup`

A clinic supplied over 30 days by a vehicle fleet, a stationary battery and household solar, compared against diesel generation.

```matlab
result = simulate_clinic_backup(EVB, N_EVs, travel_km, month)
result = simulate_clinic_backup(EVB, N_EVs, travel_km, month, trace_station_SOC, station_capacity, clinicFile, solarFile, params)
```

### How it works

Vehicles discharge at the clinic until they can no longer cover the return trip, then drive to an assigned household, recharge from that household's surplus solar, and return. Idle vehicles with spare energy charge the stationary battery. The clinic load in a given hour is supplied only if it can be met in full — partial hours count as unserved.

### Inputs

| Position | Name | Type | Meaning |
|---|---|---|---|
| 1 | `EVB` | scalar | Usable vehicle battery capacity, kWh. |
| 2 | `N_EVs` | integer | Fleet size. Vehicles are assigned to households in rotation, so a fleet larger than the number of solar profiles shares charging points. |
| 3 | `travel_km` | scalar | **One-way** distance between clinic and household, km. |
| 4 | `month` | 1–12 | Month to simulate. A fixed 30-day window from the first of that month. |
| 5 | `trace_station_SOC` | logical | Optional, default `false`. Returns the hourly stationary battery state of charge. Leave `false` for batch runs. |
| 6 | `station_capacity` | scalar | Optional, default 100. Stationary battery capacity at the clinic, kWh. |
| 7 | `clinicFile` | char | Optional path to the clinic load file. Variable `clinic_load_scaled`, a full year of hourly kWh. |
| 8 | `solarFile` | char | Optional path to the solar surplus file. Variable `hourly_excess_60`, 8760 hours by households, kWh. |
| 9 | `params` | struct | Optional. Constants from `even_parameters()`. |

### Outputs

| Field | Meaning |
|---|---|
| `Total_Demand_kWh` | Clinic demand over the 30 days, kWh. |
| `Total_Delivered_KWh` | Energy delivered to the clinic, kWh. |
| `Total_Unmet_kWh` | Demand not met, kWh. |
| `Unserved_Hours` | Hours with no supply at all. |
| `Hourly_Load` | Clinic demand per hour, 720×1, kWh. |
| `Supplied_Load_Hourly` | Energy delivered per hour, kWh. |
| `unmet_Load` | Shortfall per hour, kWh. |
| `EV_Eff_Losses_kWh` | Charge and discharge losses, kWh. |
| `Total_Travel_Energy_kWh` | Energy used driving, kWh. |
| `Station_Charge_kWh` / `Station_Discharge_kWh` | Energy into and out of the stationary battery, kWh. |
| `EV_SOC_Trace` | Per-vehicle state of charge per hour. |
| `Station_SOC_Trace` | Present only if `trace_station_SOC` was true. |
| `Month`, `EVB_kWh`, `Num_EVs`, `Travel_km`, `Station_kWh` | The scenario that produced this result. |

**Supply availability is not returned directly.** Compute it as `100 * result.Total_Delivered_KWh / result.Total_Demand_kWh`.

### The three diesel comparisons

| Prefix | What the generator covers | Use it for |
|---|---|---|
| `Diesel_FullLoad_` | The entire clinic load | The do-nothing baseline: diesel only, no vehicles. |
| `Diesel_Hybrid_` | Only the shortfall the vehicles left | The realistic hybrid case. This is what the interface reports. |
| `Diesel_SameEV_` | The same energy the vehicles delivered | Like-for-like: what that energy would have cost and emitted from diesel. |

Each prefix has three fields: `_Fuel_L`, `_CO2_kg`, `_Cost_SEK`.

---

## `even_run_scenario`

A full year of community energy sharing between a microgrid, prosumer households and electric vehicles.

```matlab
R = even_run_scenario(params)
```

`params` is a struct with **named** fields, not positional arguments. Every field is optional; anything omitted keeps the default in `even_annual_simulation.m`. `even_run_scenario(struct())` reproduces the original published default scenario.

### Input fields

| Field | Meaning |
|---|---|
| `MGFile` | Path to the microgrid supply and demand file. |
| `HHLoadFile` | Path to the household load file. |
| `HHPVFile` | Path to the household PV supply file. |
| `MGSupplyCase` | Microgrid supply scenario: 1, 2 or 3. |
| `DemandScale` | Household demand multiplier. `0.8` is a 20 % demand reduction. |
| `EV_PenetrationLevel` | Fraction of households with a vehicle, 0 to 1. |
| `PV_penetration` | Fraction of vehicle households that also have PV, 0 to 1. |
| `Battery_penetration` | Fraction of PV households that also have a battery, 0 to 1. |
| `scenario_inverter` | 1 standard inverter, 2 emergency inverter. |
| `scenario_auction` | Balancing strategy passed to the auction function. |
| `MG_B` | Community battery capacity, kWh. |
| `EVB` | Vehicle battery capacity, kWh. |
| `Parameters` | Constants struct from `even_parameters()`, to override efficiencies, limits or travel energy for this run. |

Note the nesting: `Battery_penetration` is a fraction of PV households, which are themselves a fraction of vehicle households. The number of households simulated is `round(households in the file × EV_PenetrationLevel)`.

### Outputs

| Field | Meaning |
|---|---|
| `num_houses` | Households simulated. |
| `Num_PV_B`, `Num_PVOnly`, `Num_NoPV` | Households with PV and a battery, PV only, and neither. |
| `MG_daily_demand`, `MG_daily_supply` | Microgrid demand and supply, 365×1, kWh. |
| `HH_daily_demand`, `HH_daily_supply` | Household demand and supply, 365 × households, kWh. |
| `Output_daily_EBalance_before` | Daily energy balance per participant **without** vehicle sharing, 365 × participants, kWh. Column 1 is the microgrid, the rest are households. Negative is a deficit. |
| `Output_daily_EBalance_after` | The same balance **with** sharing. The difference between the two is the resilience benefit. |
| `Output_daily_transition` | Energy moved per day, kWh, in three columns: microgrid→consumers, prosumers→microgrid, prosumers→consumers. |
| `Output_daily_index_Eloss` | Energy lost in transactions, kWh. |
| `Output_daily_Action` | Buy or sell action per participant per day; negative is selling. |
| `Degradation` | Annual battery degradation per vehicle, as a fraction. |
| `MG_SoCB` | Microgrid battery state of charge. |
| `OUTPUT_paramatric_PartA` | Five summary indicators as fractions: deficit-day ratio before, deficit-day ratio after, self-consumption, self-sufficiency, mean degradation. |
| `OUTPUT_paramatric_PartB` | Degradation distribution: minimum, quartiles, maximum. |
| `SC`, `SS` | Self-consumption and self-sufficiency before sharing, as fractions. |
| `ScenarioParameters` | The parameter values this run actually used. |

### Common derived indicators

```matlab
deficitBefore = 100*nnz(R.Output_daily_EBalance_before<0)/numel(R.Output_daily_EBalance_before);
deficitAfter  = 100*nnz(R.Output_daily_EBalance_after <0)/numel(R.Output_daily_EBalance_after);
meanDegradation = 100*mean(R.Degradation);
```

A full-size run covers 5357 households over 365 days and is slow. Use the 400-household demo dataset in `input_files/community/` while developing.

---

## `even_run_parametric`

Generates one of the community parametric studies by running `even_run_scenario` once per combination.

```matlab
[PartA, PartB, info] = even_run_parametric(group, files)
[PartA, PartB, info] = even_run_parametric(group, files, 'OutputFile', file, 'ProgressFcn', fcn)
```

| Argument | Meaning |
|---|---|
| `group` | `'A'`, `'B'` or `'C'` (sweeps listed in the README). |
| `files` | Struct with `MGFile`, `HHLoadFile`, `HHPVFile`. Demo or full dataset. |
| `'OutputFile'` | Optional. Saves `OUTPUT_paramatric_PartA`, `OUTPUT_paramatric_PartB` and `ParametricInfo` — the format the Parametric tab loads. |
| `'ProgressFcn'` | Optional. Called before each run as `keepGoing = fcn(k, n, description)`; return `false` to stop early. |

| Output | Meaning |
|---|---|
| `PartA` | 5 × levels × curves: deficit-day ratio before, deficit-day ratio after, self-consumption, self-sufficiency, mean degradation (fractions). Unrun points are `NaN`. |
| `PartB` | 5 × levels × curves: degradation minimum, quartiles and maximum. |
| `info` | Sweep values, curve labels, input files, households per run, completed runs, run time. |

---

## `even_parameters`

Returns the struct of regional constants used by all three engines, in three groups: `P.v2h`, `P.clinic`, `P.community`. Edit that file to change a value everywhere, or pass a modified struct as the final argument of an engine to override it for one run.

```matlab
P = even_parameters();
P.v2h.charging_cost_SEK_per_kWh = 3.20;
r = V2H_EconomicSimulator_HourlySOC('Personal', 77, loadVec, 2, 10, P);
```
