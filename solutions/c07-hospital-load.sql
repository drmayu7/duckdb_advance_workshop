-- Reveal: C7, "Which hospitals carry the load" (cards/c07-hospital-load.md).
-- Run from the bundle folder, in your Work database, after C6 (or its Checkpoint).

-- Look first: the dengue codes in the admissions. A97.x is today's code; A90
-- and A91 are the codes WHO retired in 2016, still used by some hospitals (DX02).
SELECT principal_dx, count(*) AS n
FROM admission_clean
WHERE principal_dx LIKE 'A9%'
GROUP BY ALL
ORDER BY principal_dx;

-- ref_icd10 groups every code the Scenario uses; scenario_group 'dengue' holds both.
SELECT icd10, title_en, scenario_group
FROM read_csv('data/open/ref_icd10.csv')
WHERE scenario_group = 'dengue';

-- Core: one row per hospital. The LEFT JOIN from facility_clean keeps a hospital
-- with no admissions (with 0); FILTER counts or sums only some rows of a group;
-- window functions over the grouped rows give each hospital its state's total and rank.
CREATE OR REPLACE TABLE hospital_load AS
WITH per_hospital AS (
  SELECT f.state, f.facility_code, f.facility_name, f.facility_type,
         count(a.facility_code) AS admissions,
         count(a.facility_code) FILTER (WHERE i.scenario_group = 'dengue') AS dengue_admissions,
         coalesce(sum(a.los_days) FILTER (WHERE a.date_flag IS NULL), 0)::BIGINT AS bed_days
  FROM facility_clean f
  LEFT JOIN admission_clean a USING (facility_code)
  LEFT JOIN read_csv('data/open/ref_icd10.csv') i ON i.icd10 = a.principal_dx
  GROUP BY ALL
)
SELECT *,
       round(100 * admissions / sum(admissions) OVER (PARTITION BY state), 1) AS state_share_pct,
       rank() OVER (PARTITION BY state ORDER BY admissions DESC) AS state_rank
FROM per_hospital;

-- The three busiest hospitals of each state.
FROM hospital_load
WHERE state_rank <= 3
ORDER BY state, state_rank, facility_code;

-- Stretch S1: counting dengue as A97.x only misses the legacy codes. Which
-- hospitals lose the most?
SELECT *, dengue_admissions - a97_only AS missed
FROM (SELECT h.state, h.facility_name, h.dengue_admissions,
             count(*) FILTER (WHERE a.principal_dx LIKE 'A97%') AS a97_only
      FROM hospital_load h
      JOIN admission_clean a USING (facility_code)
      GROUP BY ALL)
ORDER BY missed DESC, facility_name
LIMIT 10;

-- Stretch S2: a running total. How many hospitals, busiest first, carry half
-- of each state's admissions?
SELECT state, min(state_rank) FILTER (WHERE running_pct >= 50) AS hospitals_for_half, count(*) AS hospitals
FROM (SELECT state, state_rank,
             100 * sum(admissions) OVER (PARTITION BY state ORDER BY state_rank, facility_code)
                 / sum(admissions) OVER (PARTITION BY state) AS running_pct
      FROM hospital_load)
GROUP BY ALL
ORDER BY state;
