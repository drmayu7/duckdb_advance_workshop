// Day 1, 9.00-10.00: setup check and Series 1 refresher (ADR 0004).
// node slides/refresher.js  (CONTENT_ID=YYYYMMDD-HHMM)  ->  handouts/refresher.pptx
"use strict";

const { Deck, COLOR, FONT, W, MARGIN, cardsOf, cardLabel } = require("./theme");

const deck = new Deck({
  name: "refresher",
  title: "Day 1: setup check and Series 1 refresher",
  footer: "DuckDB Workshop Series 2 · Day 1 · Setup check and refresher",
});

// 1. Title
deck.titleSlide({
  kicker: "DAY 1 · WEDNESDAY 11 NOVEMBER · 9.00",
  title: "Setup check and Series 1 refresher",
  subtitle: "Bengkel Aplikasi SQL and Data Wrangling Menggunakan DuckDB, Siri 2",
  meta: "DuckDB 1.5.6 · synthetic MyHDW-like data, not real patient records",
  notes: `
Leave this up from 8.30 while people arrive, then switch to the next slide (the Content id) so latecomers can check their banner.

Welcome. Three days, one running story: the team builds a State Health Brief from a messy hospital extract. Today is reading and cleaning; tomorrow analysis and extensions; Friday the Capstone.

Housekeeping: breaks at 10.00 and lunch at 1.00. Everything runs offline from the bundle folder; the network is needed only to open the DuckDB UI page.`,
});

// 2. Content id
deck.contentIdSlide(`
Keep this slide up from 8.30 to 9.00. Everyone compares the last line of their launcher window with this id.

If the id differs or says "Content none", the Content release zip did not reach updates (or was unzipped). Hand out the USB stick: copy the zip, unopened, into the updates folder inside duckdb-bundle, close the DuckDB UI tab and the launcher window, then relaunch.

U1 or C1 on the banner: same fix, from USB. If that still fails, the Fix sheet's fallback is to extract the zip by hand over the bundle folder.`);

// 3. Setup check
deck.setupCheckSlide(`
9.00 to 9.20. Read the steps once, then walk the room. The first cell reads the Warm-up extract, so a row back proves the UI, the working folder, the Content release and the data together.

Sticky notes: green and red on every table. Count the reds at 9.10 and work through them with the Fix sheet (next two slides). Experienced Participants were seated across the room on purpose: ask them to help their neighbours.

At 9.20 start the refresher whatever the count. Anyone still red pairs with a neighbour for the Warm-up; visit them during the Warm-up time box.`);

// 4-5. Fix sheet
deck.fixCodesSlide(`
The launcher prints every failing code, not just the first, so a Participant can fix them all in one pass. Each tile shows what to try first; the next fallback is on the setup card in cards.html.

Most common in practice: W2 (the UI from yesterday is still open: close it and relaunch) and F1 (bundle under OneDrive, Desktop or Documents: move it to the user folder before writing any tables).

V1 means they started some other duckdb they installed themselves. Always start with start-workshop in the bundle folder.`);

deck.fixProblemsSlide(`
Problems the banner can't name. The UI not loading is the big one on the venue network: switch to a phone hotspot just to open the UI page, then the hotspot can go off. Don't reload the tab without it.

Government laptops with SSL inspection: only if their IT allows it, use the certificate-verification setting from the setup card; otherwise the CLI runs the same card SQL. Last resort for anything: pair with a neighbour and fix it at the break.

Three USB sticks hold the pre-extracted folder for anyone with no bundle at all.`);

// 6. Day 1 at a glance
{
  const s = deck.content("Day 1 at a glance", `
The day follows the pipeline the Capstone uses: read the raw extract, then clean it. Every Challenge's output is the next one's input, all in the Work database (my_work.duckdb), which keeps every table from day to day.

Module 1 reads three years of monthly files from three hospital systems and proves nothing was dropped. Module 2 turns that text into typed, clean, de-duplicated admissions. By 4.30 everyone has admission_clean, the table tomorrow's analysis starts from.`);
  const blocks = [
    { time: "9.00", head: "Setup check and refresher", sub: "Series 1 SQL, then a Warm-up", ids: cardsOf("refresher") },
    { time: "10.30", head: "Module 1: Reading raw data safely", sub: "CSV, JSON and Parquet from three systems", ids: cardsOf("m1") },
    { time: "2.00", head: "Module 2: Data cleaning clinic", sub: "Types, text, macros and duplicates", ids: cardsOf("m2") },
    { time: "4.30", head: "Day 1 wrap-up", sub: "What you built, and tomorrow", ids: [] },
  ];
  const gap = 0.3;
  const bw = deck.colWidth(4, gap);
  const axisY = 1.95;
  s.addShape(deck.shapes.LINE, { x: MARGIN, y: axisY, w: W - 2 * MARGIN, h: 0, line: { color: COLOR.line, width: 2 } });
  blocks.forEach((b, i) => {
    const x = MARGIN + i * (bw + gap);
    deck.chip(s, x, axisY - 0.3, 1.25, 0.6, b.time, { fill: i === 3 ? COLOR.ink : COLOR.teal, color: COLOR.white, fontFace: FONT.head, fontSize: 20 });
    deck.panel(s, x, 2.6, bw, 3.9, { fill: COLOR.mist });
    deck.text(s, x + 0.25, 2.8, bw - 0.5, 1.15, b.head, { fontFace: FONT.head, fontSize: 21, bold: true });
    deck.text(s, x + 0.25, 3.95, bw - 0.5, 0.85, b.sub, { fontSize: 15, color: COLOR.muted });
    b.ids.forEach((c, j) => {
      deck.chip(s, x + 0.25 + j * 0.8, 5.15, 0.7, 0.5, cardLabel(c), { fill: COLOR.amber, color: COLOR.ink, fontFace: FONT.head, fontSize: 16 });
    });
    if (!b.ids.length) deck.text(s, x + 0.25, 5.15, bw - 0.5, 0.5, "Breaks 10.00 and 1.00", { fontSize: 14, color: COLOR.muted, valign: "middle" });
  });
}

// 7. How every Challenge runs
{
  const s = deck.content("How every Challenge runs", `
This is the rhythm for all three days, so say it once clearly. A short demo on different data; then the Challenge card; then the Reveal.

The Self-check is how they know they're right without waiting for the facilitator: one cell on the card compares their table with the expected result. 0 rows differ means done. Anything else, the second cell shows which rows.

Out of time is normal, not failure. The Checkpoint loads the expected result as their table, so the next Challenge still works. Solutions are already in the bundle (solutions/), kept apart from the cards: they choose whether to look early.`);
  const steps = [
    { head: "Demo", time: "~10 min", body: "The technique, on other data. Watch, or follow along." },
    { head: "Challenge", time: "25-30 min", body: "Follow the card in cards.html. Core first; Stretch if you finish." },
    { head: "Self-check", time: "1 cell", body: "0 rows differ from the expected result means done." },
    { head: "Reveal", time: "~10 min", body: "The solution, walked through. It is in solutions/ already." },
  ];
  const gap = 0.45;
  const bw = deck.colWidth(4, gap);
  steps.forEach((st, i) => {
    const x = MARGIN + i * (bw + gap);
    deck.panel(s, x, 1.55, bw, 3.05, { fill: i === 2 ? COLOR.greenTint : COLOR.mist });
    deck.dot(s, x + 0.25, 1.8, 0.6, i + 1, { fill: i === 2 ? COLOR.green : COLOR.teal });
    deck.text(s, x + 1.0, 1.8, bw - 1.15, 0.6, st.head, { fontFace: FONT.head, fontSize: 22, bold: true, valign: "middle" });
    deck.text(s, x + 0.25, 2.6, bw - 0.5, 0.4, st.time, { fontSize: 15, bold: true, color: COLOR.teal });
    deck.text(s, x + 0.25, 3.05, bw - 0.5, 1.4, st.body, { fontSize: 15 });
    if (i < 3) deck.arrow(s, x + bw + 0.07, 3.05, gap - 0.14, { color: COLOR.teal, width: 2.5 });
  });
  // The Checkpoint escape hatch
  deck.panel(s, MARGIN, 4.95, W - 2 * MARGIN, 1.6, { fill: COLOR.amberTint });
  deck.text(s, MARGIN + 0.35, 5.1, 3.0, 1.3, "Behind? Load the Checkpoint", { fontFace: FONT.head, fontSize: 22, bold: true, valign: "middle" });
  deck.text(
    s, MARGIN + 3.55, 5.1, 3.85, 1.3,
    "It loads the expected result as your table, so the next Challenge still works. The card has the cell.",
    { fontSize: 15, valign: "middle" },
  );
  deck.code(s, MARGIN + 7.65, 5.2, W - 2 * MARGIN - 7.95, 1.1, "CREATE OR REPLACE TABLE t AS\nFROM 'expected/t.parquet';", { max: 16, valign: "middle" });
}

// 8. Section: refresher
deck.sectionSlide({
  kicker: "9.20 · SERIES 1 REFRESHER · 40 MIN",
  title: "The SQL you already know",
  subtitle: "Four queries on real open data, then the Warm-up Challenge on the 2017 admissions",
  chips: ["WHERE", "GROUP BY", "HAVING", "JOIN", "WITH", "subquery"],
  notes: `
Not a re-teach: a reminder of Series 1, three months on, and a first run of the UI on a cell that does real work.

The four queries use the MoH bed counts and DOSM population (real open data in data/open). The Warm-up then uses the same ideas on the clean 2017 admissions. About 10 minutes of demo, 25 of Warm-up, 5 of Reveal.`,
});

// 9. The order a query runs in
{
  const s = deck.content("One query, in the order DuckDB runs it", `
Written order is SELECT first; run order is FROM first. This is why a column alias from SELECT can't be used in WHERE (in standard SQL), why WHERE filters rows before grouping and HAVING filters the groups after.

DuckDB is friendlier than Series 1 needed: you can start a query with FROM, and GROUP BY ALL groups by every non-aggregate column. We'll meet both in the Modules.`);
  const clauses = [
    { k: "FROM / JOIN", d: "which rows, from which tables or files" },
    { k: "WHERE", d: "keep some rows" },
    { k: "GROUP BY", d: "one row per group" },
    { k: "HAVING", d: "keep some groups" },
    { k: "SELECT", d: "the columns you want" },
    { k: "ORDER BY", d: "sort" },
    { k: "LIMIT", d: "the first n" },
  ];
  const gap = 0.22;
  const cw = deck.colWidth(clauses.length, gap);
  clauses.forEach((c, i) => {
    const x = MARGIN + i * (cw + gap);
    deck.chip(s, x, 1.75, cw, 0.75, c.k, { fill: i === 0 ? COLOR.teal : COLOR.tint, color: i === 0 ? COLOR.white : COLOR.tealDark, fontSize: 14 });
    deck.text(s, x, 2.7, cw, 0.9, c.d, { fontSize: 14, align: "center", color: COLOR.muted });
  });
  deck.arrow(s, MARGIN, 3.75, W - 2 * MARGIN, { color: COLOR.teal, width: 2.5 });
  deck.text(s, MARGIN, 3.85, 4, 0.35, "run order", { fontSize: 13, color: COLOR.teal, bold: true });
  // CTE and subquery: tables you make on the way
  const half = deck.colWidth(2, 0.4);
  [
    { head: "WITH (a CTE)", body: "Names a query so the next one can read it like a table. Read top to bottom.", sql: "WITH beds AS (...)\nSELECT ... FROM beds" },
    { head: "A subquery", body: "A query inside a query: one value, or a table, computed first.", sql: "WHERE beds >\n  (SELECT avg(beds) ...)" },
  ].forEach((b, i) => {
    const x = MARGIN + i * (half + 0.4);
    deck.panel(s, x, 4.55, half, 2.1, { fill: COLOR.mist });
    deck.text(s, x + 0.3, 4.7, half - 0.6, 0.45, b.head, { fontFace: FONT.head, fontSize: 20, bold: true });
    deck.text(s, x + 0.3, 5.2, 2.3, 1.3, b.body, { fontSize: 14 });
    deck.code(s, x + 2.8, 5.2, half - 3.1, 1.2, b.sql, { max: 13, valign: "middle" });
  });
}

// 10-13. Demo
deck.demoSlides("demos/refresher/series1-recap.sql", {
  label: "Demo",
  steps: {
    1: {
      title: "Reading a file like a table",
      notes: `
Paste the cell into the UI and run it. No CREATE TABLE: DuckDB reads the CSV in place. Point at the type it guessed for beds_nonicu (DOUBLE): the sniffer decided that, and Module 1 is about when to trust it.

Hospital Kuala Lumpur tops the list with 1,672 non-ICU beds.`,
    },
    2: {
      title: "WHERE filters rows, HAVING filters groups",
      notes: `
Ask the room before running: which states have more than 2,000 beds? Sarawak is first, not Selangor: Sarawak has more, smaller hospitals.

Then ask: what would change if the condition went in WHERE instead? (It would filter hospitals, not states, and it can't use sum.)`,
    },
    3: {
      title: "A CTE and a JOIN: beds per 10,000 people",
      notes: `
Two named steps, then a join on state. DOSM's file is in thousands, hence the * 1000. Both files happen to write states the same way, so the join just works. Module 2 is about the files where that isn't true.

Putrajaya leads by far: a small population with a large hospital that serves people from elsewhere. A good reminder that a rate needs the right denominator.`,
    },
    4: {
      title: "A subquery: above the average hospital",
      notes: `
The inner query runs first and gives one number; the outer query compares every hospital with it. Note the WHERE beds_nonicu > 0 inside: hospitals with no beds figure would drag the average down.

Hand over to the Warm-up next: same ideas, on the 2017 admissions.`,
    },
  },
});

// 14-15. Warm-up Challenge and Reveal
const [warmup] = cardsOf("refresher");
deck.challengeSlide(warmup, `
25 minutes. Open cards.html and go to the Warm-up card. It loads two Parquet files into the Work database first, then asks for one row per state.

Only Series 1 SQL is needed: JOIN, GROUP BY, count(DISTINCT ...), CASE, round(). Walk the room, starting with anyone who was still red at 9.20.

At about 9.50 say: Self-check now, or load the Checkpoint. Both are on the card.`);

deck.revealSlide(
  warmup,
  [
    { head: "Join, then group", body: "Sex is on the patient table, so join patient_2017 on patient_id, then group by the hospital's state." },
    { head: "Rows or people?", body: "count(*) counts admissions; count(DISTINCT patient_id) counts people, who may come back more than once." },
    { head: "Count only some rows", body: "count(CASE WHEN ... THEN 1 END) counts the rows that match: female admissions, deaths." },
  ],
  `
5 minutes, then the break. Run the Core cell of the solution file and show the Self-check giving 0.

If time allows, show Stretch S1: HAVING against a subquery, the national average. Stretch S2 (busiest hospital per state, with a tie-break) is a preview of the window functions in Module 2 and Day 2.

Close: "You can still do everything from Series 1. From 10.30 the data stops being clean."`,
);

// 16. Break
deck.sectionSlide({
  kicker: "10.00 · BREAK",
  title: "Module 1 at 10.30",
  subtitle: "Reading raw data safely: three hospital systems, 36 monthly files, one manifest",
  chips: cardsOf("m1").map((c) => `${cardLabel(c)} · ${c.output}`),
  notes: `
Leave this up over the break. Anyone still red: come to the front now, with laptop and charger.

After the break, Module 1 starts with the CSV vs Parquet demo on 30 million rows (check large/ is unzipped in the facilitator bundle and the CSV was written before the session).`,
});

deck.write().catch((e) => {
  console.error(e);
  process.exit(1);
});
