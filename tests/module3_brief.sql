-- Module 3 (#29): the C7-C10 expected results, which the canonical solutions
-- write (tests/solution_chain.sh proves they are current), checked against the
-- generator's clean truth, the Answer key and the open data, so a Self-check
-- never certifies a wrong State Health Brief.
CREATE TABLE truth AS
SELECT a.*, a.admit_ts::DATE AS admit_date, a.discharge_ts::DATE AS discharge_date,
       p.mykad, p.dob, p.sex, p.state AS res_state
FROM 'generator/truth/admission.parquet' a JOIN 'generator/truth/patient.parquet' p USING (patient_id)
WHERE year(a.admit_ts) BETWEEN 2018 AND 2020;
CREATE TABLE answer_key AS FROM 'generator/dq_answer_key.parquet';
CREATE TABLE icd AS FROM read_csv('data/open/ref_icd10.csv');
CREATE TABLE truth_adm AS
SELECT *, lag(admission_id) OVER (PARTITION BY patient_id ORDER BY admit_ts) AS prev_id
FROM 'generator/truth/admission.parquet';
-- Admissions whose discharge date no cleaning can know: a placeholder (DT05)
-- or an impossible stay (DT06, flagged in C4).
CREATE TABLE unknown_end AS
SELECT DISTINCT admission_id FROM answer_key
WHERE defect_code IN ('DT05', 'DT06') AND column_name IN ('tarikh_keluar', 'discharge_date', 'discharge_ts');

-- ---------------------------------------------------------- C7 hospital_load
CREATE TABLE load AS FROM 'expected/hospital_load.parquet';

SELECT assert_eq('hospital_load columns and types',
  (SELECT string_agg(column_name || ' ' || column_type, ',') FROM (DESCRIBE load)),
  'state VARCHAR,facility_code VARCHAR,facility_name VARCHAR,facility_type VARCHAR,admissions BIGINT,'
  || 'dengue_admissions BIGINT,bed_days BIGINT,state_share_pct DOUBLE,state_rank BIGINT');

SELECT assert_eq('hospital_load is the 166 hospitals of facility_clean, one row each', count(*), 0)
FROM ((SELECT facility_code, facility_name, state FROM load
       EXCEPT ALL SELECT facility_code, facility_name, state FROM 'expected/facility_clean.parquet')
      UNION ALL
      (SELECT facility_code, facility_name, state FROM 'expected/facility_clean.parquet'
       EXCEPT ALL SELECT facility_code, facility_name, state FROM load));

CREATE TABLE truth_load AS
SELECT facility_code, count(*) AS admissions,
       count(*) FILTER (WHERE principal_dx LIKE 'A97.%') AS dengue_admissions,
       sum(date_diff('day', admit_date, discharge_date)) FILTER (WHERE admission_id NOT IN (FROM unknown_end)) AS bed_days
FROM truth GROUP BY ALL;

SELECT assert_eq('admissions per hospital are the true admissions (AD01, AD02 removed)', count(*), 0)
FROM load LEFT JOIN truth_load t USING (facility_code) WHERE load.admissions <> coalesce(t.admissions, 0);

SELECT assert_eq('dengue admissions count the legacy A90/A91 codes too (DX02)', count(*), 0)
FROM load LEFT JOIN truth_load t USING (facility_code) WHERE load.dengue_admissions <> coalesce(t.dengue_admissions, 0);

SELECT assert_eq('DX02 moves the dengue count of some hospitals', count(*) > 50, true)
FROM (SELECT DISTINCT t.facility_code FROM answer_key k JOIN truth t USING (admission_id) WHERE k.defect_code = 'DX02');

SELECT assert_eq('bed days are the true stay lengths, leaving out stays whose end is unknown (DT05, DT06)', count(*), 0)
FROM load LEFT JOIN truth_load t USING (facility_code) WHERE load.bed_days <> coalesce(t.bed_days, 0);

SELECT assert_eq('state shares add up to 100% in every state, give or take rounding', count(*), 0)
FROM (SELECT state, sum(state_share_pct) AS s, count(*) AS n FROM load GROUP BY ALL) WHERE abs(s - 100) > 0.05 * n;

SELECT assert_eq('state_rank 1 is the busiest hospital of each state, and ranks are rank() (ties share)', count(*), 0)
FROM load l
WHERE state_rank <> 1 + (SELECT count(*) FROM load o WHERE o.state = l.state AND o.admissions > l.admissions);

-- ---------------------------------------------------------------- C8 episode
CREATE TABLE ep AS FROM 'expected/episode.parquet';

SELECT assert_eq('episode columns and types',
  (SELECT string_agg(column_name || ' ' || column_type, ',') FROM (DESCRIBE ep)),
  'patient_key VARCHAR,episode_no INTEGER,state VARCHAR,sex VARCHAR,age BIGINT,episode_start DATE,episode_end DATE,'
  || 'los_days BIGINT,admissions BIGINT,first_facility VARCHAR,last_facility VARCHAR,principal_dx VARCHAR,'
  || 'discharge_status VARCHAR');

SELECT assert_eq('every admission of admission_clean is in exactly one episode', sum(admissions),
                 (SELECT count(*) FROM 'expected/admission_clean.parquet'))
FROM ep;

SELECT assert_eq('episodes are numbered 1, 2, ... per patient, in date order', count(*), 0)
FROM (SELECT episode_no, row_number() OVER (PARTITION BY patient_key ORDER BY episode_start) AS n FROM ep)
WHERE episode_no <> n;

SELECT assert_eq('a patient''s next episode starts more than a day after the last one ends', count(*), 0)
FROM (SELECT episode_end, lead(episode_start) OVER (PARTITION BY patient_key ORDER BY episode_no) AS next_start FROM ep)
WHERE next_start <= episode_end + 1;

SELECT assert_eq('los_days is the episode''s length', count(*), 0)
FROM ep WHERE los_days <> date_diff('day', episode_start, episode_end) OR los_days < 0;

-- The truth's own episodes, by the card's rule, for the patients no defect can
-- move: their IC is never ID03/ID04 and every stay's end is known.
CREATE TABLE moved_patient AS
SELECT DISTINCT patient_id FROM truth
WHERE admission_id IN (FROM unknown_end)
   OR admission_id IN (SELECT admission_id FROM answer_key WHERE defect_code IN ('ID03', 'ID04'));
CREATE TABLE truth_ep AS
WITH m AS (
  SELECT *, coalesce(admit_date > lag(discharge_date) OVER w + 1, true) AS starts
  FROM truth WHERE patient_id NOT IN (FROM moved_patient)
  WINDOW w AS (PARTITION BY patient_id ORDER BY admit_date)
), n AS (
  SELECT *, sum(starts::INTEGER) OVER (PARTITION BY patient_id ORDER BY admit_date) AS episode_no FROM m
)
SELECT mykad AS patient_key, episode_no, min(admit_date) AS episode_start, max(discharge_date) AS episode_end,
       count(*) AS admissions, first(facility_code ORDER BY admit_date) AS first_facility,
       first(facility_code ORDER BY admit_date DESC) AS last_facility,
       first(principal_dx ORDER BY admit_date) AS true_dx,
       first(discharge_status ORDER BY admit_date DESC) AS true_status,
       date_sub('year', any_value(dob), min(admit_date)) AS true_age, any_value(res_state) AS true_state
FROM n GROUP BY ALL;

SELECT assert_eq('for patients no defect moves, the episodes are the truth''s episodes', count(*), 0)
FROM ((SELECT patient_key, episode_no, episode_start, episode_end, admissions, first_facility, last_facility FROM ep
       WHERE patient_key IN (SELECT patient_key FROM truth_ep)
       EXCEPT ALL SELECT patient_key, episode_no, episode_start, episode_end, admissions, first_facility, last_facility FROM truth_ep)
      UNION ALL
      (SELECT patient_key, episode_no, episode_start, episode_end, admissions, first_facility, last_facility FROM truth_ep
       EXCEPT ALL SELECT patient_key, episode_no, episode_start, episode_end, admissions, first_facility, last_facility FROM ep));

SELECT assert_eq('state is the residence state, and age the full years at the start (when the dob is known)', count(*), 0)
FROM ep JOIN truth_ep t USING (patient_key, episode_no)
WHERE ep.state <> t.true_state OR ep.age <> t.true_age;

SELECT assert_eq('principal_dx is the first admission''s (DX02 kept as found)', count(*), 0)
FROM ep JOIN truth_ep t USING (patient_key, episode_no)
WHERE ep.principal_dx <> t.true_dx AND ep.principal_dx NOT IN ('A90', 'A91');

SELECT assert_eq('every transfer (AD03) of an unmoved patient is inside one episode', count(*), 0)
FROM answer_key k
JOIN truth_adm a USING (admission_id) JOIN truth_adm p ON p.admission_id = a.prev_id
JOIN 'generator/truth/patient.parquet' pt ON pt.patient_id = a.patient_id
WHERE k.defect_code = 'AD03' AND a.patient_id NOT IN (FROM moved_patient)
  AND NOT EXISTS (SELECT 1 FROM ep WHERE ep.patient_key = pt.mykad
                  AND ep.episode_start <= p.admit_ts::DATE AND ep.episode_end >= a.admit_ts::DATE);

SELECT assert_eq('transfers make multi-hospital episodes', count(*) > 1000, true)
FROM ep WHERE first_facility <> last_facility;

-- ---------------------------------------------------------- C9 readmit_state
CREATE TABLE readmit AS FROM 'expected/readmit_state.parquet';
-- Each discharge_status as written, and the status it means, from the Answer key (AD04).
CREATE TABLE status_means AS
SELECT DISTINCT dirty_value AS written, clean_value AS status FROM answer_key WHERE defect_code = 'AD04'
UNION SELECT s, s FROM unnest(['DISCHARGED', 'DIED', 'TRANSFERRED', 'AOR']) t(s);
-- Every episode with whether it is a diabetes index episode and whether a new
-- episode follows within 1-30 days, from the expected episodes.
CREATE TABLE ep_follow AS
SELECT e.*, m.status,
       e.principal_dx IN (SELECT icd10 FROM icd WHERE scenario_group = 'diabetes') AND m.status <> 'DIED' AS is_index,
       coalesce(date_diff('day', e.episode_end,
                          lead(e.episode_start) OVER (PARTITION BY e.patient_key ORDER BY e.episode_no)) BETWEEN 1 AND 30,
                false) AS readmitted
FROM ep e JOIN status_means m ON m.written = e.discharge_status;

SELECT assert_eq('readmit_state columns and types',
  (SELECT string_agg(column_name || ' ' || column_type, ',') FROM (DESCRIBE readmit)),
  'state VARCHAR,index_episodes BIGINT,readmissions BIGINT,readmit_pct DOUBLE');

SELECT assert_eq('every episode''s discharge status is a known spelling', count(*), 0)
FROM ep ANTI JOIN status_means m ON m.written = ep.discharge_status;

SELECT assert_eq('readmit_state has the 16 states', count(DISTINCT state) || '/' || count(*), '16/16') FROM readmit;

SELECT assert_eq('index episodes are the diabetes episodes not ending in death, in every spelling (AD04)', count(*), 0)
FROM readmit r
LEFT JOIN (SELECT state, count(*) FILTER (WHERE is_index) AS n, count(*) FILTER (WHERE is_index AND readmitted) AS k
           FROM ep_follow GROUP BY ALL) t USING (state)
WHERE r.index_episodes <> t.n OR r.readmissions <> t.k OR r.readmit_pct <> round(100 * t.k / t.n, 1);

SELECT assert_eq('AD04 hides diabetes deaths behind other spellings', count(*) > 20, true)
FROM ep_follow WHERE status = 'DIED' AND discharge_status <> 'DIED'
  AND principal_dx IN (SELECT icd10 FROM icd WHERE scenario_group = 'diabetes');

SELECT assert_eq('the national rate is the truth''s 15.4%, give or take a point',
  abs(100 * sum(readmissions) / sum(index_episodes) - 15.4) < 1, true)
FROM readmit;

-- The planted effects (truth.sql): older patients and longer stays are
-- readmitted a little more often. The Statistics track and C9 S2 look for them.
SELECT assert_eq('readmission rises with age: <50, 50-64, 65+',
  list(pct ORDER BY band) = list_sort(list(pct ORDER BY band)) AND max(pct) - min(pct) >= 1, true)
FROM (SELECT CASE WHEN age < 50 THEN 1 WHEN age < 65 THEN 2 ELSE 3 END AS band, 100 * avg(readmitted::INTEGER) AS pct
      FROM ep_follow WHERE is_index AND age IS NOT NULL GROUP BY ALL);

SELECT assert_eq('readmission rises with length of stay: 0-2, 3-6, 7+ days',
  list(pct ORDER BY band) = list_sort(list(pct ORDER BY band)) AND max(pct) - min(pct) >= 1, true)
FROM (SELECT CASE WHEN los_days < 3 THEN 1 WHEN los_days < 7 THEN 2 ELSE 3 END AS band, 100 * avg(readmitted::INTEGER) AS pct
      FROM ep_follow WHERE is_index GROUP BY ALL);

-- ------------------------------------------------------------ C10 state_brief
CREATE TABLE brief AS FROM 'expected/state_brief.parquet';
-- DOSM population (thousands) as people, by MoH state name and year.
CREATE TABLE people AS
SELECT replace(upper(state), 'W.P. ', 'WILAYAH PERSEKUTUAN ') AS state, year(date) AS year,
       round(population * 1000) AS people
FROM 'data/open/population_state.parquet'
WHERE year(date) BETWEEN 2018 AND 2020 AND sex = 'both' AND age = 'overall' AND ethnicity = 'overall';
CREATE TABLE dengue_csv AS FROM read_csv('data/open/dengue_state_age_2018_2021.csv');

SELECT assert_eq('state_brief columns and types',
  (SELECT string_agg(column_name || ' ' || column_type, ',') FROM (DESCRIBE brief)),
  'state VARCHAR,diabetes_index_episodes BIGINT,diabetes_readmit_pct DOUBLE,'
  || 'dengue_adm_2018 DOUBLE,dengue_adm_2019 DOUBLE,dengue_adm_2020 DOUBLE,'
  || 'dengue_cases_2018 DOUBLE,dengue_cases_2019 DOUBLE,dengue_cases_2020 DOUBLE,'
  || 'top_hospital VARCHAR,top_hospital_share_pct DOUBLE');

SELECT assert_eq('state_brief has the 16 states', count(DISTINCT state) || '/' || count(*), '16/16') FROM brief;

SELECT assert_eq('the diabetes columns are readmit_state''s', count(*), 0)
FROM brief b JOIN readmit r USING (state)
WHERE b.diabetes_index_episodes <> r.index_episodes OR b.diabetes_readmit_pct <> r.readmit_pct;

SELECT assert_eq('the top hospital is the state''s rank-1 hospital in hospital_load', count(*), 0)
FROM brief b
WHERE (b.top_hospital, b.top_hospital_share_pct) NOT IN
      (SELECT (facility_name, state_share_pct) FROM load WHERE load.state = b.state AND state_rank = 1);

-- Dengue admissions per 100k, from the truth: true dengue (A97.x, which DX02
-- wrote as A90/A91 in places), by residence state and admit year.
CREATE TABLE truth_dengue AS
SELECT p.state, p.year, round(100000 * count(t.admission_id) / p.people, 1) AS rate
FROM people p
LEFT JOIN truth t ON t.res_state = p.state AND year(t.admit_date) = p.year AND t.principal_dx LIKE 'A97.%'
GROUP BY p.state, p.year, p.people;

SELECT assert_eq('dengue admissions per 100k are the true ones, by residence state and year', count(*), 0)
FROM brief b
JOIN (PIVOT truth_dengue ON year IN (2018, 2019, 2020) USING first(rate) GROUP BY state) t USING (state)
WHERE (b.dengue_adm_2018, b.dengue_adm_2019, b.dengue_adm_2020) IS DISTINCT FROM (t."2018", t."2019", t."2020");

-- Notified dengue cases per 100k: the wide CSV's column for the state, summed
-- over its age groups (SH01). Three states, read straight from their columns.
SELECT assert_eq('notified dengue per 100k, Selangor 2018-2020', count(*), 0)
FROM brief b WHERE b.state = 'SELANGOR'
  AND [b.dengue_cases_2018, b.dengue_cases_2019, b.dengue_cases_2020] IS DISTINCT FROM
      (SELECT list(round(100000 * c / p.people, 1) ORDER BY y)
       FROM (SELECT TAHUN AS y, sum(SELANGOR) AS c FROM dengue_csv GROUP BY ALL) d
       JOIN people p ON p.state = 'SELANGOR' AND p.year = d.y);

SELECT assert_eq('notified dengue per 100k, Kuala Lumpur (WP KUALA LUMPUR) 2018-2020', count(*), 0)
FROM brief b WHERE b.state = 'WILAYAH PERSEKUTUAN KUALA LUMPUR'
  AND [b.dengue_cases_2018, b.dengue_cases_2019, b.dengue_cases_2020] IS DISTINCT FROM
      (SELECT list(round(100000 * c / p.people, 1) ORDER BY y)
       FROM (SELECT TAHUN AS y, sum("WP KUALA LUMPUR") AS c FROM dengue_csv GROUP BY ALL) d
       JOIN people p ON p.state = 'WILAYAH PERSEKUTUAN KUALA LUMPUR' AND p.year = d.y);

SELECT assert_eq('notified dengue per 100k, Perlis 2018-2020', count(*), 0)
FROM brief b WHERE b.state = 'PERLIS'
  AND [b.dengue_cases_2018, b.dengue_cases_2019, b.dengue_cases_2020] IS DISTINCT FROM
      (SELECT list(round(100000 * c / p.people, 1) ORDER BY y)
       FROM (SELECT TAHUN AS y, sum(PERLIS) AS c FROM dengue_csv GROUP BY ALL) d
       JOIN people p ON p.state = 'PERLIS' AND p.year = d.y);

SELECT assert_eq('Putrajaya has no column in the dengue CSV, so its notified rates are NULL, and only its',
  (SELECT string_agg(state, ',') FROM brief
   WHERE dengue_cases_2018 IS NULL OR dengue_cases_2019 IS NULL OR dengue_cases_2020 IS NULL),
  'WILAYAH PERSEKUTUAN PUTRAJAYA');
