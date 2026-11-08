---
id: c06
title: One row per real admission
module: m2
timebox: 30 min
input: admission_typed
output: admission_clean
---

# C6: One row per real admission

> **Synthetic data, not real hospital performance.** Patients and admissions are made up. The hospital names are real, so no number here says anything about a real hospital.

**Time box:** 30 min · **Techniques:** `CREATE MACRO`, `regexp_replace`, `lpad`, window functions, `row_number() OVER (PARTITION BY … ORDER BY …)`, `QUALIFY`, `EXCEPT ALL`

**Scenario.** Readmission counts patients, so the brief needs to know who is who. A patient has a different MRN at every hospital, their IC is written with dashes, spaces or none (and lost its leading zero in the old HIS), and their name is spelled several ways. Some admissions are in the extract twice: re-exported as exact copies, or as an older version that was corrected later. The team gives every patient one key and keeps one row per real admission: the latest version.

**Input → output.** `admission_typed` (from C4), with C5's macros → **`admission_clean`**, one row per real admission, with these columns in this order:

`source_system`, `patient_key`, `mrn`, `name`, `sex`, `dob`, `state`, `district`, `postcode`, `facility_code`, `admit_date`, `discharge_date`, `los_days`, `date_flag`, `discharge_status`, `principal_dx`, `secondary_dx`, `updated_at`, `ward`, `admission_type`, `file`

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

Records that are in the extract more than once, and how many versions each has:

```sql
SELECT mrn, facility_code, admit_date, count(*) AS records, count(DISTINCT updated_at) AS versions
FROM admission_typed
GROUP BY ALL
HAVING count(*) > 1
ORDER BY records DESC, mrn
LIMIT 10;
```

How ICs are written:

```sql
SELECT regexp_replace(regexp_replace(mykad, '[0-9]', '9', 'g'), ' ', '_', 'g') AS shape, count(*) AS n
FROM admission_typed
GROUP BY ALL
ORDER BY n DESC;
```

## Definitions

- **`norm_mykad(ic)`**: take the IC's digits only. 12 digits are a MyKad number. 9 to 11 digits are one whose leading zeros were lost when it was stored as a number (C1's ID02: someone born in 2000 loses two or three), so pad it to 12 with zeros on the left. Write it as `YYMMDD-PB-####`. Anything else gives NULL. Don't use the serial's first digit to work out the century: every workshop IC's serial starts with `9` (`YYMMDD-PB-9##G`), whatever the year of birth.
- **`patient_key`** = `norm_mykad(mykad)`. The `mykad` and `address` columns are not in the output.
- **Cleaned columns:** `state` = `norm_state(state)`, `principal_dx` = `norm_icd(principal_dx)`, and `name` and `district` in capitals with spaces and `chr(160)` trimmed from both ends: `upper(trim(x, ' ' || chr(160)))`. Names are not otherwise changed, so a patient may still have several spellings. That is why `patient_key` comes from the IC. Every other column is as in `admission_typed`.
- **A real admission** is one `(patient_key, admit_date)`: no patient is admitted twice on the same day.
- **Keep the latest version:** of the records of one real admission, keep the one with the latest `updated_at`.
- **Tie-break:** exact copies (re-exports) tie on `updated_at`, and they are identical, so keep either one. No two different versions share an `updated_at`.
- Flagged stays (`date_flag`) are kept. C8 decides what to do with them.

## Example row

<!-- begin example-row -->
| source_system | patient_key | mrn | name | sex | dob | state | district | postcode | facility_code | admit_date | discharge_date | los_days | date_flag | discharge_status | principal_dx | secondary_dx | updated_at | ward | admission_type | file |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| new_his | 000509-02-9154 | RN1930580 | PRIYA A/P VELU | F | 2000-05-09 | KEDAH | KUALA MUDA | 08010 | 11-02040020 | 2020-02-28 | 2020-02-25 | -3 | discharge_before_admit | DISCHARGED | A97.1 | J18.9 | 2020-03-03 00:30:00 | MEDICAL | EMERGENCY | 2020-02.parquet |
<!-- end example-row -->

## Core and Stretch

| Tier | Task |
|---|---|
| Core | Write `norm_mykad` and try it on `'850312105523'`, `'850312 10 9523 '` and `'50312109524'`. Create `admission_clean`: clean the columns, then keep one row per real admission with `QUALIFY row_number() OVER (…) = 1`. Compare the number of records, admissions, MRNs and patients, list a few patients with more than one name, then run the Self-check. |
| S1 | Find the ICs whose date part (the first six digits) is not a real date, or is not the patient's `dob` (compare the six digits as text with `strftime(dob, '%y%m%d')`: the IC has no century). |
| S2 | Find the ICs whose last digit has the wrong parity: odd for a man (`M`), even for a woman (`F`). What do S1 and S2 do to the number of patients? |

## Self-check

Run this cell. **`0`** means you're done. `EXCEPT ALL` counts every copy of a row, so a missing or extra copy shows too.

<!-- begin self-check -->
```sql
SELECT count(*) AS rows_differ
FROM ((SELECT * FROM admission_clean
       EXCEPT ALL SELECT * FROM 'expected/admission_clean.parquet')
      UNION ALL
      (SELECT * FROM 'expected/admission_clean.parquet'
       EXCEPT ALL SELECT * FROM admission_clean));
```

Anything else? This cell shows the differing rows: `yours` rows are in your table but not the expected one, `expected` rows the other way round.

```sql
SELECT * FROM (
  (SELECT 'yours' AS side, * FROM (SELECT * FROM admission_clean
                                   EXCEPT ALL SELECT * FROM 'expected/admission_clean.parquet'))
  UNION ALL
  (SELECT 'expected' AS side, * FROM (SELECT * FROM 'expected/admission_clean.parquet'
                                      EXCEPT ALL SELECT * FROM admission_clean)))
ORDER BY patient_key, admit_date, side
LIMIT 50;
```
<!-- end self-check -->

The Self-check compares columns by position, so check your column order against the list above first. Only `yours` rows, all with the same `patient_key` and `admit_date` as an expected row? Those are duplicates you kept: check the `ORDER BY` in your window.

## Checkpoint

Out of time? Load the expected result as your table and carry on:

<!-- begin checkpoint -->
```sql
CREATE OR REPLACE TABLE admission_clean AS FROM 'expected/admission_clean.parquet';
```
<!-- end checkpoint -->

## Reveal

The facilitator walks through `solutions/c06-dedupe.sql` after the time box. It is in your bundle now, if you'd rather check it yourself afterwards.
