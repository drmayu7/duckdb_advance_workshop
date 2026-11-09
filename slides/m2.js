// Day 1, 2.00-4.30: Module 2, Data cleaning clinic (ADR 0004).
// node slides/m2.js  ->  handouts/m2.pptx
"use strict";

const { Deck, COLOR, FONT, W, MARGIN, cardsOf, cardLabel } = require("./theme");

const deck = new Deck({
  name: "m2",
  title: "Module 2: Data cleaning clinic",
  footer: "DuckDB Workshop Series 2 · Day 1 · Module 2: Data cleaning clinic",
});
const [c4, c5, c6] = cardsOf("m2");
const [, , c3] = cardsOf("m1");

// 1. Title
deck.titleSlide({
  kicker: "DAY 1 · MODULE 2 · 2.00 – 4.30",
  title: "Data cleaning clinic",
  subtitle: "From text you read to rows you can trust",
  meta: "TRY_CAST and try_strptime · regex and macros · window functions and QUALIFY",
  notes: `
Three cycles: C4 at 2.00, C5 at 2.50, C6 at 3.40, then the Day 1 wrap-up at 4.20.

Before starting, check everyone has admission_raw: anyone who didn't finish C3 loads its Checkpoint now (one cell on the C3 card). C4 starts from it.`,
});

// 2. Where we are
deck.chainSlide("From admission_raw to admission_clean", [c3, c4, c5, c6], `
Module 1 left every row of all three systems in admission_raw, all as text. This afternoon makes it trustworthy in three steps: real dates and numbers (C4), one clean hospital list plus the cleaning rules as macros (C5), and one row per real admission (C6).

admission_clean is where Day 2's analysis starts: hospital load, episodes of care, readmission.`, [
  { module: "m1", head: "From Module 1", body: "Every row, every column as text." },
  { module: "m2", head: "This afternoon", body: "Typed, cleaned with reusable rules, one row per real admission." },
]);

// 3. C4 idea: fail loud, fail quiet
{
  const s = deck.content("CAST fails loud; TRY_CAST fails quiet", `
The C4 cycle, 2.00. The key idea: on messy data, a cast that stops the query at the first bad value is useless; a cast that gives NULL lets you finish, then count and inspect what failed. "Quiet" is only safe if you count the NULLs afterwards.

try_strptime does the same for dates, and takes a list of formats: the first that fits wins. A whole number no format reads is often an Excel serial day number (day 0 is 1899-12-30).`);
  const half = deck.colWidth(2, 0.4);
  [
    { head: "CAST", sql: "CAST('tiada' AS INTEGER)", out: "Error: the whole query stops", fill: COLOR.coralTint, chip: COLOR.coral },
    { head: "TRY_CAST", sql: "TRY_CAST('tiada' AS INTEGER)", out: "NULL: the query finishes; count the NULLs", fill: COLOR.greenTint, chip: COLOR.green },
  ].forEach((b, i) => {
    const x = MARGIN + i * (half + 0.4);
    deck.panel(s, x, 1.45, half, 2.0, { fill: b.fill });
    deck.text(s, x + 0.3, 1.6, half - 0.6, 0.45, b.head, { fontFace: FONT.head, fontSize: 21, bold: true });
    deck.code(s, x + 0.3, 2.1, half - 0.6, 0.6, b.sql, { max: 16, valign: "middle" });
    deck.chip(s, x + 0.3, 2.85, half - 0.6, 0.45, b.out, { fill: b.chip, color: COLOR.white, fontFace: FONT.body, fontSize: 15 });
  });
  // try_strptime: the first format that fits
  deck.text(s, MARGIN, 3.75, 8, 0.4, "try_strptime(raw, [formats]): the first format that fits", { fontSize: 17, bold: true });
  const rows = [
    { raw: "03/04/2019", fmt: "%d/%m/%Y", out: "2019-04-03" },
    { raw: "2019-04-03", fmt: "%Y-%m-%d", out: "2019-04-03" },
    { raw: "03-Apr-2019", fmt: "%d-%b-%Y", out: "2019-04-03" },
    { raw: "43558", fmt: "Excel day number", out: "2019-04-03" },
  ];
  rows.forEach((r, i) => {
    const y = 4.3 + i * 0.6;
    deck.chip(s, MARGIN, y, 2.6, 0.45, r.raw, { fill: COLOR.mist, color: COLOR.text, fontSize: 15, bold: false });
    deck.arrow(s, MARGIN + 2.75, y + 0.225, 0.6);
    deck.chip(s, MARGIN + 3.5, y, 3.0, 0.45, r.fmt, { fill: i === 3 ? COLOR.amberTint : COLOR.tint, color: COLOR.text, fontSize: 15 });
    deck.arrow(s, MARGIN + 6.65, y + 0.225, 0.6);
    deck.chip(s, MARGIN + 7.4, y, 2.4, 0.45, r.out, { fill: COLOR.teal, color: COLOR.white, fontSize: 15 });
  });
  deck.panel(s, MARGIN + 10.1, 4.3, W - 2 * MARGIN - 10.1, 2.25, { fill: COLOR.amberTint });
  deck.text(s, MARGIN + 10.3, 4.4, W - 2 * MARGIN - 10.5, 2.05, "Same date, four spellings. Day always before month: no system wrote MM/DD.", { fontSize: 15, valign: "middle" });
}

// 4-7. Demo: types
deck.demoSlides("demos/m2/fix-types.sql", {
  label: "Demo",
  steps: {
    1: { title: "TRY_CAST gives NULL instead of an error", notes: `
If you like, first run CAST('tiada' AS INTEGER) on its own to show the error, then this cell. ' 95 ' casts fine (spaces at the ends are allowed); '1,156' doesn't: a thousands separator is not a number to DuckDB. Ask: how would you count how many values failed? (count(*) FILTER (WHERE TRY_CAST(...) IS NULL AND raw IS NOT NULL).)` },
    2: { title: "try_strptime: a list of formats", notes: `
Three spellings of the same date all read. 43558 matches no format, and 31/02/2019 is not a date: both NULL, which is what we want: they show up when we count.

C4 has five formats on its card, in a set order. Order matters when a value could fit two formats.` },
    3: { title: "Excel day numbers, and coalesce", notes: `
A date copied through Excel can arrive as its serial number. Day 0 is 1899-12-30, so 43558 is 2019-04-03. coalesce takes the first non-NULL: try the formats, then the Excel rule. "not yet" stays NULL.` },
    4: { title: "* REPLACE: typed columns in place", notes: `
* REPLACE swaps a column for its typed version without listing every other column, and keeps the order: important, because the Self-check compares columns by position. * EXCLUDE drops columns the same way. Hand over to C4.` },
  },
});

// 8-9. C4
deck.challengeSlide(c4, `
30 minutes, about 2.10 to 2.40. The card's definitions settle every case: null spellings first (C2's list), then the five date formats in order, Excel serials, placeholders to NULL, years before 1900 to NULL (a two-digit year read by %Y), and a date_flag for impossible stays, which are kept.

Common trap: %Y reads any number of digits, so 08/03/63 becomes year 63 AD rather than failing. The card's "year before 1900 becomes NULL" rule catches it; Stretch S1 recovers them.

Self-check differences in only a few rows usually mean one format missing or in the wrong order.`);

deck.revealSlide(c4, [
  { head: "Null spellings first", body: "C2's words that mean nothing become NULL in every column at once, before any typing." },
  { head: "Formats, then Excel", body: "try_strptime with the five formats in order; a whole number left over is an Excel day number." },
  { head: "Keep, but flag", body: "Placeholders and impossible years become NULL; impossible stays keep their row, with a date_flag." },
], `
10 minutes. Walk the solution's four numbered parts of the Core query. Then the proof cell: every admission and update date was read (want 0 and 0).

Point at the flagged stays: we keep them, because deleting rows hides problems; the flag lets the analysis decide. Stretch S2 (which formats each system really used, by the shape of the text) is a nice profiling trick to mention.`);

// 10. C5 idea: macros
{
  const s = deck.content("Write the rule once: a macro", `
The C5 cycle, about 2.50. Cleaning text is regex plus discipline. The discipline is writing each rule once, as a macro, so C6, the Capstone and next year's extract all clean the same way.

Regex essentials for today: \\s is a space, * means "any number of", [^A-Z] is "anything but a capital letter", ^ and $ anchor the start and end. regexp_replace changes only the first match unless you pass 'g'.`);
  // Many spellings -> one rule -> one value
  const raws = ["' 5 - 9'", "'5-9 '", "'5 -9'"];
  raws.forEach((r, i) => deck.chip(s, MARGIN, 1.65 + i * 0.68, 2.2, 0.5, r, { fill: COLOR.mist, color: COLOR.text, fontSize: 16, bold: false }));
  deck.arrow(s, MARGIN + 2.35, 2.58, 0.6, { color: COLOR.teal, width: 3 });
  deck.chip(s, MARGIN + 3.1, 2.2, 2.75, 0.8, "clean_age(s)", { fill: COLOR.teal, color: COLOR.white, fontSize: 20 });
  deck.arrow(s, MARGIN + 6.0, 2.58, 0.6, { color: COLOR.teal, width: 3 });
  deck.chip(s, MARGIN + 6.75, 2.33, 1.15, 0.55, "'5-9'", { fill: COLOR.amber, color: COLOR.ink, fontSize: 18 });
  deck.code(s, MARGIN, 3.85, 7.9, 1.25, "CREATE MACRO clean_age(s) AS\n  regexp_replace(trim(s), '\\s*-\\s*', '-');", { max: 16, valign: "middle" });
  deck.text(s, MARGIN, 5.3, 7.9, 1.3, "Written once, used on every table: this file, next year's file, the Capstone's.", { fontSize: 17 });
  // Regex cheat sheet
  const x = MARGIN + 8.4;
  const w = W - MARGIN - x;
  deck.panel(s, x, 1.55, w, 5.1, { fill: COLOR.tint });
  deck.text(s, x + 0.3, 1.7, w - 0.6, 0.45, "Regex in four symbols", { fontFace: FONT.head, fontSize: 20, bold: true });
  [
    ["\\s", "a space (or tab, line break)"],
    ["*", "any number of the thing before"],
    ["[^A-Z]", "anything but a capital letter"],
    ["^ $", "the start, the end"],
  ].forEach(([sym, mean], i) => {
    const y = 2.35 + i * 0.75;
    deck.chip(s, x + 0.3, y, 1.15, 0.48, sym, { fill: COLOR.white, color: COLOR.tealDark, fontSize: 16 });
    deck.text(s, x + 1.6, y, w - 1.9, 0.48, mean, { fontSize: 15, valign: "middle" });
  });
  deck.text(s, x + 0.3, 5.45, w - 0.6, 1.0, [
    { text: "regexp_replace", options: { fontFace: FONT.code } },
    { text: " changes the first match only, unless you pass ", options: {} },
    { text: "'g'", options: { fontFace: FONT.code } },
    { text: ".", options: {} },
  ], { fontSize: 15 });
}

// 11-14. Demo: text and macros
deck.demoSlides("demos/m2/clean-strings.sql", {
  label: "Demo",
  steps: {
    1: { title: "Look first: three spellings of an age group", notes: `
The MOH dengue file (real open data) writes its age groups three ways: 0-4, " 5 - 9" with spaces, and >75. The chars column gives the stray spaces away. A join or GROUP BY on these would quietly miss rows.` },
    2: { title: "trim and regexp_replace", notes: `
trim removes spaces at the ends; regexp_replace rewrites a pattern anywhere. \\s* means "any number of spaces", so " 5 - 9" becomes "5-9". Note >75 is still different: that's a rule, not a pattern.` },
    3: { title: "A macro is a rule with a name", notes: `
CREATE MACRO saves the rule in the Work database. CASE handles the special case (>75 becomes 75+), regexp_replace the pattern. It lives as long as the database, so tomorrow's cells can use it too.` },
    4: { title: "Use the rule", notes: `
The macro reads like a built-in function. One more lesson: text sorts "10-14" before "5-9", so sort by the number the group starts with.

Hand over to C5: the same tools on the MoH facility list and on the patient's state, written more than a hundred ways.` },
  },
});

// 15-16. C5
deck.challengeSlide(c5, `
30 minutes, about 3.00 to 3.30. Two jobs: clean the 166 hospitals in the MoH facility list (names broken over lines, double spaces, padded districts), and write the state and diagnosis-code rules as macros (norm_state, norm_icd) that C6 uses.

The card says how the macros must behave, including that an unknown spelling gives NULL. Check that every admission's state and diagnosis normalises (the card's macro checks want 0 rows).

The Checkpoint for C5 loads the table only, not the macros: anyone who loads it should run the macro cells from the solution before C6 (C6's solution repeats them).`);

deck.revealSlide(c5, [
  { head: "Clean the names once", body: "regexp_replace turns line breaks and runs of spaces into one space; trim the ends; one row per hospital." },
  { head: "Rules with names", body: "norm_state and norm_icd are macros: C6, the Capstone and next year's extract all use the same rules." },
  { head: "Unknown means NULL", body: "A spelling the macro doesn't know becomes NULL, so it shows up in a check instead of hiding." },
], `
10 minutes. Show the facility list as published first (the line breaks), then the clean table. Then the two macros: norm_state compares letters only, so case, spaces, dots and non-breaking spaces don't matter, then maps each known spelling.

Stretch S2 is a good discussion: one NEGERI spelling in the full list of 5,160 facilities can't be mapped to one state. Ask why mapping it would be wrong.`);

// 17. C6 idea: which row is the real one
{
  const s = deck.content("Which row is the real one?", `
The C6 cycle, about 3.40. Two kinds of duplicate: an exact copy (re-exported twice) and an older version that was corrected later. DISTINCT removes only the first kind.

The tool for "keep one per group" is a window function: row_number() numbers the rows inside each group in the order you choose, without collapsing them; QUALIFY keeps row 1, as HAVING does for aggregates. And EXCEPT ALL proves exactly what you removed.`);
  const rows = [
    { h: "Hospital Bentong", beds: "86", sent: "05 Apr 16.30", v: "1", keep: true },
    { h: "Hospital Bentong", beds: "80", sent: "02 Apr 10.00", v: "2", keep: false, why: "older version" },
    { h: "Hospital Raub", beds: "120", sent: "02 Apr 09.00", v: "1", keep: true },
    { h: "Hospital Raub", beds: "120", sent: "02 Apr 09.00", v: "2", keep: false, why: "exact copy" },
  ];
  const cols = [{ t: "hospital", w: 3.0 }, { t: "beds", w: 1.0 }, { t: "sent_at", w: 2.2 }, { t: "row_number()", w: 1.9 }];
  let cx = MARGIN;
  cols.forEach((c) => {
    deck.text(s, cx, 1.5, c.w, 0.35, c.t, { fontSize: 14, bold: true, color: COLOR.muted, fontFace: FONT.code });
    cx += c.w + 0.1;
  });
  rows.forEach((r, i) => {
    const y = 1.95 + i * 0.68 + (i >= 2 ? 0.2 : 0);
    const fill = r.keep ? COLOR.greenTint : COLOR.coralTint;
    deck.panel(s, MARGIN - 0.1, y - 0.05, 8.5, 0.58, { fill });
    let x = MARGIN;
    [r.h, r.beds, r.sent].forEach((v, j) => {
      deck.text(s, x, y, cols[j].w, 0.48, v, { fontSize: 15, valign: "middle", fontFace: j ? FONT.code : FONT.body });
      x += cols[j].w + 0.1;
    });
    deck.dot(s, x + 0.2, y + 0.02, 0.44, r.v, { fill: r.keep ? COLOR.green : COLOR.coral, fontSize: 15 });
    deck.text(s, x + 0.8, y, 1.6, 0.48, r.keep ? "keep" : r.why, { fontSize: 14, bold: true, valign: "middle", color: r.keep ? COLOR.green : COLOR.coral });
  });
  const x = MARGIN + 8.8;
  deck.panel(s, x, 1.5, W - MARGIN - x, 3.3, { fill: COLOR.mist });
  deck.text(s, x + 0.3, 1.65, W - MARGIN - x - 0.6, 0.8, "DISTINCT is not enough", { fontFace: FONT.head, fontSize: 19, bold: true });
  deck.text(s, x + 0.3, 2.5, W - MARGIN - x - 0.6, 2.2, "It removes the exact copy, but both Bentong versions differ, so both stay. Choosing the newest needs an order: a window function.", { fontSize: 15 });
  deck.code(s, MARGIN, 4.95, W - 2 * MARGIN, 1.7,
    "SELECT *\nFROM bed_return\nQUALIFY row_number() OVER (PARTITION BY hospital, return_date ORDER BY sent_at DESC) = 1;", { max: 17, valign: "middle" });
}

// 18-22. Demo: duplicates
deck.demoSlides("demos/m2/dedupe.sql", {
  label: "Demo",
  setupSlide: {
    title: "The data: three hospitals, five returns",
    notes: `
Run the setup cell (Participants can follow along). Five bed returns for 1 April: Raub's was sent twice, identically; Bentong's was corrected three days later (80 beds became 86). Ask the room: how many real returns are there? (Three.)`,
  },
  steps: {
    1: { title: "DISTINCT removes exact copies only", notes: `
Four rows: Raub's copy is gone, but both Bentong versions stay because they differ. DISTINCT can't know which version is right.` },
    2: { title: "row_number() numbers each group's rows", notes: `
PARTITION BY says what one group is (one hospital's return for one date); ORDER BY sent_at DESC puts the newest first. Unlike GROUP BY, every row stays, now with its number. Raub's two identical rows get 1 and 2: which is which doesn't matter, they're the same.` },
    3: { title: "QUALIFY keeps row 1", notes: `
QUALIFY filters on a window function, the way HAVING filters on an aggregate. One row per hospital and date, the latest. C6 does exactly this, with a patient key and admission date as the group and updated_at as the order.` },
    4: { title: "EXCEPT ALL: prove what you removed", notes: `
EXCEPT ALL keeps every copy, so it shows exactly the two rows that went: Raub's duplicate and Bentong's old version. Always look at what you removed. The Self-check uses the same EXCEPT ALL idea. Hand over to C6.` },
  },
});

// 23-24. C6
deck.challengeSlide(c6, `
30 minutes, about 3.50 to 4.20. Two steps: give every patient one key (the IC, cleaned: digits only, lost leading zeros restored, written YYMMDD-PB-####), then keep the latest version of each admission with QUALIFY.

Watch for: the card's definition of "one real admission" is (patient_key, admit_date), because a patient is never admitted twice on one day. And the C5 macros must exist in the Work database (Checkpoint users: run them from the solution).

This is the last Challenge of the day; let it run into the wrap-up if needed.`);

deck.revealSlide(c6, [
  { head: "One key per patient", body: "norm_mykad: digits only, pad lost leading zeros to 12, then write YYMMDD-PB-####. Anything else is NULL." },
  { head: "One row per admission", body: "(patient_key, admit_date) is one real admission; QUALIFY row_number() … ORDER BY updated_at DESC = 1." },
  { head: "Look at what went", body: "Count the rows removed and the people there really are; the same patient under several names shows up too." },
], `
10 minutes, or 5 if the day ran late. Show the "look first" cells (one person, several MRNs and IC spellings), then the Core query, then what de-duplication removed.

Stretch S1 and S2 (IC date part vs dob, and the odd/even last digit for sex) are checks a MyHDW analyst will recognise: mention them as take-home.`);

// 25. Wrap-up
{
  const s = deck.content("Day 1: what you built", `
4.20 to 4.30. Recap the chain: six tables, each proven. Everyone should leave with admission_clean and facility_clean in their Work database (or loaded from the Checkpoints): Day 2 starts from them.

Tomorrow: arrive by 9.00, drop the Day 2 Content release zip, unopened, into updates and relaunch, exactly like this morning. The id will be on the slide. Close the DuckDB UI and launcher before you leave, so the Work database is closed cleanly.`);
  const all = [...cardsOf("m1"), ...cardsOf("m2")];
  const gap = 0.25;
  const cw = deck.colWidth(all.length, gap);
  const longest = Math.max(...all.map((c) => c.output.length));
  const size = Math.min(15, Math.floor(((cw - 0.2) * 72) / (longest * 0.6)));
  all.forEach((c, i) => {
    const x = MARGIN + i * (cw + gap);
    deck.dot(s, x + cw / 2 - 0.35, 1.5, 0.7, cardLabel(c), { fontSize: 18, fill: COLOR.green });
    deck.chip(s, x, 2.4, cw, 0.6, c.output, { fill: COLOR.greenTint, color: COLOR.text, fontSize: size, margin: 2 });
  });
  const half = deck.colWidth(2, 0.4);
  deck.panel(s, MARGIN, 3.45, half, 3.2, { fill: COLOR.mist });
  deck.text(s, MARGIN + 0.35, 3.6, half - 0.7, 0.5, "The habits", { fontFace: FONT.head, fontSize: 21, bold: true });
  deck.text(s, MARGIN + 0.35, 4.15, half - 0.7, 2.4, [
    { text: "Count against the source", options: { bullet: true, breakLine: true } },
    { text: "Profile before you trust", options: { bullet: true, breakLine: true } },
    { text: "Fail quiet, then count the NULLs", options: { bullet: true, breakLine: true } },
    { text: "Write each rule once, as a macro", options: { bullet: true, breakLine: true } },
    { text: "Look at what you removed", options: { bullet: true } },
  ], { fontSize: 17, paraSpaceAfter: 6 });
  const x = MARGIN + half + 0.4;
  deck.panel(s, x, 3.45, half, 3.2, { fill: COLOR.amberTint });
  deck.text(s, x + 0.35, 3.6, half - 0.7, 0.5, "Tomorrow, 9.00", { fontFace: FONT.head, fontSize: 21, bold: true });
  deck.text(s, x + 0.35, 4.15, half - 0.7, 2.4, [
    { text: "Drop the Day 2 Content release, ", options: {} },
    { text: "unopened", options: { bold: true } },
    { text: ", into ", options: {} },
    { text: "updates", options: { fontFace: FONT.code } },
    { text: " and relaunch.", options: { breakLine: true } },
    { text: " ", options: { breakLine: true, fontSize: 8 } },
    { text: "Module 3 starts from admission_clean: hospital load, episodes of care, 30-day readmission.", options: {} },
  ], { fontSize: 17 });
}

// 26. Close
deck.sectionSlide({
  kicker: "4.30 · END OF DAY 1",
  title: "See you at 9.00",
  subtitle: "Close the DuckDB UI tab and the launcher window before you go",
  chips: cardsOf("m3").map((c) => `${cardLabel(c)} · ${c.output}`),
  notes: `
Leave this up as people pack. Closing the UI and launcher matters: the Work database is then closed cleanly, and tomorrow's launch won't report W2.

After the room empties: build and publish the Day 2 Content release by 07.00 (build.sh slides with its CONTENT_ID if the decks changed, commit, then build.sh content).`,
});

deck.write().catch((e) => {
  console.error(e);
  process.exit(1);
});
