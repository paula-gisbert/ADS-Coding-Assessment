# ==========================================================================
# QUESTION 4 - Test Script: GenAI Assistant Validation
#
# Author: Paula Gisbert
# Description:
#   Primary execution script for the GenAI Clinical Data Assistant.
#   - Validates the assistant using three diverse clinical queries.
#   - Implements a DualLogger system to capture session metadata and 
#     LLM mapping results into 'question4.log'.
#   - Ensures environment compliance and resource cleanup.
# ==========================================================================


import os
import sys
from datetime import datetime
from question4_agent import ClinicalTrialDataAgent

# --- CUSTOM LOGGER FOR DUAL OUTPUT ---
class DualLogger:
    def __init__(self, terminal, file):
        self.terminal = terminal
        self.file = file
    def write(self, message):
        self.terminal.write(message)
        if not self.file.closed:
            self.file.write(message)
    def flush(self):
        self.terminal.flush()
        if not self.file.closed:
            self.file.flush()

def run_assessment_tests():
    target_dir = os.path.dirname(os.path.abspath(__file__))
    log_path = os.path.join(target_dir, "question4.log")
    
    # 1. Capture original terminal output
    original_stdout = sys.stdout 

    with open(log_path, 'w') as log_file:
        # 2. Redirect output
        sys.stdout = DualLogger(original_stdout, log_file)

        print("====================================================")
        print(f"GENAI ASSISTANT EXECUTION: {datetime.now()}")
        print("====================================================\n")
        
        try:
            agent = ClinicalTrialDataAgent()
            test_queries = [
                "Give me the subjects who had Adverse events of Moderate severity.",
                "Which subjects experienced a Headache?",
                "Find subjects with Diarrhoea."
            ]

            for i, q in enumerate(test_queries, 1):
                print(f"TEST QUERY {i}: {q}")
                result = agent.execute_query(q)
                print(f"-> Mapped: {result['intent']['target_column']} == {result['intent']['filter_value']}")
                print(f"-> Result: Found {result['subject_count']} unique subjects.")
                print(f"-> IDs:    {result['matching_ids'][:5]}...\n")

        except Exception as e:
            print(f"[FATAL ERROR]: {e}")

        print("====================================================")
        print(f"PIPELINE COMPLETED: {datetime.now()}")
        print("====================================================")

        # 3. Clean restoration before the file closes
        sys.stdout.flush()
        sys.stdout = original_stdout

if __name__ == "__main__":
    run_assessment_tests()
