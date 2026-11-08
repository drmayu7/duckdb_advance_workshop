---
id: w
title: Reproduce last year's numbers
module: refresher
timebox: 25 min
input: data/warmup/admission_2017.parquet, data/warmup/patient_2017.parquet
output: warmup_state_summary
---

# Warm-up: Reproduce last year's numbers

> **Synthetic data, not real hospital performance.** Patients and admissions are made up. The hospital names are real, so no number here says anything about a real hospital.

**Time box:** 25 min · **Techniques:** `JOIN`, `GROUP BY`, `count(DISTINCT …)`, `CASE`, `round()` · Series 1 SQL only

**Scenario.** Before the Director's State Health Brief for 2018–2021, the team checks that it can reproduce last year's state summary. You get a clean 2017 extract: one row per admission, with the hospital's name and state already filled in, and one row per patient.

**Input → output.** `admission_2017` + `patient_2017` → **`warmup_state_summary`**, one row per state, with these columns in this order:

`state`, `admissions`, `patients`, `female_admissions`, `avg_los_days`, `deaths`

## Load the extract

Run these two cells first, from the DuckDB UI opened by the launcher:

```sql
CREATE OR REPLACE TABLE admission_2017 AS
SELECT * FROM 'data/warmup/admission_2017.parquet';
```

```sql
CREATE OR REPLACE TABLE patient_2017 AS
SELECT * FROM 'data/warmup/patient_2017.parquet';
```

## Definitions

- **state**: the hospital's state, `facility_state`. There are 16. Don't use `patient_2017.state`: that is where the patient lives.
- **admissions**: rows of `admission_2017`. Every row is one admission admitted in 2017.
- **patients**: the number of different `patient_id`s admitted in that state.
- **female_admissions**: admissions whose patient has `sex = 'F'` in `patient_2017`.
- **avg_los_days**: the average length of stay, `discharge_date - admit_date` in days, rounded with `round(…, 2)`. A same-day discharge counts as 0 days.
- **deaths**: admissions with `discharge_status = 'DIED'`.
- **Tie-break** (Stretch S2): the busiest hospital has the most admissions; if two tie, take the lower `facility_code`.
- Row order doesn't matter to the Self-check; sort by `state` to read it.

## Example row

<!-- begin example-row -->
| state | admissions | patients | female_admissions | avg_los_days | deaths |
|---|---|---|---|---|---|
| PERLIS | 50 | 33 | 19 | 3.26 | 1 |
<!-- end example-row -->

## Core and Stretch

| Tier | Task |
|---|---|
| Core | Create the table `warmup_state_summary` as above, then run the Self-check. |
| S1 | List the states whose average length of stay is above the national average (all 2017 admissions together). Hint: `HAVING` with a subquery. |
| S2 | For each state, find its busiest hospital: `state`, `facility_code`, `facility_name`, `admissions`. Hint: a CTE that counts per hospital. |

## Self-check

Run this cell. **`0`** means you're done.

<!-- begin self-check -->
```sql
SELECT count(*) AS rows_differ
FROM ((SELECT * FROM warmup_state_summary
       EXCEPT SELECT * FROM 'expected/warmup_state_summary.parquet')
      UNION ALL
      (SELECT * FROM 'expected/warmup_state_summary.parquet'
       EXCEPT SELECT * FROM warmup_state_summary));
```

Anything else? This cell shows the differing rows: `yours` rows are in your table but not the expected one, `expected` rows the other way round.

```sql
SELECT * FROM (
  (SELECT 'yours' AS side, * FROM (SELECT * FROM warmup_state_summary
                                   EXCEPT SELECT * FROM 'expected/warmup_state_summary.parquet'))
  UNION ALL
  (SELECT 'expected' AS side, * FROM (SELECT * FROM 'expected/warmup_state_summary.parquet'
                                      EXCEPT SELECT * FROM warmup_state_summary)))
ORDER BY state, side;
```
<!-- end self-check -->

The Self-check compares columns by position, so check your column order against the list above first.

## Checkpoint

Out of time? Load the expected result as your table and carry on:

<!-- begin checkpoint -->
```sql
CREATE OR REPLACE TABLE warmup_state_summary AS FROM 'expected/warmup_state_summary.parquet';
```
<!-- end checkpoint -->

## Reveal

The facilitator walks through `solutions/w-warmup.sql` after the time box. It is in your bundle now, if you'd rather check it yourself afterwards.
