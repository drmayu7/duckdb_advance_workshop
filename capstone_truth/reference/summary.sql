-- SUMMARY: the three Angle tables of the State Health Brief for 2021, with the
-- columns capstone/brief.md gives, each with its earlier figure alongside from
-- the 2018-2020 Checkpoints, written as Parquet and CSV as a team delivers them.
-- Runs after C7 (hospital_load), C9 (readmit_state) and admission_clean.
-- A team builds only its own Angle's table; the reference builds all three.

-- Angle A: diabetes 30-day readmission by state. state_brief's rate is
-- 2018-2020 pooled (C9 counts every year of the Raw extract together).
CREATE OR REPLACE TABLE readmit_2021 AS
SELECT r.state, r.index_episodes, r.readmissions, r.readmit_pct,
       b.diabetes_readmit_pct AS readmit_pct_2018_2020
FROM readmit_state r
LEFT JOIN 'expected/state_brief.parquet' b USING (state)
ORDER BY state;

-- Angle B: dengue admissions per 100k people by state of residence: C10's
-- rate, with DOSM's 2021 population, next to state_brief's 2020 rate.
CREATE OR REPLACE TABLE dengue_2021 AS
WITH people AS (
  SELECT norm_state(state) AS state, round(population * 1000) AS people
  FROM 'data/open/population_state.parquet'
  WHERE year(date) = 2021 AND sex = 'both' AND age = 'overall' AND ethnicity = 'overall'
),
admitted AS (
  SELECT a.state, count(*) AS admissions
  FROM admission_clean a
  JOIN read_csv('data/open/ref_icd10.csv') i ON i.icd10 = a.principal_dx
  WHERE i.scenario_group = 'dengue' AND year(a.admit_date) = 2021
  GROUP BY ALL
)
SELECT p.state,
       coalesce(a.admissions, 0) AS dengue_admissions,
       round(100000 * coalesce(a.admissions, 0) / p.people, 1) AS adm_per_100k,
       b.dengue_adm_2020 AS adm_per_100k_2020
FROM people p
LEFT JOIN admitted a USING (state)
LEFT JOIN 'expected/state_brief.parquet' b USING (state)
ORDER BY state;

-- Angle C: the load on each hospital (C7), next to its 2020 admissions and
-- bed days from the admission_clean Checkpoint.
CREATE OR REPLACE TABLE hospital_load_2021 AS
WITH y2020 AS (
  SELECT facility_code, count(*) AS admissions_2020,
         coalesce(sum(los_days) FILTER (WHERE date_flag IS NULL), 0)::BIGINT AS bed_days_2020
  FROM 'expected/admission_clean.parquet'
  WHERE year(admit_date) = 2020
  GROUP BY ALL
)
SELECT h.state, h.facility_code, h.facility_name, h.admissions, h.bed_days, h.state_share_pct, h.state_rank,
       coalesce(y.admissions_2020, 0) AS admissions_2020, coalesce(y.bed_days_2020, 0) AS bed_days_2020
FROM hospital_load h
LEFT JOIN y2020 y USING (facility_code)
ORDER BY state, facility_code;

COPY readmit_2021 TO 'readmit_2021.parquet' (FORMAT parquet);
COPY readmit_2021 TO 'readmit_2021.csv' (HEADER true);
COPY dengue_2021 TO 'dengue_2021.parquet' (FORMAT parquet);
COPY dengue_2021 TO 'dengue_2021.csv' (HEADER true);
COPY hospital_load_2021 TO 'hospital_load_2021.parquet' (FORMAT parquet);
COPY hospital_load_2021 TO 'hospital_load_2021.csv' (HEADER true);
