# ==========================================================================
# QUESTION 2 - ADaM ADSL Dataset Creation
#
# Author: Paula Gisbert
# Description:
# This script generates the Subject Level (ADSL) dataset from SDTM domains.
# It leverages the {admiral} package to perform standardized derivations:
#   - Ingesting raw SDTM domains (DM, EX, AE, VS, DS).
#   - Deriving age categories (AGEGR9, AGEGR9N) and population flags (ITTFL)
#   - Calculating treatment start datetimes (TRTSDTM, TRTSTMF) using exposure
#   - Optimizing the last known alive date (LSTAVLDT) across multiple domains
#   - Outputting a fully formatted ADSL dataset alongside an execution log
# ==========================================================================

# --- Phase 1: Environment Setup ---
library(pharmaversesdtm)
library(admiral)
library(dplyr)
library(stringr)

# Ensure target directory exists
target_dir <- "question_2_adam"
if (!dir.exists(target_dir)) dir.create(target_dir)

# --- Phase 2: Logging Initialization ---
execution_log <- file(file.path(target_dir, "question2.log"), open = "wt")
sink(execution_log, type = "output")
sink(execution_log, type = "message")

cat("====================================================\n")
cat("ADSL PIPELINE EXECUTING: ", as.character(Sys.time()), "\n")
cat("====================================================\n\n")

cat("--- Session Details ---\n")
cat("R Version: ", R.version.string, "\n")
cat("{admiral} Version: ", as.character(packageVersion("admiral")), "\n")
cat("{dplyr} Version: ", as.character(packageVersion("dplyr")), "\n")
cat("-----------------------\n\n")

# --- Phase 3: Raw Data Ingestion & Pre-processing ---
# Load all required SDTM domains
domain_dm <- pharmaversesdtm::dm
domain_ex <- pharmaversesdtm::ex
domain_ae <- pharmaversesdtm::ae
domain_vs <- pharmaversesdtm::vs
domain_ds <- pharmaversesdtm::ds

cat("[INFO] Source domains loaded successfully.\n")
cat("[INFO] Base DM records:", nrow(domain_dm), "\n\n")

# --- Phase 4: Base Demographics & Flags ---
# Build the foundation of ADSL from DM and derive initial classifications
adsl_base <- domain_dm %>%
  select(STUDYID, USUBJID, SUBJID, SITEID, AGE, SEX, RACE, ARM, ARMCD) %>%
  mutate(
    # Age Groupings
    AGEGR9 = case_when(
      AGE < 18 ~ "<18",
      AGE >= 18 & AGE <= 50 ~ "18-50",
      AGE > 50 ~ ">50",
      TRUE ~ NA_character_
    ),
    AGEGR9N = case_when(
      AGE < 18 ~ 1,
      AGE >= 18 & AGE <= 50 ~ 2,
      AGE > 50 ~ 3,
      TRUE ~ NA_real_
    ),
    
    # Intent-to-Treat Flag (Populated ARM indicates randomization)
    ITTFL = if_else(!is.na(ARM) & ARM != "", "Y", "N")
  )

cat("[INFO] Base demographics and ITTFL derived.\n")
# --- Phase 5: Treatment Start (TRTSDTM & TRTSTMF) ---
# Isolate valid exposures based on business logic
valid_doses <- domain_ex %>%
  filter(EXDOSE > 0 | (EXDOSE == 0 & grepl("PLACEBO", toupper(EXTRT)))) %>%
  filter(!is.na(EXSTDTC))

# Merge first valid exposure into ADSL and handle imputation
adsl_trt <- adsl_base %>%
  derive_vars_merged(
    dataset_add = valid_doses,
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(FIRST_EXDTC = EXSTDTC),
    order = exprs(EXSTDTC, EXSEQ),
    mode = "first"
  ) %>%
  derive_vars_dtm(
    dtc = FIRST_EXDTC,
    new_vars_prefix = "TRTS",
    time_imputation = "00:00:00",
    flag_imputation = "time",
    ignore_seconds_flag = TRUE # Silences the default warning in admiral 1.3+
  ) %>%
  select(-FIRST_EXDTC)

cat("[INFO] TRTSDTM and missing time imputation (TRTSTMF) processed.\n")

# --- Phase 6: Last Known Alive Date (LSTAVLDT) ---
# Pre-process dates into a standard Date object (`ALIVE_DT`) to satisfy 
# the strict typing requirements of the modern admiral event() API.

ae_alive <- domain_ae %>%
  filter(!is.na(AESTDTC)) %>%
  mutate(ALIVE_DT = convert_dtc_to_dt(AESTDTC))

ds_alive <- domain_ds %>%
  filter(!is.na(DSSTDTC)) %>%
  mutate(ALIVE_DT = convert_dtc_to_dt(DSSTDTC))

vs_alive <- domain_vs %>%
  filter(!is.na(VSDTC) & (!is.na(VSSTRESN) | !is.na(VSSTRESC))) %>%
  mutate(ALIVE_DT = convert_dtc_to_dt(VSDTC))

ex_alive <- valid_doses %>% 
  mutate(ALIVE_DT = convert_dtc_to_dt(EXSTDTC))

# Define the tracking events using the modern API
alive_events <- list(
  event(dataset_name = "ae_src", order = exprs(ALIVE_DT)),
  event(dataset_name = "ds_src", order = exprs(ALIVE_DT)),
  event(dataset_name = "vs_src", order = exprs(ALIVE_DT)),
  event(dataset_name = "ex_src", order = exprs(ALIVE_DT))
)

# Extract extreme date across all prepared sources
adsl_alive <- adsl_trt %>%
  derive_vars_extreme_event(
    by_vars = exprs(STUDYID, USUBJID),
    events = alive_events,
    source_datasets = list(
      ae_src = ae_alive,
      ds_src = ds_alive,
      vs_src = vs_alive,
      ex_src = ex_alive
    ),
    order = exprs(ALIVE_DT),
    mode = "last",
    new_vars = exprs(LSTAVLDT = ALIVE_DT)
  )

cat("[INFO] LSTAVLDT evaluated across modern event() definitions.\n\n")
# --- Phase 7: Domain Assembly & Sequencing ---
final_adsl <- adsl_alive %>%
  select(
    STUDYID, USUBJID, SUBJID, SITEID,
    AGE, AGEGR9, AGEGR9N, SEX, RACE,
    ARM, ARMCD, ITTFL,
    TRTSDTM, TRTSTMF, LSTAVLDT
  )

# --- Phase 8: Quality Control Checks ---
cat("--- Quality Control Status ---\n")
missing_ids <- sum(is.na(final_adsl$USUBJID))
dup_seqs <- final_adsl %>% group_by(USUBJID) %>% filter(n() > 1) %>% nrow()

cat("[QC] Missing USUBJIDs: ", missing_ids, "\n")
cat("[QC] Duplicate Subjects: ", dup_seqs, "\n")

if(missing_ids == 0 && dup_seqs == 0) {
  cat("[QC] OVERALL STATUS: PASS\n")
} else {
  cat("[QC] OVERALL STATUS: FAIL - Review dataset.\n")
}
cat("------------------------------\n\n")

# --- Phase 9: File Export & Cleanup ---
output_path <- file.path(target_dir, "adsl_final.csv")
write.csv(final_adsl, output_path, row.names = FALSE)

cat("Final Output Subject Count: ", length(unique(final_adsl$USUBJID)), "\n")
cat("Final Output Record Count:  ", nrow(final_adsl), "\n")
cat("====================================================\n")
cat("PIPELINE COMPLETED: ", as.character(Sys.time()), "\n")
cat("====================================================\n")

sink(type = "message")
sink(type = "output")
close(execution_log)