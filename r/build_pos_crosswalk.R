# =============================================================================
# Meridian: CCN to county FIPS crosswalk
#
# Purpose: build a hospital-level crosswalk mapping CMS Certification Numbers
#          (CCNs) to county FIPS codes, so HCRIS hospital financials can be
#          joined to county-level data.
#
# Input:   CMS Provider of Services File (Hospital & Non-Hospital Facilities),
#          Q2 2026 release, downloaded from data.cms.gov
#
# Output:  pos_crosswalk.csv, 13,566 hospitals, one row per CCN
#
# Note on colClasses: the file is read entirely as character. CCNs and FIPS
#       codes carry leading zeros that numeric import destroys, which would
#       silently break every downstream join.
# =============================================================================


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

repo_dir <- dirname(dirname(script_path))
data_dir <- file.path(repo_dir, "data")

pos_file <- file.path(data_dir, "Hospital_and_other.DATA.Q2_2026.csv")
out_file <- file.path(data_dir, "pos_crosswalk.csv")

pos <- read.csv(pos_file, colClasses = "character")


# ---- trim to the four fields the crosswalk needs ----------------------------
# FIPS state (2 digits) + FIPS county (3 digits) = the 5-digit county code
# used as the primary key throughout Meridian.

pos_small <- data.frame(
  pn            = pos$PRVDR_NUM,
  fips_st_cnty  = paste0(sprintf("%02s", pos$FIPS_STATE_CD),
                         sprintf("%03s", pos$FIPS_CNTY_CD)),
  facility_name = pos$FAC_NAME,
  prvdr_ctgry   = pos$PRVDR_CTGRY_CD,
  stringsAsFactors = FALSE
)


# ---- filter to hospitals ----------------------------------------------------
# Provider category 01 = hospitals. The full file also contains clinics,
# hospices, labs and other facility types that are out of scope.

pos_hosp <- pos_small[pos_small$prvdr_ctgry == "01",
                      c("pn", "fips_st_cnty", "facility_name")]

write.csv(pos_hosp, out_file, row.names = FALSE)


# ---- verification -----------------------------------------------------------

stopifnot(
  "every FIPS must be 5 characters" = all(nchar(pos_hosp$fips_st_cnty) == 5),
  "every CCN must be 6 characters"  = all(nchar(pos_hosp$pn) == 6),
  "CCN must be unique"              = !any(duplicated(pos_hosp$pn))
)

cat("\nRows:", nrow(pos_hosp), "\n")
cat("Unique CCNs:", length(unique(pos_hosp$pn)), "\n")

cat("\nProvider categories in the full file (top 10):\n")
print(head(sort(table(pos_small$prvdr_ctgry), decreasing = TRUE), 10))

cat("\nFirst rows:\n")
print(head(pos_hosp, 5))