-- The clean 2017 Warm-up extract (#7): every 2017 admission, with the hospital's
-- name and state flattened in, and the patients those admissions belong to.
-- Runs after truth.sql in the same session.
CREATE TABLE admission_2017 AS
SELECT a.admission_id, a.patient_id, a.facility_code,
       h.facility_name, h.state AS facility_state,
       a.admit_ts::DATE AS admit_date, a.discharge_ts::DATE AS discharge_date,
       a.principal_dx, a.discharge_status
FROM admission a JOIN ref_hospital h USING (facility_code)
WHERE year(a.admit_ts) = 2017;

CREATE TABLE patient_2017 AS
SELECT patient_id, mykad, name, sex, dob, state, district, postcode
FROM patient
WHERE patient_id IN (SELECT patient_id FROM admission_2017);

COPY (FROM patient_2017 ORDER BY patient_id)
  TO 'data/warmup/patient_2017.parquet' (FORMAT parquet, COMPRESSION zstd);
COPY (FROM admission_2017 ORDER BY admission_id)
  TO 'data/warmup/admission_2017.parquet' (FORMAT parquet, COMPRESSION zstd);
