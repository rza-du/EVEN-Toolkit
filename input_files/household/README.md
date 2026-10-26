# Inputs for the Single Family House module

Open the module from the selector card **Single Family House** and press **Upload Load Profile MAT**. The uploaded profile is used by all three tabs.

| File | Contents |
|---|---|
| `Loadprofile_35.mat` | `load_profile`, 24 × 1, hourly household demand in kWh for one day, 35.1 kWh/day. **Use this one for the examples in the paper.** |
| `Loadprofile15.mat` | `load_profile`, 24 × 1, a low-consumption day. |
| `Loadprofile_70.mat` | `load_profile`, 24 × 1, a high-consumption day. |

Upload the low or high profile instead of the medium one to see how household consumption changes the results.

The profile is repeated for every day of the outage, so supply one day (24 values), not a year.
