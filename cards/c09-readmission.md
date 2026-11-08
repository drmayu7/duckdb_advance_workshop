---
id: c09
title: 30-day readmission
module: m3
timebox: 30 min
input: episode, data/open/ref_icd10.csv
output: readmit_state
---

# C9: 30-day readmission

> **Synthetic data, not real hospital performance.** Patients and admissions are made up. The hospital names are real, so no number here says anything about a real hospital.

**Time box:** 30 min · **Techniques:** `lead()`, `CREATE MACRO`, `count(*) FILTER (WHERE …)`, reusing a column alias in the same `SELECT`

**Scenario.** The Director's first question: how many diabetes patients come back within 30 days, by state? Now that a transfer is one episode, the team can count readmissions without counting transfers. But a patient who died can't be readmitted, and the three systems write "died" in more than one language.

**Input → output.** `episode` (from C8), with `data/open/ref_icd10.csv` → **`readmit_state`**, one row per state, with these columns in this order:

`state`, `index_episodes`, `readmissions`, `readmit_pct`

## Look first

How the discharge status is written:

```sql
SELECT discharge_status, count(*) AS episodes
FROM episode
GROUP BY ALL
ORDER BY episodes DESC;
```

## Definitions

- **`norm_status(s)`**: compare upper-case letters only (`regexp_replace(upper(s), '[^A-Z]', '', 'g')`, as C5's `state_key`), then map every spelling to one of four statuses:
  - `DISCHARGED`: Discharged, Discaj, Balik rumah, Home
  - `DIED`: Died, Death, Expired, Mati, Meninggal dunia
  - `TRANSFERRED`: Transferred, Transfer, Transferred out, Pindah, Dipindahkan, Pindah hospital
  - `AOR` (at own risk): AOR, At own risk, Discharge at own risk, Atas risiko sendiri, Discaj atas risiko sendiri
- **Diabetes index episode:** an episode whose `principal_dx` is in `ref_icd10`'s `scenario_group = 'diabetes'` (E10–E14), and whose `norm_status(discharge_status)` is not `DIED` (`IS DISTINCT FROM 'DIED'`: a missing status is not a death). Secondary diagnoses don't count (that's S1).
- **30-day readmission:** the patient's next episode, of any diagnosis, starts 1–30 days after the index episode's `episode_end`: `date_diff('day', episode_end, next_start) BETWEEN 1 AND 30`. Take the next start with `lead()` over all the patient's episodes, before you filter to the index episodes.
- **`state`**: the index episode's `state` (where the patient lives). **`index_episodes`** and **`readmissions`** count index episodes, all and readmitted. **`readmit_pct`** = `round(100 * readmissions / index_episodes, 1)`.
- **Tie-break:** a patient's episodes are ordered by `episode_start`, then `admission_id`. `episode_no` already is that order: no two episodes of a patient start on the same day, so the extract's missing `admission_id` is never needed.

## Example row

<!-- begin example-row -->
| state | index_episodes | readmissions | readmit_pct |
|---|---|---|---|
| SELANGOR | 3378 | 533 | 15.8 |
<!-- end example-row -->

## Core and Stretch

| Tier | Task |
|---|---|
| Core | Write `norm_status` and check that every spelling maps (no NULLs). Add each episode's next start with `lead()`, keep the index episodes, and count them and their readmissions by state. How many diabetes deaths would `discharge_status = 'DIED'` have missed? Run the Self-check. |
| S1 | Count diabetes as a secondary diagnosis too: join each episode to its first admission in `admission_clean` (`patient_key`, `admit_date = episode_start`), and test `list_has_any(string_split(secondary_dx, '; '), …)` against the diabetes codes. How many more index episodes is that? |
| S2 | Readmission by age band (under 50, 50–64, 65+) and by `los_days` (0–2, 3–6, 7+). Which way does each go? (`GROUP BY GROUPING SETS ((age_band), (los_band))` does both in one query.) |

## Self-check

Run this cell. **`0`** means you're done. `EXCEPT ALL` counts every copy of a row, so a missing or extra copy shows too.

<!-- begin self-check -->
```sql
SELECT count(*) AS rows_differ
FROM ((SELECT * FROM readmit_state
       EXCEPT ALL SELECT * FROM 'expected/readmit_state.parquet')
      UNION ALL
      (SELECT * FROM 'expected/readmit_state.parquet'
       EXCEPT ALL SELECT * FROM readmit_state));
```

Anything else? This cell shows the differing rows: `yours` rows are in your table but not the expected one, `expected` rows the other way round.

```sql
SELECT * FROM (
  (SELECT 'yours' AS side, * FROM (SELECT * FROM readmit_state
                                   EXCEPT ALL SELECT * FROM 'expected/readmit_state.parquet'))
  UNION ALL
  (SELECT 'expected' AS side, * FROM (SELECT * FROM 'expected/readmit_state.parquet'
                                      EXCEPT ALL SELECT * FROM readmit_state)))
ORDER BY state, side
LIMIT 50;
```
<!-- end self-check -->

The Self-check compares columns by position, so check your column order against the list above first. Your `index_episodes` are a little high? Some deaths are still in: check `norm_status`. Your `readmissions` are low? You probably filtered to diabetes before `lead()`, so a readmission for something else was skipped.

## Checkpoint

Out of time? Load the expected result as your table and carry on:

<!-- begin checkpoint -->
```sql
CREATE OR REPLACE TABLE readmit_state AS FROM 'expected/readmit_state.parquet';
```
<!-- end checkpoint -->

## Reveal

The facilitator walks through `solutions/c09-readmission.sql` after the time box. It is in your bundle now, if you'd rather check it yourself afterwards.
