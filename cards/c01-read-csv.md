---
id: c01
title: Read the 2018 CSVs safely
module: m1
timebox: 30 min
input: data/raw/2018-*.csv, data/raw/manifest.csv
output: raw_2018
---

# C1: Read the 2018 CSVs safely

> **Synthetic data, not real hospital performance.** Patients and admissions are made up. The hospital names are real, so no number here says anything about a real hospital.

**Time box:** 30 min · **Techniques:** `read_csv`, `sniff_csv`, `store_rejects` and `reject_errors`, `all_varchar`, `strict_mode`, `filename`, row-count checks against a manifest

**Scenario.** The State Health Brief starts from the Raw extract. In 2018 the hospitals were on the old HIS, which exported one CSV per month with Malay column names. Before anyone trusts a number, the team proves that reading the twelve files dropped nothing: every file must give exactly the rows that `data/raw/manifest.csv` says it holds.

**Input → output.** `data/raw/2018-01.csv` … `2018-12.csv` → **`raw_2018`**, one row per record in the files, every column as text, with these columns in this order:

`no_mrn`, `no_kp`, `nama`, `tarikh_lahir`, `jantina`, `negeri`, `daerah`, `poskod`, `alamat`, `kod_fasiliti`, `tarikh_masuk`, `tarikh_keluar`, `status_discaj`, `dx_utama`, `dx_sekunder`, `dikemaskini`, `file`

## Load the manifest and look first

Run these cells in order. Compare the first cell's two numbers.

```sql
CREATE OR REPLACE TABLE manifest AS
SELECT * FROM read_csv('data/raw/manifest.csv');
```

```sql
SELECT (SELECT count(*) FROM 'data/raw/2018-01.csv') AS rows_read,
       (SELECT rows FROM manifest WHERE file = '2018-01.csv') AS manifest_rows;
```

What did the CSV sniffer decide? Look at `Delimiter`, `Quote` and the number of columns.

```sql
SELECT Delimiter, Quote, HasHeader, len(Columns) AS columns
FROM sniff_csv('data/raw/2018-01.csv');
```

Read it again keeping the rejected lines. The rejects tables are temporary (they last only for this session), so keep a copy:

```sql
SELECT count(*) AS rows_read
FROM read_csv('data/raw/2018-01.csv', store_rejects = true);
```

```sql
CREATE OR REPLACE TABLE rejects_2018 AS
SELECT scan_id, line, error_type, csv_line FROM reject_errors;
```

```sql
SELECT error_type, count(*) AS lines FROM rejects_2018 GROUP BY error_type;
```

## Definitions

- **A record** is one admission row as the old HIS wrote it. Addresses can hold commas and line breaks inside quotes, so a record can span more than one line of the file: count records, never lines.
- **Some addresses break the CSV rules.** The old HIS put quotes inside a quoted address without doubling them, for example `"NO 5, JALAN "MAWAR" 3"`. Find the `read_csv` option that tolerates this (the error message for an explicit `quote = '"'` names it).
- **Every column as text** (`all_varchar = true`): `raw_2018` keeps each value exactly as the file has it, including `TIADA`, odd spaces and lost leading zeros. Types come in C4.
- **file**: the file name only, such as `2018-01.csv`, from `read_csv(…, filename = true)` and `parse_filename(filename)`. Don't keep the full path column.
- **Done** means: `raw_2018` has every file's manifest row count, and the Self-check gives 0.
- **Tie-break:** none needed. Nothing is ranked, and row order doesn't matter to the Self-check.

## Example row

<!-- begin example-row -->
| no_mrn | no_kp | nama | tarikh_lahir | jantina | negeri | daerah | poskod | alamat | kod_fasiliti | tarikh_masuk | tarikh_keluar | status_discaj | dx_utama | dx_sekunder | dikemaskini | file |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| RN3279283 | 360721-10-9874 | HIDAYAH BINTI IZZAT | 21/07/1936 | F | SELANGOR | KUALA SELANGOR | 45600 | NO 111, JALAN DURIAN 12 | 11-10072300 | 02/03/2018 | 15/03/2018 | DISCHARGED | J44.9 | NA | 17/03/2018 09:40 | 2018-03.csv |
<!-- end example-row -->

## Core and Stretch

| Tier | Task |
|---|---|
| Core | Create `raw_2018` from all twelve files in one `read_csv('data/raw/2018-*.csv', …)`, then prove nothing was dropped: list every 2018 file whose row count in `raw_2018` differs from `manifest` (you want 0 rows). Then run the Self-check. |
| S1 | Rejects per file: read all twelve files plainly with `store_rejects = true`, then count `reject_errors` per file by joining `reject_scans` on `scan_id` and `file_id`. The rejects tables keep every scan of the session, so count only the latest `scan_id`. |
| S2 | Some values had lost their leading zeros before the export: the old HIS once stored ICs and postcodes as numbers. Count the `no_kp` values that aren't 14 characters and the `poskod` values that aren't 5. |

## Self-check

Run this cell. **`0`** means you're done. `EXCEPT ALL` counts every copy of a row, so a missing or extra copy shows too.

<!-- begin self-check -->
```sql
SELECT count(*) AS rows_differ
FROM ((SELECT * FROM raw_2018
       EXCEPT ALL SELECT * FROM 'expected/raw_2018.parquet')
      UNION ALL
      (SELECT * FROM 'expected/raw_2018.parquet'
       EXCEPT ALL SELECT * FROM raw_2018));
```

Anything else? This cell shows the differing rows: `yours` rows are in your table but not the expected one, `expected` rows the other way round.

```sql
SELECT * FROM (
  (SELECT 'yours' AS side, * FROM (SELECT * FROM raw_2018
                                   EXCEPT ALL SELECT * FROM 'expected/raw_2018.parquet'))
  UNION ALL
  (SELECT 'expected' AS side, * FROM (SELECT * FROM 'expected/raw_2018.parquet'
                                      EXCEPT ALL SELECT * FROM raw_2018)))
ORDER BY file, no_mrn, tarikh_masuk, side
LIMIT 50;
```
<!-- end self-check -->

The Self-check compares columns by position, so check your column order against the list above first. Hundreds of differing rows usually mean a missing option: compare one `yours` row with its `expected` row.

## Checkpoint

Out of time? Load the expected result as your table and carry on:

<!-- begin checkpoint -->
```sql
CREATE OR REPLACE TABLE raw_2018 AS FROM 'expected/raw_2018.parquet';
```
<!-- end checkpoint -->

## Reveal

The facilitator walks through `solutions/c01-read-csv.sql` after the time box. It is in your bundle now, if you'd rather check it yourself afterwards.
