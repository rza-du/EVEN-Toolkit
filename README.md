# EVEN Toolkit

## Electric Vehicle based virtual Electricity Network — a simulation suite for EV-based power supply resilience

A MATLAB application suite for techno-economic assessment of electric-vehicle-based backup power at three scales: a single household, a critical facility, and a community microgrid.


## What it does

EVEN runs outage-resilience simulations through a graphical interface, with no programming required. Three modules share the same structure — single scenario, full-factorial batch analysis, and structured sensitivity analysis — and report technical, economic and environmental indicators with one-click export to Excel.

| Module | Scale | Question it answers |
|---|---|---|
| Single Family House | 1–2 day outage, one EV | Can one EV cover a household load, and at what cost per kWh? |
| Critical Infrastructure | One month, EV fleet + solar + stationary battery | Can an EV fleet replace a diesel generator at a clinic, and what does it save in fuel and CO₂? |
| Municipality / Community | Full year, multi-agent energy sharing | How much does community-level EV energy sharing reduce deficit days, and what does it cost in battery degradation? |

## Requirements

- MATLAB `R2021a` or later
- Base MATLAB only — no additional toolboxes
- Windows

## Quick start

```matlab
cd src
Main_Scenario_Selector_App_Visual
```

Pick a module from the three cards, upload its files from the matching folder in `input_files/`, and press **Run**:

| Card | Folder | Files to upload |
|---|---|---|
| Single Family House | `input_files/household/` | `Loadprofile_35.mat` |
| Critical Infrastructure | `input_files/critical_infrastructure/` | `clinic_load_scaled.mat` and `hourly_excess_EVcharging_60houses.mat` |
| Municipality / Community | `input_files/community/` | `MG_supply_demand.mat`, `HH_Load_demo400.mat` and `HH_PV_supply2_demo400.mat` |

Each folder has a short README saying which file goes with which upload button.

Fastest first run — the household module:

1. Press **Upload Load Profile MAT** and select `input_files/household/Loadprofile_35.mat`.
2. Keep the default dropdown values.
3. Press **Run Simulation**.



## Custom parameter values

Numeric scenario fields are editable: pick a preset from the list, or type any value. Each entry is range-checked before it reaches the simulation.

| Module | Editable field | Accepted range |
|---|---|---|
| Household | Battery capacity | 10–200 kWh |
| Household | Outage duration | 1–14 days, whole numbers |
| Household | Travel distance | 0–50 km |
| Clinic | EV battery capacity | 10–200 kWh |
| Clinic | Number of EVs | 1–200, whole numbers |
| Clinic | Travel distance | 0– 50km |
| Clinic | Station battery capacity | 0–5000 kWh |
| Community | Demand reduction | 0–90 % |
| Community | EV penetration | 0.1–100 % |
| Community | EV battery capacity | 10–250 kWh |
| Community | PV penetration | 0–100 % |
| Community | PV battery deployment | 0–100 % |
| Community | MG battery capacity | 0–50000 kWh |

Ownership type, month, microgrid supply scenario, inverter type and balancing strategy remain fixed lists, because the simulations branch on these rather than treating them as quantities.

Batch and sensitivity runs use fixed scenario grids, matching the experimental designs of the published studies. The household batch sweeps 72 scenarios (3 ownership models x 3 battery sizes x 2 outage durations x 4 travel distances); the clinic batch sweeps 432 (2 battery sizes x 3 fleet sizes x 2 distances x 3 station sizes x 12 months). The sensitivity tabs use one-factor-at-a-time designs around a fixed reference scenario, so the effect of each factor is isolated.

Typed values apply to single-scenario runs.

## Parametric studies (community module)

The **Parametric** tab plots three pre-defined studies of the community simulation:

| Group | Sweep | Runs |
|---|---|---|
| A | Demand reduction 0–50 % × microgrid supply scenarios 1–3 | 18 |
| B | EV penetration 5–50 % × EV battery 56 / 75 / 100 kWh | 30 |
| C | PV penetration 25–65 % × household battery 11 / 30 % × standard / emergency inverter | 36 |

**Load Parametric Results** opens the stored results. **Generate from Uploaded Files** recomputes the chosen group from the three files uploaded on the Single Scenario tab and saves them to `results/Parametric_GroupX.mat`, which Load then uses in preference to the bundled files in `input_files/community/parametric_results/`. It works with the 400-household demo data (a few minutes per group) and the full 5357-household dataset (roughly 30–60 minutes per group). A cancelled run saves what it finished as `Parametric_GroupX_partial.mat`.

The same studies can be generated from a script:

```matlab
f.MGFile     = '../input_files/community/MG_supply_demand.mat';
f.HHLoadFile = '../input_files/community/HH_Load_demo400.mat';
f.HHPVFile   = '../input_files/community/HH_PV_supply2_demo400.mat';
even_run_parametric('B', f, 'OutputFile', '../results/Parametric_GroupB.mat');
```

The bundled `input_files/community/parametric_results/Parametric_Group*.mat` files were computed on the full dataset, and `even_run_parametric` reproduces them to floating-point precision. The studies use the settings of the original parametric scripts, which differ from the single-scenario defaults: battery efficiency 0.95 instead of 0.9, EV penetration fixed at 35 % in Groups A and C, and a Group C vehicle power limit of 0.2 × battery capacity.

## Repository structure

```
EVEN-Toolkit/
├── src/                            MATLAB code — keep all files together
├── input_files/                    Input data, one folder per simulator
│   ├── household/                  Load profiles
│   ├── critical_infrastructure/    Clinic load and household solar surplus
│   └── community/                  Microgrid and household data (demo subset)
│       └── parametric_results/     Published parametric studies
├── docs/                           API.md and DATA.md
├── results/                        Created when you generate parametric studies
├── README.md
├── CITATION.cff
└── LICENSE
```

### Main files in `src/`

| File | Purpose |
|---|---|
| `Main_Scenario_Selector_App_Visual.m` | Launcher with the three cards — start here |
| `V2H_GUI_App.m` | Single Family House module |
| `Clinic_Backup_GUI_App.m` | Critical Infrastructure module |
| `Community_Microgrid_GUI_App.m` | Municipality / Community module |
| `V2H_EconomicSimulator_HourlySOC.m` | Household simulation engine |
| `simulate_clinic_backup.m` | Clinic simulation engine |
| `even_run_scenario.m` | Community simulation, one scenario |
| `even_run_parametric.m` | Community parametric studies (Groups A, B, C) |
| `even_annual_simulation.m` | Community annual model, called by the two above |
| `even_parameters.m` | All regional constants (prices, efficiencies, limits) |
| `even_radar_plot.m` | Radar charts for the sensitivity tabs |
| `f_*.m`, `func_*.m` | Helpers: battery dispatch, energy trading, degradation |

## Documentation

- [docs/API.md](docs/API.md) — calling the engines directly from a script, without the interface: every argument and output field explained
- [docs/DATA.md](docs/DATA.md) — input file variable names and dimensions

## Input data

Variable names and dimensions for every input file are documented in [docs/DATA.md](docs/DATA.md). Note that the community dataset shipped here is a reduced 400-household subset; the full 5357-household data exceeds GitHub's file size limit and is archived separately.

## Regional parameters

Every constant that encodes a regional or contextual assumption lives in a single file, **`src/even_parameters.m`**, grouped by module. All values are for the Swedish case study.

| Group | Contains |
|---|---|
| `P.v2h` | Charging cost 5.69 SEK/kWh, battery degradation 0.30 SEK/kWh, driver cost 400 SEK/h plus a 500 SEK call-out, hire cost 1000 SEK/day, outage compensation 1200 SEK/day, charge/discharge efficiency, vehicle consumption and speed, SOC limits |
| `P.clinic` | Solar LCOE 1.02 SEK/kWh, battery degradation 0.30 SEK/kWh, diesel 22 SEK/L, CO₂ factor 2.68 kg/L, 25 kW generator fuel curve, EV and stationary battery power and SOC limits |
| `P.community` | Battery efficiencies and SOC limits for the microgrid, households and vehicles, household battery size and power limits, EV travel energy |

To adapt the suite to another country or price year, edit that one file. No simulation logic changes.

A single run can also override values without editing the file, by passing a modified struct as the final argument:

```matlab
P = even_parameters();
P.v2h.charging_cost_SEK_per_kWh = 3.20;
r = V2H_EconomicSimulator_HourlySOC('Personal', 77, loadVec, 2, 10, P);
```

## Citing this software


## Related publications


## Licence

MIT — see [LICENSE](LICENSE). The toolkit contains no third-party code.

## Contact


