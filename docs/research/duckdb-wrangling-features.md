# DuckDB SQL and UI features for Series 2 data wrangling

Research for ticket #2: *Which current DuckDB SQL and UI features should Series 2 teach for data wrangling?*
Researched 2026-11-08 for the DuckDB Workshop Series 2 (11–13 Nov 2026, KKM / MyHDW staff, DuckDB UI on Windows laptops).

**How this was checked.** Claims come from duckdb.org docs and blog posts, the `duckdb/duckdb` and `duckdb/duckdb-ui` GitHub repos (releases, source, issues), and Context7 (`/duckdb/duckdb-web`, which mirrors the duckdb.org sources). I ran every SQL snippet below on **DuckDB v2.0.0** (official macOS arm64 CLI from the GitHub release) and on **v1.5.5** (local Homebrew). I tested UI behaviour by starting the v2.0.0 UI server and sending SQL to its `/ddb/run` endpoint, which is the endpoint the browser UI uses. Tags used below:

- **[verified-local]**: I ran it and saw the result.
- **[docs]**: the cited page states it.
- **[unverified]**: I could not confirm it.

I had no Windows machine. Windows-specific notes come from docs and GitHub issues, not from testing.

---

## 1. Version summary

| Release | Date | Status | Source |
|---|---|---|---|
| **v2.0.0 LTS "Cyanoptera" (Cinnamon Teal)** | 2026-10-21 | **Current stable**, LTS supported to at least Oct 2027 | [GitHub release](https://github.com/duckdb/duckdb/releases/tag/v2.0.0), [announcement](https://duckdb.org/2026/10/21/announcing-duckdb-200) |
| v1.5.6 (bugfix) | 2026-09-28 | Supported until March 2027 | [releases](https://github.com/duckdb/duckdb/releases/tag/v1.5.6), [announcement](https://duckdb.org/2026/10/21/announcing-duckdb-200) |
| v1.5.5 (bugfix) | 2026-07-22 | Probably what Series 1 Participants installed in Aug 2026 [unverified: I did not check their laptops] | [releases](https://github.com/duckdb/duckdb/releases/tag/v1.5.5) |
| v1.4.5 LTS | 2026-06-17 | 1.4 support ends **2026-11-17** | [announcement](https://duckdb.org/2026/10/21/announcing-duckdb-200) |

- The install page offers 2.0.0 (LTS), 1.5.6 and 1.4.5 (LTS). On Windows: `powershell -NoExit -ExecutionPolicy Bypass -Command "irm https://install.duckdb.org/install.ps1 | iex"`. To pin a version, set `$env:DUCKDB_VERSION = '1.5.6'` first. Winget is listed only for 1.5.6 (`winget install DuckDB.cli --version 1.5.6`). The direct Windows download for 2.0.0 is a **`.tar.gz`**, not a `.zip` like 1.5.6. DuckDB on Windows needs the Microsoft Visual C++ Redistributable. [docs](https://duckdb.org/docs/2.0/installation)
- The UI extension is built for 2.0.0 on `windows_amd64`. `http://extensions.duckdb.org/v2.0.0/windows_amd64/ui.duckdb_extension.gz` returns HTTP 200, last modified 2026-10-26 [verified-local]. The duckdb-ui repo commit "Build and deploy the UI extension for DuckDB 2.0.0" is dated 2026-10-21 ([commits](https://github.com/duckdb/duckdb-ui/commits)).

### 2.0 changes that affect wrangling lessons

All from the [2.0 migration guide](https://duckdb.org/docs/2.0/operations_manual/migration) and confirmed on v2.0.0 vs v1.5.5 [verified-local]:

| Change | v1.5.5 | v2.0.0 |
|---|---|---|
| Lambda arrow `x -> x + 1` | Warning, still works | **Binder Error**. Use `lambda x: x + 1`, which has worked since v1.3 ([1.3 post](https://duckdb.org/2025/05/21/announcing-duckdb-130)) |
| `'abc' ~ 'b'` | `false` (full match) | `true` (partial match, like PostgreSQL) |
| `1 // 0`, `1 % 0` | `NULL` | **Error**. Use `TRY(1 // 0)` or `SET error_on_division_by_zero = false`. `1 / 0` still returns `inf` |
| `CREATE TABLE t AS SELECT NULL AS x` | column type `INTEGER` | column type `"NULL"`. A later `INSERT` of a number fails, so cast it: `NULL::VARCHAR` |
| `$var` shorthand for `getvariable('var')` | Error | Works |
| `regexp_extract(s, pattern, 'i')` (options) | Error | Works |
| Named `PREPARE` parameters fall back to session variables | Error | Works |
| `regexp_replace` with an invalid back-reference (`'\9'`) | Silently accepted | Error |
| Any error inside an explicit `BEGIN … COMMIT` | Transaction continues | Transaction is aborted and needs `ROLLBACK` |
| Default storage format of a **new** `.duckdb` file | v1.x | v2.0 (**unreadable by 1.5.x**). Write an older format with `-storage-version v1.5.6` or `ATTACH … (STORAGE_VERSION 'v1.5.6')` |
| PEG parser | Experimental | **Default**. Error messages show more precise locations; `legacy_parser` extension available |

A related change from v1.5.0 that 2.0 keeps: `date_trunc('month', <DATE>)` now returns a **TIMESTAMP** ([1.5 announcement](https://duckdb.org/2026/03/09/announcing-duckdb-150)) [verified-local on both versions].

**Recommendation:** use **v2.0.0** for Series 2. It is the current LTS, it has `$var`, the new `regexp_extract` options and prepared-statement defaults, and its error messages are clearer. Write all examples in syntax that runs on both versions (the `lambda` keyword, explicit casts) so that a Participant still on 1.5.x is not blocked. Teach `$var` and session-variable defaults as 2.0-only. If any `.duckdb` file is handed out, create it with v2.0 and require v2.0, or create it with `STORAGE_VERSION 'v1.5.6'`.

---

## 2. Ranked feature table

Ranked by value to Participants for ad-hoc MyHDW extraction, cleaning and statistics.

- **Core**: every Participant should leave able to use it.
- **Stretch**: demo or bonus exercise.
- **UI?**: "Yes" means it ran through the v2.0.0 UI server endpoint [verified-local], unless the cell says otherwise.
- **Min version**: the version needed for the syntax shown. "≤1.5" means confirmed on 1.5.5 and 2.0.0; I did not find the exact first release.

| # | Feature | Why it matters for health-data wrangling | Core / Stretch | Works in UI? | Min version | Source |
|---|---|---|---|---|---|---|
| 1 | **`read_csv` sniffing + `sniff_csv` + rejects tables** (`store_rejects`, `reject_errors`, `reject_scans`, `ignore_errors`, `null_padding`, `all_varchar`, `dateformat`) | MyHDW and facility extracts come as messy CSVs. One malformed row can make the sniffer **silently drop most of the file** (see Pitfalls). Rejects tables show which lines failed and why | **Core** | Yes. Rejects tables are **temporary**, so they are visible only in the session that ran the read | ≤1.5 | [faulty CSV](https://duckdb.org/docs/stable/data/csv/reading_faulty_csv_files), [auto-detection](https://duckdb.org/docs/stable/data/csv/auto_detection), [CSV overview](https://duckdb.org/docs/stable/data/csv/overview) |
| 2 | **`TRY_CAST`, `TRY(...)`, `try_strptime`** (accepts a **list** of formats) | Free-text ages (`NA`, `abc`), impossible dates (`31/02/2026`) and mixed `dd/mm/yyyy` / ISO dates become `NULL` instead of failing the query, so bad rows can be counted and fixed | **Core** | Yes | ≤1.5 (`TRY(1 // 0)` matters only in 2.0) | [cast](https://duckdb.org/docs/stable/sql/expressions/cast), [TRY](https://duckdb.org/docs/stable/sql/expressions/try), [dateformat](https://duckdb.org/docs/stable/sql/functions/dateformat), [timestamp fns](https://duckdb.org/docs/stable/sql/functions/timestamp) |
| 3 | **Regex and string cleaning**: `trim`, `regexp_replace(…, 'g')`, `regexp_matches`, `regexp_full_match`, `regexp_extract` (groups, named-struct, `'i'` option), `string_split`, `lpad`, `concat_ws`, `strip_accents`, `levenshtein` / `jaro_winkler_similarity` | Standardise IC/NRIC numbers, ward and facility names, ICD-10 codes, and BP strings like `120/80`. Fuzzy-match facility names | **Core** | Yes | ≤1.5 (`'i'` option in `regexp_extract`: 2.0) | [regex](https://duckdb.org/docs/stable/sql/functions/regular_expressions), [text](https://duckdb.org/docs/stable/sql/functions/text), [gems 2.0](https://duckdb.org/2026/10/26/gems-of-duckdb-200) |
| 4 | **Window functions + `QUALIFY`** (`row_number`, `lag` / `lead`, named `WINDOW`) | Keep the latest record per patient, remove duplicate admissions, compute days since last discharge for 30-day readmission | **Core** | Yes | ≤1.5 | [QUALIFY](https://duckdb.org/docs/stable/sql/query_syntax/qualify), [window functions](https://duckdb.org/docs/stable/sql/functions/window_functions) |
| 5 | **Scalar and table macros** (`CREATE [TEMP] MACRO … AS` / `AS TABLE`, default params, `query_table`) | Package the team's cleaning rules (`clean_nric`, `age_band`, `parse_my_date`) once and reuse them. Non-temp macros are stored in the database file and shared across notebooks | **Core** | Yes. Persistent macros are visible in every notebook; `TEMP` macros only in the session that created them | ≤1.5 | [CREATE MACRO](https://duckdb.org/docs/stable/sql/statements/create_macro), [SQL-only extensions post](https://duckdb.org/2024/09/27/sql-only-extensions) |
| 6 | **Friendly SQL for wide tables**: `* EXCLUDE`, `* REPLACE`, `* LIKE 'sbp%'`, `COLUMNS(*)`, `COLUMNS('regex')` with rename `AS '\1'`, `COLUMNS(lambda c: …)`, `GROUP BY ALL` / `ORDER BY ALL`, `count(*) FILTER (WHERE …)`, `SUMMARIZE` | Apply one cleaning rule to 50 columns at once, profile a new extract in one line, write shorter GROUP BYs | **Core** | Yes | ≤1.5 | [star / COLUMNS](https://duckdb.org/docs/stable/sql/expressions/star), [friendly SQL](https://duckdb.org/docs/stable/sql/dialect/friendly_sql), [SUMMARIZE](https://duckdb.org/docs/stable/guides/meta/summarize), [GROUP BY](https://duckdb.org/docs/stable/sql/query_syntax/groupby) |
| 7 | **`UNION [ALL] BY NAME`** and `read_csv([...], union_by_name = true, filename = true)` | Stack monthly or state extracts whose columns drift (a new `ward` column, reordered columns) and keep the source file name for audit | **Core** | Yes | ≤1.5 | [set operations](https://duckdb.org/docs/stable/sql/query_syntax/setops), [combining schemas](https://duckdb.org/docs/stable/data/multiple_files/combining_schemas) |
| 8 | **`PIVOT` / `UNPIVOT`** (simplified DuckDB syntax, `UNPIVOT … ON COLUMNS('sbp_.*')`) | Turn long to wide (counts by ward or ICD chapter per facility) and wide to long (repeated BP readings, yearly columns) | **Core** | Yes. Dynamic `PIVOT` used to fail in the UI ("Cannot prepare multiple statements at once"); fixed in the UI in June 2025 ([#57](https://github.com/duckdb/duckdb-ui/issues/57), [#112](https://github.com/duckdb/duckdb-ui/issues/112)) and runs on 2.0 [verified-local] | ≤1.5 | [PIVOT](https://duckdb.org/docs/stable/sql/statements/pivot), [UNPIVOT](https://duckdb.org/docs/stable/sql/statements/unpivot) |
| 9 | **Gaps-and-islands** (`lag` + running `sum` of a "new episode" flag) | Merge back-to-back or overlapping stays (ward transfers) into **episodes of care**, find continuous treatment periods, find gaps in follow-up | **Core demo, Stretch exercise** | Yes | ≤1.5 | Pattern built from [window functions](https://duckdb.org/docs/stable/sql/functions/window_functions) |
| 10 | **`LIST` / `STRUCT` + lambdas** (`list()`, `list_transform`, `list_filter`, list comprehension `[x FOR x IN l IF …]`, `unnest`, `struct.field`) | Explode multi-diagnosis strings (`I21.9;E11.9;I10`), collect a patient's wards in order, work with nested JSON/VARIANT feeds | **Stretch** | Yes | Lambda keyword: 1.3. **Arrow form errors in 2.0** | [lambda](https://duckdb.org/docs/stable/sql/functions/lambda), [list fns](https://duckdb.org/docs/stable/sql/functions/list) |
| 11 | **`SET VARIABLE` / `getvariable` / `$var`** | Set the study window (`$start_dt`, `$end_dt`) or a facility code once at the top of a notebook | **Core tip** | Yes, per session (a variable set in one connection was `NULL` in another) | `getvariable`: 1.1; `$var`: **2.0** | [SET VARIABLE](https://duckdb.org/docs/stable/sql/statements/set_variable), [1.1 post](https://duckdb.org/2024/09/09/announcing-duckdb-110) |
| 12 | **`PREPARE` / `EXECUTE` / `DEALLOCATE`** (`?`, `$1`, `$name`; 2.0 falls back to a session variable when a named parameter is not supplied) | Re-run one extraction query for different facilities or periods without editing SQL | **Stretch (tip)**. Macros cover most of the same needs more simply | **Yes**, within one session: PREPARE then EXECUTE in a later request on the same connection worked; EXECUTE from a different connection gave `Prepared statement "q" does not exist` [verified-local] | ≤1.5 (variable fallback: 2.0) | [prepared statements](https://duckdb.org/docs/stable/sql/query_syntax/prepared_statements) |
| 13 | **Date arithmetic**: `date_diff`, `age()`, `strftime`, `date_trunc` | Length of stay, age at admission, monthly aggregation, Malaysian `dd/mm/yyyy` output | **Core** (inside the cleaning clinic) | Yes | ≤1.5 (`date_trunc` on DATE returns TIMESTAMP since 1.5) | [date fns](https://duckdb.org/docs/stable/sql/functions/date) |
| 14 | **Newer 2.0 extras**: `FETCH FIRST`, `CREATE SECURE VIEW`, data-modifying CTEs, `COPY … (PARTITION_BY …, ORDER_BY …)`, `SHOW <setting>`, JSON mutation functions | `SECURE VIEW` for sharing restricted data; partitioned exports of extracts | Stretch / mention only | `FETCH FIRST` yes; others untested in UI | 2.0 | [what's new 2.0](https://duckdb.org/docs/2.0/whats_new_in_the_docs), [gems 2.0](https://duckdb.org/2026/10/26/gems-of-duckdb-200) |

---

## 3. Example snippets (top features)

Every snippet ran on v2.0.0 [verified-local]. The table is a toy table, not MyHDW data.

### 3.1 Reading a messy CSV safely (rank 1)

```sql
-- messy.csv: ';' delimited, one row has an extra column, values like 'NA', '31/02/2026'
FROM sniff_csv('messy.csv');                               -- check what the sniffer decided first

CREATE OR REPLACE TABLE raw AS
FROM read_csv('messy.csv', store_rejects = true);         -- 4 good rows
SELECT line, error_type, csv_line FROM reject_errors;     -- line 6, TOO MANY COLUMNS

-- or keep every row as text and clean afterwards
CREATE OR REPLACE TABLE raw2 AS
FROM read_csv('messy.csv', all_varchar = true, null_padding = true, nullstr = ['NA', '']);
```

### 3.2 TRY_CAST / try_strptime / regex cleaning (ranks 2–3)

```sql
SELECT mrn,
       regexp_replace(trim(nric), '[^0-9]', '', 'g')                       AS nric_digits,
       try_strptime(adm_date, ['%d/%m/%Y', '%Y-%m-%d'])::DATE              AS adm_date,  -- 31/02/2026 -> NULL
       TRY_CAST(age AS INTEGER)                                            AS age,       -- 'abc' -> NULL
       upper(regexp_replace(ward, '[\s\-]+', '', 'g'))                     AS ward_std,  -- 'wad 3a','WAD-3A' -> 'WAD3A'
       regexp_full_match(trim(nric), '\d{6}-?\d{2}-?\d{4}')                AS nric_ok
FROM raw2;

SELECT regexp_extract('BP 120/80 mmHg', '(\d+)/(\d+)', ['sys', 'dia']) AS bp;  -- {'sys': 120, 'dia': 80}
```

### 3.3 Deduplicate and readmissions with QUALIFY / lag (rank 4)

```sql
-- latest admission per patient
SELECT * FROM adm
QUALIFY row_number() OVER (PARTITION BY mrn ORDER BY adm_dt DESC) = 1;

-- days since previous discharge (30-day readmission flag)
SELECT mrn, adm_dt,
       adm_dt - lag(dis_dt) OVER w        AS gap_days,
       (adm_dt - lag(dis_dt) OVER w) <= 30 AS readmit_30d
FROM adm
WINDOW w AS (PARTITION BY mrn ORDER BY adm_dt);
```

### 3.4 Macros as a cleaning toolkit (rank 5)

```sql
CREATE OR REPLACE MACRO clean_nric(s)    AS regexp_replace(trim(s), '[^0-9]', '', 'g');
CREATE OR REPLACE MACRO parse_my_date(s) AS try_strptime(s, ['%d/%m/%Y', '%Y-%m-%d', '%d-%m-%Y'])::DATE;
CREATE OR REPLACE MACRO age_band(a)      AS CASE WHEN a < 18 THEN '0-17' WHEN a < 60 THEN '18-59' ELSE '60+' END;

-- table macro with a default parameter
CREATE OR REPLACE MACRO adm_between(d1, d2) AS TABLE
    SELECT * FROM adm WHERE adm_dt BETWEEN d1 AND d2;
FROM adm_between(DATE '2026-01-01', DATE '2026-01-31');

CREATE OR REPLACE MACRO top_n(tbl, n := 5) AS TABLE FROM query_table(tbl) LIMIT n;
FROM top_n('adm', n := 1);
```

### 3.5 Wide-table friendly SQL (ranks 6–7)

```sql
SELECT trim(COLUMNS(* EXCLUDE (adm_dt))) FROM adm;          -- trim every text column, keep names
SELECT nullif(trim(COLUMNS(['ward', 'age'])), 'NA') FROM adm;
SELECT COLUMNS('(.*)_raw') AS '\1' FROM vitals_raw;         -- age_raw -> age, sbp_raw -> sbp
SELECT * LIKE 'sbp%' FROM vitals;
SUMMARIZE adm;                                              -- min/max/null % per column
FROM read_csv(['jan.csv', 'feb.csv'], union_by_name = true, filename = true);
```

### 3.6 PIVOT / UNPIVOT (rank 8)

```sql
PIVOT adm ON ward USING count(*) GROUP BY mrn;
UNPIVOT vitals ON COLUMNS('sbp_.*') INTO NAME reading VALUE sbp;
```

### 3.7 Gaps-and-islands: episodes of care (rank 9)

```sql
WITH f AS (
  SELECT *, CASE WHEN adm_dt <= lag(dis_dt) OVER (PARTITION BY mrn ORDER BY adm_dt)
                 THEN 0 ELSE 1 END AS new_ep
  FROM (SELECT DISTINCT * FROM adm)
), g AS (
  SELECT *, sum(new_ep) OVER (PARTITION BY mrn ORDER BY adm_dt) AS ep FROM f
)
SELECT mrn, ep, min(adm_dt) AS ep_start, max(dis_dt) AS ep_end,
       list(ward ORDER BY adm_dt) AS wards                   -- e.g. [Wad 3A, ICU]
FROM g GROUP BY ALL ORDER BY ALL;
```

### 3.8 Lists and lambdas (rank 10), new 2.0 syntax

```sql
SELECT unnest(string_split('I21.9;E11.9;I10', ';')) AS dx;
SELECT list_transform(string_split('I21.9;E11.9', ';'), lambda c: left(c, 3)) AS dx3;   -- [I21, E11]
SELECT [x * 2 FOR x IN [1, 2, 3] IF x > 1] AS comp;
-- x -> x + 1  errors in 2.0: "Deprecated lambda arrow (->) detected"
```

### 3.9 Variables and prepared statements (ranks 11–12)

```sql
SET VARIABLE start_dt = DATE '2026-01-01';
SELECT * FROM adm WHERE adm_dt >= $start_dt;             -- 2.0; on 1.5 use getvariable('start_dt')

PREPARE by_ward AS SELECT * FROM adm WHERE adm_dt >= $start_dt AND ward = $ward;
EXECUTE by_ward(ward := 'ICU');                           -- $start_dt filled from the variable (2.0)
PREPARE q2 AS SELECT * FROM adm WHERE ward = ?;
EXECUTE q2('Wad 3A');
DEALLOCATE by_ward;
```

---

## 4. Pitfalls

### DuckDB UI (on Windows)

1. **The UI needs internet.** The local server downloads the UI front end from `https://ui.duckdb.org` ([UI docs](https://duckdb.org/docs/stable/core_extensions/ui)). There is no official offline mode ([#62](https://github.com/duckdb/duckdb-ui/issues/62)). Check that the training-room network allows `ui.duckdb.org` and `extensions.duckdb.org`, because `INSTALL ui` and `icu` download the extensions from there.
2. **Corporate or government SSL inspection** can break the UI with `Could not fetch: '/' from 'https://ui.duckdb.org': SSL server verification failed` ([#201](https://github.com/duckdb/duckdb-ui/issues/201), [#95](https://github.com/duckdb/duckdb-ui/issues/95)). The maintainer workaround is the environment variable `ui_disable_server_certificate_verification=1`. The duckdb-ui source checks it in `src/http_server.cpp`. On Windows: `set ui_disable_server_certificate_verification=1` (cmd) or `$env:ui_disable_server_certificate_verification=1` (PowerShell), then `duckdb -ui`. This turns off TLS verification, so agree it with MOH IT first. [I could not test this on a Windows or MOH network.]
3. **No UI on Windows ARM** (`windows_arm64`) or Intel Macs (`osx_amd64`) ([UI docs](https://duckdb.org/docs/stable/core_extensions/ui)). Check for any Snapdragon laptops.
4. **Session state belongs to one connection.** The UI server keeps one DuckDB connection per `X-DuckDB-UI-Connection-Name` header ([`http_server.cpp`](https://github.com/duckdb/duckdb-ui/blob/main/src/http_server.cpp)). On one connection, PREPARE then EXECUTE, `SET VARIABLE`, `TEMP` macros and the `reject_errors` / `reject_scans` temp tables all persisted across requests. From a second connection name, none of them were visible [verified-local]. Tables and non-temp macros were visible everywhere. **[unverified]** I did not confirm in the browser which UI unit gets its own connection name (notebook, tab or page load), so as not to change the facilitator's real `ui.db`. Tell Participants to keep `SET VARIABLE` / `PREPARE` / `EXECUTE` in the same notebook and to re-run setup cells after restarting DuckDB. Teach persistent macros, not temp ones, for anything shared.
5. **A cell with several statements shows only the last result.** The server runs every statement but returns only the last statement's result ([`http_server.cpp` lines ~513–530](https://github.com/duckdb/duckdb-ui/blob/main/src/http_server.cpp)); the UI blog post confirms cells can hold several statements ([UI post](https://duckdb.org/2025/03/12/duckdb-ui)).
6. **`SELECT * FROM a JOIN b USING (id)` can fail in the UI** with a duplicate-column-name error when the tables share another column name. It has failed since 1.4, works in the CLI, and is still open ([#253](https://github.com/duckdb/duckdb-ui/issues/253)). Use explicit column lists or `ON`.
7. **Only one UI process at a time.** A second DuckDB with the UI on another port hangs because `ui.db` is locked ([#256](https://github.com/duckdb/duckdb-ui/issues/256)). The UI does not support `-readonly` either; attach read-only databases with `ATTACH … (READ_ONLY)` ([UI docs](https://duckdb.org/docs/stable/core_extensions/ui)).
8. **Windows start-up takes about 4 seconds** for `duckdb -ui` / `start_ui()` ([#257](https://github.com/duckdb/duckdb-ui/issues/257)). This is cosmetic; tell Participants to wait.
9. One Windows user reports a `regex_error … insufficient memory` with `COUNT(*) AS alias` + `GROUP BY` when connected to MotherDuck; the maintainer could not reproduce it ([#216](https://github.com/duckdb/duckdb-ui/issues/216), open). Probably not relevant for local work.
10. Compatibility of `ui.db` across versions: I opened a copy of a real Series-1-era `ui.db` (including its WAL) with v1.5.5 **after** the v2.0.0 UI had used it. It opened and reported `storage_version=v1.0.0+` [verified-local, one machine]. Switching between 1.5 and 2.0 therefore did not break saved notebooks in this test.

### SQL / data cleaning

1. **One bad CSV row can make the sniffer drop data without any error.** On a 5-row `;` file whose last row has an extra column, plain `read_csv('messy.csv')` returned **1 row** on both v1.5.5 and v2.0.0. The sniffer chose `skip=5, header=false`. `strict_mode = false` also gave 1 row. `store_rejects = true` or `ignore_errors = true` gave 4 rows, and `null_padding = true` gave 5 [verified-local]. Teach the habit: **always run `sniff_csv` and compare row counts with the source** (`wc -l`, or the line count in Excel or Notepad++).
2. **Dates are ambiguous.** The sniffer considers both `%m-%d-%Y` and `%d-%m-%Y` ([CSV sniffer post](https://duckdb.org/2023/10/27/csv-sniffer)). On a file where every day was ≤ 12, both versions picked `%d/%m/%Y`, which is correct for Malaysia [verified-local], but do not rely on that. Pass `dateformat = '%d/%m/%Y'` explicitly.
3. `strptime` raises an error on bad input (`31/02/2026` gives "Date out of range"). Use `try_strptime`, which returns NULL ([dateformat docs](https://duckdb.org/docs/stable/sql/functions/dateformat)) [verified-local].
4. `regexp_replace` replaces **only the first match** unless you pass `'g'` [verified-local]. `regexp_matches` is a partial match, so anchor with `^…$` or use `regexp_full_match`. In 2.0, `~` also does partial matching ([migration](https://duckdb.org/docs/2.0/operations_manual/migration)).
5. `date_diff('year', dob, ref)` counts **year boundaries crossed**, not completed years: `1980-12-31` to `2026-01-01` gives 46. For age use `date_part('year', age(ref, dob))` ([date fns](https://duckdb.org/docs/stable/sql/functions/date)) [verified-local].
6. `date_trunc('month', some_date)` returns TIMESTAMP since 1.5. Cast back with `::DATE` before joining to DATE columns ([1.5 announcement](https://duckdb.org/2026/03/09/announcing-duckdb-150)).
7. `max(COLUMNS(*))` and `SUMMARIZE` on text columns compare strings: `'NA' > '61'` [verified-local]. Cast to the right types before computing statistics.
8. Lambda arrow syntax (`x -> …`) found in older blog posts and Stack Overflow **errors in 2.0**. Teach only `lambda x: …` ([lambda docs](https://duckdb.org/docs/stable/sql/functions/lambda), [roadmap](https://duckdb.org/roadmap)).
9. 2.0 integer division by zero (`//`, `%`) raises an error, so rates computed with `//` need `TRY()` or `nullif(denominator, 0)`. Untyped `NULL AS x` in `CREATE TABLE AS` creates a `NULL`-typed column. Errors inside `BEGIN…COMMIT` abort the transaction ([migration](https://duckdb.org/docs/2.0/operations_manual/migration)).
10. The column filter is written `COLUMNS(* EXCLUDE (col))`. `COLUMNS(*) EXCLUDE (col)` is a parser error [verified-local].
11. A JDBC client (for example DBeaver) supports only `?` parameters in prepared statements ([prepared statements](https://duckdb.org/docs/stable/sql/query_syntax/prepared_statements)). This does not affect the UI.

---

## 5. Recommended Day 1 topic list

**Morning: advanced SQL for wrangling** (builds on the Series 1 CTEs, joins and GROUP BY)

1. Warm-up and version check: `SELECT version();`. Confirm the UI starts and briefly explain the 2.0 changes (lambda syntax, `~`, `//`). About 15 min.
2. Friendly SQL for wide tables: `* EXCLUDE/REPLACE/LIKE`, `COLUMNS(*)` and regex `COLUMNS`, `GROUP BY ALL`, `FILTER`, `SUMMARIZE` for profiling a new extract.
3. Window functions + `QUALIFY`: deduplicating to the latest record per patient, `lag`/`lead`, a 30-day readmission flag.
4. Gaps-and-islands: merging ward transfers into episodes of care (instructor-led demo, then a guided exercise).
5. Reshaping: `PIVOT` / `UNPIVOT` (counts by ward or ICD chapter; repeated vitals readings).
6. `UNION BY NAME` and multi-file `read_csv(..., union_by_name = true, filename = true)` for monthly extracts.
7. Stretch: `LIST`/`STRUCT`, `string_split` + `unnest` for multi-diagnosis fields, `list_transform` with `lambda`.

**Afternoon: data cleaning clinic** (one messy synthetic MyHDW-style CSV, worked from end to end)

1. Ingest defensively: `sniff_csv`, the "silently dropped rows" demo, `store_rejects` + `reject_errors`, `all_varchar` / `null_padding` / `nullstr` / explicit `dateformat`.
2. Type repair: `TRY_CAST`, `try_strptime` with a format list, `TRY()`. Count NULLs before and after.
3. String repair: `trim`, `regexp_replace(…, 'g')`, `regexp_full_match` validation (NRIC pattern), `regexp_extract` into a struct (BP), `upper`/`lpad` standardisation, `levenshtein` / `jaro_winkler_similarity` for facility names.
4. Dates: length of stay, age at admission (the `age()` vs `date_diff` pitfall), `strftime` to `dd/mm/yyyy`, the `date_trunc` cast.
5. Package it: turn the clinic's rules into **persistent scalar macros** and one **table macro** (`clean_admissions(tbl)`). Show that they are visible in every notebook.
6. Tips and tricks to finish: `SET VARIABLE` / `$var` for the study period, then `PREPARE` / `EXECUTE` for a repeated extraction. Keep both in the same notebook.

---

## 6. Open items / not verified

- I did not test anything on Windows. All Windows UI notes come from docs and GitHub issues.
- In the browser front end, which unit gets its own UI connection (notebook, tab or page) is inferred, not observed (see UI pitfall 4).
- Whether `ui_disable_server_certificate_verification` is needed, or allowed, on the MOH network.
- Which DuckDB version each Participant installed in Series 1.
- First-release versions for the long-standing features (QUALIFY, PIVOT, rejects tables, COLUMNS, macros). They were only confirmed present in 1.5.5 and 2.0.0.
