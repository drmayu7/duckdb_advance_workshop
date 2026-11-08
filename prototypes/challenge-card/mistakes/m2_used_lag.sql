-- PROTOTYPE. Common mistake 2: used LAG, so the flag lands on the readmission, not the index admission.
CREATE OR REPLACE TABLE ch13_readmit AS
SELECT admission_id, patient_id, discharge_date,
       admit_date AS next_admit_date,
       admit_date - lag(discharge_date) OVER w AS days_to_readmit,
       coalesce(days_to_readmit BETWEEN 0 AND 30, false) AS readmit_30d
FROM admissions
WINDOW w AS (PARTITION BY patient_id ORDER BY admit_date, admission_id)
QUALIFY discharge_status <> 'Died'
ORDER BY admission_id;
