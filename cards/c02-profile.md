---
id: c02
title: Profile before you trust
module: m1
timebox: 25 min
input: raw_2018
output: profile_nulls
---

# C2: Profile before you trust

> **Synthetic data, not real hospital performance.** Patients and admissions are made up. The hospital names are real, so no number here says anything about a real hospital.

**Time box:** 25 min · **Techniques:** `SUMMARIZE`, `COLUMNS(*)`, `count(*) FILTER (WHERE …)`, `trim()`, `UNION ALL`

**Scenario.** `raw_2018` has every record, but the Director won't accept a brief built on columns nobody has looked at. Before cleaning anything, the team profiles the extract: where are the empty values, how many are hidden behind words like `TIADA`, and which values carry stray spaces?

**Input → output.** `raw_2018` (from C1) → **`profile_nulls`**, one row per measure, with these columns in this order:

`measure`, then one count per `raw_2018` column in `raw_2018`'s order: `no_mrn`, `no_kp`, `nama`, `tarikh_lahir`, `jantina`, `negeri`, `daerah`, `poskod`, `alamat`, `kod_fasiliti`, `tarikh_masuk`, `tarikh_keluar`, `status_discaj`, `dx_utama`, `dx_sekunder`, `dikemaskini`, `file`

## Look first

Profile every column in one line. On text columns, `min` and `max` compare strings, so look at what sorts first and last in `tarikh_lahir`, `tarikh_keluar`, `nama` and `negeri`, and at `null_percentage`.

```sql
SUMMARIZE raw_2018;
```

`COLUMNS(*)` applies one expression to every column. This counts the real NULLs in each:

```sql
SELECT count(*) FILTER (WHERE COLUMNS(*) IS NULL) FROM raw_2018;
```

## Definitions

- **measure** is one of three text labels, one row each:
  - `is_null`: the value `IS NULL`.
  - `null_spelling`: a word that means "nothing": `upper(trim(value))` is one of `'NULL'`, `'N/A'`, `'NA'`, `'-'`, `'TIADA'`, `'TIDAK DIKETAHUI'`, `'UNKNOWN'`.
  - `padded`: the value has a space or a non-breaking space (`chr(160)`) at the start or the end: `value <> trim(value, ' ' || chr(160))`.
- **Each count** is the number of `raw_2018` rows for which the measure holds in that column, as a `BIGINT` (what `count(*)` gives).
- A NULL is not a null spelling and not padded: those two measures don't count NULLs.
- **Tie-break:** none needed. Nothing is ranked, and row order doesn't matter to the Self-check.

## Example row

<!-- begin example-row -->
| measure | no_mrn | no_kp | nama | tarikh_lahir | jantina | negeri | daerah | poskod | alamat | kod_fasiliti | tarikh_masuk | tarikh_keluar | status_discaj | dx_utama | dx_sekunder | dikemaskini | file |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| null_spelling | 0 | 0 | 0 | 0 | 0 | 0 | 173 | 0 | 196 | 0 | 0 | 0 | 0 | 0 | 3932 | 0 | 0 |
<!-- end example-row -->

## Core and Stretch

| Tier | Task |
|---|---|
| Core | Create `profile_nulls` with its three rows, one `SELECT … FROM raw_2018` per measure stacked with `UNION ALL`, then run the Self-check. Which columns will need cleaning in C4 and C6? |
| S1 | For each column with null spellings, list each spelling as it is written and how often it appears, most frequent first. |
| S2 | `SUMMARIZE` showed placeholder dates. Count the birth dates that are `01/01/1900` or `01/01/1970`, and the discharge dates that are `31/12/9999`. |

## Self-check

Run this cell. **`0`** means you're done.

<!-- begin self-check -->
```sql
SELECT count(*) AS rows_differ
FROM ((SELECT * FROM profile_nulls
       EXCEPT SELECT * FROM 'expected/profile_nulls.parquet')
      UNION ALL
      (SELECT * FROM 'expected/profile_nulls.parquet'
       EXCEPT SELECT * FROM profile_nulls));
```

Anything else? This cell shows the differing rows: `yours` rows are in your table but not the expected one, `expected` rows the other way round.

```sql
SELECT * FROM (
  (SELECT 'yours' AS side, * FROM (SELECT * FROM profile_nulls
                                   EXCEPT SELECT * FROM 'expected/profile_nulls.parquet'))
  UNION ALL
  (SELECT 'expected' AS side, * FROM (SELECT * FROM 'expected/profile_nulls.parquet'
                                      EXCEPT SELECT * FROM profile_nulls)))
ORDER BY measure, side;
```
<!-- end self-check -->

The Self-check compares columns by position, so check your column order against the list above first.

## Checkpoint

Out of time? Load the expected result as your table and carry on:

<!-- begin checkpoint -->
```sql
CREATE OR REPLACE TABLE profile_nulls AS FROM 'expected/profile_nulls.parquet';
```
<!-- end checkpoint -->

## Reveal

The facilitator walks through `solutions/c02-profile.sql` after the time box. It is in your bundle now, if you'd rather check it yourself afterwards.
