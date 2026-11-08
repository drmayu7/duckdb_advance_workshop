-- Module 2 (#24): the C4-C6 expected results, which the canonical solutions
-- write (tests/solution_chain.sh proves they are current), checked against the
-- generator's clean truth and the Answer key, so a Self-check never certifies a
-- wrong cleaning.
CREATE TABLE truth AS
SELECT a.admission_id, a.mrn, a.facility_code, a.admit_ts::DATE AS admit_date, a.discharge_ts::DATE AS discharge_date,
       a.principal_dx, p.mykad, p.name, p.dob, p.sex, p.state, p.district
FROM 'generator/truth/admission.parquet' a JOIN 'generator/truth/patient.parquet' p USING (patient_id)
WHERE year(a.admit_ts) BETWEEN 2018 AND 2020;
CREATE TABLE answer_key AS FROM 'generator/dq_answer_key.parquet';
-- The admissions with a defect of this code in this column (as admission_raw names it).
CREATE MACRO hit(code, col) AS TABLE
  SELECT DISTINCT admission_id FROM answer_key k
  WHERE defect_code = code
    AND column_name IN (SELECT unnest(CASE col WHEN 'dob' THEN ['tarikh_lahir', 'dob']
                                               WHEN 'discharge_date' THEN ['tarikh_keluar', 'discharge_date', 'discharge_ts']
                                               WHEN 'mykad' THEN ['no_kp', 'mykad']
                                               WHEN 'name' THEN ['nama', 'name']
                                               WHEN 'district' THEN ['daerah', 'district'] END));

-- ------------------------------------------------------------ C4 admission_typed
CREATE TABLE typed AS
SELECT t.admission_id, x.*
FROM 'expected/admission_typed.parquet' x
LEFT JOIN truth t USING (mrn, facility_code, admit_date);

SELECT assert_eq('admission_typed columns and types',
  (SELECT string_agg(column_name || ' ' || column_type, ',') FROM (DESCRIBE FROM 'expected/admission_typed.parquet')),
  'source_system VARCHAR,mrn VARCHAR,mykad VARCHAR,name VARCHAR,dob DATE,sex VARCHAR,state VARCHAR,district VARCHAR,'
  || 'postcode VARCHAR,address VARCHAR,facility_code VARCHAR,admit_date DATE,discharge_date DATE,los_days BIGINT,'
  || 'date_flag VARCHAR,discharge_status VARCHAR,principal_dx VARCHAR,secondary_dx VARCHAR,updated_at TIMESTAMP,'
  || 'ward VARCHAR,admission_type VARCHAR,file VARCHAR');

SELECT assert_eq('admission_typed keeps every record of the Raw extract', count(*),
                 (SELECT sum(rows) FROM read_csv('data/raw/manifest.csv')))
FROM typed;

SELECT assert_eq('every admit_date is the true admit date (DT01, DT03 parsed)', count(*), 0)
FROM typed WHERE admission_id IS NULL;

SELECT assert_eq('dob is the true dob, or NULL for a placeholder (DT05) or a two-digit year (DT04)', count(*), 0)
FROM typed JOIN truth t USING (admission_id)
WHERE typed.dob IS DISTINCT FROM t.dob
  AND NOT (typed.dob IS NULL AND admission_id IN (FROM hit('DT05', 'dob') UNION ALL FROM hit('DT04', 'dob')));

SELECT assert_eq('a dob read from a two-digit year is NULL, not year 00YY', count(*), 0)
FROM typed WHERE year(dob) < 1900;

SELECT assert_eq('discharge_date is true, NULL for a placeholder (DT05), or left as found (DT06, AD02)', count(*), 0)
FROM typed JOIN truth t USING (admission_id)
WHERE typed.discharge_date IS DISTINCT FROM t.discharge_date
  AND NOT (typed.discharge_date IS NULL AND admission_id IN (FROM hit('DT05', 'discharge_date')))
  AND admission_id NOT IN (FROM hit('DT06', 'discharge_date'))
  AND admission_id NOT IN (SELECT admission_id FROM answer_key WHERE defect_code = 'AD02');

SELECT assert_eq('date_flag marks exactly the DT06 stays', count(*), 0)
FROM typed
WHERE (date_flag IS NOT NULL) <> (admission_id IN (FROM hit('DT06', 'discharge_date'))
                                  AND discharge_date IS DISTINCT FROM (SELECT t.discharge_date FROM truth t WHERE t.admission_id = typed.admission_id));

SELECT assert_eq('date_flag values', string_agg(DISTINCT date_flag, ',' ORDER BY date_flag), 'discharge_before_admit,stay_365_days_or_more')
FROM typed;

SELECT assert_eq('every updated_at is read', count(*), 0) FROM typed WHERE updated_at IS NULL;

SELECT assert_eq('no null spellings are left (NU02)', count(*), 0)
FROM (SELECT unnest([mrn, mykad, name, sex, state, district, postcode, address, facility_code, discharge_status,
                     principal_dx, secondary_dx, ward, admission_type]) AS v FROM typed)
WHERE upper(trim(v)) IN ('NULL', 'N/A', 'NA', '-', 'TIADA', 'TIDAK DIKETAHUI', 'UNKNOWN');

-- ------------------------------------------------------------ C5 facility_clean
CREATE TABLE facility AS FROM 'expected/facility_clean.parquet';
CREATE TABLE moh_hospital AS
SELECT * FROM read_json('data/open/facilities.json') WHERE KATEGORI_FASILITI = 'HOSPITAL';

SELECT assert_eq('facility_clean columns and types',
  (SELECT string_agg(column_name || ' ' || column_type, ',') FROM (DESCRIBE facility)),
  'facility_code VARCHAR,facility_name VARCHAR,facility_type VARCHAR,state VARCHAR,district VARCHAR,'
  || 'postcode VARCHAR,latitude DOUBLE,longitude DOUBLE');

SELECT assert_eq('facility_clean is the 166 MoH hospitals, one row each',
  (SELECT count(*) || ' rows, ' || count(DISTINCT facility_code) || ' codes' FROM facility), '166 rows, 166 codes');

SELECT assert_eq('every facility_clean code is an MoH hospital', count(*), 0)
FROM facility ANTI JOIN moh_hospital ON KOD_FASILITI = facility_code;

SELECT assert_eq('every admission is at a facility_clean hospital', count(*), 0)
FROM truth ANTI JOIN facility USING (facility_code);

SELECT assert_eq('facility names have no line breaks, double spaces or padding', count(*), 0)
FROM facility
WHERE facility_name LIKE '%' || chr(10) || '%' OR facility_name LIKE '%  %' OR facility_name <> trim(facility_name)
   OR district <> trim(district);

SELECT assert_eq('HOSPITAL ENCHE'' BESAR HAJJAH KHALSOM is cleaned', facility_name, 'HOSPITAL ENCHE'' BESAR HAJJAH KHALSOM')
FROM facility WHERE facility_code = '11-01030012';

SELECT assert_eq('facility_clean states are the 16 states the patients live in',
  (SELECT string_agg(DISTINCT state, ',' ORDER BY state) FROM facility),
  (SELECT string_agg(DISTINCT state, ',' ORDER BY state) FROM truth));

-- ------------------------------------------------------------ C6 admission_clean
CREATE TABLE clean AS
SELECT t.admission_id, x.*
FROM 'expected/admission_clean.parquet' x
LEFT JOIN truth t USING (mrn, facility_code, admit_date);

SELECT assert_eq('admission_clean columns and types',
  (SELECT string_agg(column_name || ' ' || column_type, ',') FROM (DESCRIBE FROM 'expected/admission_clean.parquet')),
  'source_system VARCHAR,patient_key VARCHAR,mrn VARCHAR,name VARCHAR,sex VARCHAR,dob DATE,state VARCHAR,'
  || 'district VARCHAR,postcode VARCHAR,facility_code VARCHAR,admit_date DATE,discharge_date DATE,los_days BIGINT,'
  || 'date_flag VARCHAR,discharge_status VARCHAR,principal_dx VARCHAR,secondary_dx VARCHAR,updated_at TIMESTAMP,'
  || 'ward VARCHAR,admission_type VARCHAR,file VARCHAR');

SELECT assert_eq('one admission_clean row per real admission (AD01, AD02 removed)',
  (SELECT count(*) || ' rows, ' || count(DISTINCT admission_id) || ' admissions' FROM clean),
  (SELECT count(*) || ' rows, ' || count(*) || ' admissions' FROM truth));

SELECT assert_eq('one row per patient_key and admit_date', count(*), 0)
FROM (SELECT patient_key, admit_date FROM clean GROUP BY ALL HAVING count(*) > 1);

SELECT assert_eq('patient_key is the true IC (ID01, ID02 fixed), except the ID03/ID04 ICs', count(*), 0)
FROM clean JOIN truth t USING (admission_id)
WHERE clean.patient_key IS DISTINCT FROM t.mykad
  AND admission_id NOT IN (FROM hit('ID03', 'mykad') UNION ALL FROM hit('ID04', 'mykad'));

SELECT assert_eq('every patient_key keeps the 9### serial (ADR 0003)', count(*), 0)
FROM clean WHERE NOT regexp_full_match(patient_key, '\d{6}-\d{2}-9\d{3}');

SELECT assert_eq('state is the true state (GE01, TX01 fixed by norm_state)', count(*), 0)
FROM clean JOIN truth t USING (admission_id) WHERE clean.state IS DISTINCT FROM t.state;

SELECT assert_eq('principal_dx is the true code (DX01 fixed by norm_icd), or a legacy dengue code (DX02, for C7)', count(*), 0)
FROM clean JOIN truth t USING (admission_id)
WHERE clean.principal_dx IS DISTINCT FROM t.principal_dx
  AND NOT (clean.principal_dx IN ('A90', 'A91') AND admission_id IN (SELECT admission_id FROM answer_key WHERE defect_code = 'DX02'));

SELECT assert_eq('district is the true district, or NULL for a null spelling (NU02)', count(*), 0)
FROM clean JOIN truth t USING (admission_id)
WHERE clean.district IS DISTINCT FROM t.district
  AND NOT (clean.district IS NULL AND admission_id IN (FROM hit('NU02', 'district')));

SELECT assert_eq('name is the true name in capitals, unpadded, except the PT01 spellings', count(*), 0)
FROM clean JOIN truth t USING (admission_id)
WHERE clean.name IS DISTINCT FROM t.name AND admission_id NOT IN (FROM hit('PT01', 'name'));

SELECT assert_eq('the latest version is kept: discharge_date is true, NULL (DT05) or flagged (DT06)', count(*), 0)
FROM clean JOIN truth t USING (admission_id)
WHERE clean.discharge_date IS DISTINCT FROM t.discharge_date
  AND NOT (clean.discharge_date IS NULL AND admission_id IN (FROM hit('DT05', 'discharge_date')))
  AND NOT (clean.date_flag IS NOT NULL AND admission_id IN (FROM hit('DT06', 'discharge_date')));

SELECT assert_eq('PT01: some patients appear under more than one name', count(*) > 100, true)
FROM (SELECT patient_key FROM clean GROUP BY ALL HAVING count(DISTINCT name) > 1);

-- C6 Stretch: the MyKad checks (date part, sex parity) flag exactly the ID03
-- and ID04 ICs, and none of the real 9### ones (ADR 0003).
SELECT assert_eq('the IC date check flags exactly the ID03 ICs', count(*), 0)
FROM ((SELECT DISTINCT patient_key FROM clean
       WHERE try_strptime(patient_key[1:6], '%y%m%d') IS NULL OR patient_key[1:6] <> strftime(dob, '%y%m%d')
       EXCEPT SELECT DISTINCT dirty_value FROM answer_key WHERE defect_code = 'ID03')
      UNION ALL
      (SELECT DISTINCT dirty_value FROM answer_key WHERE defect_code = 'ID03'
       EXCEPT SELECT DISTINCT patient_key FROM clean));

SELECT assert_eq('the IC sex-parity check flags exactly the ID04 ICs', count(*), 0)
FROM ((SELECT DISTINCT patient_key FROM clean WHERE (patient_key[-1:]::INTEGER % 2 = 1) <> (sex = 'M')
       EXCEPT SELECT DISTINCT dirty_value FROM answer_key WHERE defect_code = 'ID04')
      UNION ALL
      (SELECT DISTINCT dirty_value FROM answer_key WHERE defect_code = 'ID04'
       EXCEPT SELECT DISTINCT patient_key FROM clean));
