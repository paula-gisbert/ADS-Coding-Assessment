
# ==========================================================================
# QUESTION 4 - Python Coding Assessment: GenAI Clinical Data Assistant
#
# Author: Paula Gisbert
# Description:
#   This module defines the core Generative AI Assistant logic.
#   It handles the dynamic mapping of natural language to dataset variables 
#   using Google Gemini (via LangChain).
#   - Features: Schema reasoning, Structured Output parsing (Pydantic), 
#     and Pandas-based clinical data filtering.
# ==========================================================================

import pandas as pd
import os
from typing import Dict
from pydantic import BaseModel, Field
from dotenv import load_dotenv
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import JsonOutputParser

load_dotenv()

ADAE_SCHEMA = {
    "AESEV": "Severity or intensity (e.g., MILD, MODERATE, SEVERE).",
    "AETERM": "Specific condition term (e.g., HEADACHE, NAUSEA, DIZZINESS).",
    "AESOC": "Primary body system/organ class (e.g., CARDIAC DISORDERS)."
}

class QueryIntent(BaseModel):
    target_column: str = Field(description="The column name to filter: AESEV, AETERM, or AESOC")
    filter_value: str = Field(description="The specific value to search for, in UPPERCASE")

class ClinicalTrialDataAgent:
    def __init__(self, data_path: str = None):
        self.llm = ChatGoogleGenerativeAI(model="gemini-2.5-flash", temperature=0)
        self.parser = JsonOutputParser(pydantic_object=QueryIntent)
        
        if data_path is None:
            current_dir = os.path.dirname(os.path.abspath(__file__))
            data_path = os.path.join(current_dir, "data", "adae.csv")
        
        try:
            self.df = pd.read_csv(data_path)
            for col in ['AESEV', 'AETERM', 'AESOC']:
                if col in self.df.columns:
                    self.df[col] = self.df[col].astype(str).str.upper()
        except FileNotFoundError:
            self.df = pd.DataFrame(columns=["USUBJID", "AESEV", "AETERM", "AESOC"])

    def execute_query(self, question: str) -> Dict:
        system_prompt = (
            "You are a Clinical Data Assistant. Extract filtering criteria "
            "based on the following dataset schema:\n{schema_context}\n\n"
            "{format_instructions}"
        )
        prompt = ChatPromptTemplate.from_messages([
            ("system", system_prompt),
            ("user", "{question}")
        ])
        chain = prompt | self.llm | self.parser
        parsed = chain.invoke({
            "schema_context": str(ADAE_SCHEMA),
            "question": question,
            "format_instructions": self.parser.get_format_instructions()
        })
        
        col, val = parsed['target_column'], parsed['filter_value']
        filtered_df = self.df[self.df[col].str.contains(val, na=False, case=False)]
        unique_ids = filtered_df['USUBJID'].unique().tolist()
        
        return {
            "intent": parsed,
            "subject_count": len(unique_ids),
            "matching_ids": unique_ids
        }
