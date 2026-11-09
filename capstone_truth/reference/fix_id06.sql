-- DQ FIX: ID06 (Angle A). Patients without a MyKad (foreign workers and
-- visitors, most in Sabah) are registered by passport or police/army number,
-- written in the IC column: "A51234567", "B1234567", "RF123456". norm_mykad()
-- gives NULL for every one of them, so C6 and C8 treat them all as ONE patient
-- (NULL): C6 keeps one of its admissions per day, dropping different people's
-- admissions, and C8 chains the rest into one year-long episode, so their
-- diabetes index episodes and readmissions vanish. Keep the document number as
-- the patient key when there is no MyKad. This is C6's core statement with
-- that one change. Runs after C6, on admission_typed.
--
-- How a team finds it: distinct patient_key against distinct ICs; a NULL
-- patient_key after C6 (want 0); one "patient" with hundreds of admissions.
CREATE OR REPLACE MACRO other_id(ic) AS nullif(regexp_replace(upper(ic), '[^A-Z0-9]', '', 'g'), '');

CREATE OR REPLACE TABLE admission_clean AS
SELECT source_system,
       coalesce(norm_mykad(mykad), other_id(mykad)) AS patient_key,  -- DQ FIX: ID06
       mrn,
       upper(trim(name, ' ' || chr(160))) AS name,
       sex, dob,
       norm_state(state) AS state,
       upper(trim(district, ' ' || chr(160))) AS district,
       postcode, facility_code, admit_date, discharge_date, los_days, date_flag, discharge_status,
       norm_icd(principal_dx) AS principal_dx,
       secondary_dx, updated_at, ward, admission_type, file
FROM admission_typed
QUALIFY row_number() OVER (PARTITION BY patient_key, admit_date ORDER BY updated_at DESC) = 1;

-- No admission without a patient key (want 0).
SELECT count(*) AS no_patient_key FROM admission_clean WHERE patient_key IS NULL;
