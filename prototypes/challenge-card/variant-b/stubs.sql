-- PROTOTYPE. Variant B: empty answer tables shipped in workshop.duckdb so the check macros can bind.
-- Side effect: Participants can DESCRIBE the stub to see exactly which columns their answer needs.
CREATE OR REPLACE TABLE ch13_readmit (admission_id INTEGER, patient_id VARCHAR, discharge_date DATE,
    next_admit_date DATE, days_to_readmit BIGINT, readmit_30d BOOLEAN);
CREATE OR REPLACE TABLE ch13_readmit_unplanned (admission_id INTEGER, patient_id VARCHAR, discharge_date DATE,
    next_admit_date DATE, next_dx VARCHAR, days_to_readmit BIGINT, readmit_30d BOOLEAN, unplanned_30d BOOLEAN);
CREATE OR REPLACE TABLE ch13_by_state (state VARCHAR, index_admissions BIGINT, unplanned_readmissions BIGINT, rate_pct DOUBLE);
