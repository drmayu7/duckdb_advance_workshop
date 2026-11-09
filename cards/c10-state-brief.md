---
id: c10
title: State summary
module: m3
timebox: 35 min
input: admission_clean, hospital_load, readmit_state, data/open/dengue_state_age_2018_2021.csv, data/open/population_state.parquet
output: state_brief
---

# C10: State summary

> **Synthetic data, not real hospital performance.** Patients and admissions are made up. The hospital names are real, so no number here says anything about a real hospital.

**Time box:** 35 min · **Techniques:** `UNPIVOT … ON COLUMNS(* EXCLUDE …)`, `PIVOT … ON … USING …`, `QUALIFY`, `COPY … TO` Parquet and CSV (Stretch: Excel)

**Scenario.** The Director wants the State Health Brief on one page: one row per state, with the diabetes readmission rate, dengue per 100,000 people for each year, and the hospital that carries the most load. The MoH dengue table is wide, one column per state, so it has to be turned into rows before it can be joined, and the years turned back into columns for the brief. Then the team exports it.

**Input → output.** `admission_clean` (C6), `hospital_load` (C7) and `readmit_state` (C9), with the dengue CSV and DOSM population from `data/open/` → **`state_brief`**, one row per state, with these columns in this order, exported to `state_brief.parquet` and `state_brief.csv`:

`state`, `diabetes_index_episodes`, `diabetes_readmit_pct`, `dengue_adm_2018`, `dengue_adm_2019`, `dengue_adm_2020`, `dengue_cases_2018`, `dengue_cases_2019`, `dengue_cases_2020`, `top_hospital`, `top_hospital_share_pct`

## Start here: C5's macros

Did C5 from its Checkpoint, or in another Work database? Run this cell first (it is C5's solution, so it replaces yours if you have them):

<!-- begin macros -->
```sql
CREATE OR REPLACE MACRO state_key(s) AS regexp_replace(upper(s), '[^A-Z]', '', 'g');
CREATE OR REPLACE MACRO norm_state(s) AS
  CASE
    WHEN state_key(s) IN ('JOHOR', 'JOHORDARULTAKZIM', 'JHR') THEN 'JOHOR'
    WHEN state_key(s) IN ('KEDAH', 'KEDAHDARULAMAN', 'KDH') THEN 'KEDAH'
    WHEN state_key(s) IN ('KELANTAN', 'KELANTANDARULNAIM', 'KTN') THEN 'KELANTAN'
    WHEN state_key(s) IN ('MELAKA', 'MALACCA', 'MLK') THEN 'MELAKA'
    WHEN state_key(s) IN ('NEGERISEMBILAN', 'NSEMBILAN', 'NEGRISEMBILAN', 'NSN') THEN 'NEGERI SEMBILAN'
    WHEN state_key(s) IN ('PAHANG', 'PAHANGDARULMAKMUR', 'PHG') THEN 'PAHANG'
    WHEN state_key(s) IN ('PERAK', 'PERAKDARULRIDZUAN', 'PRK') THEN 'PERAK'
    WHEN state_key(s) IN ('PERLIS', 'PERLISINDERAKAYANGAN', 'PLS') THEN 'PERLIS'
    WHEN state_key(s) IN ('PULAUPINANG', 'PPINANG', 'PENANG', 'PNG') THEN 'PULAU PINANG'
    WHEN state_key(s) IN ('SABAH', 'SBH') THEN 'SABAH'
    WHEN state_key(s) IN ('SARAWAK', 'SWK') THEN 'SARAWAK'
    WHEN state_key(s) IN ('SELANGOR', 'SELANGORDARULEHSAN', 'SGR') THEN 'SELANGOR'
    WHEN state_key(s) IN ('TERENGGANU', 'TERENGGANUDARULIMAN', 'TRG') THEN 'TERENGGANU'
    WHEN state_key(s) IN ('WILAYAHPERSEKUTUANKUALALUMPUR', 'WPKUALALUMPUR', 'KUALALUMPUR', 'WPKL')
      THEN 'WILAYAH PERSEKUTUAN KUALA LUMPUR'
    WHEN state_key(s) IN ('WILAYAHPERSEKUTUANLABUAN', 'WPLABUAN', 'LABUAN') THEN 'WILAYAH PERSEKUTUAN LABUAN'
    WHEN state_key(s) IN ('WILAYAHPERSEKUTUANPUTRAJAYA', 'WPPUTRAJAYA', 'PUTRAJAYA') THEN 'WILAYAH PERSEKUTUAN PUTRAJAYA'
  END;

-- norm_icd (DX01): upper case, letters and digits only, then a dot after the
-- third character and at most one character after it: e119, E11.9 and E11.90
-- all become E11.9; I10 stays I10.
CREATE OR REPLACE MACRO icd_key(code) AS regexp_replace(upper(code), '[^A-Z0-9]', '', 'g');
CREATE OR REPLACE MACRO norm_icd(code) AS
  CASE WHEN code IS NOT NULL THEN concat_ws('.', icd_key(code)[1:3], nullif(icd_key(code)[4:4], '')) END;
```
<!-- end macros -->


## Look first

The dengue table as published:

```sql
FROM read_csv('data/open/dengue_state_age_2018_2021.csv') LIMIT 5;
```

The same table, one row per state:

```sql
UNPIVOT read_csv('data/open/dengue_state_age_2018_2021.csv')
ON COLUMNS(* EXCLUDE (TAHUN, "KUMPULAN UMUR"))
INTO NAME state VALUE cases
LIMIT 5;
```

## Definitions

- **States and years:** the 16 states, 2018–2020. `state` is the MoH name, as `norm_state()` gives it.
- **People:** DOSM `population_state.parquet` for the state and year (`date` = 1 January), with `sex = 'both'`, `age = 'overall'`, `ethnicity = 'overall'`. `population` is in thousands, so people = `round(population * 1000)`. Each year's rate uses that year's population. (District rates, in the Spatial track, use the 2020 population for every year: DOSM's district file starts in 2020.)
- **`dengue_adm_YYYY`**: dengue admissions in `admission_clean` that year (dengue as in C7: `scenario_group = 'dengue'`), by the state the patient lives in, per 100,000 people: `round(100000 * admissions / people, 1)`. `0` when a state has none.
- **`dengue_cases_YYYY`**: notified dengue cases in the dengue CSV (`TAHUN` is the year), summed over the age groups, per 100,000 people, rounded the same way. The CSV has no Putrajaya column, so Putrajaya's are NULL.
- **`diabetes_index_episodes`** and **`diabetes_readmit_pct`** are `readmit_state`'s `index_episodes` and `readmit_pct`.
- **`top_hospital`** and **`top_hospital_share_pct`**: the `facility_name` and `state_share_pct` of the state's `state_rank = 1` hospital in `hospital_load`.
- **Tie-break:** if two hospitals share rank 1, take the lower `facility_code`.
- **Export:** `state_brief` ordered by `state`, to `state_brief.parquet` and to `state_brief.csv` with a header row, in the bundle folder.

## Example row

<!-- begin example-row -->
| state | diabetes_index_episodes | diabetes_readmit_pct | dengue_adm_2018 | dengue_adm_2019 | dengue_adm_2020 | dengue_cases_2018 | dengue_cases_2019 | dengue_cases_2020 | top_hospital | top_hospital_share_pct |
|---|---|---|---|---|---|---|---|---|---|---|
| PERAK | 1352 | 16.1 | 4.8 | 4.4 | 4.6 | 109.3 | 128.6 | 106.8 | HOSPITAL RAJA PERMAISURI BAINUN | 20.8 |
<!-- end example-row -->

## Core and Stretch

| Tier | Task |
|---|---|
| Core | `UNPIVOT` the dengue CSV and sum it by state and year. Build a long table, one row per state and year, with the dengue admission rate and the notified rate. `PIVOT` it on year (`USING first(adm_per_100k) AS adm, first(cases_per_100k) AS cases` gives `2018_adm`, `2018_cases`, …), join `readmit_state` and each state's busiest hospital, and name the columns as above. Run the Self-check, then export and run the export check. |
| S1 | Export to Excel too: `LOAD excel;` then `COPY … TO 'state_brief.xlsx' (FORMAT xlsx, HEADER true)`. Open it, or read it back with `read_xlsx`. |
| S2 | What share of notified dengue cases ends up as an admission in the extract, by state, in 2020? Where is it highest? |

## Self-check

Run this cell. **`0`** means you're done. `EXCEPT ALL` counts every copy of a row, so a missing or extra copy shows too.

<!-- begin self-check -->
```sql
SELECT count(*) AS rows_differ
FROM ((SELECT * FROM state_brief
       EXCEPT ALL SELECT * FROM 'expected/state_brief.parquet')
      UNION ALL
      (SELECT * FROM 'expected/state_brief.parquet'
       EXCEPT ALL SELECT * FROM state_brief));
```

Anything else? This cell shows the differing rows: `yours` rows are in your table but not the expected one, `expected` rows the other way round.

```sql
SELECT * FROM (
  (SELECT 'yours' AS side, * FROM (SELECT * FROM state_brief
                                   EXCEPT ALL SELECT * FROM 'expected/state_brief.parquet'))
  UNION ALL
  (SELECT 'expected' AS side, * FROM (SELECT * FROM 'expected/state_brief.parquet'
                                      EXCEPT ALL SELECT * FROM state_brief)))
ORDER BY state, side
LIMIT 50;
```
<!-- end self-check -->

The Self-check compares columns by position, so check your column order against the list above first. Kuala Lumpur and Labuan have no notified rates? The CSV writes them `WP KUALA LUMPUR` and `WP LABUAN`: `norm_state()` the unpivoted names. A state is missing a year? Start the long table from the population, not from the admissions.

## Check your export

After the `COPY`, this cell reads both files back and compares them with the expected result. **`0`** and **`0`** means the export is right.

<!-- begin export-check -->
```sql
SELECT
  (SELECT count(*) FROM ((FROM 'state_brief.parquet' EXCEPT ALL FROM 'expected/state_brief.parquet')
                         UNION ALL (FROM 'expected/state_brief.parquet' EXCEPT ALL FROM 'state_brief.parquet'))) AS parquet_rows_differ,
  (SELECT count(*) FROM ((FROM read_csv('state_brief.csv') EXCEPT ALL FROM 'expected/state_brief.parquet')
                         UNION ALL (FROM 'expected/state_brief.parquet' EXCEPT ALL FROM read_csv('state_brief.csv')))) AS csv_rows_differ;
```
<!-- end export-check -->

## Checkpoint

Out of time? Load the expected result as your table and carry on:

<!-- begin checkpoint -->
```sql
CREATE OR REPLACE TABLE state_brief AS FROM 'expected/state_brief.parquet';
```
<!-- end checkpoint -->

## Reveal

The facilitator walks through `solutions/c10-state-brief.sql` after the time box. It is in your bundle now, if you'd rather check it yourself afterwards.
