# Input data

## What is in this repository

The `input_files/` folder holds a complete set of inputs, one subfolder per
simulator, so every module can be run immediately after cloning:
`household/`, `critical_infrastructure/` and `community/` (with the published
parametric results in `community/parametric_results/`). Each subfolder has a
README naming the upload button for every file.

| File | Used by | Contents |
|---|---|---|
| `Loadprofile15.mat`, `Loadprofile_35.mat`, `Loadprofile_70.mat` | Household | `load_profile`, 24x1, hourly household demand in kWh for one day. The three files are low, medium and high consumption and are used together in the sensitivity tab. |
| `clinic_load_scaled.mat` | Clinic | `clinic_load_scaled`, 1x8760, hourly clinic demand in kWh for a full year. |
| `hourly_excess_EVcharging_60houses.mat` | Clinic | `hourly_excess_60`, 8760x60, hourly surplus PV generation available for EV charging at 60 households, in kWh. |
| `MG_supply_demand.mat` | Community | `MG_Load` 8760x8, and `MG_Supply1` 8760x3, `MG_Supply2` 8760x4, `MG_Supply3` 8760x4. Hourly microgrid demand and three supply scenarios, in kWh. |
| `HH_Load_demo400.mat` | Community | `household_demand`, 8760x400, hourly demand per household in kWh. **Reduced demo subset**, see below. |
| `HH_PV_supply2_demo400.mat` | Community | `PV_supply`, 8760x400, hourly PV generation per household in kWh. **Reduced demo subset**, see below. |
| `Parametric_GroupA/B/C.mat` | Community | `OUTPUT_paramatric_PartA`, pre-computed parametric sweep results loaded by the Parametric tab. |

## The reduced community dataset

The full community dataset covers 5357 households in the case municipality.
At that size each of the two household files is larger than GitHub's 100 MB
per-file limit, so this repository ships a 400-household subset instead.

The subset runs correctly and reproduces the structure of the results, but
the absolute annual energy figures are smaller than those in the published
study, because the community is smaller. The number of simulated households
is `round(400 * EV_penetration)` rather than `round(5357 * EV_penetration)`.


## Using your own data

Save a variable with the shape given in the table above and select the file
through the module's upload dialog. The household module accepts any
variable name matching `load_profile`, `household_demand`, `load` or
`demand`; the clinic and community modules expect the variable names listed
above, though the clinic module will also accept a file containing exactly
one numeric variable.
