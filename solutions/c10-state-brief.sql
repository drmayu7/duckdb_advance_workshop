-- Reveal: C10, "State summary" (cards/c10-state-brief.md).
-- Run from the bundle folder, in your Work database, after C9 (or its Checkpoint).

-- C5's macros, in case C5 was done from its Checkpoint (which loads the table only).
CREATE OR REPLACE MACRO state_key(s) AS regexp_replace(upper(s), '[^A-Z]', '', 'g');
CREATE OR REPLACE MACRO norm_state(s) AS
  CASE
    WHEN state_key(s) IN ('JOHOR', 'JOHORDARULTAKZIM', 'JHR') THEN 'JOHOR'
    WHEN state_key(s) IN ('KEDAH', 'KEDAHDARULAMAN', 'KDH') THEN 'KEDAH'
    WHEN state_key(s) IN ('KELANTAN', 'KELANTANDARULNAIM', 'KTN') THEN 'KELANTAN'
    WHEN state_key(s) IN ('MELAKA', 'MALACCA', 'MLK') THEN 'MELAKA'
    WHEN state_key(s) IN ('NEGERISEMBILAN', 'NSEMBILAN', 'NEGRISEMBILAN', 'NSN') THEN 'NEGERI SEMBILAN'
    WHEN state_key(s) IN ('PAHANG', 'PAHANGDARULMAKMUR', 'PHG') THEN 'PAHANG'
    WHEN state_key(s) IN ('PERAK', 'PERAKDARULRIDZUAN', 'PRK') THEN 'PERAK'
    WHEN state_key(s) IN ('PERLIS', 'PERLISINDERAKAYANGAN', 'PLS') THEN 'PERLIS'
    WHEN state_key(s) IN ('PULAUPINANG', 'PPINANG', 'PENANG', 'PNG') THEN 'PULAU PINANG'
    WHEN state_key(s) IN ('SABAH', 'SBH') THEN 'SABAH'
    WHEN state_key(s) IN ('SARAWAK', 'SWK') THEN 'SARAWAK'
    WHEN state_key(s) IN ('SELANGOR', 'SELANGORDARULEHSAN', 'SGR') THEN 'SELANGOR'
    WHEN state_key(s) IN ('TERENGGANU', 'TERENGGANUDARULIMAN', 'TRG') THEN 'TERENGGANU'
    WHEN state_key(s) IN ('WILAYAHPERSEKUTUANKUALALUMPUR', 'WPKUALALUMPUR', 'KUALALUMPUR', 'WPKL')
      THEN 'WILAYAH PERSEKUTUAN KUALA LUMPUR'
    WHEN state_key(s) IN ('WILAYAHPERSEKUTUANLABUAN', 'WPLABUAN', 'LABUAN') THEN 'WILAYAH PERSEKUTUAN LABUAN'
    WHEN state_key(s) IN ('WILAYAHPERSEKUTUANPUTRAJAYA', 'WPPUTRAJAYA', 'PUTRAJAYA') THEN 'WILAYAH PERSEKUTUAN PUTRAJAYA'
  END;

-- norm_icd (DX01): upper case, letters and digits only, then a dot after the
-- third character and at most one character after it: e119, E11.9 and E11.90
-- all become E11.9; I10 stays I10.
CREATE OR REPLACE MACRO icd_key(code) AS regexp_replace(upper(code), '[^A-Z0-9]', '', 'g');
CREATE OR REPLACE MACRO norm_icd(code) AS
  CASE WHEN code IS NOT NULL THEN concat_ws('.', icd_key(code)[1:3], nullif(icd_key(code)[4:4], '')) END;

-- Look first: the dengue CSV is wide, one column per state (SH01).
FROM read_csv('data/open/dengue_state_age_2018_2021.csv') LIMIT 5;

-- UNPIVOT turns the state columns into rows: one row per year, age group and state.
UNPIVOT read_csv('data/open/dengue_state_age_2018_2021.csv')
ON COLUMNS(* EXCLUDE (TAHUN, "KUMPULAN UMUR"))
INTO NAME state VALUE cases
LIMIT 5;

-- Core, step 1: the long table, one row per state and year, 2018-2020.
--   people:         DOSM population (thousands) x 1000, for the state and year.
--   adm_per_100k:   dengue admissions (scenario_group 'dengue', so A90/A91 too) by
--                   where the patient lives, per 100k people. 0 when there are none.
--   cases_per_100k: notified dengue cases, summed over age groups, per 100k people.
--                   The CSV has no Putrajaya column, so Putrajaya's is NULL.
CREATE OR REPLACE TABLE dengue_long AS
WITH people AS (
  SELECT norm_state(state) AS state, year(date) AS year, round(population * 1000) AS people
  FROM 'data/open/population_state.parquet'
  WHERE year(date) BETWEEN 2018 AND 2020 AND sex = 'both' AND age = 'overall' AND ethnicity = 'overall'
),
admitted AS (
  SELECT a.state, year(a.admit_date) AS year, count(*) AS admissions
  FROM admission_clean a
  JOIN read_csv('data/open/ref_icd10.csv') i ON i.icd10 = a.principal_dx
  WHERE i.scenario_group = 'dengue'
  GROUP BY ALL
),
notified AS (
  SELECT norm_state(state) AS state, TAHUN AS year, sum(cases) AS cases
  FROM (UNPIVOT read_csv('data/open/dengue_state_age_2018_2021.csv')
        ON COLUMNS(* EXCLUDE (TAHUN, "KUMPULAN UMUR"))
        INTO NAME state VALUE cases)
  GROUP BY ALL
)
SELECT p.state, p.year,
       round(100000 * coalesce(a.admissions, 0) / p.people, 1) AS adm_per_100k,
       round(100000 * n.cases / p.people, 1) AS cases_per_100k
FROM people p
LEFT JOIN admitted a USING (state, year)
LEFT JOIN notified n USING (state, year);

-- Step 2: PIVOT the years back out to columns, two per year (2018_adm, 2018_cases, ...),
-- then join the readmission rates and each state's busiest hospital.
-- Tie-break for the busiest: rank 1 in hospital_load, then the lowest facility_code.
CREATE OR REPLACE TABLE state_brief AS
WITH wide AS (
  PIVOT dengue_long ON year IN (2018, 2019, 2020) USING first(adm_per_100k) AS adm, first(cases_per_100k) AS cases GROUP BY state
),
busiest AS (
  SELECT state, facility_name, state_share_pct
  FROM hospital_load
  QUALIFY row_number() OVER (PARTITION BY state ORDER BY state_rank, facility_code) = 1
)
SELECT w.state,
       r.index_episodes AS diabetes_index_episodes,
       r.readmit_pct AS diabetes_readmit_pct,
       w."2018_adm" AS dengue_adm_2018, w."2019_adm" AS dengue_adm_2019, w."2020_adm" AS dengue_adm_2020,
       w."2018_cases" AS dengue_cases_2018, w."2019_cases" AS dengue_cases_2019, w."2020_cases" AS dengue_cases_2020,
       t.facility_name AS top_hospital,
       t.state_share_pct AS top_hospital_share_pct
FROM wide w
LEFT JOIN readmit_state r USING (state)
LEFT JOIN busiest t USING (state);

FROM state_brief ORDER BY state;

-- Export: one file per audience. Parquet keeps the types; CSV opens anywhere.
-- The files are written next to your Work database, in the bundle folder.
COPY (FROM state_brief ORDER BY state) TO 'state_brief.parquet' (FORMAT parquet);
COPY (FROM state_brief ORDER BY state) TO 'state_brief.csv' (HEADER true);

-- Stretch S1: Excel, with the excel extension (in your bundle).
LOAD excel;
COPY (FROM state_brief ORDER BY state) TO 'state_brief.xlsx' (FORMAT xlsx, HEADER true);
FROM read_xlsx('state_brief.xlsx') LIMIT 3;

-- Stretch S2: how far admissions are from notified cases. Most dengue is
-- notified without an admission; the ratio shows where the extract is thin.
SELECT state, dengue_adm_2020, dengue_cases_2020,
       round(100 * dengue_adm_2020 / dengue_cases_2020, 1) AS admitted_pct_of_notified
FROM state_brief
ORDER BY admitted_pct_of_notified DESC NULLS LAST;
