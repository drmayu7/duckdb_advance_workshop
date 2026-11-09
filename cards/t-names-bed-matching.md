---
id: t-names
title: Name matching
module: m4
timebox: 40 min
input: facility_clean, data/open/bed_utilisation.csv
output: bed_facility
---

# Extension track: Name matching

> **Synthetic data, not real hospital performance.** Patients and admissions are made up. The hospital names are real, so no number here says anything about a real hospital.

**Time box:** 40 min · **Extensions:** core `jaro_winkler_similarity()`, then `rapidfuzz` and `splink_udfs` · **Techniques:** a match key (`split_part`, `regexp_replace`), scoring every candidate, `QUALIFY row_number()`, a threshold

**Scenario.** The Director wants bed numbers next to the admission load. The MoH bed utilisation file names its 149 hospitals by **name only**, written its own way, with no facility code. The team links each name to a `facility_clean` code, and is honest about the ones that don't match.

**Starts from:** the C5 Checkpoint (`facility_clean`), so you can do this track whatever state your earlier work is in.

**Input → output.** `data/open/bed_utilisation.csv` with `facility_clean` (from C5) → **`bed_facility`**, one row per bed utilisation hospital, with these columns in this order:

`hospital`, `state`, `facility_code`, `match_type`, `similarity`

## Start here: C5's macros

Did C5 from its Checkpoint, or in another Work database? Run this cell first (it is C5's solution, so it replaces yours if you have them):

<!-- begin macros -->
```sql
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
```
<!-- end macros -->

## Look first

```sql
FROM read_csv('data/open/bed_utilisation.csv') LIMIT 5;
```

How far does an exact match get? (132 of 149.)

```sql
SELECT count(*) AS names, count(f.facility_code) AS exact_as_written
FROM read_csv('data/open/bed_utilisation.csv') b
LEFT JOIN facility_clean f ON f.facility_name = upper(b.hospital);
```

## Definitions

- **`hospital`**: the bed file's name exactly as written. **`state`**: `norm_state()` of the bed file's `state`. A name is only ever matched to a hospital of the **same state**.
- **The match key `hosp_key(s)`**: upper case; drop everything from the first comma (the MoH list adds the town: `…, JOHOR BAHRU`); turn every run of characters that aren't `A-Z` or `0-9` into one space; trim; drop a leading `HOSPITAL `:
  `trim(regexp_replace(regexp_replace(upper(split_part(s, ',', 1)), '[^A-Z0-9]+', ' ', 'g'), '^HOSPITAL ', ''))`
- **`similarity`**: `jaro_winkler_similarity()` of the two keys, for the **best** candidate in the state, `round(…, 3)`. Every row has one, matched or not.
- **`match_type`**: `exact` when the keys are equal; `fuzzy` when they aren't but similarity is 0.9 or more; else `none`.
- **`facility_code`**: the best candidate's code for `exact` and `fuzzy`; `NULL` for `none`.
- **Tie-break:** the best candidate is the highest similarity (unrounded), then the lowest `facility_code`.

## Example row

<!-- begin example-row -->
| hospital | state | facility_code | match_type | similarity |
|---|---|---|---|---|
| Hospital Sungai Buloh | SELANGOR | 11-10010019 | fuzzy | 0.967 |
<!-- end example-row -->

## Core and Stretch

| Tier | Task |
|---|---|
| Core | Write `hosp_key` as a macro (`CREATE OR REPLACE MACRO hosp_key(s) AS …`). Join every bed name to every `facility_clean` hospital of its state, score each pair, keep the best with `QUALIFY`, then label it. You should get 143 `exact`, 2 `fuzzy`, 4 `none`. Read the 6 non-exact rows next to their best candidate's name: would you accept them? Run the Self-check. |
| S1 | One `none` is really there: the MoH list has the new name with the old one in brackets, `… NORASHIKIN (HOSPITAL KAJANG)`. Match the bracketed alias too (`regexp_extract(facility_name, '\(([^)]*)\)', 1)`). |
| S2 | `LOAD rapidfuzz;` and score Hospital Sultanah Aminah against Johor's hospitals on the full names, with `rapidfuzz_token_set_ratio` and `rapidfuzz_token_sort_ratio`. Which one ranks the wrong Sultanah first, and why does the key avoid it? |
| S3 | `LOAD splink_udfs;` and compare `double_metaphone()` and `soundex()` for BULOH / BULUH and SERDANG / SELAYANG. A phonetic code is a blocking key (a short list of candidates to score), not a match decision: its rules are English-centric. |

## Self-check

Run this cell. **`0`** means you're done. `EXCEPT ALL` counts every copy of a row, so a missing or extra copy shows too.

<!-- begin self-check -->
```sql
SELECT count(*) AS rows_differ
FROM ((SELECT * FROM bed_facility
       EXCEPT ALL SELECT * FROM 'expected/bed_facility.parquet')
      UNION ALL
      (SELECT * FROM 'expected/bed_facility.parquet'
       EXCEPT ALL SELECT * FROM bed_facility));
```

Anything else? This cell shows the differing rows: `yours` rows are in your table but not the expected one, `expected` rows the other way round.

```sql
SELECT * FROM (
  (SELECT 'yours' AS side, * FROM (SELECT * FROM bed_facility
                                   EXCEPT ALL SELECT * FROM 'expected/bed_facility.parquet'))
  UNION ALL
  (SELECT 'expected' AS side, * FROM (SELECT * FROM 'expected/bed_facility.parquet'
                                      EXCEPT ALL SELECT * FROM bed_facility)))
ORDER BY hospital, side
LIMIT 50;
```
<!-- end self-check -->

The Self-check compares columns by position, so check your column order against the list above first. Sultanah Aminah matched to Sultanah Nora Ismail? Your key kept the `, JOHOR BAHRU`. Hospital Kajang matched to Hospital Ampang at 0.95? Your key kept the word `HOSPITAL`, which every name shares.

## Checkpoint

Out of time? Load the expected result as your table and carry on:

<!-- begin checkpoint -->
```sql
CREATE OR REPLACE TABLE bed_facility AS FROM 'expected/bed_facility.parquet';
```
<!-- end checkpoint -->

## Reveal

The facilitator walks through `solutions/t-names-bed-matching.sql` after the time box. It is in your bundle now, if you'd rather check it yourself afterwards.
