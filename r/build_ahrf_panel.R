# =============================================================================
# Meridian: AHRF county panel construction
#
# Purpose: build a five-year county-level panel (2010, 2015, 2018, 2022, 2023)
#          of OB-GYN workforce supply, population, births, and rurality, for use
#          as model features predicting loss of hospital-based obstetric care.
#
# Inputs:  AHRF 2024-2025 county CSVs (current years: 2022, 2023)
#          AHRF 2019-2020 county SAS file (historical years: 2010, 2015, 2018)
#
# Outputs: ahrf_hp_trimmed.csv, ahrf_pop_trimmed.csv, ahrf_geo_trimmed.csv
#            2023 cross-sections uploaded to Foundry for the County object
#          ahrf_panel_full.csv
#            16,160 county-year rows, 13 columns, the model feature panel
#
# Note on variable codes: the 2019-2020 AHRF release uses opaque field codes
#       (f1168510 etc.). These were resolved to human-readable meanings via the
#       SAS label attributes; the mapping is recorded in old_map and births_map.
# =============================================================================

library(haven)
library(tidyr)
library(dplyr)

# ---- locate the repository --------------------------------------------------
# Paths are resolved from this script's own location (r/ inside the
# repository), so it runs from any working directory on any machine.

script_path <- NULL

cmd_file <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(cmd_file) == 1) {
  script_path <- normalizePath(sub("^--file=", "", cmd_file))
}
if (is.null(script_path)) {
  script_path <- tryCatch(normalizePath(sys.frame(1)$ofile),
                          error = function(e) NULL)
}
if (is.null(script_path) &&
    requireNamespace("rstudioapi", quietly = TRUE) &&
    rstudioapi::isAvailable()) {
  script_path <- rstudioapi::getSourceEditorContext()$path
}
stopifnot("run this file with source(), Rscript, or RStudio's Source button" =
            !is.null(script_path) && nzchar(script_path))

repo_dir    <- dirname(dirname(script_path))
data_dir    <- file.path(repo_dir, "data")
current_dir <- file.path(data_dir, "ahrf_2024_25",
                         "NCHWA-2024-2025+AHRF+COUNTY+CSV")

options(timeout = 1800)


# ---- 1. current AHRF release (2022, 2023) -----------------------------------

hp  <- read.csv(file.path(current_dir, "AHRF2025hp.csv"),  check.names = FALSE)
pop <- read.csv(file.path(current_dir, "AHRF2025pop.csv"), check.names = FALSE)
geo <- read.csv(file.path(current_dir, "AHRF2025geo.csv"), check.names = FALSE)


# ---- 1b. 2023 cross-sections for the County object --------------------------
# The full AHRF release is too wide to import into Foundry directly, so the
# three files are trimmed to the columns the County object type needs. These
# outputs are separate from the panel built below: the panel supplies model
# features, these supply County attributes.

hp_small <- hp[, c("fips_st_cnty",
                   "md_nf_obgyn_gen_23",
                   "md_nf_obgyn_gen_all_pc_23",
                   "md_nf_obgyn_gen_all_pc_22",
                   "do_nf_obgyn_gen_all_pc_23",
                   "do_nf_obgyn_gen_all_pc_22",
                   "md_nf_obgyn_subsp_all_pc_23",
                   "md_nf_obgyn_gen_55_64_23",
                   "md_nf_obgyn_gen_65_74_23",
                   "md_nf_obgyn_gen_ge75_23")]

pop_small <- pop[, c("fips_st_cnty",
                     "popn_est_23",
                     "popn_est_ge65_23",
                     "births_3yr_avg_23",
                     "births_3yr_avg_22",
                     "births_pretrm_3yr_avg_23",
                     "births_to_teens_3yr_lt18_avg_23")]

geo_small <- geo[, c("fips_st_cnty", "cnty_name", "st_name",
                     "st_name_abbrev", "cbsa_23", "cbsa_name_23")]

write.csv(hp_small,  file.path(data_dir, "ahrf_hp_trimmed.csv"),  row.names = FALSE)
write.csv(pop_small, file.path(data_dir, "ahrf_pop_trimmed.csv"), row.names = FALSE)
write.csv(geo_small, file.path(data_dir, "ahrf_geo_trimmed.csv"), row.names = FALSE)

cat("Trimmed cross-sections written:",
    nrow(hp_small), nrow(pop_small), nrow(geo_small), "rows\n")


# ---- 2. historical AHRF release (2010, 2015, 2018) --------------------------

old_zip <- file.path(data_dir, "ahrf_2019_20_sas.zip")
old_dir <- file.path(data_dir, "ahrf_2019_20")

if (!dir.exists(old_dir)) {
  download.file(
    "https://data.hrsa.gov/DataDownload/AHRF/AHRF_2019-2020_SAS.zip",
    old_zip, mode = "wb"
  )
  unzip(old_zip, exdir = old_dir)
}

sas_file <- list.files(old_dir, pattern = "sas7bdat$",
                       recursive = TRUE, full.names = TRUE)[1]
stopifnot("no .sas7bdat file found under data/ahrf_2019_20" = !is.na(sas_file))
ahrf_old <- read_sas(sas_file)


# ---- 3. historical variable mapping -----------------------------------------
# Field codes resolved from SAS label attributes.

old_map <- c(
  fips_st_cnty     = "f00002",
  
  # OB-GYN general, total patient care, non-federal
  obgyn_pc_2010    = "f1168510",
  obgyn_pc_2015    = "f1168515",
  obgyn_pc_2018    = "f1168518",
  
  # OB-GYN general, total (denominator for aging share)
  obgyn_tot_2010   = "f1168410",
  obgyn_tot_2015   = "f1168415",
  obgyn_tot_2018   = "f1168418",
  
  # DO OB-GYN, total patient care
  do_obgyn_pc_2010 = "f1473110",
  do_obgyn_pc_2015 = "f1473115",
  do_obgyn_pc_2018 = "f1473118",
  
  # OB-GYN age band 55-64
  obgyn_5564_2010  = "f1188710",
  obgyn_5564_2015  = "f1188715",
  obgyn_5564_2018  = "f1188718",
  
  # OB-GYN age band 65-74
  obgyn_6574_2010  = "f1206210",
  obgyn_6574_2015  = "f1206215",
  obgyn_6574_2018  = "f1206218",
  
  # OB-GYN age band 75+
  obgyn_75p_2010   = "f1206310",
  obgyn_75p_2015   = "f1206315",
  obgyn_75p_2018   = "f1206318",
  
  # population
  popn_2010        = "f0453010",
  popn_2015        = "f1198415",
  popn_2018        = "f1198418"
)

old_wide <- as.data.frame(ahrf_old[, old_map])
names(old_wide) <- names(old_map)

# FIPS padded to 5 characters. Leading zeros are load-bearing for the
# downstream join to the county closure series (e.g. Autauga, AL = 01001).
old_wide$fips_st_cnty <- sprintf("%05d", as.integer(old_wide$fips_st_cnty))

panel_old <- old_wide %>%
  pivot_longer(
    cols          = -fips_st_cnty,
    names_to      = c(".value", "year"),
    names_pattern = "(.*)_(\\d{4})$"
  ) %>%
  mutate(year = as.integer(year))


# ---- 4. current-year rows (2022, 2023) --------------------------------------
# Caveat logged: AHRF publishes no popn_est_22, so 2022 population is
# approximated by the 2023 estimate. Year-over-year county population drift is
# under 1% and immaterial as a density denominator.

new_map <- data.frame(
  year        = c(2022, 2023),
  obgyn_pc    = c("md_nf_obgyn_gen_all_pc_22", "md_nf_obgyn_gen_all_pc_23"),
  obgyn_tot   = c("md_nf_obgyn_gen_22",        "md_nf_obgyn_gen_23"),
  do_obgyn_pc = c("do_nf_obgyn_gen_all_pc_22", "do_nf_obgyn_gen_all_pc_23"),
  obgyn_5564  = c("md_nf_obgyn_gen_55_64_22",  "md_nf_obgyn_gen_55_64_23"),
  obgyn_6574  = c("md_nf_obgyn_gen_65_74_22",  "md_nf_obgyn_gen_65_74_23"),
  obgyn_75p   = c("md_nf_obgyn_gen_ge75_22",   "md_nf_obgyn_gen_ge75_23"),
  popn        = c("popn_est_23",               "popn_est_23"),
  stringsAsFactors = FALSE
)

panel_new <- do.call(rbind, lapply(seq_len(nrow(new_map)), function(i) {
  data.frame(
    fips_st_cnty = sprintf("%05d", as.integer(hp$fips_st_cnty)),
    year         = new_map$year[i],
    obgyn_pc     = as.numeric(hp[[new_map$obgyn_pc[i]]]),
    obgyn_tot    = as.numeric(hp[[new_map$obgyn_tot[i]]]),
    do_obgyn_pc  = as.numeric(hp[[new_map$do_obgyn_pc[i]]]),
    obgyn_5564   = as.numeric(hp[[new_map$obgyn_5564[i]]]),
    obgyn_6574   = as.numeric(hp[[new_map$obgyn_6574[i]]]),
    obgyn_75p    = as.numeric(hp[[new_map$obgyn_75p[i]]]),
    popn         = as.numeric(pop[[new_map$popn[i]]]),
    stringsAsFactors = FALSE
  )
}))


# ---- 5. combine panel -------------------------------------------------------

panel_all <- rbind(as.data.frame(panel_old), panel_new)


# ---- 6. births --------------------------------------------------------------
# Caveat logged: 2010/2015/2018 use annual birth totals; 2022/2023 use
# three-year averages. Magnitudes are comparable but the measures differ.

births_map <- c(
  fips_st_cnty = "f00002",
  births_2010  = "f1255710",
  births_2015  = "f1255715",
  births_2018  = "f1255718"
)

births_wide <- as.data.frame(ahrf_old[, births_map])
names(births_wide) <- names(births_map)
births_wide$fips_st_cnty <- sprintf("%05d",
                                    as.integer(births_wide$fips_st_cnty))

births_old <- births_wide %>%
  pivot_longer(
    cols          = -fips_st_cnty,
    names_to      = c(".value", "year"),
    names_pattern = "(.*)_(\\d{4})$"
  ) %>%
  mutate(year = as.integer(year))

births_new <- rbind(
  data.frame(fips_st_cnty = sprintf("%05d", as.integer(pop$fips_st_cnty)),
             year         = 2022,
             births       = as.numeric(pop$births_3yr_avg_22)),
  data.frame(fips_st_cnty = sprintf("%05d", as.integer(pop$fips_st_cnty)),
             year         = 2023,
             births       = as.numeric(pop$births_3yr_avg_23))
)

births_all <- rbind(as.data.frame(births_old), births_new)

panel_all <- merge(panel_all, births_all,
                   by = c("fips_st_cnty", "year"), all.x = TRUE)


# ---- 7. geography and rurality ---------------------------------------------
# cbsa_23 is the rurality marker: "NA" denotes a non-metropolitan county.

geo_key <- data.frame(
  fips_st_cnty = sprintf("%05d", as.integer(geo$fips_st_cnty)),
  cnty_name    = geo$cnty_name,
  st_name      = geo$st_name,
  cbsa_23      = geo$cbsa_23,
  stringsAsFactors = FALSE
)

panel_all <- merge(panel_all, geo_key, by = "fips_st_cnty", all.x = TRUE)
panel_all <- panel_all[order(panel_all$fips_st_cnty, panel_all$year), ]


# ---- 8. write ---------------------------------------------------------------

write.csv(panel_all, file.path(data_dir, "ahrf_panel_full.csv"),
          row.names = FALSE)


# ---- 9. verification --------------------------------------------------------
# Hard checks: the script stops if any of these fail.

stopifnot(
  "every FIPS must be 5 characters" =
    all(nchar(panel_all$fips_st_cnty) == 5),
  "county-year must be unique" =
    !any(duplicated(panel_all[, c("fips_st_cnty", "year")])),
  "expected 13 columns" = ncol(panel_all) == 13,
  "expected exactly five panel years" =
    setequal(unique(panel_all$year), c(2010, 2015, 2018, 2022, 2023))
)

cat("\nRows:", nrow(panel_all), " Columns:", ncol(panel_all), "\n")

cat("\nRows per panel year:\n")
print(table(panel_all$year))

cat("\nFIPS character length by year (all cells should read 5):\n")
print(table(nchar(panel_all$fips_st_cnty), panel_all$year))

cat("\nMissing births by year:\n")
print(tapply(is.na(panel_all$births), panel_all$year, sum))

cat("\nFirst rows:\n")
print(head(panel_all, 5))