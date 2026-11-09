// Shared theme, layouts, readers and slide builders for the Series 2 decks
// (ADR 0004). Each slides/<deck>.js is a Claude-designed script on this theme;
// `node slides/<deck>.js` rebuilds handouts/<deck>.pptx exactly.
//
// Single-sourced content: Challenge slides read card front-matter, demo slides
// read demos/<deck>/*.sql, and the Fix sheet and setup-check slides read
// cards/setup.md. Card text is never copied into a deck script.
"use strict";

const fs = require("fs");
const path = require("path");
const pptxgen = require("pptxgenjs");
const JSZip = require("jszip");

const REPO = path.resolve(__dirname, "..");

// ---------------------------------------------------------------------------
// Palette: deep ink for the dark frames, clinical teal for structure, one
// amber accent (a nod to the duck) for what to look at. Coral marks what went
// wrong, green what passed.
const COLOR = {
  ink: "12263A",
  ink2: "1D3A56",
  teal: "0B7A75",
  tealDark: "075955",
  tint: "E3F2F0",
  mist: "F2F5F8",
  amber: "F2A900",
  amberTint: "FFF4D6",
  coral: "C8434F",
  coralTint: "FBE7E9",
  green: "2E8B57",
  greenTint: "E4F3EA",
  text: "1B2631",
  muted: "5B6B7A",
  line: "C9D3DC",
  white: "FFFFFF",
  codeBg: "0F1C2A",
  codeText: "E6EDF3",
  codeKw: "F2C14E",
  codeStr: "8FD3A8",
  codeComment: "8A9BAE",
};
const FONT = { head: "Cambria", body: "Calibri", code: "Courier New" };
const W = 13.333; // LAYOUT_WIDE
const H = 7.5;
const MARGIN = 0.6;

// ---------------------------------------------------------------------------
// Readers

/** Front-matter of one card, as an object with id, title, module, timebox, input, output. */
function readCard(file) {
  const text = fs.readFileSync(file, "utf8");
  const m = text.match(/^---\n([\s\S]*?)\n---\n/);
  if (!m) throw new Error(`${file}: no front-matter`);
  const fm = { file: path.relative(REPO, file), base: path.basename(file, ".md") };
  for (const line of m[1].split("\n")) {
    const i = line.indexOf(":");
    if (i > 0) fm[line.slice(0, i).trim()] = line.slice(i + 1).trim();
  }
  return fm;
}

/** Challenge cards in chain order (Warm-up, C1-C10, tracks), as tools/cards.sh lists them. */
function challengeCards() {
  const names = fs.readdirSync(path.join(REPO, "cards")).sort();
  const pick = (re) => names.filter((n) => re.test(n));
  return [...pick(/^w-.*\.md$/), ...pick(/^c\d\d-.*\.md$/), ...pick(/^t-.*\.md$/)].map((n) =>
    readCard(path.join(REPO, "cards", n)),
  );
}

function cardsOf(module) {
  return challengeCards().filter((c) => c.module === module);
}

/** The short label a Participant knows a Challenge by: W, C1 ... C10, and STATS, NAMES, SPATIAL for the tracks. */
function cardLabel(card) {
  if (card.id === "w") return "W";
  if (isTrack(card)) return card.id.slice(2).toUpperCase();
  const m = card.id.match(/^c0*(\d+)$/);
  return m ? `C${m[1]}` : card.id.toUpperCase();
}

/** An Extension track card (t-*), rather than a Challenge in the chain. */
function isTrack(card) {
  return card.id.startsWith("t-");
}

/** The name a card goes by in cards.html. */
function cardName(card) {
  if (card.id === "w") return "Warm-up";
  return isTrack(card) ? card.title : cardLabel(card);
}

/**
 * A demo SQL file as { file, header, setup, steps }. A step starts at a
 * comment "-- N. ..." and holds its comment (the explanation) and the SQL up
 * to the next step. Setup is the "-- begin setup" block, or any SQL before
 * step 1 (it is run before the session, so it goes in the notes).
 */
function readDemo(rel) {
  const file = path.join(REPO, rel);
  const lines = fs.readFileSync(file, "utf8").replace(/\r/g, "").split("\n");
  const header = [];
  let i = 0;
  while (i < lines.length && lines[i].startsWith("--")) header.push(lines[i++].replace(/^-- ?/, ""));
  const setup = [];
  const steps = [];
  let step = null;
  let inComment = false;
  for (; i < lines.length; i++) {
    const line = lines[i];
    const m = line.match(/^-- (\d+[a-z]?)\. (.*)$/);
    if (m) {
      step = { n: m[1], comment: [m[2]], sql: [] };
      steps.push(step);
      inComment = true;
      continue;
    }
    if (/^-- (begin|end) setup\s*$/.test(line)) continue;
    if (!step) {
      setup.push(line);
      continue;
    }
    if (inComment && line.startsWith("--")) {
      step.comment.push(line.replace(/^-- ?/, ""));
      continue;
    }
    inComment = false;
    step.sql.push(line);
  }
  const trim = (arr) => {
    while (arr.length && !arr[0].trim()) arr.shift();
    while (arr.length && !arr[arr.length - 1].trim()) arr.pop();
    return arr;
  };
  trim(setup);
  for (const s of steps) {
    trim(s.sql);
    s.text = s.comment.join(" ").replace(/\s+/g, " ").trim();
  }
  return { file: rel, header: header.join("\n"), setup: setup.join("\n"), steps };
}

/** One `## heading` section of a Markdown file, without the heading line. */
function mdSection(text, heading) {
  const lines = text.split("\n");
  const start = lines.findIndex((l) => l.startsWith("## ") && l.slice(3).startsWith(heading));
  if (start < 0) throw new Error(`no section "${heading}"`);
  let end = lines.findIndex((l, j) => j > start && l.startsWith("## "));
  if (end < 0) end = lines.length;
  return lines.slice(start + 1, end).join("\n");
}

function splitRow(row) {
  return row
    .replace(/^\s*\|/, "")
    .replace(/\|\s*$/, "")
    .split(/(?<!\\)\|/)
    .map((c) => c.trim().replace(/\\\|/g, "|"));
}

/** The setup card's Fix sheet: { reminder, rows: [{ problem, code, tryFirst, fallback }] }. */
function readFixSheet() {
  const text = fs.readFileSync(path.join(REPO, "cards", "setup.md"), "utf8");
  const sec = mdSection(text, "Fix sheet");
  const reminder = (sec.split("\n").find((l) => l.startsWith("**")) || "").trim();
  const rows = sec
    .split("\n")
    .filter((l) => l.startsWith("|") && !/^\|\s*-/.test(l))
    .slice(1)
    .map(splitRow)
    .map(([problem, tryFirst, fallback]) => {
      const m = problem.match(/^`([^`]+)`(.*?):\s*(.*)$/);
      return m
        ? { code: m[1], problem: m[3], aside: m[2].trim(), tryFirst, fallback }
        : { code: null, problem: problem.replace(/\*\*/g, ""), tryFirst, fallback };
    });
  return { reminder, rows };
}

/** The setup card's numbered morning steps: [{ n, text, sql }]. */
function readSetupSteps() {
  const text = fs.readFileSync(path.join(REPO, "cards", "setup.md"), "utf8");
  const sec = mdSection(text, "Day 1 setup check");
  const steps = [];
  let inCode = false;
  for (const line of sec.split("\n")) {
    const m = line.match(/^(\d+)\. (.*)$/);
    if (m) {
      steps.push({ n: m[1], text: m[2], sql: [] });
      continue;
    }
    if (/^\s*```/.test(line)) {
      inCode = !inCode;
      continue;
    }
    const last = steps[steps.length - 1];
    if (!last) continue;
    if (inCode) last.sql.push(line.trim());
    else if (line.trim() && /^\s{2,}/.test(line)) last.text += " " + line.trim();
  }
  return steps.map((s) => ({ ...s, sql: s.sql.join("\n") }));
}

/** The first sentence of a Markdown cell, for slides that have room for one. */
function firstSentence(md) {
  const m = md.match(/^(.*?[.!?])(\s|$)/);
  return m ? m[1] : md;
}

// ---------------------------------------------------------------------------
// Text helpers

/**
 * Inline Markdown (`code`, **bold**, *italic*) as pptxgenjs text runs, with
 * `base` options on every run. Code runs use the code font.
 */
function md(text, base = {}) {
  const runs = [];
  const re = /(`[^`]+`|\*\*[^*]+\*\*|(?<![\w(])\*[^*\s][^*]*\*(?![\w)]))/g;
  let last = 0;
  let m;
  while ((m = re.exec(text))) {
    if (m.index > last) runs.push({ text: text.slice(last, m.index), options: { ...base } });
    const t = m[0];
    if (t.startsWith("`")) runs.push({ text: t.slice(1, -1), options: { ...base, fontFace: FONT.code } });
    else if (t.startsWith("**")) runs.push({ text: t.slice(2, -2), options: { ...base, bold: true } });
    else runs.push({ text: t.slice(1, -1), options: { ...base, italic: true } });
    last = m.index + t.length;
  }
  if (last < text.length) runs.push({ text: text.slice(last), options: { ...base } });
  return runs;
}

const SQL_KEYWORDS = new Set(
  (
    "SELECT FROM WHERE GROUP BY ORDER HAVING JOIN LEFT ON AS WITH UNION ALL NAME LIMIT OFFSET CREATE OR " +
    "REPLACE TABLE MACRO COPY TO DESCRIBE SUMMARIZE QUALIFY OVER PARTITION CASE WHEN THEN ELSE END AND " +
    "IN IS NULL NOT DISTINCT EXCEPT EXPLAIN ANALYZE VALUES DATE TIMESTAMP INTEGER VARCHAR EXCLUDE DESC " +
    "ASC FILTER COLUMNS TRY_CAST CAST FORMAT INSTALL LOAD SET CALL SECRET TYPE"
  ).split(" "),
);

/** One line of SQL as coloured runs: comments, strings, keywords. */
function sqlRuns(line, size) {
  const base = { fontFace: FONT.code, fontSize: size, color: COLOR.codeText };
  const runs = [];
  const re = /(--.*$)|('(?:[^']|'')*')|(\b[A-Z_]+\b)/g;
  let last = 0;
  let m;
  while ((m = re.exec(line))) {
    if (m[3] && !SQL_KEYWORDS.has(m[3])) continue;
    if (m.index > last) runs.push({ text: line.slice(last, m.index), options: { ...base } });
    if (m[1]) runs.push({ text: m[1], options: { ...base, color: COLOR.codeComment, italic: true } });
    else if (m[2]) runs.push({ text: m[2], options: { ...base, color: COLOR.codeStr } });
    else runs.push({ text: m[3], options: { ...base, color: COLOR.codeKw, bold: true } });
    last = m.index + m[0].length;
  }
  if (last < line.length) runs.push({ text: line.slice(last), options: { ...base } });
  if (!runs.length) runs.push({ text: " ", options: { ...base } });
  return runs;
}

/** Long lines broken at a space, continuing two spaces further in. */
function wrapSql(sql, max) {
  const out = [];
  for (const line of sql.split("\n")) {
    let rest = line;
    const indent = " ".repeat(line.length - line.trimStart().length + 2);
    while (rest.length > max) {
      const cut = rest.lastIndexOf(" ", max);
      if (cut <= indent.length) break;
      out.push(rest.slice(0, cut));
      rest = indent + rest.slice(cut + 1);
    }
    out.push(rest);
  }
  return out.join("\n");
}

/** The largest code font size (pt) that fits `sql` in a w x h inch box, capped. */
function codeSize(sql, w, h, max = 18) {
  const lines = sql.split("\n");
  const longest = Math.max(...lines.map((l) => l.length), 20);
  const byWidth = (w * 72) / (longest * 0.6);
  const byHeight = (h * 72) / (lines.length * 1.2);
  return Math.max(10, Math.floor(Math.min(max, byWidth, byHeight) * 2) / 2);
}

// ---------------------------------------------------------------------------
// The deck

class Deck {
  /**
   * @param {object} o
   * @param {string} o.name      file name: handouts/<name>.pptx
   * @param {string} o.title     deck title (document properties)
   * @param {string} o.footer    footer text on content slides
   */
  constructor({ name, title, footer }) {
    this.name = name;
    this.footer = footer;
    this.pres = new pptxgen();
    this.pres.layout = "LAYOUT_WIDE";
    this.pres.title = title;
    this.pres.subject = "DuckDB Workshop Series 2, KKM, 11-13 November 2026";
    this.pres.author = "Series 2 facilitator";
    this.pres.company = "KKM";
    this.pres.theme = { headFontFace: FONT.head, bodyFontFace: FONT.body };
    this.shapes = this.pres.shapes;
    this.count = 0;
    this.defineLayouts();
  }

  defineLayouts() {
    const footerText = (color) => ({
      text: {
        text: this.footer,
        options: { x: MARGIN, y: H - 0.45, w: 8, h: 0.3, fontFace: FONT.body, fontSize: 10, color, margin: 0 },
      },
    });
    this.pres.defineSlideMaster({
      title: "CONTENT",
      background: { color: COLOR.white },
      objects: [
        {
          placeholder: {
            options: {
              name: "title",
              type: "title",
              x: MARGIN,
              y: 0.35,
              w: W - 2 * MARGIN,
              h: 0.85,
              fontFace: FONT.head,
              fontSize: 32,
              bold: true,
              color: COLOR.text,
              align: "left",
              valign: "middle",
              margin: 0,
            },
            text: "",
          },
        },
        footerText(COLOR.muted),
      ],
      slideNumber: { x: W - MARGIN - 0.6, y: H - 0.45, w: 0.6, h: 0.3, fontFace: FONT.body, fontSize: 10, color: COLOR.muted, align: "right" },
    });
    this.pres.defineSlideMaster({
      title: "DARK",
      background: { color: COLOR.ink },
      objects: [footerText("9FB3C8")],
      slideNumber: { x: W - MARGIN - 0.6, y: H - 0.45, w: 0.6, h: 0.3, fontFace: FONT.body, fontSize: 10, color: "9FB3C8", align: "right" },
    });
  }

  /** A new slide. Every slide must carry speaker notes: the facilitator runs the day alone. */
  slide(layout, notes) {
    if (!notes || notes.trim().length < 40) throw new Error(`${this.name}: slide ${this.count + 1} has no speaker notes`);
    const s = this.pres.addSlide({ masterName: layout });
    s.addNotes(notes.trim());
    this.count++;
    return s;
  }

  /** A content slide with its title filled in. */
  content(title, notes) {
    const s = this.slide("CONTENT", notes);
    s.addText(title, { placeholder: "title" });
    return s;
  }

  // ----- small composable pieces ------------------------------------------

  /** A rounded chip: the deck's motif for tables, files and codes. */
  chip(s, x, y, w, h, text, o = {}) {
    s.addText(Array.isArray(text) ? text : [{ text, options: {} }], {
      shape: this.shapes.ROUNDED_RECTANGLE,
      x, y, w, h,
      rectRadius: Math.min(0.5, h / 2),
      fill: { color: o.fill || COLOR.tint },
      line: o.line ? { color: o.line, width: 1 } : { type: "none" },
      color: o.color || COLOR.tealDark,
      fontFace: o.fontFace || FONT.code,
      fontSize: o.fontSize || 16,
      bold: o.bold !== undefined ? o.bold : true,
      align: o.align || "center",
      valign: "middle",
      margin: o.margin !== undefined ? o.margin : 4,
      objectName: o.name,
    });
  }

  /** A numbered circle. */
  dot(s, x, y, d, text, o = {}) {
    s.addText(String(text), {
      shape: this.shapes.OVAL,
      x, y, w: d, h: d,
      fill: { color: o.fill || COLOR.teal },
      line: { type: "none" },
      color: o.color || COLOR.white,
      fontFace: o.fontFace || FONT.head,
      fontSize: o.fontSize || 18,
      bold: true,
      align: "center",
      valign: "middle",
      margin: 0,
    });
  }

  /** A soft card: a tinted rounded panel to group content on. */
  panel(s, x, y, w, h, o = {}) {
    s.addShape(this.shapes.ROUNDED_RECTANGLE, {
      x, y, w, h,
      rectRadius: 0.12,
      fill: { color: o.fill || COLOR.mist },
      line: o.line ? { color: o.line, width: 1 } : { type: "none" },
      shadow: o.shadow ? { type: "outer", color: "000000", opacity: 0.12, blur: 6, offset: 2, angle: 90 } : undefined,
    });
  }

  arrow(s, x, y, w, o = {}) {
    s.addShape(this.shapes.LINE, {
      x, y, w, h: 0,
      line: { color: o.color || COLOR.muted, width: o.width || 2, endArrowType: "triangle" },
    });
  }

  downArrow(s, x, y, h, o = {}) {
    s.addShape(this.shapes.LINE, {
      x, y, w: 0, h,
      line: { color: o.color || COLOR.muted, width: o.width || 2, endArrowType: "triangle" },
    });
  }

  text(s, x, y, w, h, text, o = {}) {
    const runs = typeof text === "string" ? md(text) : text;
    s.addText(runs, {
      x, y, w, h,
      fontFace: o.fontFace || FONT.body,
      fontSize: o.fontSize || 16,
      color: o.color || COLOR.text,
      bold: o.bold,
      italic: o.italic,
      align: o.align || "left",
      valign: o.valign || "top",
      margin: o.margin !== undefined ? o.margin : 0,
      paraSpaceAfter: o.paraSpaceAfter,
      isTextBox: true,
    });
  }

  /**
   * A dark code panel with highlighted SQL; the font size shrinks to fit.
   * o.wrap breaks lines longer than that many characters at a space. o.fit
   * shrinks the panel's height to the code (top-aligned at y).
   */
  code(s, x, y, w, h, sql, o = {}) {
    const pad = Math.min(0.25, h * 0.18);
    if (o.wrap) sql = wrapSql(sql, o.wrap);
    const size = o.fontSize || codeSize(sql, w - 2 * pad, h - 2 * pad, o.max || 18);
    const lines = sql.split("\n");
    if (o.fit) h = Math.min(h, (lines.length * size * 1.2) / 72 + 2 * pad + 0.1);
    s.addShape(this.shapes.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: 0.1, fill: { color: COLOR.codeBg }, line: { type: "none" } });
    const runs = [];
    lines.forEach((line, i) => {
      const r = sqlRuns(line, size);
      if (i < lines.length - 1) r[r.length - 1].options.breakLine = true;
      runs.push(...r);
    });
    s.addText(runs, {
      x: x + pad, y: y + pad, w: w - 2 * pad, h: h - 2 * pad,
      valign: o.valign || "top",
      margin: 0,
      lineSpacingMultiple: 1.0,
      isTextBox: true,
      fit: "none",
    });
    return size;
  }

  /**
   * A session's schedule as one bar: blocks [{ t, head, body, w, fill, dark }],
   * each as wide as its minutes (w). A block shows its head and body only if
   * it fits; `end` labels the bar's right end.
   */
  timeline(s, blocks, { y = 2.0, h = 1.3, end } = {}) {
    const total = blocks.reduce((a, b) => a + b.w, 0);
    const span = W - 2 * MARGIN;
    let x = MARGIN;
    blocks.forEach((b) => {
      const bw = (b.w / total) * span;
      const color = b.dark ? COLOR.ink : COLOR.white;
      s.addShape(this.shapes.RECTANGLE, { x, y, w: bw - 0.04, h, fill: { color: b.fill }, line: { type: "none" } });
      // A label only where it fits on one line (20 pt head, 13 pt body).
      if (b.head && bw >= b.head.length * 0.16 + 0.25) this.text(s, x + 0.1, y + 0.1, bw - 0.2, 0.5, b.head, { fontFace: FONT.head, fontSize: 20, bold: true, color });
      if (b.body && bw >= Math.min(b.body.length * 0.09, 1.6) + 0.25) this.text(s, x + 0.1, y + 0.6, bw - 0.2, h - 0.7, b.body, { fontSize: 13, color });
      if (b.t) this.text(s, x, y - 0.4, 1.0, 0.35, b.t, { fontSize: 13, color: COLOR.muted });
      x += bw;
    });
    if (end) this.text(s, W - MARGIN - 1.0, y + h + 0.1, 1.0, 0.35, end, { fontSize: 13, color: COLOR.muted, align: "right" });
  }

  // ----- whole slides ------------------------------------------------------

  titleSlide({ kicker, title, subtitle, meta, notes }) {
    const s = this.slide("DARK", notes);
    this.text(s, MARGIN + 0.1, 1.55, 9, 0.5, kicker, { fontSize: 18, color: COLOR.amber, bold: true });
    this.text(s, MARGIN + 0.1, 2.1, 11.5, 2.1, title, { fontFace: FONT.head, fontSize: 48, bold: true, color: COLOR.white, valign: "bottom" });
    this.text(s, MARGIN + 0.1, 4.45, 11, 0.9, subtitle, { fontSize: 22, color: "C9D6E3" });
    if (meta) this.text(s, MARGIN + 0.1, 5.75, 11, 0.4, meta, { fontSize: 14, color: "9FB3C8" });
    // The motif: a row of chips like the tables the day builds.
    return s;
  }

  sectionSlide({ kicker, title, subtitle, chips, notes }) {
    const s = this.slide("DARK", notes);
    this.text(s, MARGIN + 0.1, 2.0, 11, 0.5, kicker, { fontSize: 18, color: COLOR.amber, bold: true });
    this.text(s, MARGIN + 0.1, 2.55, 11.5, 1.2, title, { fontFace: FONT.head, fontSize: 44, bold: true, color: COLOR.white });
    if (subtitle) this.text(s, MARGIN + 0.1, 3.85, 11, 0.9, subtitle, { fontSize: 20, color: "C9D6E3" });
    if (chips) {
      let x = MARGIN + 0.1;
      for (const c of chips) {
        const w = Math.max(1.4, c.length * 0.13 + 0.45);
        this.chip(s, x, 5.1, w, 0.5, c, { fill: COLOR.ink2, color: COLOR.white, fontSize: 15 });
        x += w + 0.2;
      }
    }
    return s;
  }

  /**
   * One slide per numbered step of a demo file. `steps` maps a step number to
   * { title, notes }; the step's comment is the explanation and its SQL is shown
   * whole. The setup SQL (run before the session) goes in the first step's notes,
   * or on its own slide with `setupSlide`.
   */
  demoSlides(rel, { label, steps = {}, setupSlide } = {}) {
    const demo = readDemo(rel);
    const total = demo.steps.length;
    const kicker = (n) => `${label} · step ${n} of ${total}`;
    if (setupSlide) {
      const s = this.content(setupSlide.title, setupSlide.notes);
      this.chip(s, MARGIN, 1.3, 3.3, 0.42, `${label} · the data`, { fontFace: FONT.body, fontSize: 14, fill: COLOR.amberTint, color: COLOR.text });
      this.text(s, MARGIN + 3.6, 1.3, 8.5, 0.42, `Run the setup cell first: ${demo.file}`, { fontSize: 14, color: COLOR.muted, valign: "middle" });
      this.code(s, MARGIN, 1.95, W - 2 * MARGIN, 4.75, demo.setup.split("\n").filter((l) => !/^--/.test(l)).join("\n"), { fit: true });
    }
    demo.steps.forEach((st, i) => {
      const o = steps[st.n] || {};
      let notes = o.notes || "";
      if (i === 0 && demo.setup && !setupSlide) {
        notes += `\n\nBefore the session, run the setup in ${demo.file}:\n${demo.setup}`;
      }
      const s = this.content(o.title || firstSentence(st.text).replace(/[.:]$/, ""), notes);
      this.chip(s, MARGIN, 1.3, 3.3, 0.42, kicker(st.n), { fontFace: FONT.body, fontSize: 14, fill: COLOR.amberTint, color: COLOR.text });
      this.text(s, MARGIN + 3.6, 1.3, 8.5, 0.42, demo.file, { fontSize: 14, color: COLOR.muted, valign: "middle", fontFace: FONT.code });
      const sql = st.sql.join("\n");
      if (st.sql.length > 9) {
        // Long SQL: explanation beside it, code at full height.
        this.text(s, MARGIN, 2.0, 3.6, 4.7, st.text, { fontSize: 17, color: COLOR.text });
        this.code(s, MARGIN + 3.9, 1.95, W - 2 * MARGIN - 3.9, 4.8, sql, { fit: true });
      } else {
        this.text(s, MARGIN, 1.95, W - 2 * MARGIN, 0.95, st.text, { fontSize: 17, color: COLOR.text });
        this.code(s, MARGIN, 3.0, W - 2 * MARGIN, 3.75, sql, { fit: true });
      }
    });
    return demo;
  }

  /** The Challenge slide, built from the card's front-matter alone. */
  challengeSlide(card, notes) {
    const s = this.slide("CONTENT", notes);
    const label = cardLabel(card);
    // Badge and title
    this.chip(s, MARGIN, 0.45, 1.35, 1.35, label, {
      fill: COLOR.teal, color: COLOR.white, fontFace: FONT.head, fontSize: label.length > 3 ? 17 : label.length > 2 ? 30 : 40, margin: 2,
    });
    this.text(s, MARGIN + 1.65, 0.45, 7.6, 0.4, card.id === "w" ? "WARM-UP CHALLENGE" : isTrack(card) ? "EXTENSION TRACK" : "CHALLENGE", {
      fontSize: 14, bold: true, color: COLOR.teal,
    });
    this.text(s, MARGIN + 1.65, 0.82, 7.8, 1.0, card.title, { fontFace: FONT.head, fontSize: 32, bold: true, valign: "top" });
    // Time box
    this.panel(s, W - MARGIN - 2.6, 0.45, 2.6, 1.35, { fill: COLOR.amberTint });
    this.text(s, W - MARGIN - 2.6, 0.55, 2.6, 0.75, card.timebox, { fontFace: FONT.head, fontSize: 36, bold: true, align: "center", valign: "middle" });
    this.text(s, W - MARGIN - 2.6, 1.3, 2.6, 0.35, "time box", { fontSize: 14, color: COLOR.muted, align: "center" });

    // Input -> output
    const inputs = card.input.split(/,\s*/);
    const top = 2.35;
    this.text(s, MARGIN, top, 4, 0.35, "YOU START FROM", { fontSize: 13, bold: true, color: COLOR.muted });
    this.text(s, 8.15, top, 4, 0.35, "YOU BUILD", { fontSize: 13, bold: true, color: COLOR.muted });
    const chipH = inputs.length > 4 ? 0.34 : inputs.length > 2 ? 0.42 : 0.5;
    const gap = inputs.length > 4 ? 0.07 : inputs.length > 2 ? 0.12 : 0.16;
    const blockH = inputs.length * chipH + (inputs.length - 1) * gap;
    const mid = top + 0.5 + Math.max(blockH, chipH) / 2;
    inputs.forEach((inp, i) => {
      const y = top + 0.5 + i * (chipH + gap) + (blockH < chipH ? 0 : 0);
      this.chip(s, MARGIN, y, 6.4, chipH, inp, { fill: COLOR.mist, color: COLOR.text, fontSize: inp.length > 40 ? 14 : 16, bold: false });
    });
    this.arrow(s, MARGIN + 6.6, mid, 0.85, { color: COLOR.teal, width: 3 });
    this.chip(s, 8.15, mid - 0.35, W - MARGIN - 8.15, 0.7, card.output, { fill: COLOR.teal, color: COLOR.white, fontSize: 22 });
    this.text(s, 8.15, mid + 0.45, W - MARGIN - 8.15, 0.35, "your table, in your Work database", { fontSize: 14, color: COLOR.muted, align: "center" });
    this.text(s, MARGIN, Math.max(4.5, top + 0.6 + blockH), W - 2 * MARGIN, 0.3, "Synthetic data, not real hospital performance.", { fontSize: 13, italic: true, color: COLOR.muted });

    // How it ends: the card, the Self-check, the Checkpoint
    const y = 5.3;
    const cols = [
      { n: "1", head: "Read the card", body: [{ text: "cards.html → ", options: {} }, { text: cardName(card), options: { bold: true } }] },
      { n: "2", head: "Self-check", body: [{ text: "0", options: { bold: true, fontFace: FONT.code } }, { text: " rows differ from the expected result means done.", options: {} }] },
      { n: "3", head: "Out of time?", body: [{ text: "Load the Checkpoint and carry on. Nobody falls behind.", options: {} }] },
    ];
    const cw = (W - 2 * MARGIN - 2 * 0.3) / 3;
    cols.forEach((c, i) => {
      const x = MARGIN + i * (cw + 0.3);
      this.panel(s, x, y, cw, 1.4, { fill: COLOR.mist });
      this.dot(s, x + 0.25, y + 0.25, 0.5, c.n, { fontSize: 16 });
      this.text(s, x + 0.95, y + 0.25, cw - 1.15, 0.5, c.head, { fontSize: 17, bold: true, valign: "middle" });
      this.text(s, x + 0.95, y + 0.78, cw - 1.15, 0.7, c.body.map((r) => ({ text: r.text, options: { ...r.options } })), { fontSize: 14, color: COLOR.text });
    });
    return s;
  }

  /** The Reveal slide: where the solution is, and what to point out. */
  revealSlide(card, points, notes) {
    const s = this.content(`Reveal: ${cardName(card)}, ${card.title}`, notes);
    this.text(s, MARGIN, 1.3, 2.4, 0.45, "Open in the UI", { fontSize: 15, color: COLOR.muted, valign: "middle" });
    this.chip(s, MARGIN + 2.4, 1.3, 6.2, 0.45, `solutions/${card.base}.sql`, { fill: COLOR.ink, color: COLOR.white, fontSize: 15 });
    const n = points.length;
    const top = 2.15;
    const rowH = Math.min(1.45, (6.75 - top - (n - 1) * 0.25) / n);
    points.forEach((p, i) => {
      const y = top + i * (rowH + 0.25);
      this.panel(s, MARGIN, y, W - 2 * MARGIN, rowH, { fill: i % 2 ? COLOR.white : COLOR.mist, line: i % 2 ? COLOR.line : undefined });
      this.dot(s, MARGIN + 0.3, y + rowH / 2 - 0.3, 0.6, i + 1, { fill: COLOR.amber, color: COLOR.ink, fontSize: 18 });
      this.text(s, MARGIN + 1.2, y + 0.12, 3.6, rowH - 0.24, p.head, { fontSize: 18, bold: true, valign: "middle" });
      this.text(s, MARGIN + 4.9, y + 0.12, W - 2 * MARGIN - 5.1, rowH - 0.24, p.body, { fontSize: 15, valign: "middle" });
    });
    return s;
  }

  /** The morning slide: the Content id the banner should end with. */
  contentIdSlide(notes) {
    const id = process.env.CONTENT_ID;
    if (!/^\d{8}-\d{4}$/.test(id || "")) throw new Error("CONTENT_ID=YYYYMMDD-HHMM is required for the morning Content id slide");
    const s = this.slide("DARK", notes);
    this.text(s, MARGIN + 0.1, 0.8, 11, 0.5, "BEFORE 9.00 · CHECK YOUR BANNER", { fontSize: 18, bold: true, color: COLOR.amber });
    this.text(s, MARGIN + 0.1, 1.35, 11.5, 0.9, "Today's Content release", { fontFace: FONT.head, fontSize: 40, bold: true, color: COLOR.white });
    // The id, big enough to read from the back row
    s.addText(`Content ${id}`, {
      shape: this.shapes.ROUNDED_RECTANGLE, x: MARGIN + 0.1, y: 2.55, w: 9.4, h: 1.35, rectRadius: 0.2,
      fill: { color: COLOR.amber }, line: { type: "none" }, color: COLOR.ink, fontFace: FONT.code, fontSize: 48, bold: true,
      align: "center", valign: "middle", margin: 0,
    });
    // What the launcher window shows
    s.addShape(this.shapes.ROUNDED_RECTANGLE, { x: MARGIN + 0.1, y: 4.35, w: 9.4, h: 1.0, rectRadius: 0.1, fill: { color: "0A1622" }, line: { color: "3C5873", width: 1 } });
    s.addText(
      [
        { text: "SETUP OK (n/n)", options: { color: COLOR.codeStr, bold: true } },
        { text: " · ", options: { color: COLOR.codeText } },
        { text: `Content ${id}`, options: { color: COLOR.codeKw, bold: true } },
      ],
      { x: MARGIN + 0.4, y: 4.35, w: 9, h: 1.0, fontFace: FONT.code, fontSize: 24, valign: "middle", margin: 0, isTextBox: true },
    );
    this.text(s, MARGIN + 0.1, 5.55, 9.4, 0.4, "the last line in your launcher window", { fontSize: 14, color: "9FB3C8" });
    // Side: what to do if it differs
    this.panel(s, 10.35, 2.55, W - MARGIN - 10.35, 3.4, { fill: COLOR.ink2 });
    this.text(s, 10.6, 2.75, W - MARGIN - 10.85, 0.5, "Not this id?", { fontSize: 20, bold: true, color: COLOR.white });
    this.text(
      s, 10.6, 3.3, W - MARGIN - 10.85, 2.5,
      [
        { text: "Drop the latest zip, ", options: {} },
        { text: "unopened", options: { bold: true } },
        { text: ", into ", options: {} },
        { text: "updates", options: { fontFace: FONT.code } },
        { text: ", close the UI tab, and relaunch.", options: { breakLine: true } },
        { text: " ", options: { breakLine: true, fontSize: 8 } },
        { text: "Content none", options: { fontFace: FONT.code } },
        { text: " means no release was applied yet.", options: {} },
      ],
      { fontSize: 16, color: "DCE6F0" },
    );
    return s;
  }

  /** The setup check steps, read from the setup card. */
  setupCheckSlide(notes) {
    const steps = readSetupSteps();
    const s = this.content("Setup check: 9.00 to 9.20", notes);
    const top = 1.4;
    const rowH = 0.98;
    const textW = 6.1;
    steps.forEach((st, i) => {
      const y = top + i * (rowH + 0.08);
      this.dot(s, MARGIN, y + 0.08, 0.55, st.n, { fontSize: 18, fill: i === 3 ? COLOR.amber : COLOR.teal, color: i === 3 ? COLOR.ink : COLOR.white });
      this.text(s, MARGIN + 0.8, y, textW, rowH, md(st.text.replace(/:$/, "."), { fontSize: 14 }), { fontSize: 14, valign: "middle" });
    });
    const sql = steps.map((st) => st.sql).filter(Boolean).join("\n");
    const x = MARGIN + 0.8 + textW + 0.4;
    const w = W - MARGIN - x;
    this.text(s, x, 1.4, w, 0.35, "THE FIRST CELL", { fontSize: 13, bold: true, color: COLOR.muted });
    this.code(s, x, 1.8, w, 1.35, sql, { max: 16, valign: "middle", wrap: 42 });
    this.text(s, x, 3.45, w, 0.35, "THEN, ON YOUR LAPTOP LID", { fontSize: 13, bold: true, color: COLOR.muted });
    const nw = (w - 0.3) / 2;
    [
      { fill: "BFE8C9", head: "Green", body: "Rows came back" },
      { fill: "F6C1C6", head: "Red", body: "Anything else: Fix sheet" },
    ].forEach((n, i) => {
      const nx = x + i * (nw + 0.3);
      s.addShape(this.shapes.RECTANGLE, {
        x: nx, y: 3.9, w: nw, h: 1.7, fill: { color: n.fill }, line: { type: "none" },
        shadow: { type: "outer", color: "000000", opacity: 0.18, blur: 5, offset: 3, angle: 60 },
      });
      this.text(s, nx + 0.2, 4.05, nw - 0.4, 0.5, n.head, { fontFace: FONT.head, fontSize: 22, bold: true });
      this.text(s, nx + 0.2, 4.6, nw - 0.4, 0.9, n.body, { fontSize: 15 });
    });
    this.text(s, x, 5.85, w, 0.8, "At 9.20 the refresher starts regardless.", { fontSize: 14, color: COLOR.muted, italic: true });
    return s;
  }

  /** The Fix sheet's banner codes, read from the setup card. */
  fixCodesSlide(notes) {
    const { reminder, rows } = readFixSheet();
    const coded = rows.filter((r) => r.code);
    const s = this.content("Fix sheet: banner codes", notes);
    s.addText(md(reminder, { fontSize: 15, color: COLOR.text }), {
      shape: this.shapes.ROUNDED_RECTANGLE, x: MARGIN, y: 1.3, w: W - 2 * MARGIN, h: 0.5, rectRadius: 0.25,
      fill: { color: COLOR.amberTint }, line: { type: "none" }, align: "center", valign: "middle", margin: 0, fontFace: FONT.body,
    });
    // One row per code: the code, what it means, what to try first.
    const top = 2.0;
    const rowH = (6.7 - top) / coded.length;
    const meanX = MARGIN + 1.45;
    const meanW = 4.2;
    const tryX = meanX + meanW + 0.3;
    const tryW = W - MARGIN - tryX - 0.15;
    this.text(s, meanX, top - 0.15, meanW, 0.3, "WHAT IT MEANS", { fontSize: 12, bold: true, color: COLOR.muted });
    this.text(s, tryX, top - 0.15, tryW, 0.3, "TRY FIRST", { fontSize: 12, bold: true, color: COLOR.muted });
    coded.forEach((r, i) => {
      const y = top + 0.2 + i * rowH;
      if (i % 2 === 0) this.panel(s, MARGIN, y, W - 2 * MARGIN, rowH - 0.04, { fill: COLOR.mist });
      this.chip(s, MARGIN + 0.12, y + (rowH - 0.04) / 2 - 0.19, 1.15, 0.38, r.code, { fill: COLOR.coral, color: COLOR.white, fontSize: 14 });
      this.text(s, meanX, y, meanW, rowH - 0.04, md(r.problem, { fontSize: 13, color: COLOR.text }), { fontSize: 13, valign: "middle" });
      this.text(s, tryX, y, tryW, rowH - 0.04, md(firstSentence(r.tryFirst), { fontSize: 13, color: COLOR.text }), { fontSize: 13, valign: "middle" });
    });
    return s;
  }

  /** The Fix sheet's other rows (no banner code): problem and what to try first. */
  fixProblemsSlide(notes) {
    const { rows } = readFixSheet();
    const plain = rows.filter((r) => !r.code);
    const s = this.content("Fix sheet: no code, still stuck", notes);
    const perCol = Math.ceil(plain.length / 2);
    const gap = 0.35;
    const cw = (W - 2 * MARGIN - gap) / 2;
    const rowH = (6.8 - 1.35) / perCol;
    plain.forEach((r, i) => {
      const col = Math.floor(i / perCol);
      const x = MARGIN + col * (cw + gap);
      const y = 1.35 + (i % perCol) * rowH;
      if (i % perCol) s.addShape(this.shapes.LINE, { x, y, w: cw, h: 0, line: { color: COLOR.line, width: 1 } });
      this.text(s, x, y + 0.06, 2.3, rowH - 0.12, md(r.problem, { fontSize: 13, bold: true }), { fontSize: 13, bold: true, valign: "middle" });
      this.text(s, x + 2.45, y + 0.06, cw - 2.45, rowH - 0.12, md(firstSentence(r.tryFirst), { fontSize: 13 }), { fontSize: 13, valign: "middle" });
    });
    return s;
  }

  /** Today's chain of tables, from the cards' front-matter, grouped by Module. */
  chainSlide(title, cards, notes, groups = []) {
    const s = this.content(title, notes);
    const n = cards.length;
    const gap = 0.4;
    const cw = (W - 2 * MARGIN - (n - 1) * gap) / n;
    const y = 2.75;
    const longest = Math.max(...cards.map((c) => c.output.length));
    const size = Math.min(16, Math.floor(((cw - 0.2) * 72) / (longest * 0.6)));
    cards.forEach((c, i) => {
      const x = MARGIN + i * (cw + gap);
      const dark = c.module !== cards[0].module;
      this.dot(s, x + cw / 2 - 0.4, y - 1.1, 0.8, cardLabel(c), { fontSize: 20, fill: dark ? COLOR.ink : COLOR.teal });
      this.chip(s, x, y, cw, 0.65, c.output, { fill: dark ? COLOR.mist : COLOR.tint, color: COLOR.text, fontSize: size, margin: 2 });
      this.text(s, x, y + 0.85, cw, 0.9, c.title, { fontSize: 15, align: "center", color: COLOR.muted });
      if (i < n - 1) this.arrow(s, x + cw + 0.05, y + 0.325, gap - 0.1, { color: COLOR.teal });
    });
    // Brackets under each group of Challenges: which Module does what.
    for (const g of groups) {
      const idx = cards.map((c, i) => (c.module === g.module ? i : -1)).filter((i) => i >= 0);
      if (!idx.length) continue;
      const x = MARGIN + idx[0] * (cw + gap);
      const w = idx.length * cw + (idx.length - 1) * gap;
      const dark = g.module !== cards[0].module;
      this.panel(s, x, 4.95, w, 1.7, { fill: dark ? COLOR.mist : COLOR.tint });
      this.text(s, x + 0.3, 5.1, w - 0.6, 0.5, g.head, { fontFace: FONT.head, fontSize: 20, bold: true, color: dark ? COLOR.ink : COLOR.tealDark });
      this.text(s, x + 0.3, 5.6, w - 0.6, 0.95, g.body, { fontSize: 16 });
    }
    return s;
  }

  async write() {
    const dir = process.env.HANDOUTS_DIR || path.join(REPO, "handouts");
    fs.mkdirSync(dir, { recursive: true });
    const file = path.join(dir, `${this.name}.pptx`);
    // JSZip writes an entry for every folder; some cloud drives refuse to
    // open or preview a deck with them, and the decks travel by Drive.
    // (JSZip's remove() on a folder drops its files too, so copy the files instead.)
    const built = await JSZip.loadAsync(await this.pres.write({ outputType: "nodebuffer", compression: true }));
    const zip = new JSZip();
    for (const [p, entry] of Object.entries(built.files)) {
      if (!entry.dir) zip.file(p, await entry.async("nodebuffer"), { date: entry.date, createFolders: false });
    }
    fs.writeFileSync(file, await zip.generateAsync({ type: "nodebuffer", compression: "DEFLATE" }));
    console.log(`slides: wrote ${file} (${this.count} slides)`);
    return file;
  }
}

module.exports = {
  Deck, COLOR, FONT, W, H, MARGIN, REPO,
  readCard, challengeCards, cardsOf, cardLabel, cardName, isTrack, readDemo, readFixSheet, readSetupSteps, md, firstSentence,
};
