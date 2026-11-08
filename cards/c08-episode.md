---
id: c08
title: Episodes of care
module: m3
timebox: 30 min
input: admission_clean
output: episode
---

# C8: Episodes of care

> **Synthetic data, not real hospital performance.** Patients and admissions are made up. The hospital names are real, so no number here says anything about a real hospital.

**Time box:** 30 min · **Techniques:** gaps and islands: `lag()`, a running `sum(…) OVER (… ORDER BY …)`, `WINDOW`, `first(x ORDER BY …)`, `date_sub`

**Scenario.** A patient who is transferred leaves one hospital and is admitted to another the same day. The extract holds that as two admissions, so a readmission count would see the second one as a readmission. Before counting readmissions, the team joins each run of back-to-back stays into one **episode of care**.

**Input → output.** `admission_clean` (from C6) → **`episode`**, one row per episode, with these columns in this order:

`patient_key`, `episode_no`, `state`, `sex`, `age`, `episode_start`, `episode_end`, `los_days`, `admissions`, `first_facility`, `last_facility`, `principal_dx`, `discharge_status`

## Look first

Three patients who were transferred, admission by admission, with the days since their last discharge:

```sql
SELECT patient_key, facility_code, admit_date, discharge_date, discharge_status,
       admit_date - lag(discharge_date) OVER (PARTITION BY patient_key ORDER BY admit_date) AS days_since_last
FROM admission_clean
WHERE patient_key IN (SELECT patient_key FROM admission_clean
                      WHERE discharge_status IN ('TRANSFERRED', 'Pindah', 'Transfer')
                      ORDER BY patient_key LIMIT 3)
ORDER BY patient_key, admit_date;
```

## Definitions

- **A stay's end** is its `discharge_date`. If that is missing, or the stay has a `date_flag` (C4: its discharge date is wrong), the stay ends on its `admit_date`.
- **Episode:** an admission that starts on or before the previous admission's end + 1 day, at any hospital, continues the episode. Any other admission starts a new one. "Previous" means the same `patient_key`'s admission just before it.
- **`episode_no`**: 1 for a patient's first episode, then 2, 3, … in date order (`INTEGER`).
- **`episode_start`** is the first admission's `admit_date`, **`episode_end`** the latest stay end, **`los_days`** = `date_diff('day', episode_start, episode_end)`, and **`admissions`** the number of admissions in the episode.
- From the episode's **first admission**: `state`, `sex`, `first_facility` (its `facility_code`), `principal_dx`, and `age` = `date_sub('year', dob, episode_start)` (whole years). `age` is NULL when that admission's `dob` is.
- From the episode's **last admission**: `last_facility` and `discharge_status`, as `admission_clean` has them.
- **Tie-break:** a patient's admissions are ordered by `admit_date`, then `admission_id`. The extract has no `admission_id`, and it needs none: C6 left at most one admission per `patient_key` and `admit_date`.

## Example row

<!-- begin example-row -->
| patient_key | episode_no | state | sex | age | episode_start | episode_end | los_days | admissions | first_facility | last_facility | principal_dx | discharge_status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 050123-14-9130 | 2 | WILAYAH PERSEKUTUAN KUALA LUMPUR | F | 15 | 2020-05-17 | 2020-06-01 | 15 | 2 | 11-14010002 | 12-14010031 | J45.9 | DISCHARGED |
<!-- end example-row -->

## Core and Stretch

| Tier | Task |
|---|---|
| Core | Add each stay's end. Mark the admissions that start a new episode with `lag()`, then number the episodes with a running `sum()` of the marks. Group to one row per episode, taking the first and last admission's values with `first(x ORDER BY admit_date)` and `first(x ORDER BY admit_date DESC)`. Compare the number of admissions and episodes, count the episodes that span two hospitals, then run the Self-check. |
| S1 | Mean and median `los_days` by diagnosis group (`scenario_group` from `ref_icd10`), for episodes at one hospital and at more than one. |
| S2 | Why `date_sub('year', …)` and not `date_diff('year', …)`? Try both from `DATE '2000-12-31'` to `DATE '2001-01-01'`. |

## Self-check

Run this cell. **`0`** means you're done. `EXCEPT ALL` counts every copy of a row, so a missing or extra copy shows too.

<!-- begin self-check -->
```sql
SELECT count(*) AS rows_differ
FROM ((SELECT * FROM episode
       EXCEPT ALL SELECT * FROM 'expected/episode.parquet')
      UNION ALL
      (SELECT * FROM 'expected/episode.parquet'
       EXCEPT ALL SELECT * FROM episode));
```

Anything else? This cell shows the differing rows: `yours` rows are in your table but not the expected one, `expected` rows the other way round.

```sql
SELECT * FROM (
  (SELECT 'yours' AS side, * FROM (SELECT * FROM episode
                                   EXCEPT ALL SELECT * FROM 'expected/episode.parquet'))
  UNION ALL
  (SELECT 'expected' AS side, * FROM (SELECT * FROM 'expected/episode.parquet'
                                      EXCEPT ALL SELECT * FROM episode)))
ORDER BY patient_key, episode_no, side
LIMIT 50;
```
<!-- end self-check -->

The Self-check compares columns by position, so check your column order against the list above first. A few rows differ only in `age`, `state` or `sex`? `arg_min()` skips a NULL value and takes the next admission's; `first(x ORDER BY …)` does not. Episodes split where yours shouldn't be? Check the end you used for a flagged stay.

## Checkpoint

Out of time? Load the expected result as your table and carry on:

<!-- begin checkpoint -->
```sql
CREATE OR REPLACE TABLE episode AS FROM 'expected/episode.parquet';
```
<!-- end checkpoint -->

## Reveal

The facilitator walks through `solutions/c08-episode.sql` after the time box. It is in your bundle now, if you'd rather check it yourself afterwards.
