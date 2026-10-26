# Inputs for the Critical Infrastructure (clinic) module

Open the module from the selector card **Critical Infrastructure**. Both files are needed before any tab will run.

| File | Upload with | Contents |
|---|---|---|
| `clinic_load_scaled.mat` | **Upload Clinic** | `clinic_load_scaled`, 1 × 8760, hourly clinic demand in kWh for a full year. |
| `hourly_excess_EVcharging_60houses.mat` | **Upload Solar** | `hourly_excess_60`, 8760 × 60, hourly surplus PV at 60 households available for charging the fleet, kWh. |
