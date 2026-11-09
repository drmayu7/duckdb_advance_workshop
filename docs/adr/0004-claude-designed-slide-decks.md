# Slide decks are Claude-designed scripts, not generated from Markdown

Everything else in the repo is single-sourced Markdown or SQL built by `build.sh`: cards, solutions, the guide (DOCX then PDF) and `cards.html`. Slides are the exception. Each deck (`refresher`, `m1`–`m4`, `closing`) is a committed pptxgenjs script, `slides/<deck>.js`, that Claude designs slide by slide in a session using the `pptx` skill, including speaker notes and the skill's visual QA. A shared `slides/theme.js` holds the theme, layouts and helpers. Running `node slides/<deck>.js` rebuilds a deck exactly without Claude. Changing a deck's content or design means a Claude session.

The facilitator chose this for design quality. A generic Markdown-to-PPTX converter gives every slide the same title and bullets, while the skill's value comes from choosing a layout and visual for each slide and checking the rendered result. The skill is instructions for Claude, not a library a build script can call.

## Considered options

- **Markdown outlines plus one generic `build.js`**: one source and no Claude needed, but uniform, text-heavy slides.
- **Claude regenerates decks through the skill every time, with nothing committed**: the best design, but not reproducible, and no record of the slides in the repo.
- **One committed, Claude-designed script per deck** (chosen).

## Consequences

- Repo content is still single-sourced where it matters: deck scripts read demo SQL from `demos/<deck>/*.sql`, and Challenge slides read each card's front-matter (`id`, `title`, `module`, `timebox`, `input`, `output`). A card's text is never copied into a deck.
- Framing, diagrams and callouts live only in the deck script. A typo fix in that text is a JavaScript edit.
- Speaker notes and Reveal points may name a card's key definitions as talking points (C4's date formats, C6's IC format). Only the card's own text is off-limits. If a card's definition changes, its deck's notes need the same edit, and no test catches it.
- The build machine needs Node with pinned `pptxgenjs`, plus LibreOffice for the skill's render-and-inspect QA.
