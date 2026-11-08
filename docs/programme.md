# Programme (amended Tentatif Program)

**Bengkel Aplikasi SQL and Data Wrangling Menggunakan DuckDB, Siri 2 Tahun 2026**
Kementerian Kesihatan Malaysia (KKM) · 11–13 November 2026

Amended from the original Lampiran 1. Changes from the original:

- Modules now follow the pipeline order the Capstone uses: read raw data, clean it, analyse it, report it.
- Day 1 opens with a setup check and a Series 1 refresher.
- Day 2 afternoon adds Extension tracks before the Capstone kickoff.
- The Friday break is 12.15–2.45 for Friday prayers.
- The first slot each day runs 9.00–10.00, so it no longer overlaps the 10.00 break.

All exercises use a synthetic MyHDW-like dataset, not real MyHDW data. The DuckDB version is 1.5.6.

## Day 1 · Wednesday 11 November

| Time | Session |
|---|---|
| 8.30 – 9.00 | Registration & Opening |
| 9.00 – 10.00 | **Setup check**: confirm DuckDB, the DuckDB UI and the workshop data work on every laptop<br>**Series 1 refresher**: recap of joins, GROUP BY/HAVING, CTEs and subqueries, then a Warm-up Challenge |
| 10.00 – 10.30 | Break |
| 10.30 – 1.00 | **Module 1: Reading Raw Data Safely** (Data Import & File Formats)<br>- Why file formats matter: CSV vs Parquet on 30 million rows (demo)<br>- Querying files directly: `read_csv`, `read_parquet`, `read_json`<br>- CSV sniffing, rejects tables and row-count checks<br>- Profiling data with `SUMMARIZE` and `COLUMNS(*)`<br>- Combining monthly CSV, JSON and Parquet feeds with `UNION BY NAME` |
| 1.00 – 2.00 | Lunch |
| 2.00 – 4.30 | **Module 2: Data Cleaning Clinic**<br>- Fixing messy dates and numbers with `TRY_CAST` and `try_strptime`<br>- Regex and string cleaning of the MoH facility list<br>- Reusable cleaning rules with macros<br>- Removing duplicates with window functions and `QUALIFY`<br>**Day 1 Wrap-Up** |

## Day 2 · Thursday 12 November

| Time | Session |
|---|---|
| 9.00 – 10.00 | **Module 3: Advanced SQL for Health Analysis**<br>- Window functions: ROW_NUMBER, RANK, running totals<br>- Episodes of care (gaps-and-islands) |
| 10.00 – 10.30 | Break |
| 10.30 – 1.00 | **Module 3 (continued)**<br>- 30-day readmission<br>- PIVOT / UNPIVOT for state-level summaries<br>- Exporting query results to Parquet, CSV and Excel<br>- Live demo: querying Parquet files on Amazon S3<br>- Integration overview: DuckDB + Python, DuckDB + R (take-home notebooks) |
| 1.00 – 2.00 | Lunch |
| 2.00 – 3.40 | **Module 4: Extension Tracks**: short tour of all three, then each Participant picks two<br>- Statistics for health data (`stats_duck`)<br>- Name matching: linking messy facility names<br>- Spatial: dengue cases by district |
| 3.40 – 4.30 | **Capstone Project: Kickoff**: brief, teams of 3–4, peer-review rubric, start work<br>**Day 2 Wrap-Up** |

## Day 3 · Friday 13 November

| Time | Session |
|---|---|
| 9.00 – 10.00 | **Capstone Project**: teams build an end-to-end pipeline from raw MyHDW-like data to a state-level health summary using SQL in DuckDB |
| 10.00 – 10.30 | Break |
| 10.30 – 12.15 | **Capstone Project (continued)**, until 11.15<br>**Capstone Presentations & Peer Review** (11.15 – 12.15): each team presents for 7 minutes, including one data-quality issue they found and fixed |
| 12.15 – 2.45 | Lunch & Friday Prayers |
| 2.45 – 4.30 | **Revision & Closing Session**<br>- Peer-review results<br>- Course summary & key takeaways, including what changes in DuckDB 2.0<br>- Resources for continued learning<br>- Feedback & Closing<br>**Day 3 Wrap-Up** |

<!-- Planning detail (not for organisers): each Module runs as cycles of about 10 min demo → 30 min Challenge → 10 min Reveal.
Challenge count: Warm-up 1; Module 1: 3; Module 2: 3; Module 3: 4; Extension tracks: 3 cards (each Participant does 2).
Capstone working time ≈ 2 h 35 min (D2 3.40–4.30, D3 9.00–10.00 and 10.30–11.15).
Python/R: no live demo; a 5 min overview slide plus take-home notebooks. Module 3 has a 10 min buffer. -->
