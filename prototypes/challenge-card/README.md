# PROTOTYPE: Challenge card (wayfinder ticket #5). Throwaway, never merged to main.

**Question:** What should one Challenge look like to a Participant in the repo and the DuckDB UI: task wording, Core/Stretch tiers, how the Self-check works, and where the reveal's solution lives?

**Plan:** three structurally different cards for the same Challenge (1.3, 30-day readmissions with `lead()`/`QUALIFY`), run against ~4.5k synthetic admissions.

```bash
bash prototypes/challenge-card/run.sh A   # or B, or C
```

Each run prints the card, then plays a Participant who makes three common mistakes (kept deaths, counted from `admit_date`, used `LAG`) before getting it right, running that variant's Self-check after every attempt. The last line tells you how to open the same database in the DuckDB UI and try it by hand.

| | **A: Worksheet** | **B: Self-grading SQL file** | **C: One-screen card + checkpoint** |
|---|---|---|---|
| Card | Rich Markdown: Scenario, definitions table, example output row, collapsible hints | A `.sql` file; prose in comments, `-- %% CELL` blocks to paste | Fits one slide / A5 print |
| Self-check | Paste a fingerprint query, compare 3 numbers by eye | `FROM check_ch13_core();` → PASS/FAIL per check **with a targeted hint** | Diff against `expected/*.parquet` → `0 rows differ` |
| What failure tells you | Which number is off; you work out why | *Why* it's off ("count from discharge_date, not admit_date") | *Which rows* differ (noisy when one column is wrong) |
| Spoiler risk | Expected numbers only | Expected numbers only (inside macro) | Expected **rows** are readable (not the SQL) |
| Falling behind | Nothing: wait for the reveal | Nothing: wait for the reveal | Load the checkpoint, carry on to 1.4 |
| Reveal lives in | Collapsed `<details>` in the same page (visible in raw file) | Separate `solutions/` file, in the repo from the start | Pushed to repo after the walkthrough (needs internet/`git pull`) |
| Facilitator build cost per Challenge | Low: run fingerprint once, paste numbers | High: write macro + hints per Challenge, plus stub tables | Low: `COPY` solution output to Parquet |
| Needs in Offline bundle | Data only | `workshop.duckdb` with stubs + macros (file version-locked) | Data + `expected/` Parquet |

## Things the prototype surfaced (regardless of variant)

1. **DuckDB UI notebooks can't be opened from a file**: they live inside `~/.duckdb/extension_data/ui/ui.db` ([DuckDB UI post](https://duckdb.org/2025/03/12/duckdb-ui.html), "Footprint"). Every variant is paste-into-cells; one statement per block, since a cell shows only the last result.
2. **Table macros bind at creation** (DuckDB 1.5.5): `check_*` macros fail unless the answer table exists, so B needs empty stub tables shipped in the bundle. Bonus: `DESCRIBE ch13_readmit` shows Participants the target columns.
3. **Ties break Self-checks.** The first data build had same-day admissions for one patient; `admission_id` order (and so the answer) changed between runs: 606 vs 605. Fixed with a total order in the generator, but any Challenge whose window orders only by date can still be ambiguous, so the card must state the tie-break (`ORDER BY admit_date, admission_id`) and the dataset generator should avoid ties.
4. **Precise definitions are the card's most important part.** Every Self-check failure traced back to an ambiguity: "within 30 days" (inclusive?), from admission or discharge, deaths as index admissions.
5. Fingerprints use `md5(string_agg(format(...)))`, not `hash()`, so they stay the same across DuckDB versions.

Files: `setup.sql` (data), `solution.sql` (canonical answer), `mistakes/` (wrong attempts), `variant-*/` (the cards).
