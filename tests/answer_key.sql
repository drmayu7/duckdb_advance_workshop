-- The Answer key (#7, #23) on the committed generator/dq_answer_key.parquet and
-- data/raw/ (tests/generator_determinism.sh proves both are current): every
-- row points at a real place in the Raw extract, and the 2018–2020 extract
-- carries exactly the defects decided for it so far.
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
-- UNPIVOT drops NULL cells, so NULL travels as chr(0) and comes back afterwards.
CREATE MACRO keep_nulls(t) AS TABLE
  SELECT filename, row_no, coalesce(COLUMNS(* EXCLUDE (filename, row_no)), chr(0)) FROM query_table(t);
CREATE TABLE u18 AS FROM keep_nulls('r18');
CREATE TABLE u19 AS FROM keep_nulls('r19');
CREATE TABLE u20 AS FROM keep_nulls('r20');
CREATE TABLE cells AS
SELECT filename, row_no, column_name, nullif(value, chr(0)) AS value
FROM (UNPIVOT u18 ON COLUMNS(* EXCLUDE (filename, row_no)) INTO NAME column_name VALUE value
      UNION ALL
      UNPIVOT u19 ON COLUMNS(* EXCLUDE (filename, row_no)) INTO NAME column_name VALUE value
      UNION ALL
      UNPIVOT u20 ON COLUMNS(* EXCLUDE (filename, row_no)) INTO NAME column_name VALUE value);

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
WHERE k.row_no IS NOT NULL;

SELECT assert_eq('the value in the file at each cell defect is its dirty_value', count(*), 0)
FROM answer_key k JOIN cells c
  ON c.filename = k.file AND c.row_no = k.row_no AND c.column_name = k.column_name
WHERE c.value IS DISTINCT FROM k.dirty_value;

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

SELECT assert_eq('only SD01 rows are whole-file defects', count(*), 0)
FROM answer_key WHERE (row_no IS NULL) <> (defect_code = 'SD01');

-- The defects decided for 2018–2020 so far (#23); later tickets add theirs.
SELECT assert_eq('2018-2020 defect codes', string_agg(DISTINCT defect_code, ',' ORDER BY defect_code),
                 'DT05,GE03,GE04,ID02,NU02,SD01,TX01')
FROM answer_key WHERE file LIKE 'data/raw/20%';

SELECT assert_eq('C1 defects (GE04, ID02, GE03) are in the old HIS CSVs only', count(*), 0)
FROM answer_key WHERE defect_code IN ('GE04', 'ID02', 'GE03') AND file NOT LIKE '%.csv';

SELECT assert_eq('NU02, TX01 and DT05 are in all three source systems', count(*), 9)
FROM (SELECT DISTINCT defect_code, regexp_extract(file, '\.(\w+)$', 1) FROM answer_key
      WHERE defect_code IN ('NU02', 'TX01', 'DT05'));

SELECT assert_eq('every 2018 file breaks a plain read (GE04 unescaped quotes)', count(*), 12)
FROM (SELECT DISTINCT file FROM answer_key WHERE defect_code = 'GE04' AND dirty_value LIKE '%"%');
