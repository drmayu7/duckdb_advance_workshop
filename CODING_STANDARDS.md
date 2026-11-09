# Coding standards

Read during review. These rules are judgement calls. Mechanical rules are checks in `tests/` (shellcheck, the version guard, the card checks), so they are not repeated here.

## Tests

A test checks what a Participant or the facilitator would see: a banner line, a row count, `0 rows differ`, a file that is or isn't in a zip. It does not check how a SQL file or launcher is written internally. Tests run on DuckDB 1.5.6 only. (From the spec, #16, "Testing".)

Card and handout text is what a Participant reads, so a test may grep it (for example the synthetic-data banner in `tests/challenge_cards.sh`). The same holds for a demo file's numbered steps (`-- 1. …`): each becomes a deck slide, so a deck test may read them.

One exception: when a test rewrites a file before running it, it may grep that file to guard the rewrite. For example, `tests/large_dataset.sh` swaps the S3 bucket for a local folder in `demos/m3/s3-demo.sql`, and it greps the bucket path first. That grep makes sure the swap still matches, so the offline run can never reach S3 by accident or test a different query. The test asserts what the rewritten file outputs, not how it is written.

A check over a set (slides, cards, files, rows) also asserts the set is not empty, so a broken build can't pass vacuously. The Day 1 deck test once printed `speaker notes on all 0 slides` for an empty deck.

`build.sh test` runs every `tests/*.sql` and `tests/*.sh` it finds. A new test file needs no wiring.
