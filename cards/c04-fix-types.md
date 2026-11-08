---
id: c04
title: Fix dates and numbers
module: m2
timebox: 30 min
input: admission_raw
output: admission_typed
---

# C4: Fix dates and numbers

> **Synthetic data, not real hospital performance.** Patients and admissions are made up. The hospital names are real, so no number here says anything about a real hospital.

**Time box:** 30 min · **Techniques:** `try_strptime` with a list of formats, `TRY_CAST`, `COLUMNS(*)` and `COLUMNS([...])`, `* EXCLUDE` / `* REPLACE`, `date_diff`, `CASE`

**Scenario.** `admission_raw` has every record, but as text. The Director's readmission and length-of-stay numbers need real dates. Each system wrote dates its own way, and some cells broke even that rule: another system's format, a number copied out of Excel, a two-digit year, a "not discharged yet" placeholder, or a stay that can't be right. The team types every date, and keeps (but flags) the stays it can't trust.

**Input → output.** `admission_raw` (from C3) → **`admission_typed`**, one row per `admission_raw` row, with these columns in this order:

`source_system`, `mrn`, `mykad`, `name`, `dob`, `sex`, `state`, `district`, `postcode`, `address`, `facility_code`, `admit_date`, `discharge_date`, `los_days`, `date_flag`, `discharge_status`, `principal_dx`, `secondary_dx`, `updated_at`, `ward`, `admission_type`, `file`

## Look first

What do the dates look like? This turns every digit into `9` and every letter into `a`, so each format shows up once:

```sql
SELECT source_system,
       regexp_replace(regexp_replace(admit_date, '[0-9]', '9', 'g'), '[A-Za-z]', 'a', 'g') AS shape,
       count(*) AS n
FROM admission_raw
GROUP BY ALL
ORDER BY source_system, n DESC;
```

`try_strptime` gives NULL instead of an error, and tries a list of formats in turn:

```sql
SELECT try_strptime('03.04.2018', ['%d/%m/%Y', '%Y-%m-%d', '%d.%m.%Y']) AS parsed;
```

Careful: `%Y` reads any number of digits.

```sql
SELECT strptime('03/04/18', '%d/%m/%Y') AS too_early;
```

## Definitions

- **Null spellings first.** In every column, a value whose `upper(trim(value))` is one of C2's null spellings (`'NULL'`, `'N/A'`, `'NA'`, `'-'`, `'TIADA'`, `'TIDAK DIKETAHUI'`, `'UNKNOWN'`) becomes NULL. Every other text value stays exactly as it is.
- **`dob`, `admit_date`, `discharge_date`** are `DATE`s. Read each value with the first of these formats that fits: `%d/%m/%Y`, `%Y-%m-%d`, `%d.%m.%Y`, `%Y%m%d`, `%d-%b-%Y` (as in `03-Apr-2018`). Day always comes before month: no system wrote `MM/DD`.
- **Excel serial numbers.** A value that is a whole number no format reads (such as `43193`) is an Excel day number: `DATE '1899-12-30' + n` (so `43193` is 2018-04-03).
- **Placeholders become NULL:** a date of `1900-01-01`, `1970-01-01` or `9999-12-31`.
- **A year before 1900 becomes NULL.** That is a two-digit year (`08/03/63`) that `%Y` read as year 63 AD. Stretch S1 recovers them.
- **`los_days`**: `date_diff('day', admit_date, discharge_date)`, a `BIGINT` (NULL when either date is NULL).
- **`date_flag`** marks a stay that can't be right, and the row is kept as it is: `'discharge_before_admit'` when `discharge_date < admit_date`, otherwise `'stay_365_days_or_more'` when `los_days >= 365`, otherwise NULL.
- **`updated_at`** is a `TIMESTAMP`: the old HIS wrote `%d/%m/%Y %H:%M`, the other two `%Y-%m-%d %H:%M:%S`.
- Every other column stays `VARCHAR`. Rows are not removed or de-duplicated (that is C6).
- **Tie-break:** none needed. Nothing is ranked, and row order doesn't matter to the Self-check.

## Example row

<!-- begin example-row -->
| source_system | mrn | mykad | name | dob | sex | state | district | postcode | address | facility_code | admit_date | discharge_date | los_days | date_flag | discharge_status | principal_dx | secondary_dx | updated_at | ward | admission_type | file |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| old_his | RN0029038 | 540421-13-9123 | LAU YONG MEI | 1954-04-21 | M | SARAWAK | SAMARAHAN | 94300 | NO 64, JALAN SETIA 7 | 11-13100024 | 2018-03-09 | 2018-03-11 | 2 | NULL | DISCHARGED | A90 | I50.9 | 2018-03-12 03:39:00 | NULL | NULL | 2018-03.csv |
<!-- end example-row -->

## Core and Stretch

| Tier | Task |
|---|---|
| Core | Create `admission_typed` in steps (a `WITH` per step works well): null spellings to NULL with `COLUMNS(*)`, then the dates and `updated_at`, then placeholders and pre-1900 years to NULL, then `los_days` and `date_flag` with the columns in order. Prove that every `admit_date` and `updated_at` was read (no NULLs), count the flagged stays, then run the Self-check. |
| S1 | Recover the two-digit birth years from `admission_raw` (all are old HIS `DD/MM/YY`). The file name gives the admit year: a two-digit year after the admit year's last two digits is 19YY, otherwise 20YY. Why is that safe for this extract but not for every dataset? |
| S2 | Which formats did each system really use, and how often? Use the shape query above on `dob` and `discharge_date` too. |

## Self-check

Run this cell. **`0`** means you're done. `EXCEPT ALL` counts every copy of a row, so a missing or extra copy shows too.

<!-- begin self-check -->
```sql
SELECT count(*) AS rows_differ
FROM ((SELECT * FROM admission_typed
       EXCEPT ALL SELECT * FROM 'expected/admission_typed.parquet')
      UNION ALL
      (SELECT * FROM 'expected/admission_typed.parquet'
       EXCEPT ALL SELECT * FROM admission_typed));
```

Anything else? This cell shows the differing rows: `yours` rows are in your table but not the expected one, `expected` rows the other way round.

```sql
SELECT * FROM (
  (SELECT 'yours' AS side, * FROM (SELECT * FROM admission_typed
                                   EXCEPT ALL SELECT * FROM 'expected/admission_typed.parquet'))
  UNION ALL
  (SELECT 'expected' AS side, * FROM (SELECT * FROM 'expected/admission_typed.parquet'
                                      EXCEPT ALL SELECT * FROM admission_typed)))
ORDER BY file, mrn, admit_date, side
LIMIT 50;
```
<!-- end self-check -->

The Self-check compares columns by position and type, so check your column order and that the dates are `DATE` (not `TIMESTAMP`) first. If only a few rows differ, look at their `dob` and `discharge_date`: one format or placeholder rule is usually missing.

## Checkpoint

Out of time? Load the expected result as your table and carry on:

<!-- begin checkpoint -->
```sql
CREATE OR REPLACE TABLE admission_typed AS FROM 'expected/admission_typed.parquet';
```
<!-- end checkpoint -->

## Reveal

The facilitator walks through `solutions/c04-fix-types.sql` after the time box. It is in your bundle now, if you'd rather check it yourself afterwards.
