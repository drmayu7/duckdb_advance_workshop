---
id: c05
title: Clean the facility list; macros
module: m2
timebox: 30 min
input: data/open/facilities.json, admission_typed, data/open/ref_icd10.csv
output: facility_clean
---

# C5: Clean the facility list; macros

> **Synthetic data, not real hospital performance.** Patients and admissions are made up. The hospital names are real, so no number here says anything about a real hospital.

**Time box:** 30 min · **Techniques:** `regexp_replace`, `trim`, `upper`, `CREATE MACRO`, `CASE … IN (…)`, `concat_ws`, string slicing `s[1:3]`

**Scenario.** The brief's third question, which hospitals carry the load, needs hospital names, and the brief joins everything by state. The MoH facility list is real and messy: names broken over two lines, double spaces, padded districts. The admissions write the patient's state in more than a hundred ways, and diagnosis codes with and without dots. The team cleans the hospital list once, and writes the state and diagnosis rules as **macros**, so that C6, the Capstone and next year's extract all use the same rules.

**Input → output.** `data/open/facilities.json` → **`facility_clean`**, one row per MoH hospital (166), with these columns in this order:

`facility_code`, `facility_name`, `facility_type`, `state`, `district`, `postcode`, `latitude`, `longitude`

and two macros, **`norm_state(s)`** and **`norm_icd(code)`**, that C6 uses on `admission_typed`.

## Look first

The hospital names that need cleaning:

```sql
SELECT KOD_FASILITI, NAMA, NEGERI, DAERAH
FROM read_json('data/open/facilities.json')
WHERE KATEGORI_FASILITI = 'HOSPITAL'
  AND (NAMA LIKE '%' || chr(10) || '%' OR NAMA LIKE '%  %' OR DAERAH <> trim(DAERAH));
```

How the admissions write the state, and the diagnosis:

```sql
SELECT state, count(*) AS n FROM admission_typed GROUP BY ALL ORDER BY state;
```

```sql
SELECT principal_dx, count(*) AS n
FROM admission_typed
WHERE NOT regexp_full_match(principal_dx, '[A-Z][0-9]{2}(\.[0-9])?')
GROUP BY ALL
ORDER BY n DESC;
```

A macro is a named expression you can use like a function:

```sql
CREATE OR REPLACE MACRO shout(s) AS upper(s) || '!';
```

```sql
SELECT shout('denggi') AS loud;
```

## Definitions

- **`facility_clean`** is the rows of `facilities.json` with `KATEGORI_FASILITI = 'HOSPITAL'`:
  - `facility_code` = `KOD_FASILITI`, `facility_type` = `JENIS_FASILITI`, `postcode` = `POSKOD`, `latitude` = `LATITUD`, `longitude` = `LONGITUD`, as they are.
  - `facility_name`: `NAMA` with every run of whitespace (spaces, line breaks) made one space, then trimmed: `trim(regexp_replace(NAMA, '\s+', ' ', 'g'))`.
  - `state`: `norm_state(NEGERI)`. `district`: `trim(DAERAH)`.
- **`norm_state(s)`** returns the state's MoH name in capitals, or NULL for a spelling it doesn't know. Compare **letters only**, after `upper`: `regexp_replace(upper(s), '[^A-Z]', '', 'g')`, so case, spaces, dots and `chr(160)` don't matter. Then map these spellings (written here as letters only):

  | State | Letters-only spellings |
  |---|---|
  | `JOHOR` | `JOHOR`, `JOHORDARULTAKZIM`, `JHR` |
  | `KEDAH` | `KEDAH`, `KEDAHDARULAMAN`, `KDH` |
  | `KELANTAN` | `KELANTAN`, `KELANTANDARULNAIM`, `KTN` |
  | `MELAKA` | `MELAKA`, `MALACCA`, `MLK` |
  | `NEGERI SEMBILAN` | `NEGERISEMBILAN`, `NSEMBILAN`, `NEGRISEMBILAN`, `NSN` |
  | `PAHANG` | `PAHANG`, `PAHANGDARULMAKMUR`, `PHG` |
  | `PERAK` | `PERAK`, `PERAKDARULRIDZUAN`, `PRK` |
  | `PERLIS` | `PERLIS`, `PERLISINDERAKAYANGAN`, `PLS` |
  | `PULAU PINANG` | `PULAUPINANG`, `PPINANG`, `PENANG`, `PNG` |
  | `SABAH` | `SABAH`, `SBH` |
  | `SARAWAK` | `SARAWAK`, `SWK` |
  | `SELANGOR` | `SELANGOR`, `SELANGORDARULEHSAN`, `SGR` |
  | `TERENGGANU` | `TERENGGANU`, `TERENGGANUDARULIMAN`, `TRG` |
  | `WILAYAH PERSEKUTUAN KUALA LUMPUR` | `WILAYAHPERSEKUTUANKUALALUMPUR`, `WPKUALALUMPUR`, `KUALALUMPUR`, `WPKL` |
  | `WILAYAH PERSEKUTUAN LABUAN` | `WILAYAHPERSEKUTUANLABUAN`, `WPLABUAN`, `LABUAN` |
  | `WILAYAH PERSEKUTUAN PUTRAJAYA` | `WILAYAHPERSEKUTUANPUTRAJAYA`, `WPPUTRAJAYA`, `PUTRAJAYA` |

- **`norm_icd(code)`** returns NULL for NULL. Otherwise take the code's letters and digits only, in capitals (`regexp_replace(upper(code), '[^A-Z0-9]', '', 'g')`), and write its first three characters, then a dot and the fourth character if there is one. Anything after the fourth is dropped: `e119`, `E11.9 ` and `E11.90` all become `E11.9`; `I10` stays `I10`.
- A macro may use another macro (a small `state_key(s)` helper keeps `norm_state` short).
- **Tie-break:** none needed. Nothing is ranked, and row order doesn't matter to the Self-check.

## Example row

<!-- begin example-row -->
| facility_code | facility_name | facility_type | state | district | postcode | latitude | longitude |
|---|---|---|---|---|---|---|---|
| 11-01030012 | HOSPITAL ENCHE' BESAR HAJJAH KHALSOM | HOSPITAL PAKAR MINOR | JOHOR | KLUANG | 86000 | 2.00732 | 103.3472 |
<!-- end example-row -->

## Core and Stretch

| Tier | Task |
|---|---|
| Core | Write `norm_state` and `norm_icd`, try them on a few spellings, then create `facility_clean`. Run the two macro checks below (0 rows each), then the Self-check. |
| S1 | Use `norm_state` on other files' states: the column names of `data/open/dengue_state_age_2018_2021.csv` (`DESCRIBE`) and the `state` values of `data/open/population_state.parquet`. Does every one map? |
| S2 | Over all 5,160 facilities, which `NEGERI` spelling does `norm_state` not map? Why would mapping it to one state be wrong? |

**Macro checks.** Every admission state, and every principal diagnosis, normalises to a known value (want **0 rows** each):

```sql
SELECT state, count(*) AS n
FROM admission_typed
WHERE norm_state(state) IS NULL
GROUP BY ALL;
```

```sql
SELECT principal_dx, count(*) AS n
FROM admission_typed
WHERE norm_icd(principal_dx) NOT IN (SELECT icd10 FROM read_csv('data/open/ref_icd10.csv'))
GROUP BY ALL;
```

## Self-check

Run this cell. **`0`** means you're done.

<!-- begin self-check -->
```sql
SELECT count(*) AS rows_differ
FROM ((SELECT * FROM facility_clean
       EXCEPT SELECT * FROM 'expected/facility_clean.parquet')
      UNION ALL
      (SELECT * FROM 'expected/facility_clean.parquet'
       EXCEPT SELECT * FROM facility_clean));
```

Anything else? This cell shows the differing rows: `yours` rows are in your table but not the expected one, `expected` rows the other way round.

```sql
SELECT * FROM (
  (SELECT 'yours' AS side, * FROM (SELECT * FROM facility_clean
                                   EXCEPT SELECT * FROM 'expected/facility_clean.parquet'))
  UNION ALL
  (SELECT 'expected' AS side, * FROM (SELECT * FROM 'expected/facility_clean.parquet'
                                      EXCEPT SELECT * FROM facility_clean)))
ORDER BY facility_code, side
LIMIT 50;
```
<!-- end self-check -->

The Self-check compares columns by position, so check your column order against the list above first. It checks `facility_clean` only; the macro checks above check the macros.

## Checkpoint

Out of time? Load the expected result as your table and carry on:

<!-- begin checkpoint -->
```sql
CREATE OR REPLACE TABLE facility_clean AS FROM 'expected/facility_clean.parquet';
```
<!-- end checkpoint -->

The Checkpoint gives you the table, not the macros: C6 starts with a cell that creates them.

## Reveal

The facilitator walks through `solutions/c05-facilities.sql` after the time box. It is in your bundle now, if you'd rather check it yourself afterwards.
