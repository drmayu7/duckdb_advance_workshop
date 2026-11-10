# Releasing content

A Content release (`duckdb-content-<id>.zip`) is complete in itself and carries every committed card, solution, expected result, extract and deck. The id is `YYYYMMDD-HHMM`: `07.00` on the day for a catch-up release, the build time for a mid-day hotfix (#34). The facilitator publishes; the agent builds and proves it.

## Steps

1. **Decks.** On a branch, `CONTENT_ID=<id> ./build.sh slides`, then commit `handouts/` with everything the release needs. The commit runs `./build.sh test` (10-minute timeout). Done when HEAD holds decks built for `<id>`.
2. **Build.** `CONTENT_ID=<id> ./build.sh content` writes `dist/duckdb-content-<id>.zip` from HEAD. It refuses decks that show another Content id; that means step 1 was skipped.
3. **Dry run.** `./build.sh dry-run dist/duckdb-bundle-20261109.zip dist/duckdb-content-<id>.zip [last card]`, on the Setup release Participants actually hold. Use the last card of the day being released (`c06` for Day 1), or none for the whole chain. Done when it prints `dry-run: OK`.
4. **Merge.** PR and merge, so `main` holds exactly what shipped.
5. **Publish (the facilitator).** The zip goes on the MyGovUC Drive folder and at least one USB stick. A mid-workshop release is announced in the room or group chat: close the UI before relaunching, and reload any bad Checkpoint. An emailed announcement must be inline-styled HTML, because MyGovUC mail strips `<style>`.

## Never in a release

The closing deck (#33) shows the repo URL, so it stays out of every Content release until after 2.45 on 13 Nov. `tests/content_release.sh` fails on any repo URL inside a deck.
