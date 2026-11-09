-- The Answer key (#7, #23, #31) on the committed generator/dq_answer_key.parquet,
-- data/raw/ and data/capstone/ (tests/generator_determinism.sh proves they are
-- current): every row points at a real place in a Raw extract, the 2018–2020
-- extract carries exactly the taught defects, and the 2021 Capstone extract
-- exactly the three Held-back defects.
CREATE TABLE answer_key AS FROM 'generator/dq_answer_key.parquet';

-- Every cell of the Raw extract as text: (file, row_no, column_name, value).
-- row_no counts records from 1 in file order, after any header.
CREATE TABLE csv_2018 AS
FROM read_csv('data/raw/2018-*.csv', header = true, all_varchar = true, strict_mode = false, filename = true);
CREATE TABLE json_2019 AS SELECT COLUMNS(*)::VARCHAR FROM read_json('data/raw/2019-*.json', filename = true);
CREATE TABLE r18 AS SELECT *, row_number() OVER (PARTITION BY filename ORDER BY rowid) AS row_no FROM csv_2018;
CREATE TABLE r19 AS SELECT *, row_number() OVER (PARTITION BY filename ORDER BY rowid) AS row_no FROM json_2019;
CREATE TABLE r20 AS
SELECT COLUMNS(* EXCLUDE (file_row_number))::VARCHAR, file_row_number + 1 AS row_no
FROM read_parquet('data/raw/2020-*.parquet', filename = true, file_row_number = true);
-- The 2021 Capstone extract: Sabah's old HIS CSVs and the new system's Parquet.
CREATE TABLE csv_2021 AS
FROM read_csv('data/capstone/2021-*-sabah.csv', header = true, all_varchar = true, filename = true);
CREATE TABLE r21c AS SELECT *, row_number() OVER (PARTITION BY filename ORDER BY rowid) AS row_no FROM csv_2021;
CREATE TABLE r21p AS
SELECT COLUMNS(* EXCLUDE (file_row_number))::VARCHAR, file_row_number + 1 AS row_no
FROM read_parquet('data/capstone/2021-*.parquet', filename = true, file_row_number = true);
-- UNPIVOT drops NULL cells, so NULL travels as chr(0) and comes back afterwards.
CREATE MACRO keep_nulls(t) AS TABLE
  SELECT filename, row_no, coalesce(COLUMNS(* EXCLUDE (filename, row_no)), chr(0)) FROM query_table(t);
CREATE TABLE u18 AS FROM keep_nulls('r18');
CREATE TABLE u19 AS FROM keep_nulls('r19');
CREATE TABLE u20 AS FROM keep_nulls('r20');
CREATE TABLE u21c AS FROM keep_nulls('r21c');
CREATE TABLE u21p AS FROM keep_nulls('r21p');
CREATE TABLE cells AS
SELECT filename, row_no, column_name, nullif(value, chr(0)) AS value
FROM (UNPIVOT u18 ON COLUMNS(* EXCLUDE (filename, row_no)) INTO NAME column_name VALUE value
      UNION ALL
      UNPIVOT u19 ON COLUMNS(* EXCLUDE (filename, row_no)) INTO NAME column_name VALUE value
      UNION ALL
      UNPIVOT u20 ON COLUMNS(* EXCLUDE (filename, row_no)) INTO NAME column_name VALUE value
      UNION ALL
      UNPIVOT u21c ON COLUMNS(* EXCLUDE (filename, row_no)) INTO NAME column_name VALUE value
      UNION ALL
      UNPIVOT u21p ON COLUMNS(* EXCLUDE (filename, row_no)) INTO NAME column_name VALUE value);

-- Every file's columns with their types: text for CSV and JSON, typed in Parquet.
CREATE TABLE file_columns AS
SELECT DISTINCT c.filename AS file, c.column_name, coalesce(d.column_type, 'VARCHAR') AS column_type
FROM cells c
LEFT JOIN (DESCRIBE FROM 'data/raw/2020-*.parquet') d
  ON c.filename LIKE '%.parquet' AND d.column_name = c.column_name;

SELECT assert_eq('Answer key columns',
  (SELECT string_agg(column_name || ' ' || column_type, ',') FROM (DESCRIBE answer_key)),
  'file VARCHAR,row_no BIGINT,column_name VARCHAR,defect_code VARCHAR,dirty_value VARCHAR,clean_value VARCHAR,admission_id BIGINT');

SELECT assert_eq('every cell defect points at a real file, record and column', count(*), 0)
FROM answer_key k ANTI JOIN cells c
  ON c.filename = k.file AND c.row_no = k.row_no AND c.column_name = k.column_name
WHERE k.row_no IS NOT NULL AND k.column_name IS NOT NULL;

-- AD01, AD02 and AD03 are about a whole record: it has no column, and no clean
-- value (a correct cleaning drops AD01/AD02 and merges AD03 into its episode).
SELECT assert_eq('only AD01, AD02 and AD03 are whole-record defects', count(*), 0)
FROM answer_key WHERE row_no IS NOT NULL AND (column_name IS NULL) <> (defect_code IN ('AD01', 'AD02', 'AD03'));

SELECT assert_eq('every record defect points at a real record and has no clean value', count(*), 0)
FROM answer_key k
WHERE k.defect_code IN ('AD01', 'AD02', 'AD03')
  AND (k.clean_value IS NOT NULL
       OR NOT EXISTS (SELECT 1 FROM cells c WHERE c.filename = k.file AND c.row_no = k.row_no));

-- AD01: the record is an exact copy of another record of its file, which its dirty_value names.
SELECT assert_eq('every AD01 record is an exact copy of the record it names', count(*), 0)
FROM answer_key k
WHERE k.defect_code = 'AD01'
  AND (SELECT list(value ORDER BY column_name) FROM cells c WHERE c.filename = k.file AND c.row_no = k.row_no)
      IS DISTINCT FROM
      (SELECT list(value ORDER BY column_name) FROM cells c
       WHERE c.filename = k.file AND c.row_no = regexp_extract(k.dirty_value, '(\d+)$', 1)::BIGINT);

SELECT assert_eq('the value in the file at each cell defect is its dirty_value', count(*), 0)
FROM answer_key k JOIN cells c
  ON c.filename = k.file AND c.row_no = k.row_no AND c.column_name = k.column_name
WHERE c.value IS DISTINCT FROM k.dirty_value AND k.column_name IS NOT NULL;

SELECT assert_eq('a cell carries at most one defect', count(*), 0)
FROM (SELECT file, row_no, column_name FROM answer_key WHERE row_no IS NOT NULL GROUP BY ALL HAVING count(*) > 1);

SELECT assert_eq('a dirty value differs from its clean value', count(*), 0)
FROM answer_key WHERE dirty_value IS NOT DISTINCT FROM clean_value;

SELECT assert_eq('every cell defect names its admission in the clean truth', count(*), 0)
FROM answer_key k ANTI JOIN 'generator/truth/admission.parquet' a USING (admission_id)
WHERE k.row_no IS NOT NULL;

-- SD01 is about a whole file: its column as the file has it ("name TYPE"),
-- and the column it becomes in admission_raw.
SELECT assert_eq('every SD01 row names a column, with its type, that its file has', count(*), 0)
FROM answer_key k ANTI JOIN file_columns f
  ON f.file = k.file AND f.column_name || ' ' || f.column_type = k.dirty_value AND f.column_name = k.column_name
WHERE k.defect_code = 'SD01';

SELECT assert_eq('only SD01 and SH01 rows are whole-file defects', count(*), 0)
FROM answer_key WHERE (row_no IS NULL) <> (defect_code IN ('SD01', 'SH01'));

-- The defects decided for 2018–2020 (#23, #24, #29).
SELECT assert_eq('2018-2020 defect codes', string_agg(DISTINCT defect_code, ',' ORDER BY defect_code),
                 'AD01,AD02,AD03,AD04,DT01,DT03,DT04,DT05,DT06,DX01,DX02,GE01,GE03,GE04,ID01,ID02,ID03,ID04,NU02,PT01,SD01,TX01')
FROM answer_key WHERE file LIKE 'data/raw/20%';

SELECT assert_eq('C1 defects (GE04, ID02, GE03) are in the old HIS CSVs only', count(*), 0)
FROM answer_key WHERE defect_code IN ('GE04', 'ID02', 'GE03') AND file NOT LIKE '%.csv';

SELECT assert_eq('NU02, TX01 and DT05 are in all three source systems', count(*), 9)
FROM (SELECT DISTINCT defect_code, regexp_extract(file, '\.(\w+)$', 1) FROM answer_key
      WHERE defect_code IN ('NU02', 'TX01', 'DT05'));

SELECT assert_eq('every 2018 file breaks a plain read (GE04 unescaped quotes)', count(*), 12)
FROM (SELECT DISTINCT file FROM answer_key WHERE defect_code = 'GE04' AND dirty_value LIKE '%"%');

SELECT assert_eq('DT01, DT03 and DT04 are in the text-date systems only (CSV, JSON)', count(*), 0)
FROM answer_key WHERE defect_code IN ('DT01', 'DT03', 'DT04') AND file LIKE '%.parquet';

SELECT assert_eq('DT04 (two-digit years) is in old HIS birth dates only', count(*), 0)
FROM answer_key WHERE defect_code = 'DT04' AND NOT (file LIKE '%.csv' AND column_name = 'tarikh_lahir');

SELECT assert_eq('DT06, GE01, DX01, ID01, ID03, ID04, PT01, AD01, AD02 are in all three source systems', count(*), 27)
FROM (SELECT DISTINCT defect_code, regexp_extract(file, '\.(\w+)$', 1) FROM answer_key
      WHERE defect_code IN ('DT06', 'GE01', 'DX01', 'ID01', 'ID03', 'ID04', 'PT01', 'AD01', 'AD02'));

-- ADR 0003: an IC defect never makes another patient's IC, and keeps the 9### serial.
SELECT assert_eq('no ID03/ID04 dirty IC is a real patient''s IC', count(*), 0)
FROM answer_key k JOIN 'generator/truth/patient.parquet' p ON p.mykad = k.dirty_value
WHERE k.defect_code IN ('ID03', 'ID04');

SELECT assert_eq('ID01, ID03, ID04 dirty ICs keep the 9### serial', count(*), 0)
FROM answer_key WHERE defect_code IN ('ID01', 'ID03', 'ID04')
  AND NOT regexp_full_match(regexp_replace(dirty_value, '[^0-9]', '', 'g'), '\d{8}9\d{3}');

-- ------------------------------------------------------- Module 3 (#29)
-- DX02 (C7): legacy dengue codes, A90 for A97.0/A97.9 and A91 for A97.1/A97.2,
-- in all three systems and most in the old HIS. The clean value is the true code.
SELECT assert_eq('DX02 writes A90 or A91 for the true A97.x code', count(*), 0)
FROM answer_key WHERE defect_code = 'DX02'
  AND NOT ((dirty_value = 'A90' AND clean_value IN ('A97.0', 'A97.9'))
           OR (dirty_value = 'A91' AND clean_value IN ('A97.1', 'A97.2')));

SELECT assert_eq('DX02 is in all three systems, most in the old HIS',
  (SELECT count(DISTINCT regexp_extract(file, '\.(\w+)$', 1)) FROM answer_key WHERE defect_code = 'DX02') = 3
  AND (SELECT count(*) FROM answer_key WHERE defect_code = 'DX02' AND file LIKE '%.csv')
      > (SELECT count(*) FROM answer_key WHERE defect_code = 'DX02' AND file LIKE '%.parquet'), true);

SELECT assert_eq('DX02 is on the principal diagnosis', count(*), 0)
FROM answer_key WHERE defect_code = 'DX02' AND column_name NOT IN ('dx_utama', 'principal_dx');

-- AD03 (C8): a transfer is two admission records, the second starting the day
-- the first ends at another hospital. The Answer key names the receiving record
-- and, in its dirty_value, the record it continues.
CREATE TABLE truth_adm AS
SELECT *, lag(admission_id) OVER (PARTITION BY patient_id ORDER BY admit_ts) AS prev_id
FROM 'generator/truth/admission.parquet';

SELECT assert_eq('every AD03 record is a truth transfer whose previous admission is in the extract', count(*), 0)
FROM answer_key k JOIN truth_adm a USING (admission_id)
WHERE k.defect_code = 'AD03' AND (a.admission_type <> 'TRANSFER' OR year(a.admit_ts) NOT BETWEEN 2018 AND 2020);

SELECT assert_eq('every 2018-2020 transfer with both stays in the extract is an AD03 record',
  (SELECT count(*) FROM answer_key WHERE defect_code = 'AD03'),
  (SELECT count(*) FROM truth_adm a JOIN truth_adm p ON p.admission_id = a.prev_id
   WHERE a.admission_type = 'TRANSFER' AND year(p.admit_ts) >= 2018 AND year(a.admit_ts) <= 2020));

SELECT assert_eq('every AD03 dirty_value names the record of the stay it continues', count(*), 0)
FROM (SELECT k.*, p.mrn AS prev_mrn, p.facility_code AS prev_facility,
             regexp_extract(k.dirty_value, '^continues the stay in record (\d+) of (\S+)$', ['n', 'f']) AS ref
      FROM answer_key k JOIN truth_adm a USING (admission_id) JOIN truth_adm p ON p.admission_id = a.prev_id
      WHERE k.defect_code = 'AD03') k
WHERE (SELECT list(value ORDER BY column_name) FROM cells c
       WHERE c.filename = k.ref.f AND c.row_no = k.ref.n::BIGINT
         AND c.column_name IN ('no_mrn', 'mrn', 'kod_fasiliti', 'facility_code'))
      IS DISTINCT FROM [k.prev_facility, k.prev_mrn];

SELECT assert_eq('AD03 is in all three systems', count(DISTINCT regexp_extract(file, '\.(\w+)$', 1)), 3)
FROM answer_key WHERE defect_code = 'AD03';

-- AD04 (C9): discharge status in words, Malay in the old HIS and English after.
SELECT assert_eq('AD04 clean values are the four statuses, dirty values are not', count(*), 0)
FROM answer_key WHERE defect_code = 'AD04'
  AND (clean_value NOT IN ('DISCHARGED', 'DIED', 'TRANSFERRED', 'AOR')
       OR dirty_value IN ('DISCHARGED', 'DIED', 'TRANSFERRED', 'AOR')
       OR column_name NOT IN ('status_discaj', 'discharge_status'));

SELECT assert_eq('AD04 is in all three systems and spells every status, deaths included',
  (SELECT count(DISTINCT regexp_extract(file, '\.(\w+)$', 1)) || ' systems, ' || count(DISTINCT clean_value) || ' statuses'
   FROM answer_key WHERE defect_code = 'AD04'), '3 systems, 4 statuses');

SELECT assert_eq('AD04 spellings are not null spellings (C4 must not null them)', count(*), 0)
FROM answer_key WHERE defect_code = 'AD04'
  AND upper(trim(dirty_value)) IN ('NULL', 'N/A', 'NA', '-', 'TIADA', 'TIDAK DIKETAHUI', 'UNKNOWN');

-- SH01 (C10): the dengue CSV is wide, one column per state. One row per state
-- column: the column with its type, and the state it becomes once unpivoted.
SELECT assert_eq('SH01 names every state column of the dengue CSV', count(*), 0)
FROM ((SELECT column_name, column_name || ' ' || column_type
       FROM (DESCRIBE FROM read_csv('data/open/dengue_state_age_2018_2021.csv'))
       WHERE column_name NOT IN ('TAHUN', 'KUMPULAN UMUR')
       EXCEPT SELECT column_name, dirty_value FROM answer_key WHERE defect_code = 'SH01')
      UNION ALL
      (SELECT column_name, dirty_value FROM answer_key WHERE defect_code = 'SH01'
       EXCEPT SELECT column_name, column_name || ' ' || column_type
       FROM (DESCRIBE FROM read_csv('data/open/dengue_state_age_2018_2021.csv'))));

SELECT assert_eq('SH01 rows are on the dengue CSV and map KL and Labuan to their MoH names',
  (SELECT string_agg(DISTINCT file, ',') FROM answer_key WHERE defect_code = 'SH01')
  || ' ' || (SELECT clean_value FROM answer_key WHERE defect_code = 'SH01' AND column_name = 'WP KUALA LUMPUR')
  || ' ' || (SELECT clean_value FROM answer_key WHERE defect_code = 'SH01' AND column_name = 'WP LABUAN'),
  'data/open/dengue_state_age_2018_2021.csv WILAYAH PERSEKUTUAN KUALA LUMPUR WILAYAH PERSEKUTUAN LABUAN');

-- ------------------------------------------- 2021 Capstone extract (#31)
-- Only the three Held-back defects, and only here (#10): ID06 for Angle A,
-- DX04 for Angle B, DT02 for Angle C.
SELECT assert_eq('2021 defect codes are the Held-back defects only',
                 string_agg(DISTINCT defect_code, ',' ORDER BY defect_code), 'DT02,DX04,ID06')
FROM answer_key WHERE file LIKE 'data/capstone/%';

SELECT assert_eq('no Held-back defect outside the 2021 extract', count(*), 0)
FROM answer_key WHERE defect_code IN ('DT02', 'DX04', 'ID06') AND file NOT LIKE 'data/capstone/%';

SELECT assert_eq('every 2021 key row is a cell defect of a 2021 admission', count(*), 0)
FROM answer_key k LEFT JOIN 'generator/truth/admission.parquet' a USING (admission_id)
WHERE k.file LIKE 'data/capstone/%' AND (k.row_no IS NULL OR k.column_name IS NULL OR year(a.admit_ts) IS DISTINCT FROM 2021);

-- ID06: a non-MyKad identifier (a letter, then fewer than 9 digits), the same
-- one on every admission of its patient and never shared; no MyKad to clean to.
SELECT assert_eq('ID06 values are not MyKad numbers, and have no clean MyKad', count(*), 0)
FROM answer_key WHERE defect_code = 'ID06'
  AND (clean_value IS NOT NULL OR column_name NOT IN ('no_kp', 'mykad')
       OR NOT regexp_full_match(dirty_value, '[A-Z]{1,2}\d{6,8}'));

SELECT assert_eq('each ID06 patient has one identifier, and each identifier one patient', count(*), 0)
FROM (SELECT count(DISTINCT patient_id) AS patients, count(DISTINCT dirty_value) AS identifiers
      FROM (SELECT a.patient_id, k.dirty_value
            FROM answer_key k JOIN 'generator/truth/admission.parquet' a USING (admission_id)
            WHERE k.defect_code = 'ID06')
      GROUP BY GROUPING SETS ((patient_id), (dirty_value)))
WHERE patients > 1 OR identifiers > 1;

SELECT assert_eq('ID06 is in both systems, more than a fifth of it in Sabah',
  (SELECT count(DISTINCT regexp_extract(file, '\.(\w+)$', 1)) FROM answer_key WHERE defect_code = 'ID06') = 2
  AND (SELECT count(*) FROM answer_key WHERE defect_code = 'ID06' AND file LIKE '%-sabah.csv')
      > (SELECT count(*) FROM answer_key WHERE defect_code = 'ID06') / 5, true);

-- DX04: free text on the principal diagnosis, with no digit in it, for a true
-- code; dengue most of all.
SELECT assert_eq('DX04 is free text (no digit) for a true ICD-10 code on the principal diagnosis', count(*), 0)
FROM answer_key k JOIN 'generator/truth/admission.parquet' a USING (admission_id)
WHERE k.defect_code = 'DX04'
  AND (regexp_matches(k.dirty_value, '\d') OR k.clean_value <> a.principal_dx
       OR k.column_name NOT IN ('dx_utama', 'principal_dx'));

SELECT assert_eq('DX04 hits dengue most, in both systems',
  (SELECT count(*) FILTER (WHERE clean_value LIKE 'A97.%') > count(*) / 2
          AND count(DISTINCT regexp_extract(file, '\.(\w+)$', 1)) = 2
   FROM answer_key WHERE defect_code = 'DX04'), true);

-- DT02: one hospital's dates month first; the clean value is the same date day first.
SELECT assert_eq('DT02 is one Sabah hospital in the old HIS CSVs', count(DISTINCT c.value) || ' ' || bool_and(k.file LIKE '%-sabah.csv'), '1 true')
FROM answer_key k JOIN cells c ON c.filename = k.file AND c.row_no = k.row_no AND c.column_name = 'kod_fasiliti'
WHERE k.defect_code = 'DT02';

SELECT assert_eq('DT02 writes MM/DD/YYYY for the DD/MM/YYYY date', count(*), 0)
FROM answer_key WHERE defect_code = 'DT02'
  AND CASE WHEN column_name = 'dikemaskini'
           THEN strptime(dirty_value, '%m/%d/%Y %H:%M') <> strptime(clean_value, '%d/%m/%Y %H:%M')
           ELSE strptime(dirty_value, '%m/%d/%Y') <> strptime(clean_value, '%d/%m/%Y') END;

SELECT assert_eq('DT02 touches the birth, admit, discharge and update dates',
                 string_agg(DISTINCT column_name, ',' ORDER BY column_name), 'dikemaskini,tarikh_keluar,tarikh_lahir,tarikh_masuk')
FROM answer_key WHERE defect_code = 'DT02';
