# Adding a deck

A deck is one Claude-designed script, `slides/<deck>.js`, on the shared `slides/theme.js` (ADR 0004). `./build.sh slides` runs every deck in `SLIDE_DECKS` that exists and writes `handouts/<deck>.pptx`. Load the `pptx` skill before designing: it holds the pptxgenjs gotchas and the design rules the Day 1 decks follow.

## What the theme builds from the repo

Reuse these rather than writing the content into the script:

- **`challengeSlide(card, notes)`**: one per card, from front-matter only (`cardsOf("<module>")`), Extension track cards included (their badge is `STATS`, `NAMES`, `SPATIAL`). The deck tests expect exactly one slide per card holding its title, time box and output, so no other slide may hold all three.
- **`demoSlides("demos/<deck>/<file>.sql", { steps })`**: one slide per numbered step (`-- 1. …`), with the step's comment as the explanation and its SQL in full. SQL before step 1, or between `-- begin setup` and `-- end setup`, goes in the first step's notes (or on its own slide with `setupSlide`). Keep demo lines short enough to read: past about 9 lines the code moves beside the text.
- **`revealSlide`**, **`chainSlide`**, **`sectionSlide`**, **`titleSlide`**, and the setup-card slides (`setupCheckSlide`, `fixCodesSlide`, `fixProblemsSlide`, `contentIdSlide`).

Every slide takes speaker notes; the build fails without them. Notes and Reveal points may name a card's key definitions (ADR 0004), but never paste the card's text.

## Demo SQL

Each demo teaches its technique on other data (open data or values typed into the cell), so it gives away no Challenge answer. Add the deck to the loop in `tests/day1_demos.sh` or `tests/day2_demos.sh` so every demo runs on 1.5.6. A demo that needs more than the bundle (the S3 bucket, a Google sign-in) is skipped there, and says so in the test's header.

The S3 demo's backup slides read `demos/m3/s3-demo-backup.json`, its captured output: rows from the local `large/`, bytes from the live bucket. A dry run that captures new figures updates that file and rebuilds `m3`.

## Tests

The deck tests share `tests/lib/decks.sh`: `check_deck` (Challenge slides, demo steps, notes), `slide_with` for a deck's own required slides, `check_committed` and `check_no_repo_url`. A new deck's test sources it and adds only what is particular to that deck.

## The Content id

A deck with `contentIdSlide` needs `CONTENT_ID`, the id of the Content release that will carry it. The order is: `CONTENT_ID=<id> ./build.sh slides`, commit `handouts/`, then `CONTENT_ID=<id> ./build.sh content`.

## Visual QA

The tests check the text; looking at the slides is the QA. After each build:

1. `tools/render_deck.sh handouts/<deck>.pptx <scratch-dir>`, then read every `sheet-N.png` it prints (nine slides each), and a single `s-NN.jpg` for detail.
2. Run the `pptx` skill's validator on the deck (`uv run --with lxml --with defusedxml --with python-pptx --with pillow python <pptx-skill>/scripts/office/validate.py <deck>.pptx`).
3. Fix what you see in the script, rebuild, and re-render. Typical first-render faults: text wrapping mid-word in chips, code panels shrunk below ~13 pt by one long line, and boxes overlapping when a title wraps.
