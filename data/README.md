# Data

Source files are public but too large to commit, so download them into this
folder before running the scripts in `r/`. Everything below is free and needs
no account.

The one committed file, `pos_crosswalk.csv`, is kept because CMS replaces the
Provider of Services file every quarter, so the exact crosswalk used in the
build cannot be regenerated once the Q2 2026 release is superseded.

---

## 1. AHRF 2024-2025: county workforce, population, births (2022 and 2023)

Download: <https://data.hrsa.gov/data/download?data=AHRF>
Choose the 2024-2025 county-level CSV release.

Unzip it into this folder so the paths become:

```
data/ahrf_2024_25/NCHWA-2024-2025+AHRF+COUNTY+CSV/AHRF2025hp.csv
data/ahrf_2024_25/NCHWA-2024-2025+AHRF+COUNTY+CSV/AHRF2025pop.csv
data/ahrf_2024_25/NCHWA-2024-2025+AHRF+COUNTY+CSV/AHRF2025geo.csv
```

## 2. AHRF 2019-2020: historical years (2010, 2015, 2018)

No manual download needed. `build_ahrf_panel.R` fetches and unzips it on first
run into `data/ahrf_2019_20/`.

## 3. CMS Provider of Services file: CCN to county FIPS crosswalk

Download: <https://data.cms.gov/provider-characteristics/hospitals-and-other-facilities/provider-of-services-file-hospital-non-hospital-facilities>

Place the CSV in this folder. The release used in this project was saved as
`Hospital_and_other.DATA.Q2_2026.csv`; if you download a different quarter,
update `pos_file` near the top of `r/build_pos_crosswalk.R`.

## 4. County obstetric status, 2010-2024: the outcome label

University of Minnesota Rural Health Research Center:
<https://rhrc.umn.edu/publication/2010-2024-county-level-hospital-based-obstetric-care-status/>

## 5. HRSA Health Professional Shortage Areas: HPSA and MCTA scores

<https://data.hrsa.gov/data/download>, Shortage Areas, primary care detail file
(`BCD_HPSA_FCT_DET_PC`).

## 6. HCRIS hospital financials

Processed panel by Adam Sacarny: <https://github.com/asacarny/hospital-cost-reports>

---

## Run order

Open each script in RStudio and click **Source**, or run it with `Rscript`.
The scripts locate this folder from their own file path, so no working
directory needs to be set.

1. `r/build_ahrf_panel.R` writes `ahrf_panel_full.csv` and three trimmed 2023
   cross-sections
2. `r/build_pos_crosswalk.R` writes `pos_crosswalk.csv`

Both scripts end with verification checks and stop if a check fails.

Their outputs, plus sources 4, 5 and 6, are then uploaded to Foundry as
datasets. Everything downstream of that point, including cleaning, joins, the
ontology, the model, and the Workshop application, runs inside Foundry.
