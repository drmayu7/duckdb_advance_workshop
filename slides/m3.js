// Day 2, 9.00-1.00: Module 3, Advanced SQL for health analysis (ADR 0004).
// node slides/m3.js  ->  handouts/m3.pptx
"use strict";

const fs = require("fs");
const path = require("path");
const { Deck, COLOR, FONT, W, MARGIN, REPO, cardsOf, cardLabel } = require("./theme");

const deck = new Deck({
  name: "m3",
  title: "Module 3: Advanced SQL for health analysis",
  footer: "DuckDB Workshop Series 2 · Day 2 · Module 3: Advanced SQL for health analysis",
});
const [c7, c8, c9, c10] = cardsOf("m3");
const [, c5, c6] = cardsOf("m2");
const tracks = cardsOf("m4");

// The S3 demo's captured output, for the backup slides at the end.
const BACKUP = JSON.parse(fs.readFileSync(path.join(REPO, "demos/m3/s3-demo-backup.json"), "utf8"));

const num = (v) => (typeof v === "number" && Number.isInteger(v) ? v.toLocaleString("en-US") : String(v));

/** A query result as the UI shows it: header row, then rows, in the code font. */
function resultTable(s, x, y, w, columns, rows, o = {}) {
  const size = o.fontSize || 13;
  const head = columns.map((c) => ({
    text: c,
    options: { bold: true, color: COLOR.tealDark, fill: { color: COLOR.tint }, fontFace: FONT.code, fontSize: size - 1 },
  }));
  const body = rows.map((r, i) =>
    r.map((v) => ({
      text: num(v),
      options: {
        fontFace: FONT.code, fontSize: size, color: COLOR.text,
        fill: { color: i % 2 ? COLOR.white : COLOR.mist },
        align: typeof v === "number" ? "right" : "left",
      },
    })),
  );
  s.addTable([head, ...body], {
    x, y, w,
    colW: o.colW,
    rowH: o.rowH || 0.32,
    margin: [2, 6, 2, 6],
    border: { type: "solid", pt: 0.5, color: COLOR.line },
    valign: "middle",
  });
}

// A big number with a small label: the bytes each step fetched.
function stat(s, x, y, w, value, label, o = {}) {
  deck.panel(s, x, y, w, 1.45, { fill: o.fill || COLOR.amberTint });
  deck.text(s, x + 0.25, y + 0.12, w - 0.5, 0.8, value, { fontFace: FONT.head, fontSize: o.size || 36, bold: true, color: o.color || COLOR.ink });
  deck.text(s, x + 0.25, y + 0.92, w - 0.5, 0.45, label, { fontSize: 14, color: COLOR.muted });
}

// ---------------------------------------------------------------------------

// 1. The morning banner
deck.contentIdSlide(`
Up from 8.45. Every Participant drops the latest Content release zip, unopened, into updates, then relaunches. The last banner line must show this id. Content none, or an older id, means the zip wasn't applied: same fix as yesterday morning.

Today's Content release holds the C7-C10 cards, their Checkpoints and solutions, the Extension track cards, and the Capstone brief.`);

// 2. Title
deck.titleSlide({
  kicker: "DAY 2 · MODULE 3 · 9.00 – 1.00",
  title: "Advanced SQL for health analysis",
  subtitle: "From one clean table to the State Health Brief",
  meta: "Window functions · episodes of care · 30-day readmission · PIVOT and export · S3 · Python and R",
  notes: `
Module 3 runs in four cycles, one per Challenge: C7 at 9.05, C8 at 9.45 (its Challenge runs after the break, at 10.30), C9 at 11.05 and C10 at 11.50. Then the live S3 demo at 12.40 and the Python/R overview at 12.55.

The cycles are tighter than Day 1's: demos about 8 minutes, Reveals about 5. If a cycle runs long, take it from the C10 Reveal or from the S3 demo's step 3b.`,
});

// 3. Where we are
deck.chainSlide("From admission_clean to the State Health Brief", [c5, c6, c7, c8, c9, c10], `
Yesterday ended with two clean tables. Today they become the three answers of the State Health Brief: hospital load (C7), episodes (C8), readmission (C9), and the one-page summary (C10).

Before C7: everyone needs admission_clean and facility_clean. Anyone who didn't finish C5 or C6 loads their Checkpoints now (one cell on each card). The C5 macros are not in its Checkpoint: C10's card repeats them in its first cell.`, [
  { module: "m2", head: "From Day 1", body: "One clean hospital list; one row per real admission." },
  { module: "m3", head: "This morning", body: "Load, episodes, readmission, then the one-page summary, exported." },
]);

// 4. The morning
{
  const s = deck.content("This morning", `
Read the plan once, quickly. Each cycle is demo, Challenge, Reveal. The one break falls inside the C8 cycle: the demo before, the Challenge after.

Anyone behind at any point loads the Checkpoint and carries on: the Checkpoints exist so nobody spends the morning stuck on yesterday.`);
  const blocks = [
    { t: "9.05", head: "C7", body: "Hospital load", w: 40, fill: COLOR.teal },
    { t: "9.45", head: "C8", body: "Demo", w: 15, fill: COLOR.teal },
    { t: "10.00", head: "Break", body: "", w: 30, fill: COLOR.line, dark: true },
    { t: "10.30", head: "C8", body: "Challenge", w: 35, fill: COLOR.teal },
    { t: "11.05", head: "C9", body: "Readmission", w: 45, fill: COLOR.teal },
    { t: "11.50", head: "C10", body: "Summary", w: 50, fill: COLOR.teal },
    { t: "12.40", head: "S3", body: "Live demo", w: 15, fill: COLOR.amber, dark: true },
    { t: "12.55", head: "Py / R", body: "", w: 5, fill: COLOR.amber, dark: true },
  ];
  deck.timeline(s, blocks, { end: "1.00" });
  const span = W - 2 * MARGIN;
  deck.text(s, W - MARGIN - 3.0, 3.75, 3.0, 0.35, "the last 5 min: Python and R", { fontSize: 12, color: COLOR.muted, align: "right", italic: true });

  const cw = (span - 2 * 0.4) / 3;
  [
    { n: "1", head: "Demo, about 8 min", body: "Watch, or type along. Open data or values typed in a cell: no demo gives away a Challenge." },
    { n: "2", head: "Challenge", body: "Card in cards.html. Self-check: 0 rows differ means done." },
    { n: "3", head: "Reveal, about 5 min", body: "The solution, then a Checkpoint for anyone who wants it." },
  ].forEach((c, i) => {
    const cx = MARGIN + i * (cw + 0.4);
    deck.panel(s, cx, 4.45, cw, 2.2, { fill: COLOR.mist });
    deck.dot(s, cx + 0.3, 4.7, 0.55, c.n, { fontSize: 18 });
    deck.text(s, cx + 1.05, 4.7, cw - 1.3, 0.55, c.head, { fontSize: 18, bold: true, valign: "middle" });
    deck.text(s, cx + 0.3, 5.45, cw - 0.6, 1.1, c.body, { fontSize: 15 });
  });
}

// ----- C7 -------------------------------------------------------------------

// 5. C7 idea: GROUP BY collapses, a window keeps the rows
{
  const s = deck.content("GROUP BY collapses rows; a window keeps them", `
The C7 cycle, 9.05. The one idea: an aggregate with OVER (...) is computed over a group of rows, like GROUP BY, but every row stays, with the group's value beside it. So "share of the state" or "rank in the state" is one column, not a second query and a join.

PARTITION BY says what the group is; ORDER BY inside OVER says the order for rank() and running totals. You can also put a window over a GROUP BY's result: sum(count(*)) OVER (PARTITION BY state) sums the grouped counts.`);
  const rows = [
    { st: "Pahang", h: "H. Tengku Ampuan Afzan", v: 798 },
    { st: "Pahang", h: "H. Kuala Lipis", v: 162 },
    { st: "Pahang", h: "H. Pekan", v: 106 },
  ];
  // Left: GROUP BY
  const lx = MARGIN;
  const half = (W - 2 * MARGIN - 0.5) / 2;
  deck.text(s, lx, 1.45, half, 0.45, "GROUP BY state", { fontFace: FONT.code, fontSize: 18, bold: true, color: COLOR.tealDark });
  rows.forEach((r, i) => {
    const y = 2.0 + i * 0.5;
    deck.panel(s, lx, y, 3.3, 0.42, { fill: COLOR.mist });
    deck.text(s, lx + 0.15, y, 2.4, 0.42, r.h, { fontSize: 13, valign: "middle" });
    deck.text(s, lx + 2.45, y, 0.7, 0.42, String(r.v), { fontSize: 13, valign: "middle", align: "right", fontFace: FONT.code });
  });
  deck.arrow(s, lx + 3.45, 2.71, 0.6, { color: COLOR.teal, width: 3 });
  deck.chip(s, lx + 4.2, 2.45, half - 4.2, 0.55, "Pahang · 1,066", { fill: COLOR.teal, color: COLOR.white, fontFace: FONT.body, fontSize: 14, margin: 2 });
  deck.text(s, lx, 3.7, half, 0.9, "One row per state: the hospitals are gone.", { fontSize: 16, color: COLOR.muted });
  // Right: window
  const rx = MARGIN + half + 0.5;
  deck.text(s, rx, 1.45, half, 0.45, "sum(...) OVER (PARTITION BY state)", { fontFace: FONT.code, fontSize: 17, bold: true, color: COLOR.tealDark });
  rows.forEach((r, i) => {
    const y = 2.0 + i * 0.5;
    deck.panel(s, rx, y, 3.3, 0.42, { fill: COLOR.mist });
    deck.text(s, rx + 0.15, y, 2.4, 0.42, r.h, { fontSize: 13, valign: "middle" });
    deck.text(s, rx + 2.45, y, 0.7, 0.42, String(r.v), { fontSize: 13, valign: "middle", align: "right", fontFace: FONT.code });
    deck.chip(s, rx + 3.45, y + 0.04, 1.1, 0.34, "1,066", { fill: COLOR.teal, color: COLOR.white, fontSize: 13 });
    deck.chip(s, rx + 4.7, y + 0.04, 1.1, 0.34, `${Math.round((1000 * r.v) / 1066) / 10}%`, { fill: COLOR.amber, color: COLOR.ink, fontSize: 13 });
  });
  deck.text(s, rx, 3.7, half, 0.9, "Every hospital keeps its row, with its state's total and its share beside it.", { fontSize: 16, color: COLOR.muted });
  // The three window functions C7 needs
  const fns = [
    { f: "sum(x) OVER (PARTITION BY g)", b: "the group's total on every row" },
    { f: "rank() OVER (PARTITION BY g ORDER BY x DESC)", b: "1, 2, 2, 4: ties share a rank" },
    { f: "sum(x) OVER (ORDER BY x DESC)", b: "a running total" },
  ];
  fns.forEach((f, i) => {
    const y = 4.75 + i * 0.62;
    deck.chip(s, MARGIN, y, 6.6, 0.48, f.f, { fill: COLOR.ink, color: COLOR.white, fontSize: 14, align: "left", margin: 8 });
    deck.text(s, MARGIN + 6.85, y, W - 2 * MARGIN - 6.85, 0.48, f.b, { fontSize: 16, valign: "middle" });
  });
}

// 6-9. Demo: windows
deck.demoSlides("demos/m3/windows.sql", {
  label: "Demo",
  steps: {
    1: { title: "A window over a GROUP BY", notes: `
MOH's bed utilisation file is real open data. Run it: one row per state. The window sum(sum(beds_nonicu)) OVER () reads inside out: the inner sum is the GROUP BY's, the outer one adds up every state's. An empty OVER () means "all rows".

Note the alias: beds is used again in the same SELECT. DuckDB allows that.` },
    2: { title: "PARTITION BY: the state's total on every row", notes: `
Every Pahang hospital is still a row, each with Pahang's total beside it. The share is then one division. In C7 the same shape gives each hospital's share of its state's admissions.` },
    3: { title: "rank() and QUALIFY", notes: `
rank() restarts at 1 in every state (PARTITION BY state), biggest first (ORDER BY ... DESC). Ties share a rank and the next number is skipped; row_number() would break the tie arbitrarily. QUALIFY filters on the window, as yesterday in C6.` },
    4: { title: "A running total", notes: `
ORDER BY inside OVER turns sum into a running sum: from the first row to this one. The hospital name in the ORDER BY breaks ties, so equal bed counts don't add up together. One hospital holds 60% of Pahang's beds.

C7's Stretch S2 asks the same question of admissions. Hand over to C7.` },
  },
});

// 10-11. C7
deck.challengeSlide(c7, `
25 minutes, about 9.15 to 9.40. One GROUP BY with count(*) FILTER (WHERE ...) for the three counts, then two windows over the grouped rows: the state share and the state rank.

Watch for: start from facility_clean and LEFT JOIN the admissions, so a hospital with no admissions is still there with 0 (count the joined column, not *). Dengue includes the legacy codes A90 and A91 the card describes, through ref_icd10's scenario_group; LIKE 'A97%' misses them (that's Stretch S1). Bed days leave out stays with a date_flag.`);

deck.revealSlide(c7, [
  { head: "Start from every hospital", body: "facility_clean LEFT JOIN admission_clean, and count a joined column, so a quiet hospital shows 0, not nothing." },
  { head: "Three counts, one pass", body: "count(*) FILTER (WHERE ...) counts dengue and sums bed days in the same GROUP BY as the admissions." },
  { head: "Windows over the groups", body: "sum(count(*)) OVER (PARTITION BY state) for the share; rank() OVER (... ORDER BY admissions DESC) for the rank." },
], `
5 minutes. Walk the solution's Core query top to bottom, then its "three busiest per state" cell (QUALIFY state_rank <= 3).

If time allows, show S1's answer: the hospitals that lose dengue admissions under LIKE 'A97%' are the ones still coding the retired A90/A91. A code list from a reference table beats a pattern.`);

// ----- C8 -------------------------------------------------------------------

// 12. C8 idea: islands
{
  const s = deck.content("Gaps and islands: runs of back-to-back stays", `
The C8 cycle, 9.45. A transfer is two admissions but one episode of care, so before counting readmissions we join each run of back-to-back stays into one episode. That's the classic "gaps and islands" problem.

The recipe has four steps, and they're the same for any runs: refills, shifts, stays. Look back with lag(), flag where a new run starts, number the runs with a running sum of the flags, then GROUP BY the number. C8's rule for "back to back" is on its card: start on or before the previous stay's end + 1 day.`);
  // A patient's timeline: three stays, the first two back to back.
  const ax = MARGIN + 0.3;
  const aw = W - 2 * MARGIN - 0.6;
  s.addShape(deck.shapes.LINE, { x: ax, y: 2.95, w: aw, h: 0, line: { color: COLOR.line, width: 1.5 } });
  const stays = [
    { x0: 0.0, x1: 0.2, label: "Hospital A", island: 1 },
    { x0: 0.2, x1: 0.42, label: "Hospital B (transfer)", island: 1 },
    { x0: 0.68, x1: 0.86, label: "Hospital A", island: 2 },
  ];
  stays.forEach((st) => {
    const x = ax + st.x0 * aw;
    const w = (st.x1 - st.x0) * aw - 0.06;
    deck.chip(s, x, 2.6, w, 0.7, st.label, { fill: st.island === 1 ? COLOR.teal : COLOR.ink2, color: COLOR.white, fontFace: FONT.body, fontSize: 14 });
  });
  // The islands, bracketed under
  [{ x0: 0, x1: 0.42, t: "episode 1 · 2 admissions" }, { x0: 0.68, x1: 0.86, t: "episode 2" }].forEach((e) => {
    const x = ax + e.x0 * aw;
    const w = (e.x1 - e.x0) * aw - 0.06;
    deck.panel(s, x, 3.45, w, 0.5, { fill: COLOR.amberTint });
    deck.text(s, x, 3.45, w, 0.5, e.t, { fontSize: 14, bold: true, align: "center", valign: "middle" });
  });
  deck.text(s, ax + 0.42 * aw, 2.2, 0.26 * aw, 0.35, "a gap: a new episode", { fontSize: 13, italic: true, color: COLOR.muted, align: "center" });
  deck.text(s, ax, 1.55, 6, 0.4, "One patient, three admissions", { fontSize: 16, bold: true });
  // The recipe
  const steps = [
    { n: "1", f: "lag()", b: "the previous stay's end" },
    { n: "2", f: "CASE", b: "1 where a new run starts" },
    { n: "3", f: "sum() OVER", b: "a running sum numbers the runs" },
    { n: "4", f: "GROUP BY", b: "one row per run" },
  ];
  const gap = 0.35;
  const cw = (W - 2 * MARGIN - 3 * gap) / 4;
  steps.forEach((st, i) => {
    const x = MARGIN + i * (cw + gap);
    deck.panel(s, x, 4.45, cw, 2.2, { fill: COLOR.mist });
    deck.dot(s, x + 0.25, 4.65, 0.55, st.n, { fontSize: 18 });
    deck.chip(s, x + 0.95, 4.7, cw - 1.2, 0.45, st.f, { fill: COLOR.white, color: COLOR.tealDark, fontSize: 15 });
    deck.text(s, x + 0.25, 5.4, cw - 0.5, 1.1, st.b, { fontSize: 16 });
    if (i < 3) deck.arrow(s, x + cw + 0.04, 5.55, gap - 0.08, { color: COLOR.teal, width: 2.5 });
  });
}

// 13-15. Demo: islands
deck.demoSlides("demos/m3/islands.sql", {
  label: "Demo",
  steps: {
    1: { title: "lag(): the previous supply, beside each refill", notes: `
Two patients' metformin refills, typed in the setup cell (made up). Each covers days_supply days. lag() reads the previous row of the same patient (PARTITION BY patient, ORDER BY filled): gap_days is how long after the last supply ran out this refill came. The first refill has no previous one: NULL.

runs_out is an alias used inside lag() in the same SELECT: DuckDB allows that too.` },
    2: { title: "Flag the starts, number the runs", notes: `
The rule here (made up for the demo): a refill within 7 days of running out continues the course. A gap of more than 7, or no previous refill (NULL), starts a new one: flag 1. The running sum of the flags is the course number: it goes up by one at every start. WINDOW w names the window once so the query stays readable; C8 uses the same trick.` },
    3: { title: "GROUP BY the run: one row per island", notes: `
First the numbered refills: course_no goes up by one at every start. Then group by patient and course_no: min and max give the course's start and end, count(*) the refills. first(days_supply ORDER BY filled) takes a value from the course's first row; C8 takes the episode's state, age and first hospital that way, and its last hospital with ORDER BY ... DESC.

Hand over: C8 starts after the break.`, },
  },
});

// 16. Break
deck.sectionSlide({
  kicker: "10.00 · BREAK",
  title: "Back at 10.30: C8 starts",
  subtitle: "Episodes of care: the card is in cards.html",
  chips: [`${cardLabel(c8)} · ${c8.output}`],
  notes: `
Leave this up over the break. Anyone who wants a head start can read the C8 card: its definitions (a stay's end, what continues an episode) are the hard part.`,
});

// 17-18. C8
deck.challengeSlide(c8, `
30 minutes, about 10.30 to 11.00. The four steps of the demo, with C8's rule: an admission continues the episode if it starts on or before the previous stay's end + 1 day.

Watch for: a stay's end is its admit_date when the discharge date is missing or flagged (the card's first definition). "Previous" is the same patient's admission just before, at any hospital. age uses date_sub('year', dob, episode_start), whole years (Stretch S2 shows why not date_diff).`);

deck.revealSlide(c8, [
  { head: "Each stay's end first", body: "coalesce the discharge date, but a flagged or missing one ends the stay on its admit date." },
  { head: "Mark, then number", body: "lag() gives the previous end; a start flag; a running sum of the flags is episode_no." },
  { head: "First and last", body: "GROUP BY the episode; first(x ORDER BY admit_date) and first(x ORDER BY admit_date DESC) pick each end's values." },
], `
5 minutes. Walk the solution's three steps. Then its check cell: fewer episodes than admissions, and how many episodes span two hospitals (transfers).

Point out: this table is what makes C9 honest. Without it a transfer would count as a readmission on day 0.`);

// ----- C9 -------------------------------------------------------------------

// 19. C9 idea: look forward
{
  const s = deck.content("Did they come back within 30 days?", `
The C9 cycle, 11.05. Readmission looks forward: for each index episode, when does the patient's next episode start? lead() is lag()'s mirror: the next row instead of the previous one.

Two traps on the card. First, take lead() over all the patient's episodes before filtering to diabetes: the readmission can be for anything. Second, a patient who died can't be readmitted, and "died" is spelled several ways in two languages: a macro maps them once. A missing status is not a death.`);
  const ax = MARGIN + 0.3;
  const aw = W - 2 * MARGIN - 0.6;
  s.addShape(deck.shapes.LINE, { x: ax, y: 2.75, w: aw, h: 0, line: { color: COLOR.line, width: 1.5 } });
  deck.chip(s, ax, 2.4, 2.6, 0.7, "index episode · E11", { fill: COLOR.teal, color: COLOR.white, fontFace: FONT.body, fontSize: 15 });
  deck.chip(s, ax + 6.0, 2.4, 2.6, 0.7, "next episode · any dx", { fill: COLOR.ink2, color: COLOR.white, fontFace: FONT.body, fontSize: 15 });
  // The 30 days, bracketed
  s.addShape(deck.shapes.LINE, { x: ax + 2.6, y: 1.85, w: 3.4, h: 0, line: { color: COLOR.amber, width: 3, beginArrowType: "triangle", endArrowType: "triangle" } });
  deck.text(s, ax + 2.6, 1.4, 3.4, 0.4, "1 – 30 days: a readmission", { fontSize: 15, bold: true, align: "center" });
  deck.chip(s, ax + 9.0, 2.45, aw - 9.0, 0.6, "lead(episode_start)", { fill: COLOR.amberTint, color: COLOR.text, fontSize: 14 });
  const cards = [
    { head: "lead() over every episode", body: "The next episode may be for anything. Take lead() first, then keep the diabetes ones.", fill: COLOR.mist },
    { head: "Died: not an index", body: "A macro maps Died, Mati, Meninggal dunia ... to DIED. Use IS DISTINCT FROM 'DIED': NULL is not a death.", fill: COLOR.coralTint },
    { head: "Count with FILTER", body: "index episodes and readmissions in one GROUP BY state; the rate reuses both aliases.", fill: COLOR.mist },
  ];
  const gap = 0.35;
  const cw = (W - 2 * MARGIN - 2 * gap) / 3;
  cards.forEach((c, i) => {
    const x = MARGIN + i * (cw + gap);
    deck.panel(s, x, 3.75, cw, 2.9, { fill: c.fill });
    deck.text(s, x + 0.3, 3.95, cw - 0.6, 0.5, c.head, { fontFace: FONT.head, fontSize: 19, bold: true });
    deck.text(s, x + 0.3, 4.6, cw - 0.6, 1.9, c.body, { fontSize: 16 });
  });
}

// 20-22. Demo: lead
deck.demoSlides("demos/m3/lead-returns.sql", {
  label: "Demo",
  steps: {
    1: { title: "lead(): each visit with the next one", notes: `
Made-up emergency department visits (the setup cell). The ED's own quality question: of the patients sent home, who came back within 3 days? lead() reads the next row of the same patient. days_to_next reuses the next_visit alias in the same SELECT.` },
    2: { title: "A macro for the outcome", notes: `
The same outcome, written four ways in two languages, plus a stray space. The macro maps each spelling once; everything after it uses the macro. C9's norm_status does this for discharge status, comparing upper-case letters only, as C5's state_key did.` },
    3: { title: "Count with FILTER", notes: `
One row: how many were sent home, how many came back within 3 days, and the rate, which reuses the two count aliases. P3 died: not sent home, so not counted. P2 came back after 18 days: not a return.

C9 is the same shape, by state, with a 1-30 day window. Hand over to C9.` },
  },
});

// 23-24. C9
deck.challengeSlide(c9, `
30 minutes, about 11.13 to 11.43. norm_status first, and check every spelling maps (no NULLs). Then lead() over all of a patient's episodes, then filter to diabetes index episodes, then count by state.

The card's question "how many diabetes deaths would discharge_status = 'DIED' have missed?" is worth asking the room at the Reveal. Putrajaya has few index episodes: its rate jumps around (the Statistics track picks this up this afternoon).`);

deck.revealSlide(c9, [
  { head: "One spelling per status", body: "norm_status compares letters only, then maps every spelling, in both languages, to four statuses." },
  { head: "lead() before the filter", body: "The next episode is found among all the patient's episodes; only then keep the diabetes index ones." },
  { head: "Not a death, not missing", body: "IS DISTINCT FROM 'DIED' keeps a missing status; = 'DIED' on the raw text would miss Mati and Meninggal dunia." },
], `
5 minutes. Walk norm_status and its check, then the Core query. Ask the room the card's question about deaths missed by a plain = 'DIED'.

Then the rates: which state is highest, and how many index episodes is that? This afternoon's Statistics track adds a confidence interval to each rate.`);

// ----- C10 ------------------------------------------------------------------

// 25. C10 idea: wide and long
{
  const s = deck.content("Wide for people, long for SQL", `
The C10 cycle, 11.50. Spreadsheets and published tables are wide: one column per state or per year. SQL wants long: one row per state and year, so one GROUP BY or join covers them all. UNPIVOT turns wide into long; PIVOT turns long back into wide for the reader.

C10 does both: the MOH dengue CSV has one column per state, so it is unpivoted, joined to population, then pivoted on year for the one-page brief. Then the brief is exported.`);
  // wide -> long -> wide
  const wide = (x, y, cols, head) => {
    deck.text(s, x, y - 0.45, 3.4, 0.4, head, { fontSize: 15, bold: true, color: COLOR.muted });
    cols.forEach((c, i) => {
      deck.chip(s, x + i * 0.85, y, 0.8, 0.42, c, { fill: COLOR.tealDark, color: COLOR.white, fontSize: 12, margin: 1 });
      for (let r = 0; r < 3; r++) s.addShape(deck.shapes.RECTANGLE, { x: x + i * 0.85, y: y + 0.5 + r * 0.32, w: 0.8, h: 0.26, fill: { color: i ? COLOR.tint : COLOR.mist }, line: { type: "none" } });
    });
  };
  wide(MARGIN, 2.0, ["year", "JHR", "KDH", "KTN"], "Wide: a column per state");
  deck.arrow(s, MARGIN + 3.55, 2.75, 0.75, { color: COLOR.teal, width: 3 });
  deck.text(s, MARGIN + 3.3, 3.0, 1.3, 0.4, "UNPIVOT", { fontSize: 13, bold: true, color: COLOR.tealDark, fontFace: FONT.code, align: "center" });
  // long
  const lx = MARGIN + 4.55;
  deck.text(s, lx, 1.55, 3.4, 0.4, "Long: a row per state", { fontSize: 15, bold: true, color: COLOR.muted });
  ["year", "state", "n"].forEach((c, i) => {
    deck.chip(s, lx + i * 0.95, 2.0, 0.9, 0.42, c, { fill: COLOR.tealDark, color: COLOR.white, fontSize: 12, margin: 1 });
    for (let r = 0; r < 6; r++) s.addShape(deck.shapes.RECTANGLE, { x: lx + i * 0.95, y: 2.5 + r * 0.32, w: 0.9, h: 0.26, fill: { color: i ? COLOR.tint : COLOR.mist }, line: { type: "none" } });
  });
  deck.arrow(s, lx + 2.95, 2.75, 0.75, { color: COLOR.teal, width: 3 });
  deck.text(s, lx + 2.75, 3.0, 1.2, 0.4, "PIVOT", { fontSize: 13, bold: true, color: COLOR.tealDark, fontFace: FONT.code, align: "center" });
  wide(lx + 3.95, 2.0, ["state", "2018", "2019", "2020"], "Wide again: a column per year");
  // the code
  deck.code(s, MARGIN, 4.55, (W - 2 * MARGIN - 0.4) / 2, 2.1,
    "UNPIVOT wide_table\nON COLUMNS(* EXCLUDE (year))\nINTO NAME state VALUE n;", { max: 17, valign: "middle" });
  deck.code(s, MARGIN + (W - 2 * MARGIN + 0.4) / 2, 4.55, (W - 2 * MARGIN - 0.4) / 2, 2.1,
    "PIVOT long_table\nON year\nUSING sum(n)\nGROUP BY state;", { max: 17, valign: "middle" });
}

// 26-29. Demo: pivot and export
deck.demoSlides("demos/m3/pivot-export.sql", {
  label: "Demo",
  steps: {
    1: { title: "UNPIVOT: columns to rows", notes: `
The bed file has one column per kind of bed (non-ICU, ICU, ventilators). UNPIVOT ... ON COLUMNS(* EXCLUDE (state, hospital)) turns every other column into rows: kind holds the old column name, beds its value. Three rows per hospital now.` },
    2: { title: "Long tables are easy to aggregate", notes: `
One GROUP BY covers every kind of bed, and a new kind would need no change to the query. On the wide table this would be three sums, edited by hand.` },
    3: { title: "PIVOT: rows to columns", notes: `
DOSM's population is long: one row per state, year, sex, age group and ethnicity. Keep the overall rows, then PIVOT ON year: one column per year, named by its value. USING says what goes in each cell. Population is in thousands (C10's card says so too).

PIVOT is a statement here, not inside a CTE: on DuckDB 2.0.0 a PIVOT inside a CTE fails until 2.0.1.` },
    4: { title: "Export: Parquet, CSV, Excel", notes: `
COPY ... TO writes the table next to the Work database. Parquet keeps the types; CSV is for anyone; Excel needs the excel extension, which is in the bundle (LOAD it once). Reading the file back is the check that it worked: the same habit as counting rows against a manifest.

Then the 2-minute gsheets demo.` },
  },
});

// 30-31. Demo: gsheets
deck.demoSlides("demos/m3/gsheets-export.sql", {
  label: "Demo · gsheets",
  steps: {
    1: { title: "A table to a Google Sheet", notes: `
2 minutes, facilitator only, no hands-on. Signed in before the session (the setup cell, with the MyGovUC account), and the URL of an empty Sheet pasted into the demo file. Run the COPY, then switch to the browser tab with the Sheet: the rows are there.

This is the Capstone's optional Stretch: a team writes its summary to a Sheet in its Drive folder. It never costs marks.` },
    2: { title: "Read it back", notes: `
read_gsheet reads the Sheet like any file. If the sign-in fails on the day, skip this demo: the Capstone Stretch stays optional and the guide covers it.

Hand over to C10.` },
  },
});

// 32-33. C10
deck.challengeSlide(c10, `
35 minutes, about 12.00 to 12.35. Unpivot the dengue CSV, sum by state and year, join DOSM population, compute both rates, pivot on year, then join readmit_state and each state's top hospital. Export to Parquet and CSV.

Watch for: population is in thousands. The CSV writes WP KUALA LUMPUR and WP LABUAN: run the unpivoted names through norm_state (C10's first cell has the C5 macros). Start the long table from population, so a state with no admissions in a year still has a row with 0. The Self-check compares columns by position.`);

deck.revealSlide(c10, [
  { head: "Unpivot, then normalise", body: "UNPIVOT the state columns to rows, then norm_state the names, so the CSV's spellings join." },
  { head: "Start from the people", body: "Population by state and year is the spine: a state with no dengue admissions still gets a 0 rate." },
  { head: "Pivot for the reader, export", body: "PIVOT ON year with two USING values gives 2018_adm, 2018_cases ...; COPY writes Parquet and CSV." },
], `
5 minutes, or skip to the S3 demo and leave the solution for them to read: it's in the bundle. Show the finished state_brief: this is the State Health Brief for 2018-2020, one row per state. The Capstone asks for 2021.`);

// ----- S3 -------------------------------------------------------------------

const s3 = BACKUP.steps;
const firstBackup = deck.count + 1 + 2 + 7 + 3; // after: section, picture, 7 steps, private S3, Python/R, close
// 34. Section
deck.sectionSlide({
  kicker: "12.40 · LIVE DEMO · 15 MIN",
  title: "30 million admissions on S3",
  subtitle: "The hospital-load question at national scale: the data stays remote, the answer comes home",
  chips: ["30,105,844 admissions", "16 Parquet files", "732 MiB", "ap-southeast-5"],
  notes: `
Facilitator only; Participants watch. Before the session: aws sso login --profile naufal that morning, then the setup cell of demos/m3/s3-demo.sql in the UI (secret, no file cache, HTTP log, fetched() macro). facility_clean must be in the Work database (or the demo loads its Checkpoint).

If the network fails: phone hotspot, and skip step 3b (414 MiB). If that fails too, the backup slides at the end of this deck (from slide ${firstBackup}) hold the captured output of every step: in the slide show, type ${firstBackup} and press Enter.`,
});

// 35. The picture
{
  const s = deck.content("Big data stays remote; the answer comes home", `
Set up the demo with this picture. The large dataset is the same synthetic story at about 300 times the scale: 30 million clean admissions, 2018-2021, in a private S3 bucket. DuckDB on the laptop reads only what each query needs, joins it to the small clean hospital list from C5, which stays local, and writes ten rows home.

The bucket is private: the secret uses the facilitator's AWS login (credential_chain), so no keys appear in the SQL. The private-S3 slide after the demo shows how Participants would do the same with their own data.`);
  // Bucket
  deck.panel(s, MARGIN, 1.5, 4.0, 4.9, { fill: COLOR.ink });
  deck.text(s, MARGIN + 0.3, 1.65, 3.8, 0.45, "S3 · private bucket", { fontSize: 16, bold: true, color: COLOR.amber });
  deck.text(s, MARGIN + 0.3, 2.1, 3.8, 0.4, "duckdb-series2-2026/large/", { fontSize: 13, color: "C9D6E3", fontFace: FONT.code });
  ["year=2018", "year=2019", "year=2020", "year=2021"].forEach((y, i) => {
    const yy = 2.7 + i * 0.85;
    deck.chip(s, MARGIN + 0.3, yy, 1.6, 0.6, y, { fill: COLOR.ink2, color: COLOR.white, fontSize: 13 });
    for (let k = 0; k < 4; k++) s.addShape(deck.shapes.RECTANGLE, { x: MARGIN + 2.05 + k * 0.45, y: yy + 0.08, w: 0.38, h: 0.44, fill: { color: i === 3 ? COLOR.teal : "3C5873" }, line: { type: "none" } });
  });
  deck.text(s, MARGIN + 0.3, 6.0, 3.8, 0.35, "16 Parquet files · 732 MiB", { fontSize: 13, color: "C9D6E3" });
  // Arrow: only what the query needs
  deck.arrow(s, MARGIN + 4.1, 3.95, 1.2, { color: COLOR.teal, width: 4 });
  deck.text(s, MARGIN + 4.0, 3.1, 1.4, 0.8, "only the columns and years asked for", { fontSize: 13, align: "center", color: COLOR.muted });
  // Laptop
  const lx = MARGIN + 5.45;
  deck.panel(s, lx, 1.5, 3.4, 4.9, { fill: COLOR.mist });
  deck.text(s, lx + 0.3, 1.65, 2.8, 0.45, "Facilitator laptop", { fontSize: 16, bold: true });
  deck.chip(s, lx + 0.3, 2.3, 2.8, 0.6, "DuckDB 1.5.6", { fill: COLOR.amber, color: COLOR.ink, fontSize: 15 });
  deck.chip(s, lx + 0.3, 3.2, 2.8, 0.6, "secret: credential_chain", { fill: COLOR.white, color: COLOR.tealDark, fontSize: 12 });
  deck.chip(s, lx + 0.3, 4.1, 2.8, 0.6, "facility_clean (C5)", { fill: COLOR.tint, color: COLOR.tealDark, fontSize: 14 });
  deck.text(s, lx + 0.3, 4.8, 2.8, 0.9, "166 clean hospitals, local", { fontSize: 13, color: COLOR.muted });
  // Home
  deck.arrow(s, lx + 3.5, 3.95, 0.7, { color: COLOR.teal, width: 4 });
  const hx = lx + 4.3;
  deck.panel(s, hx, 2.85, W - MARGIN - hx, 2.2, { fill: COLOR.greenTint });
  deck.text(s, hx + 0.25, 3.0, W - MARGIN - hx - 0.5, 0.5, "Home", { fontFace: FONT.head, fontSize: 20, bold: true, color: COLOR.green });
  deck.text(s, hx + 0.25, 3.55, W - MARGIN - hx - 0.5, 0.45, "10 rows, as Parquet:", { fontSize: 15 });
  deck.text(s, hx + 0.25, 4.0, W - MARGIN - hx - 0.4, 0.8, "hospital_load_\nnational.parquet", { fontSize: 13, fontFace: FONT.code, color: COLOR.tealDark });
}

// 36-42. Demo: S3
deck.demoSlides("demos/m3/s3-demo.sql", {
  label: "Live",
  steps: {
    1: { title: "A count from the footers alone", notes: `
Run the count: 30 million admissions, and almost nothing downloaded (0.5 MiB on 9 Nov): Parquet keeps the row count in each file's footer. No keys in the SQL: the secret from the setup cell supplies the credential.

Then the which_secret cell: it names the secret DuckDB picked for this path (demo). Useful when several secrets exist; the private-S3 slide comes back to it.` },
    2: { title: "Hive partitioning: year from the folder names", notes: `
DESCRIBE: year is a column, but it isn't in any file. DuckDB reads it from the folder names (year=2018 ...). It's detected automatically, with no flag. A filter on year can skip whole folders: step 3.` },
    3: { title: "Clear the HTTP log", notes: `
The setup cell turned on HTTP logging in memory. Clear it now, so the next fetched() shows one query's bytes only.` },
    "3a": { title: "Two columns, one year: 7 MiB", notes: `
Run the query, then fetched(): about 7 MiB in 76 requests on 9 Nov. The two columns are facility_code, read from the 4 files of 2021, and year, which comes from the folder names and costs nothing. Then clear the log again.` },
    "3b": { title: "Every column, every year: 414 MiB", notes: `
On a phone hotspot, skip this one and quote the backup figure: 414 MiB in 271 requests. count(COLUMNS(*)) forces every column of every file over the network: about 60 times step 3a.

Then EXPLAIN ANALYZE on step 3a's query: find "Scanning Files: 4/16" and the File Filters on year. The pruning is in the plan, not just in the bytes.` },
    4: { title: "The brief question, at national scale", notes: `
Hospital load 2021 vs 2020: the admissions are read from S3 (2 years, 3 columns, about 55 MiB), joined to the local facility_clean from C5, top 10 by 2021 admissions. Bed-days are counted as C4's los_days: discharge date minus admit date.

Synthetic data: the numbers say nothing about the real hospitals.` },
    5: { title: "Bring home the answer, not the data", notes: `
COPY writes ten rows next to the Work database: the answer is home, the 30 million rows never left the bucket. Same COPY as C10's export a few minutes ago.

The whole demo ran in about 45 seconds on 9 Nov.` },
  },
});

// 43. Private S3
{
  const s = deck.content("Reading a private bucket of your own", `
1-2 minutes; the guide's "Reading a private bucket" section has the full recipes. AWS only, read-only.

Walk the four boxes: the demo's way (your existing AWS login, credential_chain; needs the aws extension, which is in the bundle). Keys in a secret (PROVIDER config) work, but never commit keys or paste them into notebooks. PERSISTENT keeps a secret across sessions, stored unencrypted in ~/.duckdb/stored_secrets. SCOPE gives a bucket or prefix its own secret, and which_secret shows which one a path will use.

Since 1.4.1, CREATE SECRET checks that the credentials exist when you create it; VALIDATION 'none' skips that check (for example, before an SSO login).`);
  const gap = 0.35;
  const cw = (W - 2 * MARGIN - gap) / 2;
  const boxes = [
    { head: "Your AWS login, no keys", sql: "CREATE SECRET (TYPE s3,\n  PROVIDER credential_chain, CHAIN 'sso',\n  PROFILE 'me', REGION 'ap-southeast-5');", note: "What the demo used. Needs the aws extension (in your bundle)." },
    { head: "Keys, if you must", sql: "CREATE SECRET (TYPE s3, PROVIDER config,\n  KEY_ID '…', SECRET '…', REGION '…');", note: "Never commit keys, or paste them into a notebook.", warn: true },
    { head: "Across sessions", sql: "CREATE PERSISTENT SECRET mine (TYPE s3,\n  PROVIDER credential_chain, …);", note: "Stored unencrypted in ~/.duckdb/stored_secrets.", warn: true },
    { head: "One secret per bucket", sql: "CREATE SECRET team (…, SCOPE 's3://bucket/team');\nFROM which_secret('s3://bucket/team/x', 's3');", note: "which_secret shows the secret a path will use." },
  ];
  boxes.forEach((b, i) => {
    const x = MARGIN + (i % 2) * (cw + gap);
    const y = 1.4 + Math.floor(i / 2) * 2.45;
    deck.panel(s, x, y, cw, 2.25, { fill: b.warn ? COLOR.amberTint : COLOR.mist });
    deck.text(s, x + 0.25, y + 0.12, cw - 0.5, 0.42, b.head, { fontSize: 17, bold: true });
    deck.code(s, x + 0.25, y + 0.58, cw - 0.5, 1.1, b.sql, { max: 14, valign: "middle" });
    deck.text(s, x + 0.25, y + 1.75, cw - 0.5, 0.42, b.note, { fontSize: 14, valign: "middle" });
  });
  deck.text(s, MARGIN, 6.35, W - 2 * MARGIN, 0.35, [
    { text: "CREATE SECRET checks the credentials exist (since 1.4.1); ", options: {} },
    { text: "VALIDATION 'none'", options: { fontFace: FONT.code } },
    { text: " skips the check.", options: {} },
  ], { fontSize: 14, color: COLOR.muted });
}

// 44. Python and R
{
  const s = deck.content("DuckDB from Python and R", `
5 minutes, 12.55. No live demo: the overview, then the take-home notebooks.

The point: the same DuckDB, from a script. Everything this morning's SQL built can be read from Python or R, either from the Work database or from the Checkpoint Parquet in expected/. Python: the duckdb package (pin 1.5.6, as the workshop), results straight to a pandas DataFrame, charts with matplotlib. R: the CRAN duckdb package through DBI, with ggplot2 for charts and dbplyr for dplyr verbs that run as SQL.

The R notebook runs on the CRAN package, DuckDB 2.0: that's why the materials share data as Parquet and avoid syntax 2.0 changed.

The notebooks pick up the State Health Brief where C10 ends. They ship with the guide, by 20 November. A third idea for Python users: rerun the solutions chain as a job and diff it against expected/, which is how a SQL pipeline gets automated.`);
  const gap = 0.4;
  const cw = (W - 2 * MARGIN - gap) / 2;
  const cols = [
    { head: "DuckDB + Python", libs: ["duckdb 1.5.6", "pandas", "matplotlib"], code: "import duckdb\ndf = duckdb.sql(\n  \"FROM 'expected/state_brief.parquet'\"\n).df()" },
    { head: "DuckDB + R", libs: ["duckdb (CRAN)", "DBI", "ggplot2", "dbplyr"], code: "library(DBI)\ncon <- dbConnect(duckdb::duckdb())\ndf <- dbGetQuery(con,\n  \"FROM 'expected/state_brief.parquet'\")" },
  ];
  cols.forEach((c, i) => {
    const x = MARGIN + i * (cw + gap);
    deck.panel(s, x, 1.4, cw, 4.0, { fill: COLOR.mist });
    deck.text(s, x + 0.3, 1.55, cw - 0.6, 0.5, c.head, { fontFace: FONT.head, fontSize: 22, bold: true });
    let cx = x + 0.3;
    c.libs.forEach((l) => {
      const w = l.length * 0.11 + 0.35;
      deck.chip(s, cx, 2.2, w, 0.42, l, { fill: COLOR.white, color: COLOR.tealDark, fontSize: 13 });
      cx += w + 0.15;
    });
    deck.code(s, x + 0.3, 2.9, cw - 0.6, 2.25, c.code, { max: 16, valign: "middle" });
  });
  deck.panel(s, MARGIN, 5.65, W - 2 * MARGIN, 1.0, { fill: COLOR.amberTint });
  deck.text(s, MARGIN + 0.3, 5.65, W - 2 * MARGIN - 0.6, 1.0, [
    { text: "Take-home notebooks: ", options: { bold: true } },
    { text: "one in Python, one in R. Both start from the Checkpoint Parquet and carry on the State Health Brief. They come with the guide, by 20 November.", options: {} },
  ], { fontSize: 16, valign: "middle" });
}

// 45. Close
deck.sectionSlide({
  kicker: "1.00 · LUNCH",
  title: "Back at 2.00: Extension tracks",
  subtitle: "A short tour of all three, then you pick two",
  chips: tracks.map((c) => c.title),
  notes: `
Leave this up over lunch. The tracks each start from the Checkpoints, so nobody needs to have finished this morning to do them.

Over lunch, check the S3 bucket isn't still being read (close the UI tab with the demo), and open the Capstone brief for 3.40.`,
});

// ----- Backup: the S3 demo's captured output --------------------------------

function backupSlide(step, title, notes, draw) {
  const s = deck.content(title, `${notes}\n\nCaptured ${BACKUP.captured} (${BACKUP.region}). ${BACKUP.about}`);
  deck.chip(s, MARGIN, 1.3, 3.3, 0.42, `Backup · step ${step}`, { fontFace: FONT.body, fontSize: 14, fill: COLOR.coralTint, color: COLOR.coral });
  deck.text(s, MARGIN + 3.6, 1.3, 8.5, 0.42, `captured ${BACKUP.captured} · demos/m3/s3-demo.sql`, { fontSize: 14, color: COLOR.muted, valign: "middle" });
  draw(s);
  return s;
}

if (deck.count + 1 !== firstBackup) throw new Error(`m3: the S3 notes point at slide ${firstBackup}, but the backup starts at ${deck.count + 1}`);

// 46. Backup: steps 1 and 2
backupSlide("1", "Backup: 30 million rows, counted from the footers", `
Use if the network failed. Step 1's count, and what it cost: half a MiB for 30 million rows, because the count is in each Parquet file's footer.`, (s) => {
  stat(s, MARGIN, 2.0, 5.4, num(s3["1"].rows[0][0]), "admissions, 2018 – 2021", { size: 44 });
  stat(s, MARGIN, 3.7, 5.4, s3["1"].fetched, "fetched to count them: the footers only", { fill: COLOR.greenTint, color: COLOR.green });
  deck.text(s, MARGIN, 5.4, 5.4, 1.2, "No keys in the SQL, no download: one secret, and DuckDB reads the footers.", { fontSize: 16 });
  deck.text(s, MARGIN + 6.0, 2.0, W - 2 * MARGIN - 6.0, 0.4, "THE QUERY", { fontSize: 13, bold: true, color: COLOR.muted });
  deck.code(s, MARGIN + 6.0, 2.45, W - 2 * MARGIN - 6.0, 1.6,
    "SELECT count(*) AS admissions\nFROM 's3://duckdb-series2-2026/large/\n      admission/*/*.parquet';", { max: 16, valign: "middle" });
  deck.panel(s, MARGIN + 6.0, 4.35, W - 2 * MARGIN - 6.0, 1.6, { fill: COLOR.mist });
  deck.text(s, MARGIN + 6.3, 4.45, W - 2 * MARGIN - 6.6, 1.4, "Every Parquet file ends with a footer: its row count, column types and min/max per block. A count needs only those.", { fontSize: 16, valign: "middle" });
});
backupSlide("2", "Backup: the columns, and year from the folder names", `
Use if the network failed. DESCRIBE on the bucket path: year (the last row) is in no file; DuckDB reads it from the folder names, year=2018 to year=2021.`, (s) => {
  resultTable(s, MARGIN, 2.0, 6.2, s3["2"].columns, s3["2"].rows, { fontSize: 13, rowH: 0.34, colW: [3.4, 2.8] });
  deck.panel(s, MARGIN + 6.8, 2.0, W - 2 * MARGIN - 6.8, 2.2, { fill: COLOR.amberTint });
  deck.text(s, MARGIN + 7.1, 2.15, W - 2 * MARGIN - 7.4, 1.9, [
    { text: "year", options: { fontFace: FONT.code, bold: true } },
    { text: " is not in any file: it's read from the folder names, ", options: {} },
    { text: "admission/year=2021/", options: { fontFace: FONT.code } },
    { text: ". A filter on it skips whole folders.", options: {} },
  ], { fontSize: 17, valign: "middle" });
});

// 48. Backup: step 3a and 3b, the pruning
backupSlide("3a", "Backup: pruning, measured", `
Use if the network failed, or quote the right-hand figure if you skipped 3b on a hotspot. Step 3a read two columns of one year: ${s3["3a"].fetched} in ${s3["3a"].requests} requests, and the plan shows ${s3["3a"].plan}. Step 3b read everything: ${s3["3b"].fetched} in ${s3["3b"].requests} requests.`, (s) => {
  resultTable(s, MARGIN, 2.0, 5.4, s3["3a"].columns, s3["3a"].rows, { fontSize: 14, rowH: 0.38, colW: [3.0, 2.4] });
  deck.chip(s, MARGIN, 4.5, 5.4, 0.5, s3["3a"].plan, { fill: COLOR.ink, color: COLOR.white, fontSize: 15 });
  deck.text(s, MARGIN, 5.15, 5.4, 1.3, "From the plan (EXPLAIN ANALYZE): only the 2021 folder's files were opened.", { fontSize: 15 });
  stat(s, MARGIN + 6.0, 2.0, 3.0, s3["3a"].fetched, `3a · ${s3["3a"].requests} requests`, { fill: COLOR.greenTint, color: COLOR.green });
  deck.text(s, MARGIN + 6.0, 3.55, 3.0, 0.9, "two columns, 2021", { fontSize: 14, color: COLOR.muted });
  stat(s, MARGIN + 9.3, 2.0, W - 2 * MARGIN - 9.3, s3["3b"].fetched, `3b · ${s3["3b"].requests} requests`, { fill: COLOR.coralTint, color: COLOR.coral });
  deck.text(s, MARGIN + 9.3, 3.55, W - 2 * MARGIN - 9.3, 0.9, "every column, every year", { fontSize: 14, color: COLOR.muted });
  deck.text(s, MARGIN + 6.0, 4.6, W - 2 * MARGIN - 6.0, 1.6, "Same files, about 60 times the bytes. Name the columns and filter on the partition: the rest never crosses the network.", { fontSize: 17 });
});
backupSlide("3b", "Backup: every column, every year", `
Use if you skipped step 3b, or the network failed. This is the cost of SELECT * across all 16 files: ${s3["3b"].fetched}, against ${s3["3a"].fetched} for the pruned query.`, (s) => {
  const max = 414;
  const bars = [
    { label: "3a · two columns, 2021", v: parseFloat(s3["3a"].fetched), t: s3["3a"].fetched, fill: COLOR.green },
    { label: "4 · the brief query, 2020 – 2021", v: parseFloat(s3["4"].fetched), t: s3["4"].fetched, fill: COLOR.teal },
    { label: "3b · every column, every year", v: parseFloat(s3["3b"].fetched), t: s3["3b"].fetched, fill: COLOR.coral },
  ];
  const bx = MARGIN + 4.2;
  const bw = W - MARGIN - bx - 1.8;
  bars.forEach((b, i) => {
    const y = 2.3 + i * 1.3;
    deck.text(s, MARGIN, y, 4.0, 0.7, b.label, { fontSize: 16, valign: "middle" });
    s.addShape(deck.shapes.RECTANGLE, { x: bx, y: y + 0.1, w: Math.max(0.06, (b.v / max) * bw), h: 0.5, fill: { color: b.fill }, line: { type: "none" } });
    deck.text(s, bx + Math.max(0.06, (b.v / max) * bw) + 0.15, y, 1.6, 0.7, b.t, { fontSize: 18, bold: true, valign: "middle" });
  });
  deck.text(s, MARGIN, 6.1, W - 2 * MARGIN, 0.5, `${s3["3b"].requests} requests for 3b, against ${s3["3a"].requests} for 3a. On a phone hotspot, 3b is the one to skip.`, { fontSize: 15, color: COLOR.muted });
});

// 50. Backup: step 4
backupSlide("4", "Backup: hospital load, 2021 vs 2020", `
Use if the network failed. The top 10 hospitals by 2021 admissions, read from S3 (${s3["4"].fetched}) and joined to the local facility_clean. Synthetic data: the hospital names are real, the numbers are not.

Step 5 then wrote these ten rows to hospital_load_national.parquet.`, (s) => {
  const cols = ["state", "facility_name", "adm 2020", "adm 2021", "bed-days 2020", "bed-days 2021", "change %"];
  resultTable(s, MARGIN, 1.95, W - 2 * MARGIN, cols, s3["4"].rows, { fontSize: 12, rowH: 0.36, colW: [1.55, 4.55, 1.05, 1.05, 1.25, 1.25, 1.433] });
  deck.text(s, MARGIN, 6.15, W - 2 * MARGIN, 0.45, `Fetched ${s3["4"].fetched} · synthetic data, not real hospital performance`, { fontSize: 14, color: COLOR.muted, italic: true });
});

deck.write().catch((e) => {
  console.error(e);
  process.exit(1);
});
