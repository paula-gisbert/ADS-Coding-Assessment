# ==========================================================================
# QUESTION 3 - TLG: Adverse Events Summary Table
#
# Description:
# This script generates a regulatory-compliant Adverse Event summary table
# using the {gtsummary} and {gt} packages.
#   - Ingests ADSL and ADAE datasets.
#   - Filters for Treatment-Emergent AEs (TRTEMFL == "Y").
#   - Calculates accurate patient-level incidence rates per treatment arm.
#   - Outputs an HTML summary table sorted by descending frequency.
# ==========================================================================

# --- Phase 1: Environment Setup ---
library(pharmaverseadam)
library(dplyr)
library(gtsummary)
library(gt)
library(forcats)


target_dir <- "question_3_tlg"
if (!dir.exists(target_dir)) dir.create(target_dir, recursive = TRUE)

# --- Phase 2: Logging Initialization ---
execution_log <- file(file.path(target_dir, "01_table_generation.log"), open = "wt")
sink(execution_log, type = "output")
sink(execution_log, type = "message")

cat("====================================================\n")
cat("AE SUMMARY TABLE EXECUTING: ", as.character(Sys.time()), "\n")
cat("====================================================\n\n")

# --- Phase 3: Data Ingestion & Denominator Prep ---
adsl <- pharmaverseadam::adsl
adae <- pharmaverseadam::adae

cat("[INFO] Source domains loaded. ADSL:", nrow(adsl), " ADAE:", nrow(adae), "\n")
# Filter for the Safety Population and TEAEs
ae_safety_pop <- adae %>%
  filter(SAFFL == "Y" & TRTEMFL == "Y") %>%
  select(USUBJID, ACTARM, AESOC, AETERM)

# Normalize casing and set factor levels by frequency to ensure the table 
# sorts SOCs and PTs in descending order automatically.
ae_prepared <- ae_safety_pop %>%
  mutate(
    AESOC  = toupper(AESOC),
    AETERM = toupper(AETERM),
    AESOC  = fct_infreq(AESOC),
    AETERM = fct_infreq(AETERM)
  )

cat("[INFO] Hierarchical TEAE dataset prepared. Total records: ", nrow(ae_prepared), "\n\n")


# --- Phase 4: Table Generation ---
cat("[INFO] Constructing hierarchical {gtsummary} table...\n")

ae_summary <- ae_prepared %>%
  tbl_hierarchical(
    variables = c(AESOC, AETERM),
    by = ACTARM,
    id = USUBJID,
    denominator = adsl,
    statistic = all_categorical() ~ "{n} ({p}%)",
    overall_row = TRUE, # Keeps the top summary row intact
    label = list(
      "..ard_hierarchical_overall.." ~ "Treatment-Emergent AEs"
    )
  ) %>%
  sort_hierarchical() %>% # Keeps the descending frequency sort intact
  modify_header(
    label = "**Primary System Organ Class** <br> **Reported Term for the Adverse Event**"
  ) %>%
  bold_labels()
# --- Phase 5: Export & Cleanup ---
output_path <- file.path(target_dir, "ae_summary_table.html")

ae_summary %>%
  as_gt() %>%
  gtsave(filename = output_path)

cat("[INFO] Table successfully exported to: ", output_path, "\n")
cat("====================================================\n")
cat("PIPELINE COMPLETED: ", as.character(Sys.time()), "\n")
cat("====================================================\n")

sink(type = "message")
sink(type = "output")
close(execution_log)