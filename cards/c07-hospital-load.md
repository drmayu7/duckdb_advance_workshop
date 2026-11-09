---
id: c07
title: Which hospitals carry the load
module: m3
timebox: 25 min
input: admission_clean, facility_clean, data/open/ref_icd10.csv
output: hospital_load
---

# C7: Which hospitals carry the load

> **Synthetic data, not real hospital performance.** Patients and admissions are made up. The hospital names are real, so no number here says anything about a real hospital.

**Time box:** 25 min · **Techniques:** `LEFT JOIN`, `count(*) FILTER (WHERE …)`, window functions over a `GROUP BY`: `sum(…) OVER (PARTITION BY …)`, `rank()`

**Scenario.** The Director's third question: which hospitals carry the admission load? The team counts each hospital's admissions, dengue admissions and bed days for 2018–2020, and ranks the hospitals within their state. Dengue needs care: some hospitals still code it the old way.

**Input → output.** `admission_clean` (from C6) and `facility_clean` (from C5), with `data/open/ref_icd10.csv` → **`hospital_load`**, one row per hospital, with these columns in this order:

`state`, `facility_code`, `facility_name`, `facility_type`, `admissions`, `dengue_admissions`, `bed_days`, `state_share_pct`, `state_rank`

## Look first

The dengue codes in the admissions:

```sql
SELECT principal_dx, count(*) AS n
FROM admission_clean
WHERE principal_dx LIKE 'A9%'
GROUP BY ALL
ORDER BY principal_dx;
```

What `ref_icd10` calls dengue:

```sql
SELECT icd10, title_en, scenario_group
FROM read_csv('data/open/ref_icd10.csv')
WHERE scenario_group = 'dengue';
```

## Definitions

- **A hospital** is a row of `facility_clean`: all 166, including any with no admissions (they get `0`). `state`, `facility_code`, `facility_name` and `facility_type` come from `facility_clean`, so `state` is where the hospital is.
- **`admissions`**: the hospital's rows in `admission_clean` (2018–2020).
- **Dengue** is a principal diagnosis whose `scenario_group` in `ref_icd10` is `'dengue'`: A97.x, plus the legacy codes A90 and A91 that WHO retired in 2016. **`dengue_admissions`** counts those.
- **`bed_days`**: the sum of `los_days` over the hospital's admissions with no `date_flag`. A flagged stay's length is wrong, and a stay with no `discharge_date` has none, so neither adds anything. `0` if nothing is left.
- **`state_share_pct`** = `round(100 * admissions / state_admissions, 1)`, where `state_admissions` is the sum of `admissions` over the hospitals of the same state.
- **`state_rank`**: `rank()` within the state, by `admissions`, highest first.
- **Tie-break:** hospitals with the same `admissions` in a state share a rank, and the next rank is skipped (`rank()`, not `row_number()`).

## Example row

<!-- begin example-row -->
| state | facility_code | facility_name | facility_type | admissions | dengue_admissions | bed_days | state_share_pct | state_rank |
|---|---|---|---|---|---|---|---|---|
| PERLIS | 11-09010003 | HOSPITAL TUANKU FAUZIAH | HOSPITAL NEGERI | 586 | 45 | 1994 | 100.0 | 1 |
<!-- end example-row -->

## Core and Stretch

| Tier | Task |
|---|---|
| Core | Count each hospital's admissions, dengue admissions and bed days in one `GROUP BY`, with `FILTER`. Start from `facility_clean` and `LEFT JOIN` the admissions, so every hospital is there. Add each hospital's share of its state's admissions and its rank in the state with window functions over the grouped rows. List the three busiest hospitals of each state, then run the Self-check. |
| S1 | Count dengue as `principal_dx LIKE 'A97%'` instead. Which hospitals lose the most dengue admissions? (These are the hospitals still using the legacy codes.) |
| S2 | A running total: `sum(admissions) OVER (PARTITION BY state ORDER BY state_rank, facility_code)`. How many hospitals, busiest first, carry half of each state's admissions? |

## Self-check

Run this cell. **`0`** means you're done. `EXCEPT ALL` counts every copy of a row, so a missing or extra copy shows too.

<!-- begin self-check -->
```sql
SELECT count(*) AS rows_differ
FROM ((SELECT * FROM hospital_load
       EXCEPT ALL SELECT * FROM 'expected/hospital_load.parquet')
      UNION ALL
      (SELECT * FROM 'expected/hospital_load.parquet'
       EXCEPT ALL SELECT * FROM hospital_load));
```

Anything else? This cell shows the differing rows: `yours` rows are in your table but not the expected one, `expected` rows the other way round.

```sql
SELECT * FROM (
  (SELECT 'yours' AS side, * FROM (SELECT * FROM hospital_load
                                   EXCEPT ALL SELECT * FROM 'expected/hospital_load.parquet'))
  UNION ALL
  (SELECT 'expected' AS side, * FROM (SELECT * FROM 'expected/hospital_load.parquet'
                                      EXCEPT ALL SELECT * FROM hospital_load)))
ORDER BY state, facility_code, side
LIMIT 50;
```
<!-- end self-check -->

The Self-check compares columns by position, so check your column order against the list above first. Only `dengue_admissions` differs? Check how you decide what is dengue. Every row differs? Check `state_share_pct`: `100 * admissions / …` divides as decimals in DuckDB, so don't cast to an integer.

## Checkpoint

Out of time? Load the expected result as your table and carry on:

<!-- begin checkpoint -->
```sql
CREATE OR REPLACE TABLE hospital_load AS FROM 'expected/hospital_load.parquet';
```
<!-- end checkpoint -->

## Reveal

The facilitator walks through `solutions/c07-hospital-load.sql` after the time box. It is in your bundle now, if you'd rather check it yourself afterwards.
