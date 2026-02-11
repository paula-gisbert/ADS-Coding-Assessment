# ==========================================================================
# QUESTION 4 - Python Coding Assessment: GenAI Clinical Data Assistant
#
# Author: Paula Gisbert
# Description:
# Translates natural language questions into structured Pandas queries.
# Uses a mocked LLM response flow to demonstrate mapping user intent 
# to the dataset schema (AESEV, AETERM, AESOC).
#   - Outputs a comprehensive 'question4.log' file following repository standards.
# ==========================================================================

import pandas as pd
import json
import os
import sys
from datetime import datetime

# 1. Schema Definition
ADAE_SCHEMA = {
    "AESEV": "Severity or intensity (e.g., MILD, MODERATE, SEVERE).",
    "AETERM": "Specific condition term (e.g., HEADACHE, NAUSEA).",
    "AESOC": "Primary body system (e.g., CARDIAC DISORDERS)."
}

class ClinicalTrialDataAgent:
    def __init__(self):
        """Initializes the agent and dynamically locates the dataset."""
        # --- ROBUST PATH LOGIC ---
        # Ensures the file is found whether run from the project root or the subfolder
        current_script_dir = os.path.dirname(os.path.abspath(__file__))
        data_path = os.path.join(current_script_dir, "data", "adae.csv")
        
        try:
            self.df = pd.read_csv(data_path)
            for col in ['AESEV', 'AETERM', 'AESOC']:
                if col in self.df.columns:
                    self.df[col] = self.df[col].astype(str).str.upper()
            print(f"[INFO] Source dataset successfully loaded from: {data_path}")
        except FileNotFoundError:
            print(f"[ERROR] {data_path} not found. Ensure the R export script was run.")
            self.df = pd.DataFrame(columns=["USUBJID", "AESEV", "AETERM", "AESOC"])

    def parse_question(self, question):
        """Step 2: LLM Implementation (Mocked)."""
        q_upper = question.upper()
        if any(word in q_upper for word in ["SEVERITY", "INTENSITY", "MODERATE", "MILD", "SEVERE"]):
            target_col, filter_val = "AESEV", next((v for v in ["MILD", "MODERATE", "SEVERE"] if v in q_upper), "MODERATE")
        elif any(word in q_upper for word in ["HEADACHE", "NAUSEA", "DIZZINESS"]):
            target_col, filter_val = "AETERM", next((v for v in ["HEADACHE", "NAUSEA", "DIZZINESS"] if v in q_upper), "HEADACHE")
        elif any(word in q_upper for word in ["CARDIAC", "SKIN", "NERVOUS"]):
            target_col = "AESOC"
            if "CARDIAC" in q_upper: filter_val = "CARDIAC DISORDERS"
            elif "SKIN" in q_upper: filter_val = "SKIN AND SUBCUTANEOUS TISSUE DISORDERS"
            else: filter_val = "NERVOUS SYSTEM DISORDERS"
        else:
            target_col, filter_val = "AETERM", "UNKNOWN"

        return {"target_column": target_col, "filter_value": filter_val}

    def execute_query(self, user_question):
        """Step 3: Execution - Applies Pandas filter and returns deliverables."""
        parsed = self.parse_question(user_question)
        col, val = parsed['target_column'], parsed['filter_value']
        
        filtered_df = self.df[self.df[col].str.contains(val, na=False)]
        unique_ids = filtered_df['USUBJID'].unique().tolist()
        
        return {
            "intent": parsed,
            "subject_count": len(unique_ids),
            "matching_ids": unique_ids
        }

# --- Main Execution Block with Logging ---
if __name__ == "__main__":
    # Define log path (consistent with your R folder structure)
    target_dir = os.path.dirname(os.path.abspath(__file__))
    log_path = os.path.join(target_dir, "question4.log")

    # Start Logging capture
    with open(log_path, 'w') as log_file:
        # Custom Logger to write to both Terminal and the Log File simultaneously
        class DualLogger:
            def __init__(self, terminal, file):
                self.terminal = terminal
                self.file = file
            def write(self, message):
                self.terminal.write(message)
                self.file.write(message)
            def flush(self):
                self.terminal.flush()
                self.file.flush()

        sys.stdout = DualLogger(sys.stdout, log_file)

        # Standard Log Header (Matching your repository's style)
        print("====================================================")
        print(f"GENAI ASSISTANT EXECUTING: {datetime.now()}")
        print("====================================================\n")

        print("--- Session Details ---")
        print(f"Python Version: {sys.version.split()[0]}")
        print(f"Pandas Version: {pd.__version__}")
        print("-----------------------\n")

        agent = ClinicalTrialDataAgent() 

        test_queries = [
            "Give me the subjects who had Adverse events of Moderate severity.",
            "Which subjects experienced a Headache?",
            "Find subjects with Cardiac issues."
        ]

        for i, q in enumerate(test_queries, 1):
            result = agent.execute_query(q)
            print(f"Test Query {i}: {q}")
            print(f"-> Mapped: {result['intent']['target_column']} == {result['intent']['filter_value']}")
            print(f"-> Result: Found {result['subject_count']} unique subjects.")
            print(f"-> IDs:    {result['matching_ids'][:5]}...\n")

        print("====================================================")
        print(f"PIPELINE COMPLETED: {datetime.now()}")
        print("====================================================")

    # Restore standard output
    sys.stdout = sys.__stdout__
