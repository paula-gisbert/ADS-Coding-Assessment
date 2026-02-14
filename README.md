# Analytical Data Science Programmer Coding Assessment

This repository contains my solutions for the Analytical Data Science Programmer coding assessment. The project demonstrates uses the **Pharmaverse** ecosystem (R) and **Generative AI** integration (Python) for clinical trial data standards and reporting.

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
* **`clinical_agent.py`**: The core solution containing the `ClinicalTrialDataAgent` class and LLM schema mapping logic.
* **`test_script.py`**: The validation script that executes clinical queries and manages the dual-logging system.
* **`question4.log`**: Log file showing the execution of test queries and unique subject matching.
* **`requirements.txt`**: List of Python dependencies (LangChain, Google Generative AI, Pandas).

---

## 🛠️ Environment Setup

### R Environment (Questions 1, 2, & 3)
To ensure reproducibility, this project uses the **{renv}** package to manage dependencies.

1. **Open the Project:** Open `project.Rproj` in RStudio.  
2. **Restore Packages:** Run the following command in the R console to install all required libraries (including **{admiral}**, **{sdtm.oak}**, and **{gtsummary}**):

```r
if (!require("renv")) install.packages("renv")
renv::restore()
```

### Python Environment (Question 4)
1. **Install Dependencies:** Ensure you have Python **3.9+** installed. From the `question_4_genai_cda/` directory, run:

```bash
pip install -r requirements.txt
```

2. **Configure API Key:** This solution uses **Google Gemini 2.5 Flash** for high-speed reasoning.

- Obtain a free API key from [Google AI Studio](https://aistudio.google.com/app/apikey).
- Create a file named `.env` in the Question 4 directory.
- Add your key:

```env
GOOGLE_API_KEY=your_actual_key_here
```

---

## 📂 Repository Structure & Execution

### Question 1: SDTM DS Domain Creation
Creation of an SDTM Disposition (DS) domain from raw data using **{sdtm.oak}**.

- **Key Script:** `01_create_ds_domain.R`
- **Requirements:** Requires `sdtm_ct.csv` in the folder for controlled terminology mapping.
- **How to Run:**

```r
source("question_1_sdtm/01_create_ds_domain.R")
```

---

### Question 2: ADaM ADSL Dataset Creation
Development of the Subject Level Analysis (ADSL) dataset using **{admiral}**.

- **Key Script:** `create_adsl.R`
- **Derivations:** Includes ITT flags, age groupings, treatment start (TRTSDTM), and Last Known Alive Date (LSTAVLDT).
- **How to Run:**

```r
source("question_2_adam/create_adsl.R")
```

---

### Question 3: TLG - Adverse Events Reporting
Generating regulatory-compliant clinical Tables, Listings, and Graphs.

- **Table:** `01_create_ae_summary_table.R` (Hierarchical TEAE summary)
- **Figures:** `02_create_visualizations.R` (Severity distribution and Top 10 AE CI plot)
- **How to Run:**

```r
source("question_3_tlg/01_create_ae_summary_table.R")
source("question_3_tlg/02_create_visualizations.R")
```

---

### Question 4: GenAI Clinical Data Assistant
A Python-based assistant that translates natural language questions into structured **Pandas** queries for the AE dataset.

#### Key Components 
- **`clinical_agent.py`**: Core solution containing the `ClinicalTrialDataAgent` class and LLM schema mapping logic.  
- **`test_script.py`**: Validation script that executes clinical queries and manages the dual-logging system.  
- **`question4.log`**: Log file showing the execution of test queries and unique subject matching.  
- **`requirements.txt`**: List of Python dependencies (**LangChain**, **Google Generative AI**, **Pandas**).  

#### Getting Started (Question 4: LLM Assistant)

1. **Install Dependencies**
```bash
pip install -r requirements.txt
```

2. **Configure API Key**
- Obtain a free API key from [Google AI Studio](https://aistudio.google.com/app/apikey).
- Create `.env` in the Question 4 directory and add:
```env
GOOGLE_API_KEY=your_actual_key_here
```

3. **Running the Tests**
To execute the clinical queries and generate the log file, run:
```bash
python test_script.py
```

#### How to Run the Assistant
- **Key Script:** `question4_agent.py`
- **Configuration:** Requires a `.env` file with your `GOOGLE_API_KEY`.
- **Run:**

```bash
python question_4_genai_cda/question4_agent.py
```
