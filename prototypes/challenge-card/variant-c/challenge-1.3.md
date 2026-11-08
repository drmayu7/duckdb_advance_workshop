> **PROTOTYPE, Variant C: "One-screen card + checkpoint".** Fits on one slide or a printed A5 card. The Self-check diffs your table against the answer table in the Offline bundle. The same file is a **checkpoint**: if you're stuck, load it and keep up with the Scenario. The solution SQL isn't in the repo until the facilitator pushes it after the reveal.

## 1.3 Who comes back within 30 days?  ·  35 min  ·  `lead()` `WINDOW` `QUALIFY`

**Input** `admissions` (your cleaned table from 1.2) → **Output** `ch13_readmit`
`admission_id, patient_id, discharge_date, next_admit_date, days_to_readmit, readmit_30d`

**Rule:** for each admission where the patient didn't die, find their next admission (by `admit_date`, then `admission_id`). `readmit_30d` is true when it starts 0–30 days after discharge; otherwise false, never NULL.

| | |
|---|---|
| **Core** | Build `ch13_readmit`. |
| **Stretch S1** | `ch13_readmit_unplanned`: add `next_dx`, `unplanned_30d` (chemo `Z51.1` is planned). |
| **Stretch S2** | `ch13_by_state`: `state, index_admissions, unplanned_readmissions, rate_pct` (1 dp). |

**✔ Check:** `0 rows differ` = done.

```sql
SELECT count(*) AS rows_differ FROM (
  (FROM ch13_readmit EXCEPT FROM 'expected/ch13_readmit.parquet')
  UNION ALL
  (FROM 'expected/ch13_readmit.parquet' EXCEPT FROM ch13_readmit));
```

Not zero? See which rows:

```sql
SELECT 'only in yours' AS side, * FROM (FROM ch13_readmit EXCEPT FROM 'expected/ch13_readmit.parquet')
UNION ALL
SELECT 'missing from yours', * FROM (FROM 'expected/ch13_readmit.parquet' EXCEPT FROM ch13_readmit)
ORDER BY admission_id, side LIMIT 20;
```

(Stretch: same queries with `ch13_readmit_unplanned` / `ch13_by_state`.)

**⏭ Stuck at the time limit?** Load the checkpoint so Challenge 1.4 works:

```sql
CREATE OR REPLACE TABLE ch13_readmit AS FROM 'expected/ch13_readmit.parquet';
```

**Reveal:** `solutions/challenge-1.3.sql` appears in the repo after the walkthrough.
