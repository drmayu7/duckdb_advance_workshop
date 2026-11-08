-- Reveal: C5, "Clean the facility list; macros" (cards/c05-facilities.md).
-- Run from the bundle folder, in your Work database, after C4 (or its Checkpoint).

-- Look first: the MoH list as published. Some names hold line breaks and double spaces.
SELECT KOD_FASILITI, NAMA, NEGERI, DAERAH
FROM read_json('data/open/facilities.json')
WHERE KATEGORI_FASILITI = 'HOSPITAL'
  AND (NAMA LIKE '%' || chr(10) || '%' OR NAMA LIKE '%  %' OR DAERAH <> trim(DAERAH));

-- And the admissions write the patient's state in many ways (GE01, plus C2's TX01).
SELECT state, count(*) AS n FROM admission_typed GROUP BY ALL ORDER BY state;

-- A macro is a reusable expression: write the rule once, use it on every table.
-- norm_state: compare letters only, so case, spaces, dots and non-breaking
-- spaces don't matter, then map every known spelling to the MoH name.
-- An unknown spelling gives NULL, so it shows up instead of hiding.
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

-- Try them.
SELECT norm_state(' p. pinang') AS a, norm_state('W.P. Kuala Lumpur') AS b, norm_icd('e119') AS c, norm_icd('E11.90') AS d;

-- Core: the 166 hospitals, cleaned.
CREATE OR REPLACE TABLE facility_clean AS
SELECT KOD_FASILITI AS facility_code,
       trim(regexp_replace(NAMA, '\s+', ' ', 'g')) AS facility_name,
       JENIS_FASILITI AS facility_type,
       norm_state(NEGERI) AS state,
       trim(DAERAH) AS district,
       POSKOD AS postcode,
       LATITUD AS latitude,
       LONGITUD AS longitude
FROM read_json('data/open/facilities.json')
WHERE KATEGORI_FASILITI = 'HOSPITAL';

-- Macro checks: every admission state and principal diagnosis normalises to a
-- known value (want 0 rows each).
SELECT state, count(*) AS n
FROM admission_typed
WHERE norm_state(state) IS NULL
GROUP BY ALL;

SELECT principal_dx, count(*) AS n
FROM admission_typed
WHERE norm_icd(principal_dx) NOT IN (SELECT icd10 FROM read_csv('data/open/ref_icd10.csv'))
GROUP BY ALL;

-- Stretch S1: the same macro on other files' states. The dengue CSV has one
-- column per state; DOSM's population file writes states in mixed case.
SELECT column_name AS written, norm_state(column_name) AS state
FROM (DESCRIBE FROM read_csv('data/open/dengue_state_age_2018_2021.csv'))
WHERE column_name NOT IN ('TAHUN', 'KUMPULAN UMUR');

SELECT DISTINCT state AS written, norm_state(state) AS state
FROM 'data/open/population_state.parquet'
ORDER BY written;

-- Stretch S2: all 5,160 facilities. Which NEGERI spelling does norm_state not
-- map, and why is mapping it to one state wrong?
SELECT NEGERI, count(*) AS facilities, count(*) FILTER (WHERE KATEGORI_FASILITI = 'HOSPITAL') AS hospitals
FROM read_json('data/open/facilities.json')
WHERE norm_state(NEGERI) IS NULL
GROUP BY ALL;
