# Capstone: the State Health Brief 2021

> **Synthetic data, not real hospital performance.** Patients and admissions are made up. The hospital names are real, so no number here says anything about a real hospital.

**Working time:** Day 2 3.40–4.30, Day 3 9.00–10.00 and 10.30–11.15 · **Presentations:** Day 3 11.15–12.15 · **Rubric:** `capstone/rubric.md`

**Scenario.** The Director liked the 2018–2020 State Health Brief, and now wants 2021. The 2021 export has just arrived. Most hospitals are now on the new system, but Sabah's hospitals still export from the old HIS. Your team answers **one question** of the brief, its **Angle**, from the raw 2021 files to a summary the Director can read. You have the SQL you wrote in C1–C10: re-run it and adapt it. The 2021 export is new, so don't assume it is as clean as the last one, or dirty in the same ways.

## Your team

There are three teams, one per Angle. The facilitator gives you your team and Angle at the kickoff.

| Angle | The Director's question | Your summary table |
|---|---|---|
| **A** | 30-day readmission among diabetes patients, by state, in 2021 | `readmit_2021` |
| **B** | Dengue admissions per 100,000 people, by state, in 2021 | `dengue_2021` |
| **C** | Which hospitals carry the admission load in 2021 | `hospital_load_2021` |

Suggested roles (not enforced): the **Driver** holds the team's official `pipeline.sql` and outputs on their laptop. A **data-quality investigator** or two load the same files on their own laptops and hunt for problems, then pass their fixes to the Driver. An **analyst/presenter** writes `brief.md` and leads the talk. Everyone speaks in the presentation.

## Input

| Files | What they are |
|---|---|
| `data/capstone/2021-01.parquet` … `2021-12.parquet` | The new system, one file per admit month: the same columns and types as `data/raw/2020-*.parquet` (`admit_ts`, `discharge_ts`, `ward`, `admission_type` …). Every hospital except Sabah's. |
| `data/capstone/2021-01-sabah.csv` … `2021-12-sabah.csv` | Sabah's hospitals, on the old HIS: the same Malay columns and date format as `data/raw/2018-*.csv`. |
| `data/capstone/manifest.csv` | `file`, `rows`: how many records each file holds. |
| `expected/*.parquet` | The 2018–2020 Checkpoints, for the "2020" column and in case an earlier piece of your SQL is broken. |
| `data/open/` | The open data you already know: population, facilities, `ref_icd10.csv`. |

## Definitions

The cards' definitions hold, with one change: **2021 stands on its own.** Episodes and readmissions use 2021 admissions only. An episode that started in 2020 is not in the extract, and a 2021 index episode is not followed into 2022.

- **Diabetes index episode** (C9): principal diagnosis in `scenario_group = 'diabetes'` (E10–E14), not ending in death. **30-day readmission**: the patient's next episode starts 1–30 days after the index episode ends. **Episode** (C8): an admission starting on or before the previous stay's end + 1 day, at any hospital, continues the episode.
- **Dengue** (C7, C10): `scenario_group = 'dengue'`, by where the patient lives. **Rate**: per 100,000 people, with DOSM's **2021** state population × 1000, rounded to 1 decimal place; 0 when a state has no dengue admissions.
- **Hospital load** (C7): every one of the 166 hospitals in `facility_clean`, with 0 for a hospital with no admissions. Bed days leave out stays that C4 flags.

## Your summary table

Build your Angle's table with **exactly these columns, in this order and with these names**. The facilitator checks every team's summary the same way, by column name, so a renamed column counts as missing.

**A · `readmit_2021`** (one row per state): `state`, `index_episodes`, `readmissions`, `readmit_pct`, `readmit_pct_2018_2020`
- The first four are C9's `readmit_state` for 2021. `readmit_pct_2018_2020` is `diabetes_readmit_pct` from the `state_brief` Checkpoint (C9 pooled 2018–2020).

**B · `dengue_2021`** (one row per state, all 16): `state`, `dengue_admissions`, `adm_per_100k`, `adm_per_100k_2020`
- `dengue_admissions` counts the state's 2021 dengue admissions; `adm_per_100k` is their rate. `adm_per_100k_2020` is `dengue_adm_2020` from the `state_brief` Checkpoint.

**C · `hospital_load_2021`** (one row per hospital, all 166): `state`, `facility_code`, `facility_name`, `admissions`, `bed_days`, `state_share_pct`, `state_rank`, `admissions_2020`, `bed_days_2020`
- The first seven are C7's `hospital_load` columns for 2021 (without `facility_type` and `dengue_admissions`). The last two count each hospital's 2020 admissions and bed days in the `admission_clean` Checkpoint (`year(admit_date) = 2020`).

Export it next to your Work database as both **Parquet** and **CSV**, as C10 did:

```sql
COPY readmit_2021 TO 'readmit_2021.parquet' (FORMAT parquet);
COPY readmit_2021 TO 'readmit_2021.csv' (HEADER true);
```

## Sanity checks

There is **no Self-check and no Checkpoint** for 2021: nobody has the right answer to compare with, which is how real work goes. Run these instead. Each one is a question a careful analyst asks before trusting a number. When one surprises you, that is your lead: find where it comes from (`GROUP BY file`, `facility_code`, `source_system` …) before you fix anything. They use the table names of the C1–C10 chain; rename them if yours differ.

**1. Row counts against the manifest** (after your RAW stage). Want 0 rows.

```sql
SELECT m.file, m.rows AS manifest_rows, count(a.file) AS rows_read
FROM read_csv('data/capstone/manifest.csv') AS m
LEFT JOIN admission_raw AS a ON a.file = m.file
GROUP BY m.file, m.rows
HAVING count(a.file) <> m.rows;
```

**2. NULL rates after typing** (after C4). Which columns have NULLs you didn't expect, and how many?

```sql
SELECT round(100 * count(*) FILTER (WHERE COLUMNS(* EXCLUDE (date_flag)) IS NULL) / count(*), 2)
FROM admission_typed;
```

**3. Distinct patients against distinct ICs** (after C6). Each person has one IC, so these should agree, and every admission should have a patient.

```sql
SELECT (SELECT count(DISTINCT mykad) FROM admission_typed) AS ics,
       (SELECT count(DISTINCT patient_key) FROM admission_clean) AS patients,
       (SELECT count(*) FROM admission_clean WHERE patient_key IS NULL) AS admissions_without_patient,
       (SELECT max(n) FROM (SELECT count(*) AS n FROM admission_clean GROUP BY patient_key)) AS most_admissions_one_patient;
```

**4. 2021 against 2020, by state** (after C6). A year rarely changes much: a state, or a hospital, that moves by a third or more needs an explanation before it goes to the Director.

```sql
WITH y2021 AS (SELECT state, count(*) AS admissions_2021 FROM admission_clean GROUP BY ALL),
     y2020 AS (SELECT state, count(*) AS admissions_2020 FROM 'expected/admission_clean.parquet'
               WHERE year(admit_date) = 2020 GROUP BY ALL)
SELECT state, admissions_2020, admissions_2021,
       round(100 * (admissions_2021 - admissions_2020) / admissions_2020, 1) AS change_pct
FROM y2020 FULL JOIN y2021 USING (state)
ORDER BY abs(change_pct) DESC NULLS FIRST;
```

Then do the same for your own Angle's figure: your summary's 2021 column against its 2020 column.

## Deliverables

Upload to your team's folder in the **"Capstone 2026"** MyGovUC Drive folder (`team_A/`, `team_B/` or `team_C/`) **by 11.15 on Day 3**. Investigators drop fix SQL into `team_X/scratch/`. Capstone files move through Drive only, never by USB.

1. **`pipeline.sql`**: runs top to bottom on a fresh Work database, from `data/capstone/` to your summary. It has three stage headers, `-- RAW`, `-- CLEAN` and `-- SUMMARY`, and a `-- DQ FIX:` comment on the fix for the data-quality problem you present (what it fixes, and why).
2. **Your summary table**, as `<table>.parquet` and `<table>.csv`.
3. **`brief.md`**, from `capstone/brief_template.md`: the answer to the Director, the data-quality story, the pipeline, one caveat, and the synthetic-data banner.
4. *Optional Stretch:* your summary written to a MyGovUC Sheet in your team folder with `gsheets` (`COPY … TO '<sheet URL>' (FORMAT gsheet)`, as in the Module 3 demo). It never costs marks.

## Presentation (7 minutes, then 3 minutes of questions)

Present from `brief.md` on screen, with one live query. **1 min** the answer → **3 min** the data-quality story (symptom → how you found it → the fix → the number before and after) → **2 min** a walk through the pipeline → **1 min** the caveat. Every member speaks. The other two teams score you with the rubric; peers don't score correctness. The facilitator compares every summary with the true 2021 figures over lunch and reports that separately, at 2.45.

## If you're stuck

By the end of Day 2, aim to have the extract loaded with row counts matching the manifest. If your team has not named a suspect by **10.30 on Day 3**, the facilitator will give you a Hint card. An earlier piece of SQL broken? Load its Checkpoint (`expected/`) and carry on.
