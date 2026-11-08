-- Reveal: C6, "One row per real admission" (cards/c06-dedupe.md).
-- Run from the bundle folder, in your Work database, after C5 (or its Checkpoint).

-- C5's macros, in case C5 was done from its Checkpoint (which loads the table only).
CREATE OR REPLACE MACRO state_key(s) AS regexp_replace(upper(s), '[^A-Z]', '', 'g');
CREATE OR REPLACE MACRO norm_state(s) AS
  CASE
    WHEN state_key(s) IN ('JOHOR', 'JOHORDARULTAKZIM', 'JHR') THEN 'JOHOR'
    WHEN state_key(s) IN ('KEDAH', 'KEDAHDARULAMAN', 'KDH') THEN 'KEDAH'
    WHEN state_key(s) IN ('KELANTAN', 'KELANTANDARULNAIM', 'KTN') THEN 'KELANTAN'
    WHEN state_key(s) IN ('MELAKA', 'MALACCA', 'MLK') THEN 'MELAKA'
    WHEN state_key(s) IN ('NEGERISEMBILAN', 'NSEMBILAN', 'NEGRISEMBILAN', 'NSN') THEN 'NEGERI SEMBILAN'
    WHEN state_key(s) IN ('PAHANG', 'PAHANGDARULMAKMUR', 'PHG') THEN 'PAHANG'
    WHEN state_key(s) IN ('PERAK', 'PERAKDARULRIDZUAN', 'PRK') THEN 'PERAK'
    WHEN state_key(s) IN ('PERLIS', 'PERLISINDERAKAYANGAN', 'PLS') THEN 'PERLIS'
    WHEN state_key(s) IN ('PULAUPINANG', 'PPINANG', 'PENANG', 'PNG') THEN 'PULAU PINANG'
    WHEN state_key(s) IN ('SABAH', 'SBH') THEN 'SABAH'
    WHEN state_key(s) IN ('SARAWAK', 'SWK') THEN 'SARAWAK'
    WHEN state_key(s) IN ('SELANGOR', 'SELANGORDARULEHSAN', 'SGR') THEN 'SELANGOR'
    WHEN state_key(s) IN ('TERENGGANU', 'TERENGGANUDARULIMAN', 'TRG') THEN 'TERENGGANU'
    WHEN state_key(s) IN ('WILAYAHPERSEKUTUANKUALALUMPUR', 'WPKUALALUMPUR', 'KUALALUMPUR', 'WPKL')
      THEN 'WILAYAH PERSEKUTUAN KUALA LUMPUR'
    WHEN state_key(s) IN ('WILAYAHPERSEKUTUANLABUAN', 'WPLABUAN', 'LABUAN') THEN 'WILAYAH PERSEKUTUAN LABUAN'
    WHEN state_key(s) IN ('WILAYAHPERSEKUTUANPUTRAJAYA', 'WPPUTRAJAYA', 'PUTRAJAYA') THEN 'WILAYAH PERSEKUTUAN PUTRAJAYA'
  END;

-- norm_icd (DX01): upper case, letters and digits only, then a dot after the
-- third character and at most one character after it: e119, E11.9 and E11.90
-- all become E11.9; I10 stays I10.
CREATE OR REPLACE MACRO icd_key(code) AS regexp_replace(upper(code), '[^A-Z0-9]', '', 'g');
CREATE OR REPLACE MACRO norm_icd(code) AS
  CASE WHEN code IS NOT NULL THEN concat_ws('.', icd_key(code)[1:3], nullif(icd_key(code)[4:4], '')) END;

-- Look first: one person, several MRNs (one per hospital) and several ways of
-- writing the IC and the name (ID01, ID02, PT01).
SELECT mykad, mrn, name, facility_code, admit_date
FROM admission_typed
WHERE regexp_replace(mykad, '[^0-9]', '', 'g') = (
  SELECT regexp_replace(mykad, '[^0-9]', '', 'g') FROM admission_typed
  WHERE name LIKE '% B. %' ORDER BY mykad LIMIT 1)
ORDER BY admit_date;

-- And some records are there twice: exact copies (AD01) and older versions (AD02).
SELECT mrn, facility_code, admit_date, count(*) AS records, count(DISTINCT updated_at) AS versions
FROM admission_typed
GROUP BY ALL
HAVING count(*) > 1
ORDER BY records DESC, mrn
LIMIT 10;

-- norm_mykad: digits only; 9 to 11 digits lost their leading zeros when the IC
-- was stored as a number (ID02, C1: someone born in 2000 loses two or three),
-- so pad to 12, then write YYMMDD-PB-####. Anything else is not a MyKad
-- number: NULL. It
-- does not look at the serial's first digit, so the workshop's 9### ICs pass.
CREATE OR REPLACE MACRO mykad_digits(ic) AS regexp_replace(ic, '[^0-9]', '', 'g');
CREATE OR REPLACE MACRO norm_mykad(ic) AS
  CASE WHEN length(mykad_digits(ic)) BETWEEN 9 AND 12
       THEN regexp_replace(lpad(mykad_digits(ic), 12, '0'), '^(\d{6})(\d{2})(\d{4})$', '\1-\2-\3') END;

SELECT norm_mykad('850312105523') AS a, norm_mykad('850312 10 9523 ') AS b, norm_mykad('50312109524') AS c;

-- Core: clean the columns with the macros, then keep the latest version of each
-- admission. A patient is never admitted twice on one day, so (patient_key,
-- admit_date) is one real admission; QUALIFY filters on a window function.
CREATE OR REPLACE TABLE admission_clean AS
SELECT source_system,
       norm_mykad(mykad) AS patient_key,
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

-- What de-duplication removed, and how many people there really are.
SELECT (SELECT count(*) FROM admission_typed) AS records,
       (SELECT count(*) FROM admission_clean) AS admissions,
       (SELECT count(DISTINCT mrn) FROM admission_clean) AS mrns,
       (SELECT count(DISTINCT patient_key) FROM admission_clean) AS patients;

-- PT01: the same patient_key under more than one name.
SELECT patient_key, list(DISTINCT name ORDER BY name) AS names, list(DISTINCT mrn ORDER BY mrn) AS mrns
FROM admission_clean
GROUP BY ALL
HAVING count(DISTINCT name) > 1
ORDER BY patient_key
LIMIT 10;

-- Stretch S1 (ID03): ICs whose date part is not a date, or is not the dob.
-- The century is not in the IC, so compare the six digits as text.
SELECT patient_key, dob, count(*) AS admissions
FROM admission_clean
WHERE try_strptime(patient_key[1:6], '%y%m%d') IS NULL
   OR patient_key[1:6] <> strftime(dob, '%y%m%d')
GROUP BY ALL
ORDER BY patient_key;

-- Stretch S2 (ID04): the last digit is odd for a man and even for a woman.
SELECT patient_key, sex, count(*) AS admissions
FROM admission_clean
WHERE (patient_key[-1:]::INTEGER % 2 = 1) <> (sex = 'M')
GROUP BY ALL
ORDER BY patient_key;
