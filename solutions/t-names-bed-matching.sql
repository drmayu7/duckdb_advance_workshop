-- Reveal: Extension track "Name matching" (cards/t-names-bed-matching.md).
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

-- Look first: the bed utilisation file names hospitals, but has no facility code.
FROM read_csv('data/open/bed_utilisation.csv') LIMIT 5;

-- Core, step 1: how far does an exact match get? 132 of the 149 names.
SELECT count(*) AS names, count(f.facility_code) AS exact_as_written
FROM read_csv('data/open/bed_utilisation.csv') b
LEFT JOIN facility_clean f ON f.facility_name = upper(b.hospital);

-- Step 2: a match key. The MoH list adds the town after a comma
-- ("HOSPITAL SULTANAH AMINAH, JOHOR BAHRU"), spaces and hyphens vary
-- ("KANAK - KANAK", "Kanak-Kanak", a double space), and every name starts with
-- the same word HOSPITAL, which only makes different hospitals look alike.
CREATE OR REPLACE MACRO hosp_key(s) AS
  trim(regexp_replace(regexp_replace(upper(split_part(s, ',', 1)), '[^A-Z0-9]+', ' ', 'g'), '^HOSPITAL ', ''));
SELECT hosp_key('Hospital  Wanita Dan Kanak-Kanak') AS a, hosp_key('HOSPITAL WANITA DAN KANAK - KANAK SABAH') AS b;

-- Step 3: score every hospital of the same state on the key, keep the best one,
-- and accept it only if it is close enough.
--   exact: the keys are equal (Jaro-Winkler similarity 1).
--   fuzzy: similarity 0.9 or more.
--   none:  below 0.9, so no code. "SERDANG" vs "SELAYANG" scores 0.82.
-- Tie-break: the highest similarity, then the lowest facility_code.
CREATE OR REPLACE TABLE bed_facility AS
WITH scored AS (
  SELECT b.hospital, norm_state(b.state) AS state, f.facility_code,
         hosp_key(b.hospital) = hosp_key(f.facility_name) AS same_key,
         jaro_winkler_similarity(hosp_key(b.hospital), hosp_key(f.facility_name)) AS sim
  FROM read_csv('data/open/bed_utilisation.csv') b
  JOIN facility_clean f ON f.state = norm_state(b.state)
),
best AS (
  FROM scored
  QUALIFY row_number() OVER (PARTITION BY hospital ORDER BY sim DESC, facility_code) = 1
)
SELECT hospital, state,
       CASE WHEN sim >= 0.9 THEN facility_code END AS facility_code,
       CASE WHEN same_key THEN 'exact' WHEN sim >= 0.9 THEN 'fuzzy' ELSE 'none' END AS match_type,
       round(sim, 3) AS similarity
FROM best;

SELECT match_type, count(*) AS names FROM bed_facility GROUP BY ALL ORDER BY match_type;

-- Read the fuzzy and unmatched names next to their best candidate before trusting them.
SELECT b.hospital, b.match_type, b.similarity, f.facility_name
FROM bed_facility b LEFT JOIN facility_clean f USING (facility_code)
WHERE b.match_type <> 'exact'
ORDER BY b.similarity DESC;

-- Stretch S1: Hospital Kajang is in the MoH list under its new name, with the old
-- one in brackets: "HOSPITAL TENGKU PERMAISURI NORASHIKIN (HOSPITAL KAJANG)".
-- Match the bracketed alias too.
SELECT b.hospital, f.facility_code, f.facility_name
FROM bed_facility b
JOIN facility_clean f
  ON f.state = b.state AND hosp_key(regexp_extract(f.facility_name, '\(([^)]*)\)', 1)) = hosp_key(b.hospital)
WHERE b.match_type = 'none';

-- Stretch S2: rapidfuzz, on the full names without a key. Token-set ratio scores
-- word overlap, so it ranks the wrong Sultanah first for Sultanah Aminah.
LOAD rapidfuzz;
SELECT f.facility_name,
       round(rapidfuzz_token_set_ratio(upper('Hospital Sultanah Aminah'), f.facility_name), 1) AS token_set,
       round(rapidfuzz_token_sort_ratio(upper('Hospital Sultanah Aminah'), f.facility_name), 1) AS token_sort
FROM facility_clean f
WHERE f.state = 'JOHOR'
ORDER BY token_set DESC
LIMIT 3;

-- Stretch S3: phonetic blocking keys with splink_udfs. Two spellings that sound
-- alike share a double_metaphone code; that makes a short candidate list to score,
-- not a match decision (the rules are English-centric).
LOAD splink_udfs;
SELECT double_metaphone('BULOH') AS buloh, double_metaphone('BULUH') AS buluh,
       soundex('SERDANG') AS serdang, soundex('SELAYANG') AS selayang;
