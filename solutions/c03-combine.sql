-- Reveal: C3, "Combine three systems" (cards/c03-combine.md).
-- Run from the bundle folder, in your Work database, after C1 (or its Checkpoint).

-- The manifest again, in case C1 was done from its Checkpoint.
CREATE OR REPLACE TABLE manifest AS
SELECT * FROM read_csv('data/raw/manifest.csv');

-- Look first: the three systems name and type their columns differently (SD01).
DESCRIBE raw_2018;
DESCRIBE FROM read_json('data/raw/2019-*.json');
DESCRIBE FROM 'data/raw/2020-*.parquet';

-- Core: one table over all three systems. UNION ALL BY NAME matches columns by
-- name, not position, and fills a column a system doesn't have (ward,
-- admission_type before 2020) with NULL. Each part first renames its columns to
-- the interim system's English names and turns every value into text.
CREATE OR REPLACE TABLE admission_raw AS
SELECT source_system, mrn, mykad, name, dob, sex, state, district, postcode, address,
       facility_code, admit_date, discharge_date, discharge_status, principal_dx,
       secondary_dx, updated_at, ward, admission_type, file
FROM (
  -- 2018, old HIS: Malay names, already all text in raw_2018.
  SELECT 'old_his' AS source_system,
         no_mrn AS mrn, no_kp AS mykad, nama AS name, tarikh_lahir AS dob, jantina AS sex,
         negeri AS state, daerah AS district, poskod AS postcode, alamat AS address,
         kod_fasiliti AS facility_code, tarikh_masuk AS admit_date, tarikh_keluar AS discharge_date,
         status_discaj AS discharge_status, dx_utama AS principal_dx, dx_sekunder AS secondary_dx,
         dikemaskini AS updated_at, file
  FROM raw_2018
  UNION ALL BY NAME
  -- 2019, interim: the right names already; read_json types the dates, so cast back to text.
  SELECT 'interim' AS source_system,
         COLUMNS(* EXCLUDE (filename))::VARCHAR,
         parse_filename(filename) AS file
  FROM read_json('data/raw/2019-*.json', filename = true)
  UNION ALL BY NAME
  -- 2020, new system: typed dob and timestamps, and two extra columns.
  SELECT 'new_his' AS source_system,
         COLUMNS(* EXCLUDE (dob, admit_ts, discharge_ts, filename))::VARCHAR,
         dob::VARCHAR AS dob,
         admit_ts::DATE::VARCHAR AS admit_date,
         discharge_ts::DATE::VARCHAR AS discharge_date,
         parse_filename(filename) AS file
  FROM read_parquet('data/raw/2020-*.parquet', filename = true)
);

-- Proof that nothing was dropped: every file of all three systems against the manifest (0 rows).
SELECT m.file, m.rows AS manifest_rows, count(a.file) AS rows_read
FROM manifest AS m
LEFT JOIN admission_raw AS a ON a.file = m.file
GROUP BY m.file, m.rows
HAVING count(a.file) <> m.rows;

-- Stretch S1: the same kind of date, written differently by each system.
SELECT source_system,
       min(dob) AS dob_example, min(admit_date) AS admit_date_example, min(updated_at) AS updated_at_example
FROM admission_raw
GROUP BY source_system
ORDER BY source_system;

-- Stretch S2: rows per system, and how many have a ward (only the new system records one).
SELECT source_system, count(*) AS admissions, count(ward) AS with_ward
FROM admission_raw
GROUP BY source_system
ORDER BY source_system;
