-- Reveal: C8, "Episodes of care" (cards/c08-episode.md).
-- Run from the bundle folder, in your Work database, after C7 (or its Checkpoint).

-- Look first: a transfer. The patient leaves one hospital and is admitted to
-- another the same day (AD03). Counted as two admissions, the second looks
-- like a readmission.
SELECT patient_key, facility_code, admit_date, discharge_date, discharge_status,
       admit_date - lag(discharge_date) OVER (PARTITION BY patient_key ORDER BY admit_date) AS days_since_last
FROM admission_clean
WHERE patient_key IN (SELECT patient_key FROM admission_clean
                      WHERE discharge_status IN ('TRANSFERRED', 'Pindah', 'Transfer')
                      ORDER BY patient_key LIMIT 3)
ORDER BY patient_key, admit_date;

-- Core: gaps and islands.
--   1. Each stay's end: its discharge date, unless that is missing or flagged
--      (date_flag, C4); then the stay ends the day it starts.
--   2. A stay starts a new episode unless it starts on or before the previous
--      stay's end + 1 day (lag).
--   3. A running count of the new-episode marks numbers the episodes (sum OVER).
--   4. One row per episode. first(x ORDER BY ...) takes the first or last
--      admission's value even when it is NULL (arg_min would skip a NULL).
CREATE OR REPLACE TABLE episode AS
WITH stay AS (
  SELECT *, CASE WHEN date_flag IS NULL THEN coalesce(discharge_date, admit_date) ELSE admit_date END AS stay_end
  FROM admission_clean
),
marked AS (
  SELECT *, coalesce(admit_date > lag(stay_end) OVER w + 1, true) AS starts_episode
  FROM stay
  WINDOW w AS (PARTITION BY patient_key ORDER BY admit_date)
),
numbered AS (
  SELECT *, sum(starts_episode::INTEGER) OVER (PARTITION BY patient_key ORDER BY admit_date)::INTEGER AS episode_no
  FROM marked
)
SELECT patient_key, episode_no,
       first(state ORDER BY admit_date) AS state,
       first(sex ORDER BY admit_date) AS sex,
       date_sub('year', first(dob ORDER BY admit_date), min(admit_date)) AS age,
       min(admit_date) AS episode_start,
       max(stay_end) AS episode_end,
       date_diff('day', min(admit_date), max(stay_end)) AS los_days,
       count(*) AS admissions,
       first(facility_code ORDER BY admit_date) AS first_facility,
       first(facility_code ORDER BY admit_date DESC) AS last_facility,
       first(principal_dx ORDER BY admit_date) AS principal_dx,
       first(discharge_status ORDER BY admit_date DESC) AS discharge_status
FROM numbered
GROUP BY patient_key, episode_no;

-- Admissions, episodes, and the episodes that span more than one hospital.
SELECT (SELECT count(*) FROM admission_clean) AS admissions,
       count(*) AS episodes,
       count(*) FILTER (WHERE admissions > 1) AS multi_admission,
       count(*) FILTER (WHERE first_facility <> last_facility) AS multi_hospital
FROM episode;

-- Stretch S1: lengths of stay, by diagnosis group, for single- and multi-hospital episodes.
SELECT i.scenario_group, first_facility <> last_facility AS transferred,
       count(*) AS episodes, round(avg(los_days), 1) AS mean_los, median(los_days) AS median_los
FROM episode e
LEFT JOIN read_csv('data/open/ref_icd10.csv') i ON i.icd10 = e.principal_dx
GROUP BY ALL
ORDER BY ALL;

-- Stretch S2: how age is counted. date_diff counts year boundaries crossed;
-- date_sub counts whole years, which is what age means.
SELECT date_diff('year', DATE '2000-12-31', DATE '2001-01-01') AS diff_years,
       date_sub('year', DATE '2000-12-31', DATE '2001-01-01') AS whole_years;
