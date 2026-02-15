# ==========================================================================
# QUESTION 1 - SDTM DS Domain Creation using {sdtm.oak}

# Author: Paula Gisbert
# Description:
# This script generates the Study Data Tabulation Model (SDTM) Disposition 
# (DS) domain dataset from raw clinical trial data. It leverages the 
# {sdtm.oak} package to perform standardized transformations, including:
#   - Ingesting and pre-processing raw disposition data.
#   - Generating Oak ID variables for record traceability.
#   - Mapping verbatim terms to standardized CDISC Controlled Terminology 
#     (Codelist C66727).
#   - Applying study-specific business rules for categorization (DSCAT), 
#     handling "Other, Specify" overrides, and dynamically mapping visit 
#     numbering from reference metadata.
#   - Deriving standard datetime variables (DSDTC, DSSTDTC), subject 
#     sequence numbers (DSSEQ), and study day (DSSTDY) relative to 
#     randomization.
#   - Outputting a fully formatted DS domain dataset alongside a comprehensive 
#     execution log.
# ==========================================================================

# --- Phase 1: Environment Setup ---
library(pharmaverseraw)
library(dplyr)
library(stringr)
library(sdtm.oak)

# Ensure target directory exists
target_dir <- "question_1_sdtm"
if (!dir.exists(target_dir)) dir.create(target_dir)

# --- Phase 2: Logging Initialization ---
execution_log <- file(file.path(target_dir, "question1.log"), open = "wt")
sink(execution_log, type = "output")
sink(execution_log, type = "message")

cat("====================================================\n")
cat("DS PIPELINE EXECUTING: ", as.character(Sys.time()), "\n")
cat("====================================================\n\n")

cat("--- Session Details ---\n")
cat("R Version: ", R.version.string, "\n")
cat("{sdtm.oak} Version: ", as.character(packageVersion("sdtm.oak")), "\n")
cat("{dplyr} Version: ", as.character(packageVersion("dplyr")), "\n")
cat("-----------------------\n\n")

# --- Phase 3: Raw Data Ingestion & Pre-processing ---
# Generate oak identifiers and clean up dates/terms
input_records <- pharmaverseraw::ds_raw %>%
  generate_oak_id_vars(pat_var = "PATNUM", raw_src = "ds_raw") %>%
  mutate(
    CLEAN_DECOD = toupper(str_trim(IT.DSDECOD)),
    COL_DATE    = str_replace_all(str_trim(DSDTCOL), "/", "-"),
    COL_TIME    = str_trim(DSTMCOL),
    START_DATE  = str_replace_all(str_trim(IT.DSSTDAT), "/", "-")
  )

cat("[INFO] Raw data loaded. Total records:", nrow(input_records), "\n")
cat("[INFO] Unique subjects detected:", length(unique(input_records$PATNUM)), "\n\n")

# --- Phase 4: Controlled Terminology (CT) Preparation ---
# Load study reference values and isolate the DS Codelist (C66727)
ref_ct <- read.csv("question_1_sdtm/sdtm_ct.csv", stringsAsFactors = FALSE) %>%
  mutate(collected_value = toupper(str_trim(collected_value)))

# Extract DS codelist and manually inject the 'RANDOMIZED' milestone 
# to ensure 100% mapping coverage without downstream fallbacks.
ds_codelist <- ref_ct %>%
  filter(codelist_code == "C66727") %>%
  bind_rows(
    data.frame(
      codelist_code = "C66727", 
      collected_value = "RANDOMIZED", 
      term_value = "RANDOMIZED"
    )
  )

# --- Phase 5: OAK Variable Mapping ---
core_ids <- oak_id_vars()

term_obj <- assign_no_ct(
  raw_dat = input_records, tgt_var = "DSTERM", 
  raw_var = "IT.DSTERM", id_vars = core_ids
)

decod_obj <- assign_ct(
  raw_dat = input_records, tgt_var = "DSDECOD", 
  raw_var = "CLEAN_DECOD", ct_spec = ds_codelist, 
  ct_clst = "C66727", id_vars = core_ids
)

dtc_obj <- assign_datetime(
  raw_dat = input_records, tgt_var = "DSDTC", 
  raw_var = c("COL_DATE", "COL_TIME"), raw_fmt = c("m-d-y", "H:M"), 
  id_vars = core_ids
)

stdtc_obj <- assign_datetime(
  raw_dat = input_records, tgt_var = "DSSTDTC", 
  raw_var = "START_DATE", raw_fmt = "m-d-y", 
  id_vars = core_ids
)
# --- Phase 6: Domain Assembly & Study Logic ---

# 1. Create the Visit Number lookup from sdtm_ct.csv
visit_num_lookup <- ref_ct %>%
  filter(codelist_code == "VISITNUM") %>%
  select(collected_value, term_value) %>%
  mutate(collected_value = toupper(collected_value)) %>%
  tibble::deframe()

# 2. Assemble the domain first
dispo_domain <- input_records %>%
  left_join(term_obj,  by = core_ids) %>%
  left_join(decod_obj, by = core_ids) %>%
  left_join(dtc_obj,   by = core_ids) %>%
  left_join(stdtc_obj, by = core_ids) %>%
  mutate(
    # Handle "Other, Specify" overrides
    has_other = !is.na(OTHERSP) & OTHERSP != "",
    DSTERM    = if_else(has_other, OTHERSP, DSTERM),
    DSDECOD   = toupper(if_else(has_other, OTHERSP, DSDECOD)),
    
    # Define DS Category
    DSCAT = case_when(
      has_other ~ "OTHER EVENT",
      DSDECOD == "RANDOMIZED" ~ "PROTOCOL MILESTONE",
      TRUE ~ "DISPOSITION EVENT"
    ),
    
    # Standard Identifiers
    STUDYID  = STUDY,
    DOMAIN   = "DS",
    USUBJID  = paste0(STUDY, "-", PATNUM),
    VISIT    = toupper(INSTANCE),
    VISITNUM = as.numeric(visit_num_lookup[VISIT])
  )

# 3. Derive RFSTDTC from the assembled Randomized records
# This ensures that "Randomized" is the anchor for Day 1
ref_dates <- dispo_domain %>%
  filter(DSDECOD == "RANDOMIZED") %>%
  select(USUBJID, RFSTDTC = DSSTDTC) %>%
  distinct()

# Join the reference date back to all records for the subject
dispo_domain <- dispo_domain %>%
  left_join(ref_dates, by = "USUBJID")



# --- Phase 7: Sequencing & Calculation ---

final_ds <- dispo_domain %>%
  # Generate sequence numbers
  derive_seq(tgt_var = "DSSEQ", rec_vars = "USUBJID") %>%
  
  derive_study_day(
    sdtm_in = .,
    dm_domain = ., # Use the current data as the reference source
    tgdt = "DSSTDTC",
    refdt = "RFSTDTC",
    study_day_var = "DSSTDY"
  ) %>%
  # Final selection of standard SDTM columns
  select(
    STUDYID, DOMAIN, USUBJID, DSSEQ,
    DSTERM, DSDECOD, DSCAT, VISITNUM, VISIT,
    DSDTC, DSSTDTC, DSSTDY
  ) %>%
  filter(!is.na(DSTERM) & DSTERM != "")

# --- Phase 8: Quality Control Checks ---
cat("--- Quality Control Status ---\n")
missing_ids <- sum(is.na(final_ds$USUBJID))
dup_seqs <- final_ds %>% group_by(USUBJID, DSSEQ) %>% filter(n() > 1) %>% nrow()

cat("[QC] Missing USUBJIDs: ", missing_ids, "\n")
cat("[QC] Duplicate Sequence Keys: ", dup_seqs, "\n")

if(missing_ids == 0 && dup_seqs == 0) {
  cat("[QC] OVERALL STATUS: PASS\n")
} else {
  cat("[QC] OVERALL STATUS: FAIL - Review dataset.\n")
}
cat("------------------------------\n\n")

# --- Phase 9: File Export & Cleanup ---
output_path <- file.path(target_dir, "sdtm_ds_final.csv")
write.csv(final_ds, output_path, row.names = FALSE)

cat("Final Output Subject Count: ", length(unique(final_ds$USUBJID)), "\n")
cat("Final Output Record Count:  ", nrow(final_ds), "\n")
cat("====================================================\n")
cat("PIPELINE COMPLETED: ", as.character(Sys.time()), "\n")
cat("====================================================\n")

sink(type = "message")
sink(type = "output")
close(execution_log)
