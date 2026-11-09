# capstone_truth/: the Capstone's answers

**Facilitator only.** Not in the Setup or any Content release, and not shown to Participants until the Answer key reveal at 2.45 on Day 3. It ships in the final bundle (by 20 Nov). The Hint cards are in `capstone/hints.md`, which stays out of the releases too.

> **Synthetic data, not real hospital performance.**

| File | What it is |
|---|---|
| `readmit_2021.parquet` | Angle A: the true 2021 diabetes 30-day readmission by state (`state`, `index_episodes`, `readmissions`, `readmit_pct`). |
| `dengue_2021.parquet` | Angle B: the true 2021 dengue admissions per 100k by state (`state`, `dengue_admissions`, `adm_per_100k`). |
| `hospital_load_2021.parquet` | Angle C: the true 2021 load on each of the 166 hospitals (`state`, `facility_code`, `facility_name`, `admissions`, `bed_days`, `state_share_pct`, `state_rank`). |
| `check.sql` | The lunch-time diff: a team's summary Parquet against the truth. |
| `reference/` | The reference pipeline, in stages, and the three documented fixes. |

The three Parquet files are written by the generator (`./build.sh data`, `generator/capstone.sql`) straight from the clean truth, with the definitions the cards and `capstone/brief.md` state. They are not the output of any solution SQL, so they check the pipeline independently. `tests/capstone_defects.sh` proves that the reference pipeline matches them exactly with all three fixes, and doesn't without them.

## Over lunch: correctness

Download each team's summary Parquet from its Drive folder, then, from the repo root:

```sql
.read capstone_truth/check.sql
FROM check_readmit('team_A/readmit_2021.parquet');
FROM check_dengue('team_B/dengue_2021.parquet');
FROM check_load('team_C/hospital_load_2021.parquet');
```

Each gives `matches`, or how many state (hospital) rows differ. The diff reads the 2021 columns by the names the brief gives. A team that renamed or dropped a column gets a binder error: rename it in a copy and say so when you report the result. Correctness is reported at 2.45 apart from the peer scores, and never added to them.

## At 2.45: peer-review results

Type the slips into `capstone/scores.csv` and run `.read capstone/scores.sql` from the bundle folder. It lists any row to correct first (a team scoring itself, a score outside 1–4), then each team's average per criterion and the "did well" lines.

## The Answer key reveal

For each Angle: the true 2021 number, each team's `check.sql` result, its Held-back defect, and where that defect also touched the other Angles. The true numbers:

```sql
FROM 'capstone_truth/readmit_2021.parquet' ORDER BY readmit_pct DESC;
FROM 'capstone_truth/dengue_2021.parquet' ORDER BY adm_per_100k DESC;
FROM 'capstone_truth/hospital_load_2021.parquet' WHERE state_rank = 1 ORDER BY admissions DESC;
```

Every defect cell is in the Answer key (`generator/dq_answer_key.parquet`, `file LIKE 'data/capstone/%'`). The 2021 extract carries **only** these three defects: none of the taught ones. So a team's C1–C10 SQL, adapted to the 2021 files, cleans everything else as it is.

### ID06 → Angle A (readmission): non-MyKad identifiers

- **What:** patients without a MyKad (foreign workers and visitors, most in Sabah, some in Johor, Selangor, Kuala Lumpur and Labuan) are registered by passport or police/army number in the IC column: `A51234567`, `B1234567`, `RF123456`. Each keeps one number on every admission. They are all new patients in 2021.
- **What it does:** C6's `norm_mykad()` gives NULL for every one of them, so they become one "patient". C6 keeps only one of that patient's admissions per day, and C8 chains the rest into one year-long episode. Their diabetes index episodes and readmissions vanish: Sabah's index episodes fall by about a sixth, and its readmission rate by more than a point.
- **Symptom / how found:** sanity check 3 (distinct patients against ICs; admissions without a patient; one patient with hundreds of admissions).
- **Fix:** `reference/fix_id06.sql`: keep the document number as the patient key when there is no MyKad, in C6.
- **Touches the other Angles:** yes, all of them. The dropped same-day admissions lower dengue counts (B) and every hospital's admissions, most of all in Sabah (C).

### DX04 → Angle B (dengue): free-text diagnoses

- **What:** about a third of 2021 dengue principal diagnoses, and some pneumonia, gastroenteritis and UTI ones, are typed as text in Malay or English ("Demam denggi", "Dengue with warning signs", "Pneumonia"), in both systems.
- **What it does:** `norm_icd()` can't make a code of them, so they join no `ref_icd10` row and drop out of `scenario_group = 'dengue'`. 2021 dengue per 100k falls in almost every state, often by a third or more against 2020.
- **Symptom / how found:** C5's check on principal diagnoses that normalise to no `ref_icd10` code; the dengue rate against 2020 (sanity check 4 for the Angle's figure).
- **Fix:** `reference/fix_dx04.sql`: map each text to its code, in the RAW stage.
- **Touches the other Angles:** no. No diabetes diagnosis is typed as text, and the Angle C summary has no dengue column.

### DT02 → Angle C (hospital load): one hospital exports MM/DD

- **What:** Hospital Queen Elizabeth (`11-12060025`), Sabah's busiest, on the old HIS, writes every date month first (`MM/DD/YYYY`); the rest of the old HIS writes `DD/MM/YYYY`.
- **What it does:** C4 reads a day after the 12th as no date at all (NULL), and an earlier one as the wrong month, so some stays come out months long. The hospital's 2021 bed days come out at more than three times the truth and its 2020 figure, with no matching rise in admissions.
- **Symptom / how found:** sanity check 2 (NULL admit and discharge dates after C4, all from one facility); the hospital's bed days against 2020.
- **Fix:** `reference/fix_dt02.sql`: rewrite that hospital's dates day first, in the RAW stage, before C4.
- **Touches the other Angles:** a little, in Sabah only. Its patients' episodes break (A), and its undated dengue admissions drop out of the 2021 count (B).

## The reference pipeline

There is no model `pipeline.sql`. The test runs these stages in order, at a bundle root, in a fresh Work database: run them the same way to reproduce any number.

1. `reference/raw.sql`: the 2021 files into `admission_raw` (C1 and C3, adapted to the 2021 files).
2. `reference/fix_dt02.sql` and `reference/fix_dx04.sql`, on `admission_raw`.
3. `solutions/c04-fix-types.sql`, `c05-facilities.sql`, `c06-dedupe.sql`, unchanged.
4. `reference/fix_id06.sql`: C6's core statement with the ID06 fix.
5. `solutions/c07-hospital-load.sql`, `c08-episode.sql`, `c09-readmission.sql`, unchanged.
6. `reference/summary.sql`: the three Angle tables, written as Parquet and CSV.

Leave out step 2 or 4 to see what an unfixed team sees.
