# Inputs for the Municipality / Community module

Open the module from the selector card **Municipality / Community**. All three files are needed.

| File | Upload with | Contents |
|---|---|---|
| `MG_supply_demand.mat` | **Upload MG** | `MG_Load` 8760 × 8 and `MG_Supply1`, `MG_Supply2`, `MG_Supply3`: hourly microgrid demand and three supply scenarios, kWh. |
| `HH_Load_demo400.mat` | **HH Load** | `household_demand`, 8760 × 400, hourly demand per household, kWh. |
| `HH_PV_supply2_demo400.mat` | **HH PV** | `PV_supply`, 8760 × 400, hourly PV generation per household, kWh. |

These are a **400-household demo subset**: an annual run takes seconds, and a parametric group a few minutes. The full 5357-household files (`HH_Load.mat`, `HH_PV_supply2.mat`) exceed GitHub's 100 MB file limit and are archived separately; select them with the same buttons to reproduce the published results.

## parametric_results/

`Parametric_GroupA.mat`, `Parametric_GroupB.mat`, `Parametric_GroupC.mat` are the published parametric studies, computed on the full dataset. **Load Parametric Results** on the Parametric tab opens them. Results you create with **Generate from Uploaded Files** are saved to `results/` at the top of the repository and are loaded in preference to these.
