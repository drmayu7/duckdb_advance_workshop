-- The clean 2017 Warm-up extract (#7, #21): data/warmup/patient_2017.parquet and
-- admission_2017.parquet, with the hospital's name and state flattened in.
CREATE VIEW a17 AS FROM 'data/warmup/admission_2017.parquet';
CREATE VIEW p17 AS FROM 'data/warmup/patient_2017.parquet';
CREATE VIEW hospital AS
  FROM read_json('data/open/facilities.json') WHERE KATEGORI_FASILITI = 'HOSPITAL';

SELECT assert_eq('admission_2017 columns',
  (SELECT string_agg(column_name, ',' ORDER BY column_index) FROM duckdb_columns() WHERE table_name = 'a17'),
  'admission_id,patient_id,facility_code,facility_name,facility_state,admit_date,discharge_date,principal_dx,discharge_status');

SELECT assert_eq('patient_2017 columns',
  (SELECT string_agg(column_name, ',' ORDER BY column_index) FROM duckdb_columns() WHERE table_name = 'p17'),
  'patient_id,mykad,name,sex,dob,state,district,postcode');

SELECT assert_eq('about 5k admissions', count(*) BETWEEN 4000 AND 6500, true) FROM a17;

SELECT assert_eq('every admission is admitted in 2017', count(*), 0)
FROM a17 WHERE year(admit_date) <> 2017;

SELECT assert_eq('it is every 2017 admission of the truth', count(*),
                 (SELECT count(*) FROM 'generator/truth/admission.parquet' WHERE year(admit_ts) = 2017))
FROM a17;

SELECT assert_eq('patient_2017 is exactly the patients admitted in 2017', count(*), 0)
FROM ((SELECT DISTINCT patient_id FROM a17 EXCEPT SELECT patient_id FROM p17)
      UNION ALL (SELECT patient_id FROM p17 EXCEPT SELECT patient_id FROM a17));

SELECT assert_eq('one row per patient', count(DISTINCT patient_id), count(*)) FROM p17;

SELECT assert_eq('facility_state is the hospital''s state', count(*), 0)
FROM a17 ANTI JOIN hospital h ON h.KOD_FASILITI = a17.facility_code AND h.NEGERI = a17.facility_state;

SELECT assert_eq('16 hospital states', count(DISTINCT facility_state), 16) FROM a17;

SELECT assert_eq('facility_name is the hospital''s name, single-spaced on one line', count(*), 0)
FROM a17 ANTI JOIN hospital h
  ON h.KOD_FASILITI = a17.facility_code
 AND a17.facility_name = trim(regexp_replace(h.NAMA, '\s+', ' ', 'g'));

SELECT assert_eq('no newlines or edge spaces in facility names', count(*), 0)
FROM a17 WHERE contains(facility_name, chr(10)) OR contains(facility_name, '  ') OR facility_name <> trim(facility_name);

SELECT assert_eq('no NULLs in the clean extract', count(*), 0)
FROM a17 WHERE admission_id IS NULL OR patient_id IS NULL OR facility_code IS NULL
            OR facility_name IS NULL OR facility_state IS NULL OR admit_date IS NULL
            OR discharge_date IS NULL OR principal_dx IS NULL OR discharge_status IS NULL;
