---
id: c03
title: Combine three systems
module: m1
timebox: 30 min
input: raw_2018, data/raw/2019-*.json, data/raw/2020-*.parquet, data/raw/manifest.csv
output: admission_raw
---

# C3: Combine three systems

> **Synthetic data, not real hospital performance.** Patients and admissions are made up. The hospital names are real, so no number here says anything about a real hospital.

**Time box:** 30 min · **Techniques:** `read_json`, `read_parquet`, `DESCRIBE`, `UNION ALL BY NAME`, `COLUMNS(* EXCLUDE (…))`, `CAST` / `::`, `filename = true`

**Scenario.** The hospitals moved systems twice: the old HIS (2018, CSV), an interim system (2019, JSON) and the new system (2020, Parquet). Each export names and types its columns its own way. The brief needs all three years in one table, with every row saying which system it came from.

**Input → output.** `raw_2018` (from C1) + `data/raw/2019-*.json` + `data/raw/2020-*.parquet` → **`admission_raw`**, one row per record in all 36 files, every column as text, with these columns in this order:

`source_system`, `mrn`, `mykad`, `name`, `dob`, `sex`, `state`, `district`, `postcode`, `address`, `facility_code`, `admit_date`, `discharge_date`, `discharge_status`, `principal_dx`, `secondary_dx`, `updated_at`, `ward`, `admission_type`, `file`

## Load the manifest and look first

The manifest again, in case you did C1 from its Checkpoint:

```sql
CREATE OR REPLACE TABLE manifest AS
SELECT * FROM read_csv('data/raw/manifest.csv');
```

Compare the three systems' columns and types:

```sql
DESCRIBE FROM read_json('data/raw/2019-*.json');
```

```sql
DESCRIBE FROM 'data/raw/2020-*.parquet';
```

## Definitions

- **source_system**: `'old_his'` for the 2018 rows (from `raw_2018`), `'interim'` for 2019 (JSON) and `'new_his'` for 2020 (Parquet).
- **Column names** are the interim system's English names. The old HIS's Malay names map in order: `no_mrn` → `mrn`, `no_kp` → `mykad`, `nama` → `name`, `tarikh_lahir` → `dob`, `jantina` → `sex`, `negeri` → `state`, `daerah` → `district`, `poskod` → `postcode`, `alamat` → `address`, `kod_fasiliti` → `facility_code`, `tarikh_masuk` → `admit_date`, `tarikh_keluar` → `discharge_date`, `status_discaj` → `discharge_status`, `dx_utama` → `principal_dx`, `dx_sekunder` → `secondary_dx`, `dikemaskini` → `updated_at`.
- **Every column as text** (`VARCHAR`), with no cleaning: a value stays as its system wrote it, so 2018 dates stay `DD/MM/YYYY`. `read_json` types 2019's dates on its own: cast them back with `::VARCHAR`, which gives the text the file has.
- **2020's typed columns:** `dob` is a `DATE`, cast to text (`YYYY-MM-DD`). `admit_ts` and `discharge_ts` become `admit_date` and `discharge_date`: the date part only, `admit_ts::DATE::VARCHAR`.
- **ward** and **admission_type** exist only in 2020. They are NULL for the other two systems.
- **file**: the file name only, such as `2019-01.json`, from `filename = true` and `parse_filename(filename)`. For 2018 it is `raw_2018.file`.
- **Tie-break:** none needed. Nothing is ranked, and row order doesn't matter to the Self-check.

## Example row

<!-- begin example-row -->
| source_system | mrn | mykad | name | dob | sex | state | district | postcode | address | facility_code | admit_date | discharge_date | discharge_status | principal_dx | secondary_dx | updated_at | ward | admission_type | file |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| new_his | RN1827028 | 330425-13-9091 | IBRAHIM BIN SULAIMAN | 1933-04-25 | M | SABAH | KINABATANGAN | 90020 | NO 9, JALAN CENGAL 10 | 11-12210043 | 2020-01-17 | 2020-01-20 | DISCHARGED | J45.8 | E11.9; A09.9 | 2020-01-22 00:54:00 | MEDICAL | EMERGENCY | 2020-01.parquet |
<!-- end example-row -->

## Core and Stretch

| Tier | Task |
|---|---|
| Core | Create `admission_raw`: one `SELECT` per system, each renaming and casting to the columns above, stacked with `UNION ALL BY NAME`, then put the columns in order. Prove nothing was dropped: list every file whose row count in `admission_raw` differs from `manifest` (you want 0 rows). Then run the Self-check. |
| S1 | Show that the systems write dates differently: for each `source_system`, the smallest `dob`, `admit_date` and `updated_at`. Which ones will C4 have to parse? |
| S2 | Count rows per `source_system`, and how many have a `ward`. Why would plain `UNION ALL`, which matches columns by position, not work here? |

## Self-check

Run this cell. **`0`** means you're done.

<!-- begin self-check -->
```sql
SELECT count(*) AS rows_differ
FROM ((SELECT * FROM admission_raw
       EXCEPT SELECT * FROM 'expected/admission_raw.parquet')
      UNION ALL
      (SELECT * FROM 'expected/admission_raw.parquet'
       EXCEPT SELECT * FROM admission_raw));
```

Anything else? This cell shows the differing rows: `yours` rows are in your table but not the expected one, `expected` rows the other way round.

```sql
SELECT * FROM (
  (SELECT 'yours' AS side, * FROM (SELECT * FROM admission_raw
                                   EXCEPT SELECT * FROM 'expected/admission_raw.parquet'))
  UNION ALL
  (SELECT 'expected' AS side, * FROM (SELECT * FROM 'expected/admission_raw.parquet'
                                      EXCEPT SELECT * FROM admission_raw)))
ORDER BY file, mrn, admit_date, side
LIMIT 50;
```
<!-- end self-check -->

The Self-check compares columns by position, so check your column order against the list above first. If every row of one system differs, compare one `yours` row with its `expected` row, column by column.

## Checkpoint

Out of time? Load the expected result as your table and carry on:

<!-- begin checkpoint -->
```sql
CREATE OR REPLACE TABLE admission_raw AS FROM 'expected/admission_raw.parquet';
```
<!-- end checkpoint -->

## Reveal

The facilitator walks through `solutions/c03-combine.sql` after the time box. It is in your bundle now, if you'd rather check it yourself afterwards.
