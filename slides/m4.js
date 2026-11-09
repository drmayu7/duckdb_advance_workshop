// Day 2, 2.00-4.30: Module 4, Extension tracks, then the Capstone kickoff (ADR 0004).
// node slides/m4.js  ->  handouts/m4.pptx
//
// The deck ships to Participants in the Content release, so neither the slides
// nor the notes may say anything about the Held-back defects or the Hint cards'
// text (capstone/hints.md is facilitator only).
"use strict";

const { Deck, COLOR, FONT, W, MARGIN, cardsOf, cardLabel } = require("./theme");

const deck = new Deck({
  name: "m4",
  title: "Module 4: Extension tracks and the Capstone kickoff",
  footer: "DuckDB Workshop Series 2 · Day 2 · Module 4: Extension tracks · Capstone kickoff",
});
const tracks = cardsOf("m4");
const byId = Object.fromEntries(tracks.map((c) => [c.id, c]));
const stats = byId["t-stats"];
const names = byId["t-names"];
const spatial = byId["t-spatial"];
if (!stats || !names || !spatial) throw new Error("m4: expected the t-stats, t-names and t-spatial cards");

// The three Angles, as the Capstone brief names them (capstone/brief.md).
const ANGLES = [
  { a: "A", head: "Readmission", q: "30-day readmission among diabetes patients, by state", table: "readmit_2021", from: "C8, C9" },
  { a: "B", head: "Dengue", q: "Dengue admissions per 100,000 people, by state", table: "dengue_2021", from: "C7, C10" },
  { a: "C", head: "Hospital load", q: "Which hospitals carry the admission load", table: "hospital_load_2021", from: "C7" },
];

// ---------------------------------------------------------------------------

// 1. Title
deck.titleSlide({
  kicker: "DAY 2 · MODULE 4 · 2.00 – 4.30",
  title: "Extension tracks, then the Capstone",
  subtitle: "Three extensions to try, then your team's own State Health Brief for 2021",
  meta: "stats_duck · name matching with rapidfuzz and splink_udfs · spatial · Capstone kickoff at 3.40",
  notes: `
The afternoon has two halves. 2.00 to 3.40: a 15-minute tour of the three Extension tracks, then each Participant does two of them, 40 minutes each, at their own pace. 3.40 to 4.30: the Capstone kickoff, then teams start work.

There's no Reveal for the tracks: each card has its Self-check and its solution in the bundle. Walk the room instead.`,
});

// 2. The afternoon
{
  const s = deck.content("This afternoon", `
Read the plan once. The tracks are self-paced: anyone may switch track or stop early. At 3.35 everyone stops wherever they are; at 3.40 the Capstone starts on time, because teams need the time to load the 2021 extract before tomorrow.`);
  const blocks = [
    { t: "2.00", head: "Tour", body: "All three", w: 15, fill: COLOR.ink2 },
    { t: "2.15", head: "Track 1", body: "your first pick, 40 min", w: 40, fill: COLOR.teal },
    { t: "2.55", head: "Track 2", body: "your second pick, 40 min", w: 40, fill: COLOR.teal },
    { t: "", w: 5, fill: COLOR.line },
    { t: "3.40", head: "Capstone", body: "kickoff, 10 min", w: 10, fill: COLOR.amber, dark: true },
    { t: "3.50", head: "Teams at work", body: "Driver, extract, sanity check 1", w: 35, fill: COLOR.amber, dark: true },
    { t: "4.25", w: 5, fill: COLOR.ink2 },
  ];
  deck.timeline(s, blocks, { h: 1.4, end: "4.30" });
  const span = W - 2 * MARGIN;
  const half = deck.colWidth(2, 0.4);
  deck.panel(s, MARGIN, 4.3, half, 2.35, { fill: COLOR.tint });
  deck.text(s, MARGIN + 0.35, 4.45, half - 0.7, 0.5, "Extension tracks", { fontFace: FONT.head, fontSize: 21, bold: true, color: COLOR.tealDark });
  deck.text(s, MARGIN + 0.35, 5.0, half - 0.7, 1.55, "Pick any two of three. Each starts from the Checkpoints, so this morning's state doesn't matter. Card, Self-check and solution, as always.", { fontSize: 16 });
  deck.panel(s, MARGIN + half + 0.4, 4.3, half, 2.35, { fill: COLOR.amberTint });
  deck.text(s, MARGIN + half + 0.75, 4.45, half - 0.7, 0.5, "Capstone kickoff", { fontFace: FONT.head, fontSize: 21, bold: true });
  deck.text(s, MARGIN + half + 0.75, 5.0, half - 0.7, 1.55, "Three teams, one question each, from raw 2021 files. Today: load the extract and prove every row arrived.", { fontSize: 16 });
}

// ----- The track tour -------------------------------------------------------

// 3. Three tracks
{
  const s = deck.content("Three extensions, three questions", `
2.00, the tour: about 4 minutes a track. The point of the afternoon is that DuckDB's extensions add whole new kinds of question to the same SQL. All three are already in your bundle (installed on Day 1); the community ones need LOAD once per session.

Each track starts from Checkpoints, so pick by interest, not by how this morning went. Statistics suits anyone who reports rates; name matching anyone who links lists from different systems; spatial anyone who makes maps.`);
  const cols = [
    { card: stats, ext: "stats_duck", load: "LOAD stats_duck;", q: "Is Putrajaya's readmission rate really worse, or is it just a small number?", what: "Confidence intervals, a t-test, table_one()" },
    { card: names, ext: "built in, then rapidfuzz", load: "LOAD rapidfuzz; -- S2", q: "Which facility code is \"Hosp. Sultanah Aminah JB\"?", what: "A match key, similarity scores, an honest threshold" },
    { card: spatial, ext: "spatial", load: "LOAD spatial;", q: "Where is dengue, district by district?", what: "A crosswalk, a polygon join, a map layer" },
  ];
  const gap = 0.35;
  const cw = deck.colWidth(3, gap);
  cols.forEach((c, i) => {
    const x = MARGIN + i * (cw + gap);
    deck.panel(s, x, 1.4, cw, 5.3, { fill: COLOR.mist });
    deck.chip(s, x + 0.3, 1.6, 1.7, 0.5, cardLabel(c.card), { fill: COLOR.teal, color: COLOR.white, fontFace: FONT.head, fontSize: 16 });
    deck.text(s, x + 0.3, 2.25, cw - 0.6, 0.85, c.card.title, { fontFace: FONT.head, fontSize: 20, bold: true });
    deck.chip(s, x + 0.3, 3.15, cw - 0.6, 0.42, c.ext, { fill: COLOR.white, color: COLOR.tealDark, fontSize: 13 });
    deck.text(s, x + 0.3, 3.75, cw - 0.6, 1.3, c.q, { fontSize: 16, italic: true });
    deck.text(s, x + 0.3, 5.05, cw - 0.6, 0.8, c.what, { fontSize: 14, color: COLOR.muted });
    deck.code(s, x + 0.3, 5.9, cw - 0.6, 0.6, c.load, { max: 15, valign: "middle" });
  });
}

// 4-6. The track cards
deck.challengeSlide(stats, `
Tour, about 4 minutes. C9's rates look precise, but Putrajaya's rests on a few dozen index episodes. The track adds a 95% Wilson interval to every state's rate (the card gives the formula, R's prop.test without continuity correction), so the Director can see which differences are real. Then a second question from the wards, with ttest_2samp and table_one().

Show the card's Look first cells: LOAD stats_duck, then qnorm(0.975). stats_duck is a community extension: it never loads by itself.

Starts from the C8 and C9 Checkpoints.`);

deck.challengeSlide(names, `
Tour, about 4 minutes. The MOH bed utilisation file names its hospitals its own way, with no facility code. The track builds a match key, scores every candidate in the same state with jaro_winkler_similarity() (built in, no LOAD), keeps the best with QUALIFY, and sets a threshold below which a name stays unmatched.

The honest part is the point: some names should not match anything, and a forced match is worse than a NULL. The Stretch rows try the community extensions rapidfuzz and splink_udfs (LOAD each first).

Starts from the C5 Checkpoint (facility_clean). The card's first cell repeats C5's macros.`);

deck.challengeSlide(spatial, `
Tour, about 4 minutes. The admissions name the patient's MoH health district; DOSM's population and boundaries use administrative districts, and the two lists don't always agree. The track builds the crosswalk, computes dengue per 100,000 by DOSM district, and exports a GeoJSON map layer that QGIS or geojson.io can open.

Show ST_Read on the district GeoJSON: polygons as a column. Spatial is a core extension in the bundle; LOAD it once.

Starts from the C5 and C6 Checkpoints. The card's first cell repeats C5's macros.`);

// 7. Pick two
{
  const s = deck.content("Pick two, then go", `
2.15. Everyone picks a first track and starts. At 2.55 move to the second, finished or not: the Checkpoints mean nobody is blocked.

Walk the room. The usual snags: a community extension that wasn't loaded (LOAD it), C5's macros missing in a new Work database (the card's first cell), and the Checkpoint cells not run. Solutions are in the bundle: anyone stuck for more than five minutes may read the next step there.`);
  const steps = [
    { n: "1", head: "Load the Checkpoints", body: "The track card's first cells: the tables it starts from, and C5's macros where it needs them." },
    { n: "2", head: "LOAD the extension", body: "Once per session. stats_duck, rapidfuzz and splink_udfs are community extensions and never load by themselves." },
    { n: "3", head: "Core, Self-check", body: "0 rows differ means done. Stretch rows if you have time; the second track if you don't." },
  ];
  const gap = 0.5;
  const cw = deck.colWidth(3, gap);
  steps.forEach((st, i) => {
    const x = MARGIN + i * (cw + gap);
    deck.panel(s, x, 1.5, cw, 3.3, { fill: COLOR.mist });
    deck.dot(s, x + 0.3, 1.75, 0.7, st.n, { fontSize: 22 });
    deck.text(s, x + 1.2, 1.75, cw - 1.4, 0.7, st.head, { fontFace: FONT.head, fontSize: 20, bold: true, valign: "middle" });
    deck.text(s, x + 0.3, 2.7, cw - 0.6, 2.0, st.body, { fontSize: 16 });
    if (i < 2) deck.arrow(s, x + cw + 0.08, 3.15, gap - 0.16, { color: COLOR.teal, width: 2.5 });
  });
  const tw = deck.colWidth(2, 0.4);
  [
    { t: "2.15 – 2.55", head: "Your first track" },
    { t: "2.55 – 3.35", head: "Your second track" },
  ].forEach((b, i) => {
    const x = MARGIN + i * (tw + 0.4);
    deck.panel(s, x, 5.2, tw, 1.45, { fill: COLOR.tint });
    deck.text(s, x + 0.35, 5.3, 3.0, 1.25, b.t, { fontFace: FONT.head, fontSize: 26, bold: true, color: COLOR.tealDark, valign: "middle" });
    deck.text(s, x + 3.4, 5.3, tw - 3.7, 1.25, b.head, { fontSize: 18, valign: "middle" });
  });
}

// 8. Track wrap
{
  const s = deck.content("What each extension added", `
3.35, 5 minutes. Stop wherever you are. One sentence per track, asking the room: who did statistics, what was Putrajaya's interval? Who matched names, how many stayed unmatched, and why is that right? Who made the map, where is dengue densest?

Then straight into the Capstone: same Work database, new files.`);
  const rows = [
    { card: stats, head: "An interval, not just a rate", body: "A small state's rate comes with a wide interval: report both, or the Director compares noise." },
    { card: names, head: "An honest match", body: "Score every candidate, keep the best, and leave a name unmatched below the threshold." },
    { card: spatial, head: "A crosswalk, then a map", body: "Two district lists need a table that links them before any polygon join means anything." },
  ];
  rows.forEach((r, i) => {
    const y = 1.5 + i * 1.7;
    deck.panel(s, MARGIN, y, W - 2 * MARGIN, 1.45, { fill: i % 2 ? COLOR.white : COLOR.mist, line: i % 2 ? COLOR.line : undefined });
    deck.chip(s, MARGIN + 0.3, y + 0.45, 1.7, 0.55, cardLabel(r.card), { fill: COLOR.teal, color: COLOR.white, fontFace: FONT.head, fontSize: 15 });
    deck.text(s, MARGIN + 2.3, y + 0.1, 3.9, 1.25, r.head, { fontSize: 19, bold: true, valign: "middle" });
    deck.text(s, MARGIN + 6.4, y + 0.1, W - 2 * MARGIN - 6.7, 1.25, r.body, { fontSize: 16, valign: "middle" });
  });
}

// ----- The Capstone kickoff ------------------------------------------------

// 9. Section
deck.sectionSlide({
  kicker: "3.40 · CAPSTONE KICKOFF",
  title: "The State Health Brief 2021",
  subtitle: "Three teams, one question each, from the raw 2021 files to an answer the Director can read",
  chips: ANGLES.map((a) => `Angle ${a.a} · ${a.head}`),
  notes: `
10 minutes of talk, 3.40 to 3.50, then the teams start. Everything on the next slides is in capstone/brief.md and capstone/rubric.md in the bundle: point people there rather than asking them to take notes.

Have the team list ready (from registration, one experienced SQL person per team) and the "Capstone 2026" Drive folder shared with every member.`,
});

// 10. The brief
{
  const s = deck.content("The Director wants 2021", `
The scenario: the 2018-2020 brief went down well, and the 2021 export has just arrived. Most hospitals are on the new system now, so most months come as Parquet; Sabah's hospitals still export from the old HIS, as CSV with Malay column names, like the 2018 files.

The key sentence of the brief: don't assume 2021 is as clean as the last extract, or dirty in the same ways. You have your C1-C10 SQL: re-run it and adapt it, and check every step.

2021 stands on its own: episodes and readmissions use 2021 admissions only. The brief's Definitions section says exactly how.`);
  const files = [
    { f: "data/capstone/2021-01.parquet … 2021-12.parquet", b: "New system: every hospital except Sabah's. The same columns as the 2020 files." },
    { f: "data/capstone/2021-01-sabah.csv … 2021-12-sabah.csv", b: "Sabah, still on the old HIS: Malay columns, the 2018 date format." },
    { f: "data/capstone/manifest.csv", b: "How many records each file holds: the sender's promise." },
  ];
  files.forEach((f, i) => {
    const y = 1.45 + i * 1.05;
    deck.chip(s, MARGIN, y, 6.6, 0.55, f.f, { fill: i === 1 ? COLOR.amberTint : COLOR.tint, color: COLOR.text, fontSize: 13, align: "left", margin: 10 });
    deck.text(s, MARGIN + 6.85, y - 0.1, W - 2 * MARGIN - 6.85, 0.75, f.b, { fontSize: 15, valign: "middle" });
  });
  const half = deck.colWidth(2, 0.4);
  deck.panel(s, MARGIN, 4.75, half, 1.9, { fill: COLOR.coralTint });
  deck.text(s, MARGIN + 0.35, 4.85, half - 0.7, 0.5, "New export, new problems", { fontFace: FONT.head, fontSize: 20, bold: true, color: COLOR.coral });
  deck.text(s, MARGIN + 0.35, 5.4, half - 0.7, 1.15, "Don't assume 2021 is as clean as the last extract, or dirty in the same ways.", { fontSize: 16 });
  deck.panel(s, MARGIN + half + 0.4, 4.75, half, 1.9, { fill: COLOR.mist });
  deck.text(s, MARGIN + half + 0.75, 4.85, half - 0.7, 0.5, "You already have the SQL", { fontFace: FONT.head, fontSize: 20, bold: true });
  deck.text(s, MARGIN + half + 0.75, 5.4, half - 0.7, 1.15, "Re-run and adapt C1–C10. A piece broken? Its Checkpoint is in expected/.", { fontSize: 16 });
}

// 11. Teams and Angles
{
  const s = deck.content("Your team, your Angle", `
Read out the teams now, from the list, and say which Angle each has. Teams sit together from here to the end of the Capstone.

Each Angle is one question of the brief and one summary table. The column names and order are in the brief, and they matter: the facilitator checks every team's summary the same way, by column name, so a renamed column counts as missing.

Suggested roles, not enforced: the Driver holds the official pipeline and outputs on their laptop; one or two data-quality investigators load the same files on their own laptops and hunt for problems; an analyst/presenter writes brief.md. Everyone speaks in the presentation.`);
  const gap = 0.35;
  const cw = deck.colWidth(3, gap);
  ANGLES.forEach((a, i) => {
    const x = MARGIN + i * (cw + gap);
    deck.panel(s, x, 1.4, cw, 3.55, { fill: COLOR.mist });
    deck.text(s, x + 0.3, 1.45, 1.2, 1.2, a.a, { fontFace: FONT.head, fontSize: 64, bold: true, color: COLOR.amber });
    deck.text(s, x + 1.45, 1.7, cw - 1.7, 0.7, a.head, { fontFace: FONT.head, fontSize: 22, bold: true, valign: "middle" });
    deck.text(s, x + 0.3, 2.65, cw - 0.6, 1.0, a.q, { fontSize: 15 });
    deck.chip(s, x + 0.3, 3.75, cw - 0.6, 0.5, a.table, { fill: COLOR.teal, color: COLOR.white, fontSize: 15 });
    deck.text(s, x + 0.3, 4.35, cw - 0.6, 0.45, `re-uses ${a.from} · 2021, with 2020 beside it`, { fontSize: 13, color: COLOR.muted });
  });
  const roles = [
    { head: "Driver", body: "holds pipeline.sql and the outputs" },
    { head: "Investigators", body: "hunt for data-quality problems" },
    { head: "Presenter", body: "writes brief.md, leads the talk" },
  ];
  roles.forEach((r, i) => {
    const x = MARGIN + i * (cw + gap);
    deck.chip(s, x, 5.3, 2.0, 0.5, r.head, { fill: COLOR.ink, color: COLOR.white, fontFace: FONT.body, fontSize: 15 });
    deck.text(s, x + 2.15, 5.3, cw - 2.15, 0.5, r.body, { fontSize: 14, valign: "middle" });
  });
  deck.text(s, MARGIN, 6.15, W - 2 * MARGIN, 0.45, "Three teams, from the registration list: the facilitator reads them out now. Suggested roles, not enforced; everyone speaks.", { fontSize: 14, italic: true, color: COLOR.muted });
}

// 12. Deliverables
{
  const s = deck.content("What you hand in, by 11.15 tomorrow", `
Four things, uploaded to your team's folder in the "Capstone 2026" MyGovUC Drive folder (team_A, team_B or team_C) by 11.15 on Day 3. Investigators drop fix SQL into team_X/scratch/. Capstone files move through Drive only, never by USB.

pipeline.sql must run top to bottom on a fresh Work database, with the three stage headers, and a -- DQ FIX: comment on the fix you present: what it fixes, and why. The Google Sheet is optional: it never costs marks, and it was shown in this morning's demo.`);
  // pipeline.sql as code
  deck.text(s, MARGIN, 1.4, 6.0, 0.4, "1 · pipeline.sql", { fontSize: 17, bold: true });
  deck.code(s, MARGIN, 1.85, 6.0, 3.3,
    "-- RAW\n-- read data/capstone/, count against the manifest\n\n-- CLEAN\n-- DQ FIX: what it fixes, and why\n\n-- SUMMARY\nCOPY ... TO '<table>.parquet';", { max: 16, valign: "middle" });
  deck.text(s, MARGIN, 5.3, 6.0, 1.3, "Runs top to bottom on a fresh Work database.", { fontSize: 15, color: COLOR.muted });
  const x = MARGIN + 6.5;
  const w = W - MARGIN - x;
  const items = [
    { n: "2", head: "Your summary table", body: "as <table>.parquet and <table>.csv" },
    { n: "3", head: "brief.md", body: "from capstone/brief_template.md: answer, data-quality story, pipeline, caveat" },
    { n: "4", head: "Optional: a Google Sheet", body: "your summary via gsheets, in your team folder; never costs marks" },
  ];
  items.forEach((it, i) => {
    const y = 1.4 + i * 1.2;
    deck.panel(s, x, y, w, 1.05, { fill: i === 2 ? COLOR.white : COLOR.mist, line: i === 2 ? COLOR.line : undefined });
    deck.dot(s, x + 0.25, y + 0.25, 0.55, it.n, { fontSize: 17, fill: i === 2 ? COLOR.muted : COLOR.teal });
    deck.text(s, x + 1.0, y + 0.08, w - 1.2, 0.42, it.head, { fontSize: 17, bold: true });
    deck.text(s, x + 1.0, y + 0.5, w - 1.2, 0.5, it.body, { fontSize: 14 });
  });
  deck.panel(s, x, 5.1, w, 1.55, { fill: COLOR.amberTint });
  deck.text(s, x + 0.3, 5.15, w - 0.6, 1.45, [
    { text: "Upload to ", options: {} },
    { text: "Capstone 2026 / team_X/", options: { fontFace: FONT.code, bold: true } },
    { text: " on MyGovUC Drive by 11.15 on Day 3. Drive only, never USB.", options: {} },
  ], { fontSize: 16, valign: "middle" });
}

// 13. No Self-check: sanity checks
{
  const s = deck.content("No Self-check this time: sanity checks", `
The important difference from every Challenge so far: there is no Self-check and no Checkpoint for 2021. Nobody has the right answer to compare with, which is how real work goes.

The brief has four sanity checks, each a question a careful analyst asks before trusting a number. When one surprises you, that's your lead: find where it comes from (GROUP BY file, facility_code, source_system ...) before you fix anything. Then do the same comparison for your own Angle's figure: 2021 against 2020.`);
  const checks = [
    { n: "1", when: "after RAW", head: "Rows against the manifest", body: "Every file gave the rows it promised. Want 0 rows." },
    { n: "2", when: "after typing", head: "NULL rates", body: "Which columns have NULLs you didn't expect, and how many?" },
    { n: "3", when: "after de-duplication", head: "Patients against ICs", body: "One IC per person: do the two counts agree?" },
    { n: "4", when: "after CLEAN", head: "2021 against 2020", body: "A state or hospital that moves by a third needs an explanation." },
  ];
  const gap = 0.3;
  const cw = deck.colWidth(4, gap);
  checks.forEach((c, i) => {
    const x = MARGIN + i * (cw + gap);
    deck.panel(s, x, 1.45, cw, 3.7, { fill: COLOR.mist });
    deck.dot(s, x + 0.25, 1.7, 0.6, c.n, { fontSize: 19 });
    deck.text(s, x + 1.0, 1.7, cw - 1.2, 0.6, c.when, { fontSize: 13, color: COLOR.muted, valign: "middle" });
    deck.text(s, x + 0.25, 2.5, cw - 0.5, 0.9, c.head, { fontFace: FONT.head, fontSize: 19, bold: true });
    deck.text(s, x + 0.25, 3.45, cw - 0.5, 1.6, c.body, { fontSize: 15 });
  });
  deck.panel(s, MARGIN, 5.45, W - 2 * MARGIN, 1.2, { fill: COLOR.amberTint });
  deck.text(s, MARGIN + 0.35, 5.45, W - 2 * MARGIN - 0.7, 1.2, [
    { text: "A surprise is a lead, not a nuisance. ", options: { bold: true } },
    { text: "Find where it comes from before you fix anything: that's your data-quality story.", options: {} },
  ], { fontSize: 17, valign: "middle" });
}

// 14. The talk and the rubric
{
  const s = deck.content("Seven minutes, scored by your peers", `
Day 3, 11.15: each team presents for 7 minutes from brief.md on screen, with one live query, then 3 minutes of questions. brief_template.md has its headings in talk order. Every member speaks.

Each Participant scores the two other teams on a slip: four criteria, 1 to 4, no middle score. The rubric is formative, for feedback; teams are not ranked. Peers don't score whether the number is correct: over lunch the facilitator compares each summary with the true 2021 figures and reports that separately, at 2.45.`);
  const parts = [
    { m: 1, t: "The answer" },
    { m: 3, t: "The data-quality story" },
    { m: 2, t: "The pipeline" },
    { m: 1, t: "A caveat" },
  ];
  const span = W - 2 * MARGIN;
  let x = MARGIN;
  parts.forEach((p, i) => {
    const w = (p.m / 7) * span;
    s.addShape(deck.shapes.RECTANGLE, { x, y: 1.45, w: w - 0.05, h: 1.0, fill: { color: i === 1 ? COLOR.amber : COLOR.teal }, line: { type: "none" } });
    deck.text(s, x + 0.12, 1.45, w - 0.25, 1.0, [
      { text: `${p.m} min`, options: { bold: true, breakLine: true } },
      { text: p.t, options: {} },
    ], { fontSize: 15, color: i === 1 ? COLOR.ink : COLOR.white, valign: "middle" });
    x += w;
  });
  const criteria = [
    { head: "Answer to the Director", four: "a clear 2021 number, the change from 2020 explained in one sentence" },
    { head: "Data-quality story", four: "symptom → how found → fix → the number before and after" },
    { head: "Pipeline", four: "clear stages that run top to bottom, with the fix commented" },
    { head: "Communication and caveats", four: "within 7 min, a sensible caveat, questions handled" },
  ];
  deck.text(s, MARGIN, 2.75, 4.0, 0.35, "THE RUBRIC · 1 TO 4, NO MIDDLE", { fontSize: 13, bold: true, color: COLOR.muted });
  deck.text(s, MARGIN + 4.6, 2.75, 6.0, 0.35, "WHAT A 4 LOOKS LIKE", { fontSize: 13, bold: true, color: COLOR.muted });
  criteria.forEach((c, i) => {
    const y = 3.15 + i * 0.72;
    deck.panel(s, MARGIN, y, span, 0.62, { fill: i % 2 ? COLOR.white : COLOR.mist, line: i % 2 ? COLOR.line : undefined });
    deck.text(s, MARGIN + 0.25, y, 4.2, 0.62, c.head, { fontSize: 16, bold: true, valign: "middle" });
    deck.text(s, MARGIN + 4.6, y, span - 4.8, 0.62, c.four, { fontSize: 15, valign: "middle" });
  });
  deck.text(s, MARGIN, 6.1, span, 0.5, "Peers don't score correctness: the facilitator checks every summary against the true 2021 figures and reports it at 2.45 on Day 3.", { fontSize: 14, italic: true, color: COLOR.muted });
}

// 15. If you're stuck
{
  const s = deck.content("If you're stuck", `
Say the rule out loud and write it on the whiteboard: Hint cards come at 10.30 on Day 3, not before.

A team that has named a suspect by then carries on. A team that hasn't gets its Angle's Hint card: it describes something the team can check for itself, never the cause or the fix. Broken earlier SQL is a different problem: load that piece's Checkpoint from expected/ and carry on.

Questions about SQL syntax are fine at any time. Questions like "what's wrong with our data?" get "what does your sanity check say?"`);
  const items = [
    { t: "Any time", head: "Earlier SQL broken?", body: "Load its Checkpoint from expected/ and carry on.", fill: COLOR.mist, chip: COLOR.teal },
    { t: "End of Day 2", head: "The goal for today", body: "The extract loaded, with row counts matching manifest.csv.", fill: COLOR.tint, chip: COLOR.teal },
    { t: "10.30, Day 3", head: "No suspect yet?", body: "Your team gets its Angle's Hint card: a symptom to check, never the cause or the fix.", fill: COLOR.amberTint, chip: COLOR.amber },
  ];
  const gap = 0.35;
  const cw = deck.colWidth(3, gap);
  items.forEach((it, i) => {
    const x = MARGIN + i * (cw + gap);
    deck.panel(s, x, 1.5, cw, 3.6, { fill: it.fill });
    deck.chip(s, x + 0.3, 1.75, cw - 0.6, 0.55, it.t, { fill: it.chip, color: i === 2 ? COLOR.ink : COLOR.white, fontFace: FONT.head, fontSize: 18 });
    deck.text(s, x + 0.3, 2.55, cw - 0.6, 0.6, it.head, { fontFace: FONT.head, fontSize: 20, bold: true });
    deck.text(s, x + 0.3, 3.2, cw - 0.6, 1.8, it.body, { fontSize: 16 });
  });
  deck.panel(s, MARGIN, 5.45, W - 2 * MARGIN, 1.2, { fill: COLOR.ink });
  deck.text(s, MARGIN + 0.4, 5.45, W - 2 * MARGIN - 0.8, 1.2, [
    { text: "The Hint card rule: ", options: { bold: true, color: COLOR.amber } },
    { text: "no suspect named by 10.30 on Day 3 means a Hint card. Before that, your sanity checks are your hints.", options: { color: COLOR.white } },
  ], { fontSize: 18, valign: "middle" });
}

// 16. Start now
{
  const s = deck.content("Start now: 3.50 to 4.25", `
3.50. Teams move together and start. Walk the room: the first snag is usually Sabah's CSV, which needs the Day 1 C1-C3 reading SQL, not the Parquet SQL.

At 4.20 ask each team: does sanity check 1 come back with 0 rows? A team that's there is in good shape for tomorrow. A team that isn't should write down what it found, so the Driver can pick up at 9.00.`);
  const steps = [
    { n: "1", head: "Pick a Driver", body: "Their laptop holds the official pipeline.sql and outputs. Open the team's Drive folder." },
    { n: "2", head: "Load the extract", body: "All 24 files: the 12 Parquet months and Sabah's 12 CSVs. Your C1–C3 SQL is the start." },
    { n: "3", head: "Sanity check 1", body: "Rows read against manifest.csv, file by file. Want 0 rows." },
  ];
  const gap = 0.5;
  const cw = deck.colWidth(3, gap);
  steps.forEach((st, i) => {
    const x = MARGIN + i * (cw + gap);
    deck.panel(s, x, 1.5, cw, 3.3, { fill: COLOR.mist });
    deck.dot(s, x + 0.3, 1.75, 0.7, st.n, { fontSize: 22, fill: COLOR.amber, color: COLOR.ink });
    deck.text(s, x + 1.2, 1.75, cw - 1.4, 0.7, st.head, { fontFace: FONT.head, fontSize: 20, bold: true, valign: "middle" });
    deck.text(s, x + 0.3, 2.7, cw - 0.6, 2.0, st.body, { fontSize: 16 });
    if (i < 2) deck.arrow(s, x + cw + 0.08, 3.15, gap - 0.16, { color: COLOR.amber, width: 2.5 });
  });
  deck.panel(s, MARGIN, 5.15, W - 2 * MARGIN, 1.5, { fill: COLOR.greenTint });
  deck.text(s, MARGIN + 0.4, 5.15, 3.2, 1.5, "By 4.25", { fontFace: FONT.head, fontSize: 28, bold: true, color: COLOR.green, valign: "middle" });
  deck.text(s, MARGIN + 3.6, 5.15, W - 2 * MARGIN - 4.0, 1.5, "Every team has the 2021 extract loaded, with row counts matching manifest.csv.", { fontSize: 19, valign: "middle" });
}

// 17. Close
deck.sectionSlide({
  kicker: "4.25 · DAY 2 WRAP-UP",
  title: "Tomorrow, 9.00: the Capstone",
  subtitle: "Teams at work until 11.15, then 7 minutes each. Close the DuckDB UI and the launcher before you go.",
  chips: ["9.00 work", "10.30 Hint cards", "11.15 upload and present", "2.45 results"],
  notes: `
Five minutes. Thank the room for a long day. Tomorrow: teams sit together from 9.00; work runs 9.00-10.00 and 10.30-11.15; uploads by 11.15; presentations 11.15-12.15; the results and the Answer key reveal open the afternoon at 2.45.

Remind everyone to close the DuckDB UI tab and the launcher, so the Work database closes cleanly. Drivers: keep your Work database; everyone else's investigations can be redone from the team's scratch folder.`,
});

deck.write().catch((e) => {
  console.error(e);
  process.exit(1);
});
