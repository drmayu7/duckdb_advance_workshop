// Day 1, 10.30-1.00: Module 1, Reading raw data safely (ADR 0004).
// node slides/m1.js  ->  handouts/m1.pptx
"use strict";

const { Deck, COLOR, FONT, W, MARGIN, cardsOf, cardLabel } = require("./theme");

const deck = new Deck({
  name: "m1",
  title: "Module 1: Reading raw data safely",
  footer: "DuckDB Workshop Series 2 · Day 1 · Module 1: Reading raw data safely",
});
const [c1, c2, c3] = cardsOf("m1");

// 1. Title
deck.titleSlide({
  kicker: "DAY 1 · MODULE 1 · 10.30 – 1.00",
  title: "Reading raw data safely",
  subtitle: "Before anyone trusts a number, prove the files gave you every row",
  meta: "CSV vs Parquet · read_csv, sniffing and rejects · SUMMARIZE and COLUMNS(*) · UNION BY NAME",
  notes: `
Module 1 runs in three cycles (C1, C2, C3), after a 15-minute opening demo on file formats. Timing: 10.30 story and demo, 10.50 C1 cycle, 11.40 C2 cycle, 12.15 C3 cycle, 12.55 wrap.

The message of the whole module: reading a file is not the same as reading it correctly. Every Challenge ends with a check that proves nothing was lost.`,
});

// 2. The Scenario
{
  const s = deck.content("The Director wants a State Health Brief", `
This is the Scenario for all three days. The Participants are an analytics team at a health informatics centre. The Director asks three questions for 2018-2021, and every Challenge builds a piece of the answer. On Day 3 each Capstone team delivers one question for 2021.

Stress: synthetic data. The patients and admissions are made up; the hospital names are real, so no number here says anything about a real hospital.`);
  const qs = [
    { n: "1", head: "Readmission", body: "30-day readmission among diabetes patients, by state" },
    { n: "2", head: "Dengue", body: "Dengue admissions per 100,000 people, by state and district" },
    { n: "3", head: "Hospital load", body: "Which hospitals carry the admission load" },
  ];
  const gap = 0.4;
  const cw = deck.colWidth(3, gap);
  qs.forEach((q, i) => {
    const x = MARGIN + i * (cw + gap);
    deck.panel(s, x, 1.5, cw, 3.7, { fill: COLOR.mist });
    deck.text(s, x + 0.35, 1.65, 1.5, 1.4, q.n, { fontFace: FONT.head, fontSize: 72, bold: true, color: COLOR.amber });
    deck.text(s, x + 0.35, 3.05, cw - 0.7, 0.55, q.head, { fontFace: FONT.head, fontSize: 24, bold: true });
    deck.text(s, x + 0.35, 3.65, cw - 0.7, 1.3, q.body, { fontSize: 17, color: COLOR.text });
  });
  deck.panel(s, MARGIN, 5.55, W - 2 * MARGIN, 1.15, { fill: COLOR.tint });
  deck.text(s, MARGIN + 0.35, 5.6, W - 2 * MARGIN - 0.7, 1.05, [
    { text: "You are the analytics team. ", options: { bold: true } },
    { text: "Day 1 builds the one clean admissions table all three answers start from. Synthetic data: the hospital names are real, the patients are not.", options: {} },
  ], { fontSize: 17, valign: "middle" });
}

// 3. Three systems
{
  const s = deck.content("Three years, three hospital systems, three formats", `
The Raw extract in data/raw is how a real warehouse feed looks: the hospitals changed systems twice, and every system exported its own way. One file per month: 36 files.

The manifest is the sender's promise: how many records each file holds. Every Module 1 Challenge ends by proving the rows read equal the manifest. Keep that idea: "count against the source" is the habit to take home.`);
  const sys = [
    { year: "2018", name: "Old HIS", fmt: "CSV", files: "data/raw/2018-*.csv", note: "Malay column names; addresses with commas and line breaks" },
    { year: "2019", name: "Interim system", fmt: "JSON", files: "data/raw/2019-*.json", note: "English names; its own date formats" },
    { year: "2020", name: "New system", fmt: "Parquet", files: "data/raw/2020-*.parquet", note: "Typed columns, plus ward and admission type" },
  ];
  const gap = 0.4;
  const cw = deck.colWidth(3, gap);
  s.addShape(deck.shapes.LINE, { x: MARGIN, y: 1.95, w: W - 2 * MARGIN, h: 0, line: { color: COLOR.line, width: 2 } });
  sys.forEach((y, i) => {
    const x = MARGIN + i * (cw + gap);
    deck.chip(s, x, 1.6, 1.4, 0.7, y.year, { fill: COLOR.teal, color: COLOR.white, fontFace: FONT.head, fontSize: 24 });
    deck.panel(s, x, 2.6, cw, 2.75, { fill: COLOR.mist });
    deck.text(s, x + 0.3, 2.75, cw - 1.9, 0.5, y.name, { fontFace: FONT.head, fontSize: 21, bold: true, valign: "middle" });
    deck.chip(s, x + cw - 1.55, 2.78, 1.3, 0.45, y.fmt, { fill: COLOR.amber, color: COLOR.ink, fontSize: 15 });
    deck.chip(s, x + 0.3, 3.45, cw - 0.6, 0.45, y.files, { fill: COLOR.white, color: COLOR.text, fontSize: 14, bold: false });
    deck.text(s, x + 0.3, 4.1, cw - 0.6, 1.1, y.note, { fontSize: 15 });
  });
  deck.panel(s, MARGIN, 5.7, W - 2 * MARGIN, 1.0, { fill: COLOR.amberTint });
  deck.chip(s, MARGIN + 0.3, 5.97, 3.4, 0.46, "data/raw/manifest.csv", { fill: COLOR.white, color: COLOR.text, fontSize: 15 });
  deck.text(s, MARGIN + 4.0, 5.75, 8.0, 0.9, "The sender's promise: how many records each of the 36 files holds. Every Challenge today ends by checking against it.", { fontSize: 16, valign: "middle" });
}

// 4. Today's chain
deck.chainSlide("Each Challenge's output is the next one's input", [...cardsOf("m1"), ...cardsOf("m2")], `
The six Day 1 Challenges build one pipeline in the Work database. Module 1 (teal) reads; Module 2 (dark) cleans. C2 is a side step: it profiles raw_2018 without changing it. C5 cleans the hospital list and writes the macros C6 uses.

If someone falls behind, the Checkpoint keeps their chain intact: they load the expected table and the next Challenge works.`, [
  { module: "m1", head: "Module 1 · read", body: "Every row of 36 files from three systems, as text, proven against the manifest." },
  { module: "m2", head: "Module 2 · clean", body: "Real dates, one name per hospital and state, one row per real admission." },
]);

// 5. Section: file formats
deck.sectionSlide({
  kicker: "10.35 · DEMO · 30 MILLION ROWS",
  title: "Why file formats matter",
  subtitle: "The same admissions, once as one CSV and once as Parquet files",
  chips: ["CSV", "Parquet", "EXPLAIN ANALYZE"],
  notes: `
About 15 minutes, facilitator laptop only: Participants watch. The large dataset (30 million synthetic admissions, 2018-2021) is in large/ in the facilitator bundle; the CSV copy must be written before the session (about 20 s, 3.3 GiB: it's in the next slide's notes).

Participants can take the large dataset home: dist/duckdb-large-2018-2021.zip.`,
});

// 6. CSV vs Parquet, the idea
{
  const s = deck.content("CSV is text in rows; Parquet is typed columns", `
The picture to leave in their heads before the demo. CSV: one line per row, every value as text, so DuckDB must read every byte and guess every type. Parquet: each column stored together and compressed, the types written down, and small statistics (row count, min and max per block) in the file footer.

So Parquet answers "how many rows?" from the footer, reads only the columns a query names, and skips blocks whose min and max can't match the filter.`);
  const half = deck.colWidth(2, 0.5);
  // CSV side
  deck.panel(s, MARGIN, 1.45, half, 5.25, { fill: COLOR.mist });
  deck.chip(s, MARGIN + 0.3, 1.65, 1.4, 0.45, "CSV", { fill: COLOR.amber, color: COLOR.ink, fontSize: 16 });
  deck.code(s, MARGIN + 0.3, 2.3, half - 0.6, 1.9,
    "mrn,admit_ts,facility_code,...\nRN0001,2018-01-03 08:10,11-0101...\nRN0002,2018-01-03 09:45,11-0204...\nRN0003,2018-01-04 14:20,11-0101...\n...30 million more lines", { max: 15 });
  deck.text(s, MARGIN + 0.3, 4.45, half - 0.6, 2.1, [
    { text: "Every query reads every byte", options: { bullet: true, breakLine: true } },
    { text: "Types are guessed by sniffing", options: { bullet: true, breakLine: true } },
    { text: "Counting rows means reading to the end", options: { bullet: true } },
  ], { fontSize: 17, paraSpaceAfter: 8 });
  // Parquet side
  const px = MARGIN + half + 0.5;
  deck.panel(s, px, 1.45, half, 5.25, { fill: COLOR.tint });
  deck.chip(s, px + 0.3, 1.65, 1.6, 0.45, "Parquet", { fill: COLOR.teal, color: COLOR.white, fontSize: 16 });
  const cols = ["mrn", "admit_ts", "facility", "dx", "..."];
  const colW = (half - 0.6 - 4 * 0.12) / 5;
  cols.forEach((c, i) => {
    const x = px + 0.3 + i * (colW + 0.12);
    deck.text(s, x, 2.25, colW, 0.3, c, { fontSize: 12, align: "center", color: COLOR.tealDark, fontFace: FONT.code });
    for (let r = 0; r < 4; r++) {
      s.addShape(deck.shapes.RECTANGLE, { x, y: 2.6 + r * 0.32, w: colW, h: 0.26, fill: { color: i === 1 ? COLOR.teal : "9CCFCB" }, line: { type: "none" } });
    }
  });
  deck.text(s, px + 0.3, 3.95, half - 0.6, 0.3, "footer: types · row count · min / max per block", { fontSize: 13, italic: true, color: COLOR.tealDark });
  deck.text(s, px + 0.3, 4.45, half - 0.6, 2.1, [
    { text: "Reads only the columns you name", options: { bullet: true, breakLine: true } },
    { text: "Types are stored, not guessed", options: { bullet: true, breakLine: true } },
    { text: "Skips blocks that can't match a filter", options: { bullet: true } },
  ], { fontSize: 17, paraSpaceAfter: 8 });
}

// 7-11. Demo: CSV vs Parquet
deck.demoSlides("demos/m1/csv-vs-parquet.sql", {
  label: "Demo",
  steps: {
    1: { title: "Size on disk", notes: `
Run the size cell. The same 30 million admissions: about 3.3 GiB as CSV and a fraction of that as 16 Parquet files. Ask: which would you rather email, copy to a USB stick, or keep for ten years?` },
    2: { title: "How many rows?", notes: `
Run both counts and read out the run times under the cells. The CSV count reads the whole file, line by line. The Parquet count reads only the footers: the row count is written there.

This is also why the Module 1 Challenges count rows against a manifest: a count is cheap, and it's the first proof that a read lost nothing.` },
    3: { title: "Types: guessed or stored", notes: `
DESCRIBE both. In the CSV, secondary_dx comes back as text: a CSV can't hold a list. In Parquet it's VARCHAR[] and admit_ts a real TIMESTAMP. year doesn't exist inside the Parquet files: it comes from the folder names (year=2018 ...), Hive partitioning.` },
    4: { title: "A real question: the busiest hospitals in 2021", notes: `
The same query against both. The CSV run parses every column of every row; the Parquet run reads two columns and skips row groups whose stored admit_ts range is before 2021.

Compare the times out loud. On the facilitator laptop the difference is usually more than tenfold.` },
    5: { title: "Proof: only the 2021 files were opened", notes: `
EXPLAIN ANALYZE shows the plan with the work done. Find "Scanning Files: 4/16" on the scan: the filter on year picked the folders before any file was opened.

Hand over: Parquet is where we want to end up. But today's data arrives as CSV and JSON from hospital systems, so the rest of the module is about reading those safely.` },
  },
});

// 12. C1 idea: three checks
{
  const s = deck.content("Three checks before you trust a CSV", `
The C1 cycle starts here, about 10.50. The three checks are the module's method, not just C1's.

1. Ask the sniffer what it decided (sniff_csv) instead of trusting a count.
2. Keep the lines that don't fit (store_rejects) so a bad line can't vanish silently.
3. Count what you read against what the sender says it sent.

One definition to stress for C1: a record is not a line. A quoted address can hold a comma or a line break, so count records, never lines.`);
  const steps = [
    { head: "Sniff", fn: "sniff_csv(...)", body: "What delimiter, quote and columns did DuckDB decide on?" },
    { head: "Keep the rejects", fn: "store_rejects = true", body: "Lines that don't fit go to reject_errors, not to nowhere." },
    { head: "Count against the source", fn: "rows read = manifest", body: "Every file gave exactly the rows its sender promised." },
  ];
  const gap = 0.55;
  const cw = deck.colWidth(3, gap);
  steps.forEach((st, i) => {
    const x = MARGIN + i * (cw + gap);
    deck.panel(s, x, 1.55, cw, 3.6, { fill: i === 2 ? COLOR.greenTint : COLOR.mist });
    deck.dot(s, x + 0.3, 1.8, 0.7, i + 1, { fill: i === 2 ? COLOR.green : COLOR.teal, fontSize: 22 });
    deck.text(s, x + 1.2, 1.8, cw - 1.4, 0.7, st.head, { fontFace: FONT.head, fontSize: 22, bold: true, valign: "middle" });
    deck.chip(s, x + 0.3, 2.85, cw - 0.6, 0.5, st.fn, { fill: COLOR.white, color: COLOR.tealDark, fontSize: 15 });
    deck.text(s, x + 0.3, 3.6, cw - 0.6, 1.4, st.body, { fontSize: 17 });
    if (i < 2) deck.arrow(s, x + cw + 0.08, 3.35, gap - 0.16, { color: COLOR.teal, width: 2.5 });
  });
  deck.panel(s, MARGIN, 5.5, W - 2 * MARGIN, 1.15, { fill: COLOR.amberTint });
  deck.text(s, MARGIN + 0.35, 5.55, W - 2 * MARGIN - 0.7, 1.05, [
    { text: "A record is not a line. ", options: { bold: true } },
    { text: "A quoted address can hold a comma or a line break, so a file's record count and its line count differ. Count records.", options: {} },
  ], { fontSize: 17, valign: "middle" });
}

// 13-16. Demo: reading a CSV you don't trust
deck.demoSlides("demos/m1/read-csv-safely.sql", {
  label: "Demo",
  steps: {
    1: { title: "A plain read gives one column, not three", notes: `
Participants can follow along: run the setup cell (it writes beds_feed.csv, five made-up bed returns with real hospital names), then the plain read. One column called "hospital,state,beds". Ask: what went wrong? Nobody asked for one column, and there's no error.` },
    2: { title: "Ask the sniffer what it decided", notes: `
sniff_csv shows the sniffer's decision: delimiter "|" (it gave up on commas) and 1 column. Line 5 is a field short, so no delimiter fitted every line. The sniffer's guess is a guess: check it before trusting any count.` },
    3: { title: "Say what you expect, keep what doesn't fit", notes: `
Now we tell it: comma-delimited, beds is an INTEGER, and keep the rejects. Three rows come back. reject_errors shows the other two: line 3 ("tiada" is not a number) and line 5 (missing a column). Nothing vanished: it's all accounted for.

The rejects tables last only for this session (they're temporary), so C1 asks you to copy them into a table.` },
    4: { title: "Keep every line, then count", notes: `
The other strategy: read everything as text (all_varchar), pad short lines with NULL, and keep the file name. Five rows, the same five the sender sent. Cleaning "tiada" into NULL is Module 2's job: here we only make sure no row is lost.

Hand over to C1: twelve monthly files from the old HIS, and a manifest to check against.` },
  },
});

// 17-18. C1
deck.challengeSlide(c1, `
30 minutes, about 11.05 to 11.35. The card leads them through the first look: a plain read of January disagrees with the manifest, then sniff_csv, then rejects.

The key discovery, which the card hints at: some addresses have quotes inside a quoted field that aren't doubled. The error message for an explicit quote names the read_csv option that tolerates it. Let them find it; if a table is stuck at 11.20, point them at the error message, not the answer.

Core done = all twelve files' row counts match the manifest and the Self-check gives 0.`);

deck.revealSlide(c1, [
  { head: "The sniffer gave up", body: "Quotes inside quoted addresses broke the rules, so no delimiter fitted and each line became one column." },
  { head: "strict_mode = false", body: "Tolerates the quotes the old HIS didn't double; all_varchar = true keeps every value exactly as written." },
  { head: "Prove nothing dropped", body: "Manifest LEFT JOIN raw_2018, HAVING the counts differ: 0 rows means every file is complete." },
], `
10 minutes. Run the solution from the top: the January mismatch, the sniffer's verdict, the rejects, then the fix. Make the manifest check the climax: 0 rows is the proof, not "it looked fine".

Stretch S1 (rejects per file) shows reject_scans: the rejects tables keep every scan of the session, so count only the latest. Stretch S2 (lost leading zeros) sets up C6's IC cleaning: mention it, don't solve it.`);

// 19. C2 idea: SUMMARIZE
{
  const s = deck.content("Profile before you trust", `
The C2 cycle, about 11.45. Two tools: SUMMARIZE (one row of statistics per column) and COLUMNS(*) (one expression applied to every column).

How to read SUMMARIZE: min and max first. On text columns they compare strings, which is exactly what exposes leading spaces, lower case, and placeholder values like 01/01/1900. null_percentage only counts real NULLs: words that mean "nothing" are invisible to it.`);
  // A SUMMARIZE excerpt, from the demo's real open data
  const hdr = ["column_name", "column_type", "min", "max", "null_percentage"].map((t) => ({
    text: t, options: { bold: true, color: COLOR.white, fill: { color: COLOR.ink }, fontFace: FONT.code, fontSize: 14 },
  }));
  const cell = (t, o = {}) => ({ text: t, options: { fontFace: FONT.code, fontSize: 14, color: COLOR.text, ...o } });
  const hot = { fill: { color: COLOR.coralTint }, bold: true, color: COLOR.coral };
  s.addTable([
    hdr,
    [cell("hospital"), cell("VARCHAR"), cell("Hospital  Raja Permaisuri…", hot), cell("Pusat Perubatan…"), cell("0.00")],
    [cell("beds_nonicu"), cell("DOUBLE"), cell("-4.0", hot), cell("1672.0"), cell("26.85")],
    [cell("util_nonicu"), cell("DOUBLE"), cell("-1525.0", hot), cell("110.77"), cell("30.20")],
  ], {
    x: MARGIN, y: 1.5, w: W - 2 * MARGIN, colW: [2.0, 1.7, 3.5, 2.5, 2.43],
    border: { type: "solid", color: COLOR.line, pt: 1 }, fill: { color: COLOR.white }, rowH: 0.5, valign: "middle",
  });
  deck.text(s, MARGIN, 3.65, W - 2 * MARGIN, 0.35, "SUMMARIZE FROM 'data/open/bed_utilisation.csv' (excerpt): real MoH open data", { fontSize: 13, italic: true, color: COLOR.muted });
  const half = deck.colWidth(2, 0.4);
  [
    { head: "Read min and max first", body: "A double space, negative beds, a utilisation of −1525\u00a0%: the odd values sit at the ends." },
    { head: "COLUMNS(*): every column at once", body: "count(*) FILTER (WHERE COLUMNS(*) IS NULL) gives one count per column, in the table's order." },
  ].forEach((b, i) => {
    const x = MARGIN + i * (half + 0.4);
    deck.panel(s, x, 4.25, half, 2.35, { fill: i ? COLOR.tint : COLOR.mist });
    deck.text(s, x + 0.35, 4.45, half - 0.7, 0.5, b.head, { fontFace: FONT.head, fontSize: 21, bold: true });
    deck.text(s, x + 0.35, 5.05, half - 0.7, 1.4, b.body, { fontSize: 17 });
  });
}

// 20-23. Demo: profiling
deck.demoSlides("demos/m1/profile.sql", {
  label: "Demo",
  steps: {
    1: { title: "SUMMARIZE: every column in one result", notes: `
Run SUMMARIZE on the bed file and read min and max out loud. "Hospital  Raja Permaisuri Bainun" sorts first because of its double space. A hospital with -4 beds; a utilisation of -1525 %. Real published data has these too.` },
    2: { title: "COLUMNS(*): one expression, every column", notes: `
One line of SQL, one count per column, in the file's column order. C2 builds three rows like this one (real NULLs, null spellings, padded values) stacked with UNION ALL.` },
    3: { title: "Zero is not missing", notes: `
Before "fixing" NULLs, ask why they're there. Hospitals with 0 ICU beds have no ICU utilisation: those NULLs are correct. The 40 rows with no bed figures at all are a different story. Profiling tells you which NULLs are information.` },
    4: { title: "COLUMNS() with a pattern", notes: `
COLUMNS also takes a regular expression: every column starting with util_. A quick win when a table has dozens of similar columns. Hand over to C2.` },
  },
});

// 24-25. C2
deck.challengeSlide(c2, `
25 minutes, about 11.55 to 12.20. The card asks for three measures per column: real NULLs, "null spellings" (words like TIADA, N/A, '-' that mean nothing), and padded values with stray spaces.

Watch for: the padded measure needs trim with the non-breaking space too (the card says how). The Self-check compares by position: if they get hundreds of differences, check the column order first.`);

deck.revealSlide(c2, [
  { head: "SUMMARIZE first", body: "Placeholder dates in min and max, names starting with a space, lower case in max: the problems show before any query." },
  { head: "Three measures, one shape", body: "Each measure is one SELECT with COLUMNS(*); UNION ALL stacks them, one row per measure." },
  { head: "Words that mean nothing", body: "TIADA, N/A, '-' are not NULL, so null_percentage misses them. C4 turns them into NULL first." },
], `
10 minutes. Show SUMMARIZE raw_2018 and read the comments in the solution: they name each problem with its Answer key code (DT05, TX01, NU02). Then the three-measure table.

Read the result as a to-do list: which columns will C4 and C6 have to clean? That's the bridge to Module 2.`);

// 26. C3 idea: UNION BY NAME
{
  const s = deck.content("UNION BY NAME matches columns by name", `
The C3 cycle, about 12.20. Plain UNION ALL stacks by position: if two systems order their columns differently, values land under the wrong names without any error. UNION ALL BY NAME matches by column name, in any order, and fills a column one side doesn't have with NULL.

It only works if both sides use the same names. In C3 each system renames its columns to one vocabulary first.`);
  const tbl = (x, y, head, cols, rows, o = {}) => {
    const cw = 1.3;
    cols.forEach((c, i) => {
      deck.chip(s, x + i * (cw + 0.08), y, cw, 0.42, c, { fill: o.fill || COLOR.teal, color: COLOR.white, fontSize: 13, rectRadius: 0.05 });
      rows.forEach((r, j) => {
        const v = r[i];
        deck.chip(s, x + i * (cw + 0.08), y + 0.5 + j * 0.45, cw, 0.38, v, {
          fill: v === "NULL" ? COLOR.amberTint : COLOR.mist, color: v === "NULL" ? COLOR.text : COLOR.text, fontSize: 13, bold: v === "NULL",
        });
      });
    });
    deck.text(s, x, y - 0.45, 4.5, 0.35, head, { fontSize: 14, bold: true, color: COLOR.muted });
  };
  tbl(MARGIN, 1.95, "2019 · JSON", ["mrn", "name", "state"], [["J01", "AMIN", "PERAK"]]);
  tbl(MARGIN, 3.85, "2020 · Parquet", ["state", "mrn", "ward"], [["JOHOR", "P07", "W3"]], { fill: COLOR.tealDark });
  deck.arrow(s, 5.15, 3.4, 1.0, { color: COLOR.teal, width: 3 });
  deck.text(s, 4.95, 2.85, 1.5, 0.4, "BY NAME", { fontSize: 14, bold: true, color: COLOR.teal, align: "center", fontFace: FONT.code });
  tbl(6.5, 2.65, "UNION ALL BY NAME", ["mrn", "name", "state", "ward"], [["J01", "AMIN", "PERAK", "NULL"], ["P07", "NULL", "JOHOR", "W3"]], { fill: COLOR.ink });
  deck.panel(s, MARGIN, 5.45, W - 2 * MARGIN, 1.2, { fill: COLOR.coralTint });
  deck.text(s, MARGIN + 0.35, 5.5, W - 2 * MARGIN - 0.7, 1.1, [
    { text: "Plain UNION ALL stacks by position. ", options: { bold: true } },
    { text: "The 2020 state would land under mrn, with no error. Matching by name needs one vocabulary: rename first.", options: {} },
  ], { fontSize: 17, valign: "middle" });
}

// 27-30. Demo: combining
deck.demoSlides("demos/m1/combine.sql", {
  label: "Demo",
  steps: {
    1: { title: "DESCRIBE before you combine", notes: `
JSON and Parquet are read like CSV: read_json and read_parquet, or just the file name. DESCRIBE first: the MoH facility list names its columns in Malay (KOD_FASILITI, NEGERI, NAMA), DOSM's population file in English. Same idea as C3's three systems.` },
    2: { title: "UNION ALL stacks by position", notes: `
The offset shows the join between the two parts: facility codes landed under "name" and hospital names under "state". No error, just wrong. This is the failure UNION BY NAME prevents.` },
    3: { title: "UNION ALL BY NAME matches by name", notes: `
Columns in a different order, a column only one side has: both handled. beds is NULL for the JSON rows, facility_code NULL for the CSV rows. Note both sides first renamed their columns to one vocabulary (name, state).` },
    4: { title: "Every column as text in one line", notes: `
COLUMNS(* EXCLUDE (...))::VARCHAR casts every remaining column to text. When two feeds type the same column differently (a date in one, text in the other), casting both to text lets them stack; Module 2 types them properly once. Hand over to C3.` },
  },
});

// 31-32. C3
deck.challengeSlide(c3, `
30 minutes, about 12.25 to 12.55 (it may run into the wrap-up; that's fine). Three parts: raw_2018 (renamed from Malay), the 2019 JSON, the 2020 Parquet, combined with UNION ALL BY NAME into admission_raw, every column as text, with a source_system column.

Watch for: the 2020 Parquet has admit_ts and discharge_ts timestamps, not dates. The card says what to do. The manifest check at the end covers all 36 files.`);

deck.revealSlide(c3, [
  { head: "One vocabulary", body: "Each part renames its columns to the interim system's English names before they meet." },
  { head: "Everything as text", body: "COLUMNS(* EXCLUDE (…))::VARCHAR, so every system's columns stack; C4 types them once, properly." },
  { head: "By name, then prove it", body: "UNION ALL BY NAME fills ward and admission type with NULL before 2020; the manifest check covers all 36 files." },
], `
10 minutes, or carry it to just after lunch if time ran out. Show the three DESCRIBEs side by side first, then the one query.

Close the module: three tables, each with a proof. raw_2018 matches the manifest; profile_nulls says what to clean; admission_raw holds every row of all three systems.`);

// 33. Wrap
{
  const s = deck.content("What you have now", `
Two minutes before lunch. Each table comes with a proof, and that's the habit: a read isn't done until it's checked against the source.

After lunch, Module 2 cleans admission_raw: dates and numbers (C4), the hospital list and reusable macros (C5), and duplicates (C6). Anyone who didn't finish C3: load its Checkpoint over lunch so C4 works at 2.00.`);
  const items = [
    { c: c1, proof: "every file matches the manifest" },
    { c: c2, proof: "what C4 and C6 must clean" },
    { c: c3, proof: "all 36 files, three systems, one table" },
  ];
  items.forEach((it, i) => {
    const y = 1.6 + i * 1.45;
    deck.dot(s, MARGIN, y + 0.1, 0.8, cardLabel(it.c), { fontSize: 20 });
    deck.chip(s, MARGIN + 1.1, y + 0.15, 4.2, 0.7, it.c.output, { fill: COLOR.tint, color: COLOR.tealDark, fontSize: 20 });
    deck.arrow(s, MARGIN + 5.5, y + 0.5, 0.7, { color: COLOR.muted });
    deck.text(s, MARGIN + 6.4, y + 0.1, 5.6, 0.8, it.proof, { fontSize: 20, valign: "middle" });
  });
  deck.panel(s, MARGIN, 6.0, W - 2 * MARGIN, 0.75, { fill: COLOR.amberTint });
  deck.text(s, MARGIN + 0.35, 6.0, W - 2 * MARGIN - 0.7, 0.75, [
    { text: "Lunch, then Module 2 at 2.00. ", options: { bold: true } },
    { text: "Didn't finish C3? Load its Checkpoint before 2.00.", options: {} },
  ], { fontSize: 17, valign: "middle" });
}

deck.write().catch((e) => {
  console.error(e);
  process.exit(1);
});
