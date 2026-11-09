-- RAW: the 2021 Capstone extract into one all-text table, admission_raw, with
-- C3's columns. This is C1 and C3 adapted to the 2021 files, and nothing more:
-- no defect is fixed here. Run from the bundle folder in a fresh Work database.

-- The manifest: how many records each 2021 file holds.
CREATE OR REPLACE TABLE manifest AS
SELECT * FROM read_csv('data/capstone/manifest.csv');

CREATE OR REPLACE TABLE admission_raw AS
SELECT source_system, mrn, mykad, name, dob, sex, state, district, postcode, address,
       facility_code, admit_date, discharge_date, discharge_status, principal_dx,
       secondary_dx, updated_at, ward, admission_type, file
FROM (
  -- Sabah's hospitals, still on the old HIS: Malay names, every value as text.
  SELECT 'old_his' AS source_system,
         no_mrn AS mrn, no_kp AS mykad, nama AS name, tarikh_lahir AS dob, jantina AS sex,
         negeri AS state, daerah AS district, poskod AS postcode, alamat AS address,
         kod_fasiliti AS facility_code, tarikh_masuk AS admit_date, tarikh_keluar AS discharge_date,
         status_discaj AS discharge_status, dx_utama AS principal_dx, dx_sekunder AS secondary_dx,
         dikemaskini AS updated_at, parse_filename(filename) AS file
  FROM read_csv('data/capstone/2021-*-sabah.csv', all_varchar = true, filename = true)
  UNION ALL BY NAME
  -- Every other hospital, on the new system: typed dob and timestamps.
  SELECT 'new_his' AS source_system,
         COLUMNS(* EXCLUDE (dob, admit_ts, discharge_ts, filename))::VARCHAR,
         dob::VARCHAR AS dob,
         admit_ts::DATE::VARCHAR AS admit_date,
         discharge_ts::DATE::VARCHAR AS discharge_date,
         parse_filename(filename) AS file
  FROM read_parquet('data/capstone/2021-*.parquet', filename = true)
);

-- Sanity check: every file against the manifest (want 0 rows).
SELECT m.file, m.rows AS manifest_rows, count(a.file) AS rows_read
FROM manifest AS m
LEFT JOIN admission_raw AS a ON a.file = m.file
GROUP BY m.file, m.rows
HAVING count(a.file) <> m.rows;
