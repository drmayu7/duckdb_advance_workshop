> **PROTOTYPE, Variant A: "Worksheet".** Everything in one Markdown page: task, hints, Self-check numbers and a collapsed reveal. You read it on GitHub (or in the repo folder) and paste each SQL block into a DuckDB UI cell.

# Challenge 1.3: Who comes back within 30 days?

**Module:** Advanced SQL for wrangling (Day 1 AM) · **Time:** 35 min · **You'll practise:** `lead()`, named `WINDOW`, `QUALIFY`

## The Scenario so far

In Challenge 1.2 you cleaned the `admissions` table. Now the state health department wants to know how often patients are **readmitted within 30 days** of going home: a common quality-of-care indicator.

> The data is synthetic. Don't read clinical meaning into the results.

## Definitions (read these first: the Self-check depends on them)

| Term | Meaning |
|---|---|
| **Index admission** | Any admission where the patient did **not** die (`discharge_status <> 'Died'`). |
| **Next admission** | The same patient's next admission, ordered by `admit_date`, then `admission_id`. |
| **30-day readmission** | The next admission's `admit_date` is **0 to 30 days (inclusive)** after this admission's `discharge_date`. |

## Core (everyone)

Create a table `ch13_readmit` with **one row per index admission** and these columns, in this order:

| admission_id | patient_id | discharge_date | next_admit_date | days_to_readmit | readmit_30d |
|---|---|---|---|---|---|
| 5 | P000173 | 2024-01-03 | 2024-01-27 | 24 | true |

`readmit_30d` is never NULL: an admission with no next admission is `false`.

```sql
CREATE OR REPLACE TABLE ch13_readmit AS
-- your query here
;
```

<details><summary>Hint 1: which window function?</summary>

You need a value from the *next* row for the same patient: `lead(admit_date) OVER (PARTITION BY patient_id ORDER BY ...)`.
</details>

<details><summary>Hint 2: where do I drop the deaths?</summary>

If you drop them with `WHERE`, they disappear before the window runs. Drop them with `QUALIFY` so the window still sees every admission.
</details>

### Self-check (Core)

Paste this into a new cell and compare with the table below.

```sql
SELECT count(*)                AS index_admissions,
       count_if(readmit_30d)   AS readmissions,
       left(md5(string_agg(format('{}:{}', admission_id, readmit_30d), ',' ORDER BY admission_id)), 8) AS fingerprint
FROM ch13_readmit;
```

| index_admissions | readmissions | fingerprint |
|---|---|---|
| 4440 | 606 | `8a166ede` |

All three match → done. Counts match but fingerprint doesn't → you've flagged the wrong admissions.

## Stretch (if you finish early)

**S1. Planned readmissions don't count.** A readmission for chemotherapy (`primary_dx = 'Z51.1'`) is planned. Make `ch13_readmit_unplanned`: the Core columns plus `next_dx` (after `next_admit_date`) and `unplanned_30d` (last).

**S2. Which state is worst?** Make `ch13_by_state`: `state`, `index_admissions`, `unplanned_readmissions`, `rate_pct` (to 1 dp), highest rate first.

### Self-check (Stretch)

```sql
SELECT count_if(unplanned_30d) AS unplanned,
       left(md5(string_agg(format('{}:{}', admission_id, unplanned_30d), ',' ORDER BY admission_id)), 8) AS fingerprint
FROM ch13_readmit_unplanned;
```

```sql
FROM ch13_by_state LIMIT 1;
```

| unplanned | fingerprint | | top state | rate_pct |
|---|---|---|---|---|
| 567 | `2628b773` | | Sarawak | 14.3 |

## Reveal

<details><summary>Solution: open after the facilitator's walkthrough</summary>

```sql
CREATE OR REPLACE TABLE ch13_readmit AS
SELECT
    admission_id, patient_id, discharge_date,
    lead(admit_date) OVER w                           AS next_admit_date,
    next_admit_date - discharge_date                  AS days_to_readmit,
    coalesce(days_to_readmit BETWEEN 0 AND 30, false) AS readmit_30d
FROM admissions
WINDOW w AS (PARTITION BY patient_id ORDER BY admit_date, admission_id)
QUALIFY discharge_status <> 'Died'
ORDER BY admission_id;
```

Stretch solutions: see `../solution.sql`.
</details>
