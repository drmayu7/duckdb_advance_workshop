# Adding a Challenge

A Challenge is three files with one base name, plus an expected result. The tests enforce most of this; this page is the checklist, so the first run of `./build.sh test` is green rather than a tour of the failures.

## The files

- **`cards/<id>-<slug>.md`**: the card. `<id>` is `w`, `c01`…`c10`, or `t-…` for an Extension track; `tools/cards.sh` (`challenge_cards`) reads cards in that chain order.
- **`solutions/<id>-<slug>.sql`**: the canonical solution, which is also the Reveal. It runs in the Participant's Work database with the **bundle root** as the working directory, so paths are `data/raw/…`, `data/open/…`, and a `COPY … TO 'x'` writes `x` in the bundle root.
- **`expected/<output>.parquet`**: written by `./build.sh expected`, never by hand. It runs every solution in chain order in one fresh Work database (each Challenge's input is the previous one's output), in a scratch folder that sees `data/`.
- **A module test** that checks the expected result against `generator/truth/` and the Answer key (`tests/module2_cleaning.sql`, `tests/module3_brief.sql`), so a Self-check never certifies a wrong answer. Write its asserts first: they are the red step.

## The card

Copy the shape of a recent card (`cards/c09-readmission.md`). What the tests check (`tests/challenge_cards.sh`, `tests/solution_chain.sh`):

- **Front-matter** with `id`, `title`, `module`, `timebox`, `input`, `output`. `output` names the table and its expected Parquet.
- **The synthetic-data banner**, word for word.
- **Sections** `## Definitions`, `## Example row`, `## Core and Stretch`, `## Self-check`, `## Checkpoint`, `## Reveal`. The Definitions state a **tie-break** (the word must appear). The Core and Stretch table has `Core` and `S1` rows.
- **Example row**: inside `<!-- begin example-row -->` … `<!-- end example-row -->`. Its header is the output's columns in order, and the row must be a real row of the expected Parquet (`NULL` matches a NULL). Fill it in after `./build.sh expected`. Regenerating the data can change a row, so re-run the card test after `./build.sh data`.
- **Self-check**: copy the two cells verbatim and change only the table name and the `ORDER BY`. The first cell gives `rows_differ`, the second the differing rows by `side`. Both use `EXCEPT ALL` both ways.
- **Checkpoint**: exactly `CREATE OR REPLACE TABLE <output> AS FROM 'expected/<output>.parquet';`.
- **C5's macros**: a card that uses `norm_state()`, `norm_icd()` or their keys has a `<!-- begin macros -->` cell holding C5's solution macros verbatim, and its own solution creates them too. A Participant who loaded C5's Checkpoint has the table but not the macros.
- The **Warm-up** uses Series 1 SQL only.

## The chain

`tests/solution_chain.sh` runs, in a bundle copy:

- each solution, then the card's Self-check (must give 0);
- a wrong answer, which the Self-check must catch;
- the Checkpoint, which must bring it back to 0;
- each solution again from a fresh Work database holding only the earlier Checkpoints.

So a solution may read only the earlier outputs, `data/`, and objects it creates itself, never a helper table from an earlier solution.

An Extension track (`t-*`) catches up from the Warm-up and C1–C10 Checkpoints only, never another track's, because a Participant picks any two tracks in any order. So a track's solution may not read another track's output. A track that needs a community extension `LOAD`s it in its solution and its card (`stats_duck`, `rapidfuzz` and `splink_udfs` never autoload); `tests/extension_tracks.sql` is the tracks' module test.

## Generator defects

A defect the Challenge teaches goes in `generator/raw.sql`:

- Log it in `dq` before applying it, and pick only cells `free(rid, col)` allows.
- Put it before the AD01/AD02 copies, so the copies carry it.
- Add its code to the expected list in `tests/answer_key.sql`, with asserts for where it may appear.

Then `./build.sh data && ./build.sh expected`, and commit the regenerated `data/raw/`, `generator/` and `expected/` files with the change.
