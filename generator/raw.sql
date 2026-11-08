-- The 2018–2020 Raw extract (#7, #23) and its Answer key. Runs after truth.sql in
-- the same session, from the output root. Every 2018–2020 admission becomes one
-- raw record in its admit month's file, in the format of the source system that
-- year: the old HIS (CSV, Malay column names, DD/MM/YYYY), the interim system
-- (newline-delimited JSON, ISO text dates) or the new system (Parquet, typed
-- dob/admit_ts/discharge_ts, plus ward and admission_type). Patient fields are
-- repeated on every record.
--
-- Defects are then injected cell by cell, each one logged in `dq` first, so the
-- Answer key (generator/dq_answer_key.parquet) records every one: the file, the
-- record number in it, the column as the file names it, the defect code, the
-- value in the file and the value a correct cleaning gives (NULL where the
-- information is not there). A cell gets at most one defect.

-- ------------------------------------------------------------- raw records
-- rx holds every value as the text the source system writes; the new system's
-- typed columns are cast back when its Parquet files are written.
CREATE TABLE rx AS
WITH a AS (
  SELECT a.*, p.mykad, p.name, p.dob, p.sex, p.state, p.district, p.postcode, p.address,
         year(a.admit_ts) AS y,
         a.discharge_ts + to_minutes((60 + hash(a.admission_id, 'updated') % 2820)::BIGINT) AS updated_ts
  FROM admission a JOIN patient p USING (patient_id)
  WHERE year(a.admit_ts) BETWEEN 2018 AND 2020
)
SELECT admission_id AS rid, admission_id,
       CASE y WHEN 2018 THEN 'old_his' WHEN 2019 THEN 'interim' ELSE 'new_his' END AS sys,
       strftime(admit_ts, '%Y-%m') || CASE y WHEN 2018 THEN '.csv' WHEN 2019 THEN '.json' ELSE '.parquet' END AS file,
       mrn, mykad, name,
       CASE y WHEN 2018 THEN strftime(dob, '%d/%m/%Y') ELSE strftime(dob, '%Y-%m-%d') END AS dob,
       sex, state, district, postcode, address, facility_code,
       CASE y WHEN 2018 THEN strftime(admit_ts, '%d/%m/%Y') WHEN 2019 THEN strftime(admit_ts, '%Y-%m-%d')
            ELSE strftime(admit_ts, '%Y-%m-%d %H:%M:%S') END AS admit,
       CASE y WHEN 2018 THEN strftime(discharge_ts, '%d/%m/%Y') WHEN 2019 THEN strftime(discharge_ts, '%Y-%m-%d')
            ELSE strftime(discharge_ts, '%Y-%m-%d %H:%M:%S') END AS discharge,
       discharge_status, principal_dx,
       nullif(array_to_string(secondary_dx, '; '), '') AS secondary_dx,
       CASE y WHEN 2018 THEN strftime(updated_ts, '%d/%m/%Y %H:%M') ELSE strftime(updated_ts, '%Y-%m-%d %H:%M:%S') END AS updated_at,
       CASE WHEN y = 2020 THEN ward END AS ward,
       CASE WHEN y = 2020 THEN admission_type END AS admission_type,
       false AS unescaped_quotes  -- set by GE04: the old HIS writes this address's inner quotes as they are
FROM a;

-- The column names each source system uses, keyed by rx's column.
CREATE TABLE raw_columns (col VARCHAR, pos INTEGER, old_his VARCHAR, interim VARCHAR, new_his VARCHAR, new_his_type VARCHAR);
INSERT INTO raw_columns VALUES
  ('mrn', 1, 'no_mrn', 'mrn', 'mrn', 'VARCHAR'),
  ('mykad', 2, 'no_kp', 'mykad', 'mykad', 'VARCHAR'),
  ('name', 3, 'nama', 'name', 'name', 'VARCHAR'),
  ('dob', 4, 'tarikh_lahir', 'dob', 'dob', 'DATE'),
  ('sex', 5, 'jantina', 'sex', 'sex', 'VARCHAR'),
  ('state', 6, 'negeri', 'state', 'state', 'VARCHAR'),
  ('district', 7, 'daerah', 'district', 'district', 'VARCHAR'),
  ('postcode', 8, 'poskod', 'postcode', 'postcode', 'VARCHAR'),
  ('address', 9, 'alamat', 'address', 'address', 'VARCHAR'),
  ('facility_code', 10, 'kod_fasiliti', 'facility_code', 'facility_code', 'VARCHAR'),
  ('admit', 11, 'tarikh_masuk', 'admit_date', 'admit_ts', 'TIMESTAMP'),
  ('discharge', 12, 'tarikh_keluar', 'discharge_date', 'discharge_ts', 'TIMESTAMP'),
  ('discharge_status', 13, 'status_discaj', 'discharge_status', 'discharge_status', 'VARCHAR'),
  ('principal_dx', 14, 'dx_utama', 'principal_dx', 'principal_dx', 'VARCHAR'),
  ('secondary_dx', 15, 'dx_sekunder', 'secondary_dx', 'secondary_dx', 'VARCHAR'),
  ('updated_at', 16, 'dikemaskini', 'updated_at', 'updated_at', 'VARCHAR'),
  ('ward', 17, NULL, NULL, 'ward', 'VARCHAR'),
  ('admission_type', 18, NULL, NULL, 'admission_type', 'VARCHAR');

-- The Answer key while it is built: rid = the raw record (NULL for a whole-file defect).
CREATE TABLE dq (rid BIGINT, file VARCHAR, col VARCHAR, defect_code VARCHAR, dirty_value VARCHAR, clean_value VARCHAR);

-- ------------------------------------------------------------------ defects
-- Each defect: `hit` holds the chosen cells with their dirty and clean values,
-- is logged in dq, then applied to rx. A cell already in dq is never chosen again.
-- (A NOT EXISTS here would bind the caller's `rid` to dq.rid, so it is NOT IN.)
CREATE MACRO free(r, c) AS (r, c) NOT IN (SELECT (rid, col) FROM dq WHERE rid IS NOT NULL);

-- GE04 (C1): old HIS addresses with a line break after the comma. A few also
-- put the street name in quotes, which the old HIS writes without doubling
-- them; that breaks a plain read_csv of every 2018 file.
CREATE TABLE hit AS
SELECT rid, file, 'address' AS col, regexp_replace(address, 'JALAN (\w+)', 'JALAN "\1"') AS dirty, address AS clean
FROM rx WHERE sys = 'old_his' AND u(rid, 'ge04q') < 0.004;
INSERT INTO dq SELECT rid, file, col, 'GE04', dirty, clean FROM hit;
UPDATE rx SET address = hit.dirty, unescaped_quotes = true FROM hit WHERE rx.rid = hit.rid;
DROP TABLE hit;

CREATE TABLE hit AS
SELECT rid, file, 'address' AS col, replace(address, ', ', ',' || chr(10)) AS dirty, address AS clean
FROM rx WHERE sys = 'old_his' AND u(rid, 'ge04') < 0.02 AND free(rid, 'address');
INSERT INTO dq SELECT rid, file, col, 'GE04', dirty, clean FROM hit;
UPDATE rx SET address = hit.dirty FROM hit WHERE rx.rid = hit.rid;
DROP TABLE hit;

-- ID02 (C1): the old HIS once stored some ICs as numbers, so ICs of people born
-- 2000–2009 lost their dashes and leading zeros.
CREATE TABLE hit AS
SELECT rid, file, 'mykad' AS col, replace(mykad, '-', '')::BIGINT::VARCHAR AS dirty, mykad AS clean
FROM rx WHERE sys = 'old_his' AND mykad LIKE '0%' AND u(rid, 'id02') < 0.3;
INSERT INTO dq SELECT rid, file, col, 'ID02', dirty, clean FROM hit;
UPDATE rx SET mykad = hit.dirty FROM hit WHERE rx.rid = hit.rid;
DROP TABLE hit;

-- GE03 (C1): the same for postcodes that start with 0 (Perlis, Kedah).
CREATE TABLE hit AS
SELECT rid, file, 'postcode' AS col, postcode::INTEGER::VARCHAR AS dirty, postcode AS clean
FROM rx WHERE sys = 'old_his' AND postcode LIKE '0%' AND u(rid, 'ge03') < 0.3;
INSERT INTO dq SELECT rid, file, col, 'GE03', dirty, clean FROM hit;
UPDATE rx SET postcode = hit.dirty FROM hit WHERE rx.rid = hit.rid;
DROP TABLE hit;

-- NU02 (C2): null spellings, in every system. An empty secondary_dx is often
-- written as a word; a few districts and addresses are missing the same way.
-- The clean value is NULL.
CREATE MACRO null_spelling(x) AS
  pick(['TIADA', '-', 'N/A', 'NULL', 'NA', 'Tidak diketahui', 'Unknown'], x);
CREATE TABLE hit AS
SELECT rid, file, 'secondary_dx' AS col, null_spelling(u(rid, 'nu02s')) AS dirty, NULL AS clean
FROM rx WHERE secondary_dx IS NULL AND u(rid, 'nu02') < 0.3;
INSERT INTO dq SELECT rid, file, col, 'NU02', dirty, clean FROM hit;
UPDATE rx SET secondary_dx = hit.dirty FROM hit WHERE rx.rid = hit.rid;
DROP TABLE hit;

CREATE TABLE hit AS
SELECT rid, file, 'district' AS col, null_spelling(u(rid, 'nu02ds')) AS dirty, NULL AS clean
FROM rx WHERE u(rid, 'nu02d') < 0.01;
INSERT INTO dq SELECT rid, file, col, 'NU02', dirty, clean FROM hit;
UPDATE rx SET district = hit.dirty FROM hit WHERE rx.rid = hit.rid;
DROP TABLE hit;

CREATE TABLE hit AS
SELECT rid, file, 'address' AS col, null_spelling(u(rid, 'nu02as')) AS dirty, NULL AS clean
FROM rx WHERE u(rid, 'nu02a') < 0.01 AND free(rid, 'address');
INSERT INTO dq SELECT rid, file, col, 'NU02', dirty, clean FROM hit;
UPDATE rx SET address = hit.dirty FROM hit WHERE rx.rid = hit.rid;
DROP TABLE hit;

-- TX01 (C2): stray spaces, a trailing non-breaking space, or lower case, on
-- names, states and districts in every system. The clean value is the truth's.
CREATE MACRO tx01(x, v) AS
  CASE floor(v * 4)::INTEGER WHEN 0 THEN ' ' || x WHEN 1 THEN x || ' ' WHEN 2 THEN x || chr(160) ELSE lower(x) END;
CREATE TABLE hit AS
SELECT rid, file, 'name' AS col, tx01(name, u(rid, 'tx01nv')) AS dirty, name AS clean
FROM rx WHERE u(rid, 'tx01n') < 0.03;
INSERT INTO dq SELECT rid, file, col, 'TX01', dirty, clean FROM hit;
UPDATE rx SET name = hit.dirty FROM hit WHERE rx.rid = hit.rid;
DROP TABLE hit;

CREATE TABLE hit AS
SELECT rid, file, 'state' AS col, tx01(state, u(rid, 'tx01sv')) AS dirty, state AS clean
FROM rx WHERE u(rid, 'tx01s') < 0.03;
INSERT INTO dq SELECT rid, file, col, 'TX01', dirty, clean FROM hit;
UPDATE rx SET state = hit.dirty FROM hit WHERE rx.rid = hit.rid;
DROP TABLE hit;

CREATE TABLE hit AS
SELECT rid, file, 'district' AS col, tx01(district, u(rid, 'tx01dv')) AS dirty, district AS clean
FROM rx WHERE u(rid, 'tx01d') < 0.03 AND free(rid, 'district');
INSERT INTO dq SELECT rid, file, col, 'TX01', dirty, clean FROM hit;
UPDATE rx SET district = hit.dirty FROM hit WHERE rx.rid = hit.rid;
DROP TABLE hit;

-- DT05 (C2, nulled in C4): placeholder dates for an unknown birth date, and a
-- "not yet discharged" discharge date. The clean value is NULL.
CREATE TABLE hit AS
SELECT rid, file, 'dob' AS col,
       CASE WHEN sys = 'old_his' THEN CASE WHEN u(rid, 'dt05v') < 0.7 THEN '01/01/1900' ELSE '01/01/1970' END
            ELSE CASE WHEN u(rid, 'dt05v') < 0.7 THEN '1900-01-01' ELSE '1970-01-01' END END AS dirty,
       NULL AS clean
FROM rx WHERE u(rid, 'dt05') < 0.008;
INSERT INTO dq SELECT rid, file, col, 'DT05', dirty, clean FROM hit;
UPDATE rx SET dob = hit.dirty FROM hit WHERE rx.rid = hit.rid;
DROP TABLE hit;

CREATE TABLE hit AS
SELECT rid, file, 'discharge' AS col,
       CASE sys WHEN 'old_his' THEN '31/12/9999' WHEN 'interim' THEN '9999-12-31' ELSE '9999-12-31 00:00:00' END AS dirty,
       NULL AS clean
FROM rx WHERE u(rid, 'dt05x') < 0.003;
INSERT INTO dq SELECT rid, file, col, 'DT05', dirty, clean FROM hit;
UPDATE rx SET discharge = hit.dirty FROM hit WHERE rx.rid = hit.rid;
DROP TABLE hit;

-- SD01 (C3): schema drift, one row per file and drifting column: "name TYPE" as
-- the file has it, and the column it becomes in admission_raw. The old HIS
-- names every column in Malay; the new system types dob and the admit and
-- discharge times, and adds ward and admission_type.
INSERT INTO dq
SELECT NULL, f.file, c.col, 'SD01', c.old_his || ' VARCHAR', c.interim || ' VARCHAR'
FROM (SELECT DISTINCT file FROM rx WHERE sys = 'old_his') f, raw_columns c
WHERE c.old_his IS NOT NULL
UNION ALL
SELECT NULL, f.file, c.col, 'SD01', c.new_his || ' ' || c.new_his_type,
       coalesce(c.interim, c.new_his) || ' VARCHAR' || CASE WHEN c.interim IS NULL THEN ', new in 2020 (NULL before)' ELSE '' END
FROM (SELECT DISTINCT file FROM rx WHERE sys = 'new_his') f, raw_columns c
WHERE c.new_his_type <> 'VARCHAR' OR c.interim IS NULL;

-- ------------------------------------------------------------------ writing
-- Old HIS CSV lines: a field is quoted when it holds a comma, quote or newline,
-- with inner quotes doubled; except that GE04's unescaped addresses keep theirs.
CREATE MACRO csv_field(x) AS
  CASE WHEN x IS NULL THEN ''
       WHEN regexp_matches(x, '[,"\n]') THEN '"' || replace(x, '"', '""') || '"'
       ELSE x END;

CREATE TABLE csv_lines AS
SELECT file, 0 AS rid,
       (SELECT string_agg(old_his, ',' ORDER BY pos) FROM raw_columns WHERE old_his IS NOT NULL) AS line
FROM (SELECT DISTINCT file FROM rx WHERE sys = 'old_his')
UNION ALL
SELECT file, rid,
       concat_ws(',', csv_field(mrn), csv_field(mykad), csv_field(name), csv_field(dob), csv_field(sex),
                 csv_field(state), csv_field(district), csv_field(postcode),
                 CASE WHEN unescaped_quotes THEN '"' || address || '"' ELSE csv_field(address) END,
                 csv_field(facility_code), csv_field(admit), csv_field(discharge), csv_field(discharge_status),
                 csv_field(principal_dx), csv_field(secondary_dx), csv_field(updated_at))
FROM rx WHERE sys = 'old_his';

CREATE VIEW interim_rows AS
SELECT file, rid, mrn, mykad, name, dob, sex, state, district, postcode, address, facility_code,
       admit AS admit_date, discharge AS discharge_date, discharge_status, principal_dx, secondary_dx, updated_at
FROM rx WHERE sys = 'interim';

CREATE VIEW new_his_rows AS
SELECT file, rid, mrn, mykad, name, dob::DATE AS dob, sex, state, district, postcode, address, facility_code,
       admit::TIMESTAMP AS admit_ts, discharge::TIMESTAMP AS discharge_ts, discharge_status, principal_dx,
       secondary_dx, updated_at, ward, admission_type
FROM rx WHERE sys = 'new_his';

COPY (SELECT line FROM csv_lines WHERE file = '2018-01.csv' ORDER BY rid) TO 'data/raw/2018-01.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM csv_lines WHERE file = '2018-02.csv' ORDER BY rid) TO 'data/raw/2018-02.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM csv_lines WHERE file = '2018-03.csv' ORDER BY rid) TO 'data/raw/2018-03.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM csv_lines WHERE file = '2018-04.csv' ORDER BY rid) TO 'data/raw/2018-04.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM csv_lines WHERE file = '2018-05.csv' ORDER BY rid) TO 'data/raw/2018-05.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM csv_lines WHERE file = '2018-06.csv' ORDER BY rid) TO 'data/raw/2018-06.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM csv_lines WHERE file = '2018-07.csv' ORDER BY rid) TO 'data/raw/2018-07.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM csv_lines WHERE file = '2018-08.csv' ORDER BY rid) TO 'data/raw/2018-08.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM csv_lines WHERE file = '2018-09.csv' ORDER BY rid) TO 'data/raw/2018-09.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM csv_lines WHERE file = '2018-10.csv' ORDER BY rid) TO 'data/raw/2018-10.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM csv_lines WHERE file = '2018-11.csv' ORDER BY rid) TO 'data/raw/2018-11.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');
COPY (SELECT line FROM csv_lines WHERE file = '2018-12.csv' ORDER BY rid) TO 'data/raw/2018-12.csv' (FORMAT csv, HEADER false, QUOTE '', ESCAPE '', DELIMITER '\t');

COPY (SELECT * EXCLUDE (file, rid) FROM interim_rows WHERE file = '2019-01.json' ORDER BY rid) TO 'data/raw/2019-01.json' (FORMAT json);
COPY (SELECT * EXCLUDE (file, rid) FROM interim_rows WHERE file = '2019-02.json' ORDER BY rid) TO 'data/raw/2019-02.json' (FORMAT json);
COPY (SELECT * EXCLUDE (file, rid) FROM interim_rows WHERE file = '2019-03.json' ORDER BY rid) TO 'data/raw/2019-03.json' (FORMAT json);
COPY (SELECT * EXCLUDE (file, rid) FROM interim_rows WHERE file = '2019-04.json' ORDER BY rid) TO 'data/raw/2019-04.json' (FORMAT json);
COPY (SELECT * EXCLUDE (file, rid) FROM interim_rows WHERE file = '2019-05.json' ORDER BY rid) TO 'data/raw/2019-05.json' (FORMAT json);
COPY (SELECT * EXCLUDE (file, rid) FROM interim_rows WHERE file = '2019-06.json' ORDER BY rid) TO 'data/raw/2019-06.json' (FORMAT json);
COPY (SELECT * EXCLUDE (file, rid) FROM interim_rows WHERE file = '2019-07.json' ORDER BY rid) TO 'data/raw/2019-07.json' (FORMAT json);
COPY (SELECT * EXCLUDE (file, rid) FROM interim_rows WHERE file = '2019-08.json' ORDER BY rid) TO 'data/raw/2019-08.json' (FORMAT json);
COPY (SELECT * EXCLUDE (file, rid) FROM interim_rows WHERE file = '2019-09.json' ORDER BY rid) TO 'data/raw/2019-09.json' (FORMAT json);
COPY (SELECT * EXCLUDE (file, rid) FROM interim_rows WHERE file = '2019-10.json' ORDER BY rid) TO 'data/raw/2019-10.json' (FORMAT json);
COPY (SELECT * EXCLUDE (file, rid) FROM interim_rows WHERE file = '2019-11.json' ORDER BY rid) TO 'data/raw/2019-11.json' (FORMAT json);
COPY (SELECT * EXCLUDE (file, rid) FROM interim_rows WHERE file = '2019-12.json' ORDER BY rid) TO 'data/raw/2019-12.json' (FORMAT json);

COPY (SELECT * EXCLUDE (file, rid) FROM new_his_rows WHERE file = '2020-01.parquet' ORDER BY rid) TO 'data/raw/2020-01.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM new_his_rows WHERE file = '2020-02.parquet' ORDER BY rid) TO 'data/raw/2020-02.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM new_his_rows WHERE file = '2020-03.parquet' ORDER BY rid) TO 'data/raw/2020-03.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM new_his_rows WHERE file = '2020-04.parquet' ORDER BY rid) TO 'data/raw/2020-04.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM new_his_rows WHERE file = '2020-05.parquet' ORDER BY rid) TO 'data/raw/2020-05.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM new_his_rows WHERE file = '2020-06.parquet' ORDER BY rid) TO 'data/raw/2020-06.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM new_his_rows WHERE file = '2020-07.parquet' ORDER BY rid) TO 'data/raw/2020-07.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM new_his_rows WHERE file = '2020-08.parquet' ORDER BY rid) TO 'data/raw/2020-08.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM new_his_rows WHERE file = '2020-09.parquet' ORDER BY rid) TO 'data/raw/2020-09.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM new_his_rows WHERE file = '2020-10.parquet' ORDER BY rid) TO 'data/raw/2020-10.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM new_his_rows WHERE file = '2020-11.parquet' ORDER BY rid) TO 'data/raw/2020-11.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (SELECT * EXCLUDE (file, rid) FROM new_his_rows WHERE file = '2020-12.parquet' ORDER BY rid) TO 'data/raw/2020-12.parquet' (FORMAT parquet, COMPRESSION zstd);

-- manifest.csv: the rows a correct read of each file gives.
COPY (SELECT file, count(*) AS rows FROM rx GROUP BY file ORDER BY file)
  TO 'data/raw/manifest.csv' (FORMAT csv, HEADER true);

-- The Answer key, located by file and record number (1 = the first record after any header).
COPY (
  SELECT 'data/raw/' || dq.file AS file,
         r.row_no,
         CASE WHEN dq.file LIKE '%.csv' THEN c.old_his WHEN dq.file LIKE '%.json' THEN c.interim ELSE c.new_his END AS column_name,
         dq.defect_code, dq.dirty_value, dq.clean_value, r.admission_id
  FROM dq
  JOIN raw_columns c USING (col)
  LEFT JOIN (SELECT rid, admission_id, row_number() OVER (PARTITION BY file ORDER BY rid) AS row_no FROM rx) r USING (rid)
  ORDER BY file, row_no NULLS FIRST, c.pos, defect_code
) TO 'generator/dq_answer_key.parquet' (FORMAT parquet, COMPRESSION zstd);
