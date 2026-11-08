-- Invariants of the generator's clean truth (#16, #21, ADR 0003), on the committed
-- generator/truth/ files (tests/generator_determinism.sh proves they are current).
CREATE VIEW patient AS FROM 'generator/truth/patient.parquet';
CREATE VIEW admission AS FROM 'generator/truth/admission.parquet';

-- Window orderings need a total tie-break: no patient is admitted twice on one day.
SELECT assert_eq('no same-day admissions per patient', count(*), 0)
FROM (SELECT patient_id, admit_ts::DATE FROM admission GROUP BY ALL HAVING count(*) > 1);

SELECT assert_eq('no overlapping stays per patient', count(*), 0)
FROM (SELECT discharge_ts, lead(admit_ts) OVER (PARTITION BY patient_id ORDER BY admit_ts) AS next_admit
      FROM admission)
WHERE next_admit < discharge_ts;

SELECT assert_eq('discharge never before admit', count(*), 0)
FROM admission WHERE discharge_ts < admit_ts;

-- admission_id order is admit_ts order.
SELECT assert_eq('admission_id increases with admit_ts', count(*), 0)
FROM (SELECT admit_ts, lag(admit_ts) OVER (ORDER BY admission_id) AS prev_ts FROM admission)
WHERE admit_ts < prev_ts;

SELECT assert_eq('admission_id is unique', count(DISTINCT admission_id), count(*)) FROM admission;

SELECT assert_eq('every admission has a known patient', count(*), 0)
FROM admission a ANTI JOIN patient p USING (patient_id);

SELECT assert_eq('no admission before birth', count(*), 0)
FROM admission JOIN patient USING (patient_id) WHERE admit_ts::DATE < dob;

SELECT assert_eq('admissions are 2017-2021', count(*), 0)
FROM admission WHERE year(admit_ts) NOT BETWEEN 2017 AND 2021;

SELECT assert_eq('a death is the patient''s last admission', count(*), 0)
FROM (SELECT discharge_status, lead(admission_id) OVER (PARTITION BY patient_id ORDER BY admit_ts) AS next_id
      FROM admission)
WHERE discharge_status = 'DIED' AND next_id IS NOT NULL;

-- Synthetic ICs: YYMMDD-PB-9##G (ADR 0003).
SELECT assert_eq('IC is YYMMDD-PB-9##G', count(*), 0)
FROM patient WHERE NOT regexp_full_match(mykad, '[0-9]{6}-[0-9]{2}-9[0-9]{3}');

SELECT assert_eq('IC date part is the patient''s dob', count(*), 0)
FROM patient WHERE mykad[1:6] <> strftime(dob, '%y%m%d');

-- JPN state place-of-birth codes (docs/research/myhdw-like-data-sources.md section 4).
SELECT assert_eq('IC place-of-birth code is a JPN state code', count(*), 0)
FROM patient
WHERE mykad[8:9] NOT IN ('01', '21', '22', '23', '24', '02', '25', '26', '27', '03', '28', '29',
                         '04', '30', '05', '31', '59', '06', '32', '33', '07', '34', '35',
                         '08', '36', '37', '38', '39', '09', '40', '10', '41', '42', '43', '44',
                         '11', '45', '46', '12', '47', '48', '49', '13', '50', '51', '52', '53',
                         '14', '54', '55', '56', '57', '15', '58', '16');

SELECT assert_eq('IC last digit is odd for males, even for females', count(*), 0)
FROM patient WHERE (mykad[14]::INTEGER % 2 = 1) <> (sex = 'M');

SELECT assert_eq('IC is unique per patient', count(DISTINCT mykad), count(*)) FROM patient;

-- Residence uses the 16 MoH state names and the facility list's health districts.
SELECT assert_eq('16 residence states, all MoH hospital state names', count(DISTINCT state), 16)
FROM patient
WHERE state IN (SELECT NEGERI FROM read_json('data/open/facilities.json') WHERE KATEGORI_FASILITI = 'HOSPITAL');

SELECT assert_eq('residence district is a health district in the facility list', count(*), 0)
FROM patient
WHERE district NOT IN (SELECT trim(DAERAH) FROM read_json('data/open/facilities.json'));

-- ...and in the patient's own state (the list files KL and Putrajaya districts
-- under the merged pseudo-state too).
SELECT assert_eq('residence district is a health district of the residence state', count(*), 0)
FROM patient p
ANTI JOIN read_json('data/open/facilities.json') f
  ON trim(f.DAERAH) = p.district
 AND (f.NEGERI = p.state
      OR (f.NEGERI = 'WILAYAH PERSEKUTUAN KUALA LUMPUR DAN PUTRAJAYA'
          AND p.state IN ('WILAYAH PERSEKUTUAN KUALA LUMPUR', 'WILAYAH PERSEKUTUAN PUTRAJAYA')));

SELECT assert_eq('dob is a plausible birth date (1920 to before 2017)', count(*), 0)
FROM patient WHERE dob NOT BETWEEN DATE '1920-01-01' AND DATE '2016-12-31';

SELECT assert_eq('postcode is 5 digits', count(*), 0)
FROM patient WHERE NOT regexp_full_match(postcode, '[0-9]{5}');

-- Every admission is at one of the 166 MoH hospitals, in the patient's state.
SELECT assert_eq('admitted to a hospital in the residence state', count(*), 0)
FROM admission a JOIN patient p USING (patient_id)
ANTI JOIN read_json('data/open/facilities.json') f
  ON f.KOD_FASILITI = a.facility_code AND f.KATEGORI_FASILITI = 'HOSPITAL' AND f.NEGERI = p.state;

SELECT assert_eq('diagnoses are ref_icd10 codes', count(*), 0)
FROM (SELECT principal_dx AS dx FROM admission UNION ALL SELECT unnest(secondary_dx) FROM admission)
WHERE dx NOT IN (SELECT icd10 FROM 'data/open/ref_icd10.csv');

-- Sizes (#16): ~5k for 2017, ~75k for 2018-2020, ~25k for 2021.
SELECT assert_eq('2017 admissions about 5k', count(*) BETWEEN 4000 AND 6500, true)
FROM admission WHERE year(admit_ts) = 2017;
SELECT assert_eq('2018-2020 admissions about 75k', count(*) BETWEEN 65000 AND 85000, true)
FROM admission WHERE year(admit_ts) BETWEEN 2018 AND 2020;
SELECT assert_eq('2021 admissions about 25k', count(*) BETWEEN 20000 AND 32000, true)
FROM admission WHERE year(admit_ts) = 2021;
