# Analytical Data Science Programmer Coding Assessment

This repository contains my solutions for the Analytical Data Science Programmer coding assessment. The project demonstrates proficiency in the **Pharmaverse** ecosystem (R) and **Generative AI** integration (Python) for clinical trial data standards and reporting.

---

## 📂 Repository Structure

The repository is organized into four main folders, each dedicated to a specific task as outlined in the assessment requirements:

### [Question 1: SDTM DS Domain Creation](./question_1_sdtm/)
Focuses on creating an SDTM Disposition (DS) domain from raw clinical data using the `{sdtm.oak}` package.
* **`01_create_ds_domain.R`**: The main R script that ingests raw data, maps verbatim terms to CDISC Controlled Terminology (Codelist C66727), and derives standard variables such as DSDTC, DSSTDTC, and DSSEQ.
* **`sdtm_ds_final.csv`**: The resulting SDTM DS dataset.
* **`question1.log`**: Comprehensive execution log verifying the code runs error-free.

### [Question 2: ADaM ADSL Dataset Creation](./question_2_adam/)
Focuses on creating a Subject Level Analysis (ADSL) dataset using the `{admiral}` family of packages.
* **`create_adsl.R`**: R script that ingests SDTM domains (DM, EX, AE, VS, DS) to derive age groupings (AGEGR9), population flags (ITTFL), treatment start dates (TRTSDTM), and the Last Known Alive Date (LSTAVLDT).
* **`adsl_final.csv`**: The final ADaM ADSL dataset.
* **`question2.log`**: Execution log for the ADSL pipeline.

### [Question 3: TLG - Adverse Events Reporting](./question_3_tlg/)
Focuses on generating regulatory-compliant clinical reports (Tables, Listings, and Graphs).
* **`01_create_ae_summary_table.R`**: Generates a hierarchical summary table of Treatment-Emergent Adverse Events (TEAEs) using `{gtsummary}`, sorted by descending frequency.
* **`02_create_visualizations.R`**: Generates `{ggplot2}` visualizations, including AE severity distribution and a plot of the top 10 most frequent AEs with 95% Clopper-Pearson confidence intervals.
* **Outputs**: Includes `ae_summary_table.html` and PNG visualizations.

### [Question 4: GenAI Clinical Data Assistant](./question_4_genai_cda/)
A Python-based assistant that translates natural language questions into structured Pandas queries for the AE dataset.
* **`question4_agent.py`**: A Python script featuring a `ClinicalTrialDataAgent` class that parses user intent (e.g., "severity" or "cardiac issues") and maps it to specific CDISC variables like AESEV or AESOC.
* **`question4.log`**: Log file showing the execution of test queries and unique subject matching.

---

## 🚀 Key Design Decisions

1.  **Traceability**: In the SDTM pipeline, Oak ID variables were generated to maintain record-level traceability from raw data (`ds_raw`) to the final domain.
2.  **Modern ADaM Standards**: Used the modern `{admiral}` `event()` API for deriving `LSTAVLDT`, allowing for robust evaluation of dates across AE, DS, VS, and EX sources.
3.  **Reproducibility**: Comprehensive logging was implemented across all scripts (both R and Python) to provide clear evidence of execution and session details.
4.  **AI Integration**: The GenAI assistant was designed with a structured `Prompt -> Parse -> Execute` flow to dynamically map user intent to dataset variables without hard-coded rules.

## 🛠️ Environment Requirements

* **R Version**: 4.2.0 or above.
* **Key R Packages**: `{admiral}`, `{sdtm.oak}`, `{gtsummary}`, `{gt}`, `{ggplot2}`, `{dplyr}`.
* **Python Version**: 3.x with `pandas`.
