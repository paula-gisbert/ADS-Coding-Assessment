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
#   - Including Traceability (LALVDOM, LALVVAR).
# ==========================================================================
# --- Phase 1: Environment Setup ---
library(pharmaversesdtm)
library(admiral)
library(dplyr)
library(stringr)

target_dir <- "question_2_adam"
if (!dir.exists(target_dir)) dir.create(target_dir)

# --- Phase 2: Logging Initialization ---
execution_log <- file(file.path(target_dir, "question2.log"), open = "wt")
sink(execution_log, type = "output")
sink(execution_log, type = "message")

cat("====================================================\n")
cat("ADSL PIPELINE EXECUTING: ", as.character(Sys.time()), "\n")
cat("====================================================\n\n")

# --- Phase 3: Raw Data Ingestion & Pre-processing ---
domain_dm <- convert_blanks_to_na(pharmaversesdtm::dm)
domain_ex <- convert_blanks_to_na(pharmaversesdtm::ex)
domain_ae <- convert_blanks_to_na(pharmaversesdtm::ae)
domain_vs <- convert_blanks_to_na(pharmaversesdtm::vs)
domain_ds <- convert_blanks_to_na(pharmaversesdtm::ds)

cat("[INFO] Source domains loaded and blanks converted to NA.\n")

# --- Phase 4: Base Demographics & Flags ---
adsl_base <- domain_dm %>%
  select(STUDYID, USUBJID, SUBJID, SITEID, AGE, SEX, RACE, ARM, ARMCD) %>%
  mutate(
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
    ITTFL = if_else(!is.na(ARM) & ARM != "", "Y", "N")
  )

# --- Phase 5: Treatment Start & End (TRTSDTM/TRTEDTM) ---
ex_ext <- domain_ex %>%
  filter(EXDOSE > 0 | (EXDOSE == 0 & grepl("PLACEBO", toupper(EXTRT)))) %>%
  derive_vars_dtm(
    dtc = EXSTDTC,
    new_vars_prefix = "EXST",
    time_imputation = "00:00:00",
    flag_imputation = "time",
    ignore_seconds_flag = TRUE
  ) %>%
  derive_vars_dtm(
    dtc = EXENDTC,
    new_vars_prefix = "EXEN",
    time_imputation = "23:59:59",
    flag_imputation = "time",
    ignore_seconds_flag = TRUE
  )

adsl_trt <- adsl_base %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(TRTSDTM = EXSTDTM, TRTSTMF = EXSTTMF),
    order = exprs(EXSTDTM, EXSEQ),
    mode = "first"
  ) %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(TRTEDTM = EXENDTM),
    order = exprs(EXENDTM, EXSEQ),
    mode = "last"
  ) %>%
  derive_vars_dtm_to_dt(source_vars = exprs(TRTSDTM, TRTEDTM))

# --- Phase 6: Last Known Alive Date (LSTAVLDT) with Traceability ---
# Imputation "M" ensures that even partial dates (YYYY-MM) are used (e.g., 2014-07 becomes 2014-07-01).

adsl_alive <- adsl_trt %>%
  derive_vars_extreme_event(
    by_vars = exprs(STUDYID, USUBJID),
    events = list(
      # (1) Vital Signs
      event(
        dataset_name = "vs",
        order = exprs(LSTAVLDT, VSSEQ),
        condition = !is.na(VSDTC) & (!is.na(VSSTRESN) | !is.na(VSSTRESC)),
        set_values_to = exprs(
          LSTAVLDT = convert_dtc_to_dt(VSDTC, highest_imputation = "M"),
          LALVSEQ = VSSEQ,
          LALVDOM = "VS",
          LALVVAR = "VSDTC"
        )
      ),
      # (2) Adverse Events
      event(
        dataset_name = "ae",
        order = exprs(LSTAVLDT, AESEQ),
        condition = !is.na(AESTDTC),
        set_values_to = exprs(
          LSTAVLDT = convert_dtc_to_dt(AESTDTC, highest_imputation = "M"),
          LALVSEQ = AESEQ,
          LALVDOM = "AE",
          LALVVAR = "AESTDTC"
        )
      ),
      # (3) Disposition
      event(
        dataset_name = "ds",
        order = exprs(LSTAVLDT, DSSEQ),
        condition = !is.na(DSSTDTC),
        set_values_to = exprs(
          LSTAVLDT = convert_dtc_to_dt(DSSTDTC, highest_imputation = "M"),
          LALVSEQ = DSSEQ,
          LALVDOM = "DS",
          LALVVAR = "DSSTDTC"
        )
      ),
      # (4) Treatment End (from ADSL)
      event(
        dataset_name = "adsl",
        condition = !is.na(TRTEDT),
        set_values_to = exprs(
          LSTAVLDT = TRTEDT,
          LALVSEQ = NA_integer_,
          LALVDOM = "ADSL",
          LALVVAR = "TRTEDTM"
        )
      )
    ),
    source_datasets = list(vs = domain_vs, ae = domain_ae, ds = domain_ds, adsl = adsl_trt),
    tmp_event_nr_var = event_nr,
    order = exprs(LSTAVLDT, LALVSEQ, event_nr),
    mode = "last",
    new_vars = exprs(LSTAVLDT, LALVSEQ, LALVDOM, LALVVAR)
  )

cat("[INFO] LSTAVLDT evaluated with Traceability and Imputation.\n\n")

# --- Phase 7: Domain Assembly ---
final_adsl <- adsl_alive %>%
  select(
    STUDYID, USUBJID, SUBJID, SITEID,
    AGE, AGEGR9, AGEGR9N, SEX, RACE,
    ARM, ARMCD, ITTFL,
    TRTSDTM, TRTSTMF, LSTAVLDT,
    LALVDOM, LALVVAR, LALVSEQ
  )

# --- Phase 8: Quality Control Checks ---
cat("--- Quality Control Status ---\n")
missing_ids <- sum(is.na(final_adsl$USUBJID))
dup_subjects <- final_adsl %>% group_by(USUBJID) %>% filter(n() > 1) %>% nrow()

cat("[QC] Missing USUBJIDs: ", missing_ids, "\n")
cat("[QC] Duplicate Subjects: ", dup_subjects, "\n")
cat("[QC] Subjects with LSTAVLDT populated: ", sum(!is.na(final_adsl$LSTAVLDT)), "\n")

if(missing_ids == 0 && dup_subjects == 0) {
  cat("[QC] OVERALL STATUS: PASS\n")
} else {
  cat("[QC] OVERALL STATUS: FAIL - Review dataset.\n")
}
cat("------------------------------\n\n")

# --- Phase 9: File Export ---
output_path <- file.path(target_dir, "adsl_final.csv")
write.csv(final_adsl, output_path, row.names = FALSE)

cat("Final Output Record Count:  ", nrow(final_adsl), "\n")
cat("====================================================\n")
cat("PIPELINE COMPLETED: ", as.character(Sys.time()), "\n")
cat("====================================================\n")

sink(type = "message")
sink(type = "output")
close(execution_log)