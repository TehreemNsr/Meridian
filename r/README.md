# R data preparation

Two scripts, run once each, before anything is uploaded to Foundry.

| Script | Input | Output |
|---|---|---|
| `build_ahrf_panel.R` | AHRF 2024-2025 CSVs, AHRF 2019-2020 SAS file (downloaded automatically) | `data/ahrf_panel_full.csv` (16,160 county-year rows) and three trimmed 2023 cross-sections |
| `build_pos_crosswalk.R` | CMS Provider of Services CSV | `data/pos_crosswalk.csv` (13,566 hospitals) |

## Setup

Place the source files in the repository's `data/` folder as described in
`data/README.md`:

```
data/
  ahrf_2024_25/NCHWA-2024-2025+AHRF+COUNTY+CSV/AHRF2025hp.csv
                                               AHRF2025pop.csv
                                               AHRF2025geo.csv
  Hospital_and_other.DATA.Q2_2026.csv
```

Packages: `haven`, `tidyr`, `dplyr`. Install once with:

```r
install.packages(c("haven", "tidyr", "dplyr", "rstudioapi"))
```

## Running

Open a script in RStudio and click **Source**, or run it with `Rscript`. Each
script locates the repository from its own file path, so no working directory
needs to be set.

Both scripts end with `stopifnot()` checks (FIPS length, key uniqueness, row
and column counts) and halt rather than writing a bad file.
