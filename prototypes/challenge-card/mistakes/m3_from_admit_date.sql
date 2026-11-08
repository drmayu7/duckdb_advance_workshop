-- PROTOTYPE. Common mistake 3: counted 30 days from admit_date instead of discharge_date.
CREATE OR REPLACE TABLE ch13_readmit AS
SELECT admission_id, patient_id, discharge_date,
       lead(admit_date) OVER w AS next_admit_date,
       next_admit_date - admit_date AS days_to_readmit,
       coalesce(days_to_readmit BETWEEN 0 AND 30, false) AS readmit_30d
FROM admissions
WINDOW w AS (PARTITION BY patient_id ORDER BY admit_date, admission_id)
QUALIFY discharge_status <> 'Died'
ORDER BY admission_id;
