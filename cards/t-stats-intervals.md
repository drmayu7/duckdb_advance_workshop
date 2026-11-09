---
id: t-stats
title: Statistics for health data
module: m4
timebox: 40 min
input: readmit_state, episode, data/open/ref_icd10.csv
output: readmit_ci
---

# Extension track: Statistics for health data

> **Synthetic data, not real hospital performance.** Patients and admissions are made up. The hospital names are real, so no number here says anything about a real hospital.

**Time box:** 40 min · **Extension:** `stats_duck` · **Techniques:** `LOAD`, `qnorm()`, `qbeta()`, `ttest_2samp()`, `table_one()`, an aggregate's result as a `STRUCT`

**Scenario.** The Director reads C9's table and asks: is Putrajaya's 20.4% really worse than Selangor's 15.8%, or is it just 49 index episodes? The team adds a 95% confidence interval to every state's rate, then answers a second question from the wards: do diabetes patients stay longer than dengue patients?

**Starts from:** the C8 and C9 Checkpoints (`episode`, `readmit_state`), so you can do this track whatever state your earlier work is in.

**Input → output.** `readmit_state` (from C9) → **`readmit_ci`**, one row per state, with these columns in this order:

`state`, `index_episodes`, `readmissions`, `readmit_pct`, `ci_low_pct`, `ci_high_pct`

## Look first

`stats_duck` is a community extension, so it never loads by itself. Load it, then try two of its R-style functions:

```sql
LOAD stats_duck;
```

```sql
SELECT qnorm(0.975) AS z, pnorm(1.96) AS p;
```

## Definitions

- **The 95% Wilson interval** (R's `prop.test(x, n, correct = FALSE)`). With `p = readmissions / index_episodes`, `n = index_episodes` and `z = qnorm(0.975)`:
  - centre = `(p + z^2 / (2 * n)) / (1 + z^2 / n)`
  - half-width = `z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / (1 + z^2 / n)`
  - **`ci_low_pct`**, **`ci_high_pct`** = `round(100 * (centre ∓ half-width), 1)`. Round only at the end.
- **`state`**, **`index_episodes`**, **`readmissions`**, **`readmit_pct`**: copied from `readmit_state` unchanged.
- **LOS comparison:** an episode's group is its `principal_dx`'s `scenario_group` in `ref_icd10`; compare `los_days` of every `diabetes` episode with every `dengue` episode (deaths included), with `ttest_2samp` (Welch's t-test).
- **Tie-break:** none needed: there is one row per state, and the Self-check ignores row order.

## Example row

<!-- begin example-row -->
| state | index_episodes | readmissions | readmit_pct | ci_low_pct | ci_high_pct |
|---|---|---|---|---|---|
| SELANGOR | 3378 | 533 | 15.8 | 14.6 | 17.0 |
<!-- end example-row -->

## Core and Stretch

| Tier | Task |
|---|---|
| Core | Build `readmit_ci` and run the Self-check. Which states have the widest intervals, and does Putrajaya's overlap Selangor's? Then compare length of stay: `ttest_2samp` is an aggregate over **two columns**, so give each row's `los_days` to the column of its group and `NULL` to the other (`CASE WHEN scenario_group = 'diabetes' THEN los_days END`, and the same for dengue). Its result is a `STRUCT`: pick `.mean_diff`, `.ci_lower`, `.ci_upper`, `.p_value`. You should find diabetes episodes stay **1.1 days** longer on average (95% CI 1.0 to 1.2 days). |
| S1 | The exact (Clopper-Pearson) interval, R's `binom.test`: low = `qbeta(0.025, x, n - x + 1)`, high = `qbeta(0.975, x + 1, n - x)`. Which states does it widen most? |
| S2 | Which states' intervals leave out the national rate (all readmissions over all index episodes)? |
| S3 | A clinical "Table 1": put the diabetes and dengue episodes' `los_days`, `age` and `sex` in a table, then `FROM table_one('that_table', variables := ['los_days', 'age', 'sex'], by := ['scenario_group'])`. (`table_one` reads a table by name, and can't see a `TEMP` table.) |

## Self-check

Run this cell. **`0`** means you're done. `EXCEPT ALL` counts every copy of a row, so a missing or extra copy shows too.

<!-- begin self-check -->
```sql
SELECT count(*) AS rows_differ
FROM ((SELECT * FROM readmit_ci
       EXCEPT ALL SELECT * FROM 'expected/readmit_ci.parquet')
      UNION ALL
      (SELECT * FROM 'expected/readmit_ci.parquet'
       EXCEPT ALL SELECT * FROM readmit_ci));
```

Anything else? This cell shows the differing rows: `yours` rows are in your table but not the expected one, `expected` rows the other way round.

```sql
SELECT * FROM (
  (SELECT 'yours' AS side, * FROM (SELECT * FROM readmit_ci
                                   EXCEPT ALL SELECT * FROM 'expected/readmit_ci.parquet'))
  UNION ALL
  (SELECT 'expected' AS side, * FROM (SELECT * FROM 'expected/readmit_ci.parquet'
                                      EXCEPT ALL SELECT * FROM readmit_ci)))
ORDER BY state, side
LIMIT 50;
```
<!-- end self-check -->

The Self-check compares columns by position, so check your column order against the list above first. Off by 0.1 here and there? You rounded `p` or the half-width before the end. Every interval far too narrow? Check you divided by `n` inside the square root, not by 100.

## Checkpoint

Out of time? Load the expected result as your table and carry on:

<!-- begin checkpoint -->
```sql
CREATE OR REPLACE TABLE readmit_ci AS FROM 'expected/readmit_ci.parquet';
```
<!-- end checkpoint -->

## Reveal

The facilitator walks through `solutions/t-stats-intervals.sql` after the time box. It is in your bundle now, if you'd rather check it yourself afterwards. `stats_duck` is young (2026): a habit worth keeping is to check one of its numbers against R before you trust it, as the Reveal does for Selangor.
