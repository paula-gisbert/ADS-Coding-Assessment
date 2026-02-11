# ==========================================================================
# QUESTION 4 - GenAI Assistant: Data Preparation
#
# Author: Paula Gisbert
# Description:
# This script prepares the environment for the Python-based GenAI assistant.
# ==========================================================================

# --- Phase 1: Environment Setup ---
library(pharmaverseadam)

# Define and create the target directory for Question 4
target_dir <- file.path("question_4_genai_cda", "data") 
dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)

if (!dir.exists(target_dir)) dir.create(target_dir, recursive = TRUE)

# --- Phase 2: Logging Initialization ---
execution_log <- file(file.path(target_dir, "00_data_export.log"), open = "wt")
sink(execution_log, type = "output")
sink(execution_log, type = "message")

cat("====================================================\n")
cat("ADAE EXPORT PIPELINE EXECUTING: ", as.character(Sys.time()), "\n")
cat("====================================================\n\n")

# --- Phase 3: Data Ingestion & Pre-processing ---
# Load the ADAE domain from pharmaverseadam
ae_data <- pharmaverseadam::adae

cat("[INFO] Source dataset 'adae' loaded from pharmaverseadam.\n")
cat("[INFO] Total records detected:", nrow(ae_data), "\n")
cat("[INFO] Unique subjects (USUBJID) detected:", length(unique(ae_data$USUBJID)), "\n\n")

# --- Phase 4: File Export & Cleanup ---
output_path <- file.path(target_dir, "adae.csv")

# Export to CSV for Python/Pandas access
write.csv(ae_data, file = output_path, row.names = FALSE)

cat("[INFO] Dataset successfully exported to:", output_path, "\n")
cat("====================================================\n")
cat("EXPORT COMPLETED: ", as.character(Sys.time()), "\n")
cat("====================================================\n")

sink(type = "message")
sink(type = "output")
close(execution_log)