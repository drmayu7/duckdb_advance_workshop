-- PROTOTYPE. Common mistake 1: forgot that deaths are not index admissions.
CREATE OR REPLACE TABLE ch13_readmit AS
SELECT admission_id, patient_id, discharge_date,
       lead(admit_date) OVER w AS next_admit_date,
       next_admit_date - discharge_date AS days_to_readmit,
       coalesce(days_to_readmit BETWEEN 0 AND 30, false) AS readmit_30d
FROM admissions
WINDOW w AS (PARTITION BY patient_id ORDER BY admit_date, admission_id)
ORDER BY admission_id;
