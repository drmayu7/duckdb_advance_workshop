-- Reveal: Warm-up Challenge, "Reproduce last year's numbers" (cards/w-warmup.md).
-- Series 1 SQL only. Run from the bundle folder, in your Work database.

-- Load the 2017 extract into your Work database.
CREATE OR REPLACE TABLE admission_2017 AS
SELECT * FROM 'data/warmup/admission_2017.parquet';

CREATE OR REPLACE TABLE patient_2017 AS
SELECT * FROM 'data/warmup/patient_2017.parquet';

-- Core: one row per hospital state.
CREATE OR REPLACE TABLE warmup_state_summary AS
SELECT a.facility_state AS state,
       count(*) AS admissions,
       count(DISTINCT a.patient_id) AS patients,
       count(CASE WHEN p.sex = 'F' THEN 1 END) AS female_admissions,
       round(avg(a.discharge_date - a.admit_date), 2) AS avg_los_days,
       count(CASE WHEN a.discharge_status = 'DIED' THEN 1 END) AS deaths
FROM admission_2017 AS a
JOIN patient_2017 AS p ON p.patient_id = a.patient_id
GROUP BY a.facility_state
ORDER BY state;

-- Stretch S1: states whose average length of stay is above the national average.
SELECT facility_state AS state,
       round(avg(discharge_date - admit_date), 2) AS avg_los_days
FROM admission_2017
GROUP BY facility_state
HAVING avg(discharge_date - admit_date) >
       (SELECT avg(discharge_date - admit_date) FROM admission_2017)
ORDER BY avg_los_days DESC, state;

-- Stretch S2: the busiest hospital in each state.
-- Tie-break: more admissions first, then the lower facility_code.
WITH hospital_load AS (
  SELECT facility_state, facility_code, facility_name, count(*) AS admissions
  FROM admission_2017
  GROUP BY facility_state, facility_code, facility_name
),
state_top AS (
  SELECT facility_state, max(admissions) AS admissions
  FROM hospital_load
  GROUP BY facility_state
)
SELECT h.facility_state AS state, h.facility_code, h.facility_name, h.admissions
FROM hospital_load AS h
JOIN state_top AS t
  ON t.facility_state = h.facility_state AND t.admissions = h.admissions
WHERE h.facility_code = (SELECT min(h2.facility_code)
                         FROM hospital_load AS h2
                         WHERE h2.facility_state = h.facility_state
                           AND h2.admissions = h.admissions)
ORDER BY state;
