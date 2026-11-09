# State Health Brief 2021, Angle <A, B or C>: <the Director's question>

Team <A, B or C>: <names> · Driver: <name>

<!-- The headings are in talk order: 1 min, 3 min, 2 min, 1 min. Replace every <…>. -->

## 1. The answer to the Director

<One or two sentences with the 2021 number, and how it compares with 2020 (or 2018–2020) in one sentence: "In 2021, … . That is … than in 2020, because …".>

| <the 3–5 rows from your summary table that carry the answer> |
|---|

## 2. The data-quality story

- **Symptom:** <the number that looked wrong, and what it was compared with>
- **How we found it:** <the sanity check or query that pointed at it, and what narrowed it down>
- **The fix:** <what we changed, and in which stage of `pipeline.sql` (see its `-- DQ FIX:` comment)>
- **Before and after:** <the same number without and with the fix>

## 3. The pipeline

<The stages of `pipeline.sql`, one line each: what goes in and what comes out. Which C1–C10 SQL you re-used, and what you had to adapt for the 2021 files.>

- `-- RAW`: <…>
- `-- CLEAN`: <…>
- `-- SUMMARY`: <…>

The live query: <the one query you will run on screen, and what it shows>

## 4. One caveat

<One thing the Director should keep in mind when reading the number: what it doesn't cover, or what could still be wrong.>

---

> **Synthetic data, not real hospital performance.** Patients and admissions are made up. The hospital names are real, so no number here says anything about a real hospital.
