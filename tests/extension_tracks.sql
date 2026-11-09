-- Extension tracks (#30): each track's expected result, which its canonical
-- solution writes (tests/solution_chain.sh proves it is current and runs it
-- from the C1-C10 Checkpoints alone), checked against facts found outside the
-- solution: R's own numbers, hospitals matched by eye, and the generator's truth.

-- ------------------------------------------------------------ t-stats readmit_ci
CREATE TABLE ci AS FROM 'expected/readmit_ci.parquet';

SELECT assert_eq('readmit_ci columns and types',
  (SELECT string_agg(column_name || ' ' || column_type, ',') FROM (DESCRIBE ci)),
  'state VARCHAR,index_episodes BIGINT,readmissions BIGINT,readmit_pct DOUBLE,ci_low_pct DOUBLE,ci_high_pct DOUBLE');

SELECT assert_eq('readmit_ci is readmit_state with two columns added', count(*), 0)
FROM ((SELECT state, index_episodes, readmissions, readmit_pct FROM ci
       EXCEPT ALL FROM 'expected/readmit_state.parquet')
      UNION ALL
      (FROM 'expected/readmit_state.parquet'
       EXCEPT ALL SELECT state, index_episodes, readmissions, readmit_pct FROM ci));

-- R 4.x, prop.test(x, n, correct = FALSE)$conf.int, x 100, rounded to 1 decimal.
SELECT assert_eq('Selangor 533/3378: the CI is R''s prop.test, 14.6 to 17.0',
  (SELECT [ci_low_pct, ci_high_pct] FROM ci WHERE state = 'SELANGOR'), [14.6, 17.0]);
SELECT assert_eq('Perlis 13/115: the CI is R''s prop.test, 6.7 to 18.4',
  (SELECT [ci_low_pct, ci_high_pct] FROM ci WHERE state = 'PERLIS'), [6.7, 18.4]);
SELECT assert_eq('Putrajaya 10/49: the CI is R''s prop.test, 11.5 to 33.6',
  (SELECT [ci_low_pct, ci_high_pct] FROM ci WHERE state = 'WILAYAH PERSEKUTUAN PUTRAJAYA'), [11.5, 33.6]);

SELECT assert_eq('every CI holds its own rate', count(*), 0)
FROM ci WHERE NOT readmit_pct BETWEEN ci_low_pct AND ci_high_pct;

-- The card's LOS answer: diabetes episodes stay about 1.1 days longer than dengue.
SELECT assert_eq('diabetes episodes stay 1.1 days longer than dengue ones, on average',
  round(avg(los_days) FILTER (WHERE scenario_group = 'diabetes')
        - avg(los_days) FILTER (WHERE scenario_group = 'dengue'), 1), 1.1)
FROM 'expected/episode.parquet' e JOIN read_csv('data/open/ref_icd10.csv') i ON i.icd10 = e.principal_dx;
SELECT assert_eq('the t-stats card states that difference and its CI',
  contains(content, '**1.1 days**') AND contains(content, '1.0 to 1.2'), true)
FROM read_text('cards/t-stats-intervals.md');

-- -------------------------------------------------------- t-names bed_facility
CREATE TABLE bf AS FROM 'expected/bed_facility.parquet';
CREATE TABLE bu AS FROM read_csv('data/open/bed_utilisation.csv');

SELECT assert_eq('bed_facility columns and types',
  (SELECT string_agg(column_name || ' ' || column_type, ',') FROM (DESCRIBE bf)),
  'hospital VARCHAR,state VARCHAR,facility_code VARCHAR,match_type VARCHAR,similarity DOUBLE');

SELECT assert_eq('bed_facility has one row per bed utilisation hospital (149)',
  (SELECT count(*) FROM bf SEMI JOIN bu USING (hospital)), 149)
FROM bf HAVING count(*) = 149;

SELECT assert_eq('143 exact, 2 fuzzy, 4 with no match',
  (SELECT string_agg(match_type || ' ' || n, ', ' ORDER BY match_type) FROM (SELECT match_type, count(*) AS n FROM bf GROUP BY ALL)),
  'exact 143, fuzzy 2, none 4');

SELECT assert_eq('every name that equals a facility_clean name once upper-cased gets that hospital''s code', count(*), 0)
FROM bf JOIN 'expected/facility_clean.parquet' f ON f.facility_name = upper(bf.hospital)
WHERE bf.facility_code IS DISTINCT FROM f.facility_code;

-- Checked by eye against the MoH facility list.
SELECT assert_eq(hospital || ' -> ' || want, facility_code || ' ' || match_type, want)
FROM bf JOIN (VALUES
  ('Hospital Sultanah Aminah', '11-01020010 exact'),        -- "..., JOHOR BAHRU", not Sultanah Nora Ismail
  ('Hospital  Raja Permaisuri Bainun', '11-08050011 exact'), -- double space
  ('Hospital Wanita Dan Kanak-Kanak', '11-12060045 fuzzy'),  -- "KANAK - KANAK SABAH"
  ('Hospital Sungai Buloh', '11-10010019 fuzzy')             -- "SUNGAI BULUH"
) w(hospital, want) USING (hospital);
SELECT assert_eq(hospital || ' has no match', facility_code IS NULL AND match_type = 'none', true)
FROM bf WHERE hospital IN ('Hospital Serdang', 'Hospital Universiti Kebangsaan Malaysia', 'Hospital Changkat Melintang', 'Hospital Kajang');

SELECT assert_eq('no hospital code is matched twice', count(*), 0)
FROM (SELECT facility_code FROM bf WHERE facility_code IS NOT NULL GROUP BY ALL HAVING count(*) > 1);
SELECT assert_eq('every match is a hospital in the same state', count(*), 0)
FROM bf JOIN 'expected/facility_clean.parquet' f USING (facility_code) WHERE f.state <> bf.state;

-- ------------------------------------------------------ t-spatial dengue_district
LOAD spatial;
CREATE TABLE dd AS FROM 'expected/dengue_district.parquet';
CREATE TABLE geo AS SELECT state AS geo_state, district FROM ST_Read('data/open/geo_district.geojson');

SELECT assert_eq('dengue_district columns and types',
  (SELECT string_agg(column_name || ' ' || column_type, ',') FROM (DESCRIBE dd)),
  'state VARCHAR,district VARCHAR,people BIGINT,dengue_admissions BIGINT,adm_per_100k DOUBLE');

SELECT assert_eq('dengue_district is the 160 DOSM districts, each with its polygon', count(*), 160)
FROM dd JOIN geo USING (district) HAVING count(*) = (SELECT count(*) FROM dd);

-- The truth: true 2018-2020 dengue admissions by the patient's health district,
-- leaving out those whose district the extract lost (NU02, NULL in admission_clean).
CREATE TABLE truth_dengue AS
SELECT p.state, p.district, count(*) AS n
FROM 'generator/truth/admission.parquet' a JOIN 'generator/truth/patient.parquet' p USING (patient_id)
WHERE year(a.admit_ts) BETWEEN 2018 AND 2020 AND a.principal_dx LIKE 'A97.%'
  AND a.admission_id NOT IN (SELECT admission_id FROM 'generator/dq_answer_key.parquet'
                             WHERE defect_code = 'NU02' AND column_name IN ('daerah', 'district'))
GROUP BY ALL;

SELECT assert_eq('every dengue admission with a known district lands in one DOSM district, state by state', count(*), 0)
FROM (SELECT state, sum(n) AS n FROM truth_dengue GROUP BY ALL) t
FULL JOIN (SELECT state, sum(dengue_admissions) AS n FROM dd GROUP BY ALL) d USING (state)
WHERE t.n IS DISTINCT FROM d.n;

-- GE02, the health districts DOSM names otherwise. Some districts come in both
-- spellings (HULU LANGAT and ULU LANGAT, KANGAR and PERLIS): both count.
SELECT assert_eq('GE02: ' || d.district || ' takes ' || array_to_string(w.health, ' + '),
  d.dengue_admissions, (SELECT sum(n) FROM truth_dengue t WHERE t.state = w.state AND list_contains(w.health, t.district)))
FROM dd d JOIN (VALUES
  ('W.P. Kuala Lumpur', 'WILAYAH PERSEKUTUAN KUALA LUMPUR', ['CHERAS', 'KEPONG', 'LEMBAH PANTAI', 'TITIWANGSA']),
  ('Ulu Langat', 'SELANGOR', ['HULU LANGAT', 'ULU LANGAT']),
  ('Ulu Selangor', 'SELANGOR', ['HULU SELANGOR', 'ULU SELANGOR']),
  ('Maradong', 'SARAWAK', ['MARADONG', 'MERADONG']),
  ('Perlis', 'PERLIS', ['KANGAR', 'PERLIS']),
  ('W.P. Labuan', 'WILAYAH PERSEKUTUAN LABUAN', ['LABUAN']),
  ('W.P. Putrajaya', 'WILAYAH PERSEKUTUAN PUTRAJAYA', ['PUTRAJAYA'])
) w(district, state, health) USING (district);

SELECT assert_eq('any other district keeps the admissions of the health district of the same name', count(*), 0)
FROM truth_dengue t JOIN dd d ON d.state = t.state AND upper(d.district) = t.district
WHERE d.district NOT IN ('W.P. Kuala Lumpur', 'Ulu Langat', 'Ulu Selangor', 'Maradong', 'Perlis', 'W.P. Labuan', 'W.P. Putrajaya')
  AND d.dengue_admissions <> t.n;

SELECT assert_eq('people is the DOSM 2020 district population', count(*), 0)
FROM dd JOIN 'data/open/population_district.parquet' p USING (district)
WHERE p.date = DATE '2020-01-01' AND p.sex = 'both' AND p.age = 'overall' AND p.ethnicity = 'overall'
  AND dd.people <> round(p.population * 1000);

-- Worked by hand: 66 + 74 = 140 admissions over 3 years, 1,400,500 people: 140 / 3 / 1400500 x 100000 = 3.33.
SELECT assert_eq('Ulu Langat: 140 admissions, 1,400,500 people, 3.3 per 100k per year',
  [dengue_admissions, people, adm_per_100k], [140, 1400500, 3.3])
FROM dd WHERE district = 'Ulu Langat';
