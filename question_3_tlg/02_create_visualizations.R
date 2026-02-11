# ==========================================================================
# QUESTION 3 - TLG: Adverse Events Visualizations
#
# Description:
# This script generates ggplot2 visualizations for AE distributions.
#   - Plot 1: Stacked bar chart of AE Severity by Treatment Arm.
#   - Plot 2: Point-range chart of the Top 10 most frequent AEs 
#             with exact 95% Clopper-Pearson Confidence Intervals.
# ==========================================================================

# --- Phase 1: Environment Setup ---
library(pharmaverseadam)
library(dplyr)
library(ggplot2)

target_dir <- "question_3_tlg"
if (!dir.exists(target_dir)) dir.create(target_dir, recursive = TRUE)

# --- Phase 2: Logging Initialization ---
execution_log <- file(file.path(target_dir, "02_visualizations.log"), open = "wt")
sink(execution_log, type = "output")
sink(execution_log, type = "message")

cat("====================================================\n")
cat("AE VISUALIZATIONS EXECUTING: ", as.character(Sys.time()), "\n")
cat("====================================================\n\n")

adsl <- pharmaverseadam::adsl
adae <- pharmaverseadam::adae

# --- Phase 3: Plot 1 - Severity Distribution ---
cat("[INFO] Generating Plot 1: Severity Distribution...\n")

# 1. Create the subset
ae_subset <- adae %>%
  filter(SAFFL == "Y", TRTEMFL == "Y")

# 2. CHANGE: Order levels MILD -> MODERATE -> SEVERE (Bottom to Top)
severity_data <- ae_subset %>%
  count(ACTARM, AESEV) %>%
  filter(!is.na(AESEV)) %>%
  mutate(AESEV = factor(AESEV, levels = c("MILD", "MODERATE", "SEVERE")))

# 3. Plot
plot_severity <- ggplot(severity_data, aes(x = ACTARM, y = n, fill = AESEV)) +
  geom_col() + 
  scale_fill_manual(
    values = c("MILD" = "#F8766D", "MODERATE" = "#00BA38", "SEVERE" = "#619CFF"),
    # CHANGE: Reverse breaks so the Legend matches the visual stack (Severe on top)
    breaks = c("SEVERE", "MODERATE", "MILD") 
  ) +
  labs(
    title = "AE severity distribution by treatment",
    x = "Treatment Arm",
    y = "Count of AEs",
    fill = "Severity"
  ) +
  theme_minimal()
# --- Phase 4: Plot 2 - Top 10 AEs with Confidence Intervals ---
cat("[INFO] Generating Plot 2: Top 10 AEs with 95% CIs...\n")

# 1. Ensure binom library is loaded
library(binom)

# 2. Calculate safety population denominator as in uploaded file
safety_n <- adae %>%
  filter(SAFFL == "Y") %>%
  summarise(n = n_distinct(USUBJID)) %>%
  pull(n)

# 3. Filter and Rank by total record count (n), not unique patients
top_aes <- adae %>%
  filter(SAFFL == "Y", TRTEMFL == "Y") %>%
  count(AETERM, sort = TRUE) %>%
  slice_head(n = 10) %>%
  mutate(
    TotalSubjects = safety_n,
    Percentage = (n / safety_n) * 100
  )

# 4. Compute CIs using the binom package method
ci_results <- binom.confint(
  top_aes$n, 
  top_aes$TotalSubjects, 
  methods = "exact"
)

top_aes <- top_aes %>%
  mutate(
    Lower_CI = ci_results$lower * 100,
    Upper_CI = ci_results$upper * 100
  )

# 5. Build plot with theme_grey()
plot_top10 <- ggplot(top_aes, aes(x = Percentage, y = reorder(AETERM, Percentage))) +
  geom_point(size = 3) +
  geom_errorbarh(aes(xmin = Lower_CI, xmax = Upper_CI), height = 0.2) +
  labs(
    title = "Top 10 Most Frequent Adverse Events",
    subtitle = sprintf("n = %d subjects; 95%% Clopper-Pearson CIs", safety_n),
    x = "Percentage of Patients (%)",
    y = ""
  ) +
  theme_grey() # Matches the uploaded script's visual style

ggsave(file.path(target_dir, "ae_top10_ci.png"), plot = plot_top10, width = 8, height = 6)
# --- Phase 5: Cleanup ---
cat("[INFO] Plots successfully exported as PNGs.\n")
cat("====================================================\n")
cat("PIPELINE COMPLETED: ", as.character(Sys.time()), "\n")
cat("====================================================\n")

sink(type = "message")
sink(type = "output")
close(execution_log)