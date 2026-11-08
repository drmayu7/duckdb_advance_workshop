# DuckDB extensions and Python/R integrations: what to teach, and how to install offline

Research for ticket #3 (Wayfinder map #1). Researched on 2026-11-08 for the 11–13 Nov 2026 workshop.

**Evidence markers**
- **[V]** means I verified it on 2026-11-08. The checks were: DuckDB CLI 1.5.5 on macOS arm64; Python `duckdb` 1.5.6 and 2.0.0 (Python 3.14, macOS arm64); and HTTP `HEAD` requests against `extensions.duckdb.org` / `community-extensions.duckdb.org` for the `windows_amd64`, `windows_amd64_mingw`, `windows_arm64` and `osx_arm64` builds.
- **[unverified]** means I could not test it, usually because it needs Windows.
- Every other claim cites a primary source.

---

## TL;DR

1. **Pin DuckDB 1.5.6, not 2.0.0, for the workshop** (CLI + UI, and Python take-homes). DuckDB 2.0.0 came out on 2026-10-21, only three weeks ago. In my tests it breaks things this workshop depends on:
   - `gsheets` has no 2.0.0 build.
   - `rapidfuzz` 2.0 moved to a separate Query.Farm repository.
   - `PIVOT` inside a CTE regressed.
   - Python 2.0 removed `fetchone()` from relations.
   - 2.0.1 is not due until 18 Nov ([release calendar](https://duckdb.org/release_calendar)).

   1.5.6 is supported until 2027-03-01. R is the exception: CRAN only ships 2.0.0 (see section 4).
2. **Keep for Day 2 rotations:** `stats_duck` (it exists and is the real name), fuzzy name matching (core functions + `rapidfuzz` + `splink_udfs`), `spatial`, and `fts`.
   - **Teach in Day 2 AM instead of a rotation:** `excel` (core, autoloads) and `httpfs` + S3 secrets (needs internet, so run it as a facilitator demo).
   - **Drop:** `gsheets` (OAuth friction, no 2.0 build, government data governance).
3. **Offline install works** ([V], tested with networking forced off). Mirror the official `.duckdb_extension.gz` files into a folder laid out as `<repo>/<version>/<platform>/`, then run `INSTALL <name> FROM '<repo>'`. The files stay signed, so `allow_unsigned_extensions` is not needed.
4. **Biggest risk: the DuckDB UI is not offline-capable.** Its local server downloads the web app from `https://ui.duckdb.org`. Extensions can be bundled; the UI front end cannot. Plan a hotspot and a CLI fallback.

---

## 1. Version decision (it determines every file in the Offline bundle)

Extension binaries are built for one exact DuckDB version and platform. The download path is `<repo>/<version>/<platform>/<name>.duckdb_extension.gz`, and the default install location is `~/.duckdb/extensions/<duckdb_version>/<platform>/` ([installing extensions](https://duckdb.org/docs/2.0/extensions/installing_extensions.html)). So the bundle has to match the version that Participants install.

| Check | 1.5.6 (2026-09-28) | 2.0.0 LTS (2026-10-21) | Source |
|---|---|---|---|
| Support window | EOL 2027-03-01 | until 2027-10-22 | [release calendar](https://duckdb.org/release_calendar), [2.0 announcement](https://duckdb.org/2026/10/21/announcing-duckdb-200.html) |
| `gsheets` build | yes | **404, no build** | [V] HEAD `community-extensions.duckdb.org/v2.0.0/*/gsheets…` returns 404 on windows_amd64, linux_amd64 and osx_arm64 |
| `rapidfuzz` from `community` | loads | **refuses to load**: "distributed from the Query.Farm extension repository" and needs `CREATE EXTENSION REPOSITORY` | [V] Python duckdb 2.0.0. The 2.0 repository feature is "still a work in progress and its syntax may change" ([2.0 announcement](https://duckdb.org/2026/10/21/announcing-duckdb-200.html)) |
| `WITH src AS (…), p AS (PIVOT src ON k) SELECT * FROM p` | works | **Catalog Error** (fix lands in 2.0.1) | [V], [duckdb#28370](https://github.com/duckdb/duckdb/issues/28370) |
| Single-arrow lambda `x -> x + 1` | works | disabled by default | [V], [2.0 announcement](https://duckdb.org/2026/10/21/announcing-duckdb-200.html) |
| Python `rel.fetchone()` / `fetchmany()` / `execute()` | works | removed | [V], [duckdb-python `_relation.py`](https://github.com/duckdb/duckdb-python/blob/main/duckdb/_relation.py) |
| UI extension | stable | needed a rebuild after release (version mismatch, fixed 2026-10-26) | [duckdb-ui#262](https://github.com/duckdb/duckdb-ui/issues/262) |
| Database files | readable by 2.0 | "versions before 2.0 cannot read database files created by DuckDB 2.0" | [2.0 announcement](https://duckdb.org/2026/10/21/announcing-duckdb-200.html) |
| `stats_duck` | v0.9.0 code (`98aa4e3`) | v0.9.0 | [V]. The **1.5.5** build is older (`efdd24d`) and has **no `glm_fit`**, so Participants must be on 1.5.6, not 1.5.5 |
| Bundle size, windows_amd64, 8 extensions | ~80 MB | ~130 MB | [V] `Content-Length` headers |

**Recommendation:** pin **DuckDB CLI 1.5.6** (Windows asset `duckdb_cli-windows-amd64.zip` on the [v1.5.6 release](https://github.com/duckdb/duckdb/releases/tag/v1.5.6)), plus `pip install duckdb==1.5.6`. In materials, write lambdas as `lambda x: …`; this works on 1.5 [V] and on 2.x, so the materials stay forward-compatible. Reconsider only if ticket #2 needs a 2.0-only feature.

---

## 2. Per-extension table

"Win" means the `windows_amd64` build, which the CLI, the UI and Python use. "R-Win" means `windows_amd64_mingw`: R on Windows downloads that platform, and it is a per-extension subset of `windows_amd64` ([duckdb-r handbook](https://github.com/duckdb/duckdb-r/blob/main/handbook/usage/extensions/README.md)). Availability was checked by HEAD request for v1.5.6 [V]. The UI runs inside the same DuckDB process ([UI docs](https://duckdb.org/docs/2.0/core_extensions/ui.html)), so any extension that loads in the CLI can be used from UI notebook cells.

| Extension | Core / community | What it does for health data | Setup effort | Win / R-Win (1.5.6) | Maturity | Keep / drop | Sources |
|---|---|---|---|---|---|---|---|
| **stats_duck** (the real name; it exists) | Community, maintainer `caerbannogwhite`, repo KoliStat/the-stats-duck, v0.9.0, Apache-2.0 | `table_one(…)` (a clinical "Table 1"), `chisq_independence`, `ttest_1samp/2samp/paired`, `anova_oneway`, `wilcoxon_signed_rank`, `lm_fit`, `glm_fit` (logistic and other families), R-style `pnorm/qt/dpois`, and `read_stat` for SAS/SPSS/Stata files, all in SQL | `INSTALL stats_duck FROM community; LOAD stats_duck;` No credentials. | yes / yes | Young: repo created 2026-04-02, last push 2026-11-05, 63 stars. Documented caveat: `glm_fit` z-statistics use a normal reference in every family, where R uses t. | **Keep** (rotation). Strong fit for statisticians and doctors. Frame it as "check your results against R" because the extension is young. | [ext page](https://duckdb.org/community_extensions/extensions/stats_duck), [description.yml](https://github.com/duckdb/community-extensions/blob/main/extensions/stats_duck/description.yml), [repo](https://github.com/KoliStat/the-stats-duck). [V] chi-square, t-test and `table_one` run on 1.5.5; `glm_fit` and `read_stat` present on 1.5.6 |
| Fuzzy matching: **core** `levenshtein`, `damerau_levenshtein`, `jaro_winkler_similarity`, `jaccard` | Core (built-in) | Patient-name deduplication, typos in IC/MRN-adjacent text fields | None | built-in | Stable | **Keep** (rotation, Core tier) | [V] `jaro_winkler_similarity('Mohd','Muhammad')` returns 0.58 |
| **rapidfuzz** | Community, Query.Farm (`rustyconover`), MIT | `rapidfuzz_token_sort_ratio` / `token_set_ratio` / `partial_ratio`, plus Jaro-Winkler, OSA, LCS and others. Token-sort handles Malay name-order variants: `'Ali bin Abu Muhammad'` vs `'Muhammad Ali bin Abu'` scores 100 | `INSTALL rapidfuzz FROM community;` | yes / yes | Active (pushed 2026-11-07). **On 2.0 it moves to Query.Farm's own repository** [V] | **Keep** (rotation, Stretch tier). Only on 1.5.6. | [ext page](https://duckdb.org/community_extensions/extensions/rapidfuzz), [description.yml](https://github.com/duckdb/community-extensions/blob/main/extensions/rapidfuzz/description.yml), [repo](https://github.com/query-farm/rapidfuzz), [V] |
| **splink_udfs** | Community, UK Ministry of Justice analytical services (`RobinL`, the Splink record-linkage team), MIT, v0.0.11 | `soundex`, `double_metaphone`, `unaccent`, `strip_diacritics`, `ngrams`, nickname lookup: phonetic blocking keys for record linkage | `INSTALL splink_udfs FROM community;` | yes / yes | Small (8 stars) but from a record-linkage team; pushed 2026-10-14 | **Keep** (rotation, Stretch tier). `soundex('Muhammad') = soundex('Mohamad') = 'M530'` [V]. The phonetic rules are English-centric, so present them as a blocking key, not a match decision. | [ext page](https://duckdb.org/community_extensions/extensions/splink_udfs), [description.yml](https://github.com/duckdb/community-extensions/blob/main/extensions/splink_udfs/description.yml), [repo](https://github.com/moj-analytical-services/splink_udfs), [V] |
| **spatial** | Core | Facility/patient points to state or district polygons (`ST_Read` on GeoJSON/Shapefile, `ST_Contains`), distance to the nearest hospital (`ST_Distance_Sphere`), dengue clusters | `INSTALL spatial; LOAD spatial;` Largest download (~20 MB). Since 1.5 the `GEOMETRY` type is built into core. | yes / yes | Mature, maintained by DuckDB Labs | **Keep** (rotation). **Gotcha:** `ST_Distance_Sphere` assumes **lat/lon** order by default. KL to Penang gives 158 km with the default and 294 km after `SET geometry_always_xy = true;` [V] | [1.5 announcement](https://duckdb.org/2026/03/09/announcing-duckdb-150.html), [spatial post](https://duckdb.org/2023/04/28/spatial.html), [V] `ST_Read` GeoJSON + `ST_Contains` |
| **fts** | Core | BM25 search over free-text fields (diagnosis text, clinical notes, complaint descriptions) | `PRAGMA create_fts_index('notes','id','txt')`, then `fts_main_notes.match_bm25(id, 'chest pain')` | yes / yes | Mature | **Keep** (rotation). Limits: **no Malay stemmer** (Indonesian, English and `none` exist); the index does **not** auto-update unless `incremental = 1`. | [FTS docs](https://duckdb.org/docs/2.0/core_extensions/full_text_search.html), [V] |
| **excel** | Core, **autoloads** | Read and write `.xlsx` (`read_xlsx(…, sheet, range, all_varchar, ignore_errors)`, `COPY … (FORMAT xlsx)`), which is what most hand-offs to health officers use | None (autoloads on first use, also offline once installed [V]) | yes / yes | Mature | **Keep, but in Day 2 AM "files and integrations", not as a rotation.** Note: **`.xls` is not supported.** | [excel docs](https://duckdb.org/docs/2.0/core_extensions/excel.html), [V] |
| rusty_sheet (alternative for `.xls`, `.ods`, WPS) | Community, MIT, v0.4.2 | `read_sheet('legacy.xls')`, for old `.xls` exports | `INSTALL rusty_sheet FROM community;` | Win yes / **R-Win excluded** | Small, single maintainer | **Optional:** a one-slide mention for legacy `.xls`. Not in the bundle unless the dataset includes `.xls`. | [description.yml](https://github.com/duckdb/community-extensions/blob/main/extensions/rusty_sheet/description.yml), [README](https://github.com/redraiment/rusty-sheet), [V] reads `.xlsx` on 1.5.5. `.xls` [unverified] |
| **httpfs** + S3 secrets | Core, autoloads on `s3://` and `https://` | Query the public workshop bucket's Parquet in place; private S3 for MOH | Public bucket: `CREATE SECRET (TYPE s3, REGION '<bucket-region>');` with no keys. Private: `PROVIDER config` (keys) or `credential_chain` (needs the `aws` extension) | httpfs yes / yes. **`aws`: Win yes, R-Win no (404)** | Mature | **Keep for the Day 2 AM live S3 demo, run by the facilitator** (needs internet). **Not a rotation.** | [S3 API docs](https://duckdb.org/docs/2.0/core_extensions/httpfs/s3api.html), [Secrets manager](https://duckdb.org/docs/2.0/configuration/secrets_manager.html), [region-only secret for public bucket](https://duckdb.org/2024/06/10/delta.html). [V] a region-only secret plus `glob('s3://overturemaps-us-west-2/…')` works with only `httpfs` loaded |
| **gsheets** | Community, maintained by Evidence (`archiewood`, `mharrisb1`), v0.0.9, MIT | Read and write Google Sheets (`read_gsheet`, `COPY … (FORMAT gsheet)`) | **High.** The default is a browser OAuth sign-in with a Google account. The alternatives are a Google Cloud project with a service account, the Sheets API enabled, a JSON key, and the sheet shared to the service-account email. Access tokens "periodically expire". The docs mark it "Experimental … Here be dragons". | Win yes / **R-Win excluded**. **No 2.0.0 build.** | Last push 2026-02-21 | **Drop.** For the Capstone's optional Google Sheet, export CSV/XLSX and upload it by hand. | [ext page](https://duckdb.org/community_extensions/extensions/gsheets), [docs](https://duckdb-gsheets.com/), [README](https://github.com/evidence-dev/duckdb_gsheets), [description.yml](https://github.com/duckdb/community-extensions/blob/main/extensions/gsheets/description.yml), [V] 404 on v2.0.0 |
| ui | Core | The DuckDB UI that Participants use | `duckdb -ui` or `CALL start_ui();` | Win yes. **windows_arm64 not supported** | See risk section 6 | Bundle it (required) | [UI docs](https://duckdb.org/docs/2.0/core_extensions/ui.html) |

Not evaluated, noted for completeness: the [community list](https://duckdb.org/community_extensions/list_of_extensions) also has `stochastic`, `duckfn_statrs` and `anofox_statistics` (statistics); `anofox_tabular` (data quality, PII masking); `dicom` and `biosignals` (medical formats). None of them is needed for this workshop.

---

## 3. Offline bundle: exact steps

### 3.1 Facilitator: build the bundle (any OS with internet)

This mirrors the official repository layout so that `INSTALL … FROM '<folder>'` works. The files are the official signed binaries.

PowerShell (Windows) [unverified on Windows; the bash version below is verified]:

```powershell
$V = "v1.5.6"; $P = "windows_amd64"
$dir = "C:\duckdb-bundle\repo\$V\$P"
New-Item -ItemType Directory -Force $dir | Out-Null
foreach ($e in "ui","httpfs","spatial","fts","excel") {
  Invoke-WebRequest "http://extensions.duckdb.org/$V/$P/$e.duckdb_extension.gz" -OutFile "$dir\$e.duckdb_extension.gz" }
foreach ($e in "stats_duck","rapidfuzz","splink_udfs") {
  Invoke-WebRequest "http://community-extensions.duckdb.org/$V/$P/$e.duckdb_extension.gz" -OutFile "$dir\$e.duckdb_extension.gz" }
```

bash/macOS (verified with the same layout for `osx_arm64`) [V]:

```bash
V=v1.5.6; P=windows_amd64; D=duckdb-bundle/repo/$V/$P; mkdir -p "$D"
for e in ui httpfs spatial fts excel; do curl -fL -o "$D/$e.duckdb_extension.gz" "http://extensions.duckdb.org/$V/$P/$e.duckdb_extension.gz"; done
for e in stats_duck rapidfuzz splink_udfs; do curl -fL -o "$D/$e.duckdb_extension.gz" "http://community-extensions.duckdb.org/$V/$P/$e.duckdb_extension.gz"; done
```

Also put in the bundle: `duckdb_cli-windows-amd64.zip` from the [v1.5.6 release](https://github.com/duckdb/duckdb/releases/tag/v1.5.6), `install.sql` and `smoke_test.sql` (below), and the datasets. Optional: `aws` (only for the private-S3 `credential_chain` documentation) and a `windows_amd64_mingw` copy for the R take-home (R would need the **v2.0.0** mingw builds; see section 4).

### 3.2 Participant: install once (from USB or download)

Copy the bundle to `C:\duckdb-bundle` (a fixed path keeps the SQL identical for everyone), unzip `duckdb.exe`, then run `duckdb -f C:/duckdb-bundle/install.sql`:

```sql
-- install.sql : installs into the default folder %USERPROFILE%\.duckdb\extensions\v1.5.6\windows_amd64\
INSTALL ui          FROM 'C:/duckdb-bundle/repo';
INSTALL httpfs      FROM 'C:/duckdb-bundle/repo';
INSTALL spatial     FROM 'C:/duckdb-bundle/repo';
INSTALL fts         FROM 'C:/duckdb-bundle/repo';
INSTALL excel       FROM 'C:/duckdb-bundle/repo';
INSTALL stats_duck  FROM 'C:/duckdb-bundle/repo';
INSTALL rapidfuzz   FROM 'C:/duckdb-bundle/repo';
INSTALL splink_udfs FROM 'C:/duckdb-bundle/repo';
```

Why this works:
- `INSTALL <name> FROM '<path>'` treats the path as a repository and resolves `<path>/<version>/<platform>/<name>.duckdb_extension.gz`. I tested this with HTTP forced to a dead proxy: the local install succeeded, and an online `INSTALL aws` failed with "Could not establish connection" [V].
- A single file also works: `INSTALL 'C:/duckdb-bundle/repo/v1.5.6/windows_amd64/excel.duckdb_extension.gz';` (`install_mode = CUSTOM_PATH`) [V].
- The files keep DuckDB's signatures, so community extensions load without `allow_unsigned_extensions` [V].
- Installing into the **default** folder (not a custom `extension_directory`) means later sessions need no extra settings. Core extensions then **autoload offline**: reading an `.xlsx` loaded `excel` with networking off [V]. Community extensions are not autoloaded; the Challenge SQL must say `LOAD stats_duck;` and so on.
- Installed extensions are shared by every client of the **same version and platform** that uses the same home directory ([installing extensions](https://duckdb.org/docs/2.0/extensions/installing_extensions.html)). So Python `duckdb==1.5.6` on Windows reuses the CLI's installs.
- If a Participant already has an install from another source or version, run `FORCE INSTALL <name> FROM 'C:/duckdb-bundle/repo';` (same doc).
- Windows path forms other than forward slashes are [unverified]. Use forward slashes.
- `extension_directory` (singular) is the setting on 1.5. On 2.0 it is deprecated in favour of `extension_directories = [...]` (same doc). Avoid both by using the default folder.

### 3.3 Smoke test (pre-workshop email and Day 1 setup check)

```sql
SELECT version() AS version, (SELECT platform FROM pragma_platform()) AS platform;  -- expect v1.5.6, windows_amd64
LOAD spatial; LOAD fts; LOAD stats_duck; LOAD rapidfuzz; LOAD splink_udfs;
SELECT pnorm(1.96)                                                     AS stats_ok,     -- 0.975
       rapidfuzz_token_sort_ratio('Ali bin Abu Muhammad', 'Muhammad Ali bin Abu') AS fuzzy_ok, -- 100
       soundex('Muhammad') = soundex('Mohamad')                        AS phonetic_ok,  -- true
       ST_AsText(ST_Point(101.69, 3.14))                               AS spatial_ok;
```

Each expression was verified on macOS 1.5.5 [V]. Windows output is [unverified]. If `platform` comes back as `windows_arm64` (Snapdragon laptops), the UI and `rapidfuzz` are not available there [V: 404]; pair that Participant with someone else.

---

## 4. Python and R integration

### Python (the `duckdb` package)

- Install with `pip install duckdb` (or conda-forge `python-duckdb`) ([Python overview](https://duckdb.org/docs/2.0/clients/python/overview.html)). For the workshop, pin `duckdb==1.5.6`; it has wheels for CPython 3.10–3.14, including Windows ([PyPI 1.5.6](https://pypi.org/project/duckdb/1.5.6/)) [V]. The repo's `pyproject.toml` requires Python ≥ 3.14, which is fine.
- The docs recommend explicit connection objects over the module-level `duckdb.sql` (same doc). Pandas and Polars DataFrames can be queried by variable name. `.df()` returns pandas and `.pl()` returns Polars (same doc).
- **Future-proofing:** 2.0 removed `fetchone()`, `fetchmany()`, `fetch_df_chunk()` and `execute()` on relations ([`_relation.py`](https://github.com/duckdb/duckdb-python/blob/main/duckdb/_relation.py)) [V]. Take-home notebooks should use only `.df()`, `.pl()` and `.fetchall()`, which work in 1.5 and 2.0 [V].

```python
import duckdb
con = duckdb.connect("myhdw.duckdb")                       # or duckdb.connect() for in-memory
con.sql("INSTALL stats_duck FROM 'C:/duckdb-bundle/repo'")  # offline; online: con.install_extension("stats_duck", repository="community")
con.load_extension("stats_duck")
by_state = con.sql("""
    SELECT state, count(*) AS admissions
    FROM 'data/admissions.parquet' GROUP BY state ORDER BY admissions DESC
""").df()                                                   # -> pandas
con.sql("SELECT * FROM by_state WHERE admissions > 1000").df()  # query the DataFrame by name
```

(The extension install/load and DataFrame-by-name pattern were verified on 1.5.6 and 2.0.0 [V].)

### R (`duckdb` + DBI, and `duckplyr` for dplyr users)

- CRAN `duckdb` is **2.0.0** (published 2026-10-23, requires R ≥ 4.2). `duckplyr` 1.2.2 (2026-10-22) imports `duckdb ≥ 1.4.4` ([CRAN duckdb](https://cran.r-project.org/package=duckdb), [CRAN duckplyr](https://cran.r-project.org/package=duckplyr)) [V].
- There is no easy 1.5.6 Windows binary. r-universe carries only `duckdb.1.5.dev` (1.5.5.9900) and `duckdb.1.4` ([r-universe](https://duckdb.r-universe.dev)) [V].
- **So the R take-home runs DuckDB 2.0.0.** That is acceptable for a take-home. Two rules follow:
  1. **Exchange data as Parquet or CSV, not `.duckdb` files.** A file *created* by 2.0 cannot be opened by the 1.5.6 UI ([2.0 announcement](https://duckdb.org/2026/10/21/announcing-duckdb-200.html)).
  2. On Windows, R downloads `windows_amd64_mingw` extensions ([duckdb-r handbook](https://github.com/duckdb/duckdb-r/blob/main/handbook/usage/extensions/README.md)). Of the shortlist, `gsheets`, `rusty_sheet` and `aws` have no mingw build [V]; `rapidfuzz` on 2.0 needs the Query.Farm repository [V].
- DBI is the base layer ([R client docs](https://duckdb.org/docs/2.0/clients/r.html)). duckplyr runs dplyr verbs on DuckDB and **falls back to dplyr** for anything it cannot translate. It reads Parquet and CSV directly with `read_parquet_duckdb()` / `read_csv_duckdb()` ([duckplyr](https://github.com/tidyverse/duckplyr)).

```r
install.packages(c("duckdb", "duckplyr"))
library(DBI)
con <- dbConnect(duckdb::duckdb(), dbdir = "myhdw.duckdb", read_only = TRUE)
dbGetQuery(con, "SELECT state, count(*) AS n FROM 'data/admissions.parquet' GROUP BY ALL")
dbDisconnect(con, shutdown = TRUE)

library(duckplyr)
adm <- read_parquet_duckdb("data/admissions.parquet")
adm |> summarise(.by = state, n = n()) |> arrange(desc(n))
```

(R code [unverified]: R is not installed on the research machine. The calls come from the cited docs.)

**Concurrency gotcha for the demo:** only one process can open a `.duckdb` file read-write; several processes can open it only if all are read-only ([concurrency](https://duckdb.org/docs/2.0/connect/concurrency.html)). If the UI has `myhdw.duckdb` open, Python or R must use `read_only = TRUE`, or better, read the Parquet files directly.

---

## 5. Recommended Day 2 PM rotation lineup

Four stations of about 20–25 min each. Every station runs fully offline after the bundle install. Each has a Core tier and a Stretch tier.

| Station | Extension(s) | Core tier | Stretch tier | Gotcha to put on the card |
|---|---|---|---|---|
| **A. Statistics in SQL** | `stats_duck` | `table_one('admissions', variables := ['age','sex'], by := ['readmitted'])`, then `chisq_independence(sex, readmitted)` | `glm_fit(readmitted, [age, los], 'binomial')` (logistic regression); compare with R output from the take-home | Young extension. Results are structs: `(chisq_independence(…)).p_value`. `chisq_independence` takes **VARCHAR** arguments only, so cast booleans and integers with `::VARCHAR`. `glm_fit` labels terms `x1, x2, …`, not by column name. All three behaviours were seen on 1.5.6 [V]. Ask Participants to sanity-check one result against R. |
| **B. Patient-name matching** | core `jaro_winkler_similarity` / `levenshtein`, then `rapidfuzz`, `splink_udfs` | Find likely duplicate patients with `jaro_winkler_similarity > 0.9` inside the same DOB | `rapidfuzz_token_sort_ratio` for "bin/binti" order variants; `soundex` / `double_metaphone` as blocking keys | Phonetic codes are English-centric; treat them as candidates, not matches. Use synthetic names only (ADR 0001). |
| **C. Spatial** | `spatial` | `ST_Read` the state GeoJSON, `ST_Contains` to assign facilities to states | Nearest facility per dengue case with `ST_Distance_Sphere` | `SET geometry_always_xy = true;` first, or distances come out wrong (158 km vs 294 km) [V] |
| **D. Free-text search** | `fts` | `PRAGMA create_fts_index` on diagnosis or complaint text; top-10 by `match_bm25` | `fields :=`, `conjunctive := 1`, stopwords from a custom table | English stemmer only, no Malay stemmer; rebuild the index after updates |

Placed elsewhere:
- `excel` goes in Day 2 AM files and integrations.
- `httpfs` + public S3 is the Day 2 AM facilitator live demo (internet). Private S3 goes in documentation only: `CREATE SECRET (TYPE s3, PROVIDER config, KEY_ID …, SECRET …, REGION …)`. Warn that `CREATE PERSISTENT SECRET` writes **unencrypted** to `~/.duckdb/stored_secrets` ([secrets manager](https://duckdb.org/docs/2.0/configuration/secrets_manager.html)).
- `gsheets` is dropped.

---

## 6. Risks the facilitator must know

1. **The DuckDB UI needs internet every time it loads.** The local server "fetches the files for the UI from a remote HTTP server" (`https://ui.duckdb.org`) ([UI docs](https://duckdb.org/docs/2.0/core_extensions/ui.html), [duckdb-ui README](https://github.com/duckdb/duckdb-ui)).
   - Offline mode is an **open** request ([duckdb-ui#62](https://github.com/duckdb/duckdb-ui/issues/62)). A maintainer's only workaround is mitmproxy capture and replay.
   - The UI bundle is about 8.8 MB, and it is re-downloaded once the browser cache is stale ([duckdb-ui#258](https://github.com/duckdb/duckdb-ui/issues/258)).
   - Mitigation: a facilitator phone hotspot for UI start-up, and the DuckDB CLI (`duckdb.exe`, fully offline) as the documented fallback. Optionally, have Participants open the UI once at home during the smoke test so the browser cache is warm. Whether a warm cache survives a disconnected restart is [unverified].
2. **Version drift.**
   - `pip install duckdb` and `install.packages("duckdb")` now give **2.0.0** by default.
   - The pre-workshop email must give the exact 1.5.6 CLI link and `pip install duckdb==1.5.6`.
   - Participants still on **1.5.5** get an older `stats_duck` without `glm_fit` [V].
3. **Windows on ARM** (`windows_arm64`): no UI and no `rapidfuzz` builds [V]. Check `pragma_platform()` in the smoke test.
4. **gsheets OAuth friction** (if anyone revives it). It needs a browser Google sign-in, or a GCP service account and JSON key. Its tokens expire. Also likely data-governance objections to putting MOH-derived data in personal Google Sheets [unverified: policy not checked]. It has no 2.0.0 build.
5. **Community extensions are young.** `stats_duck` is seven months old. `splink_udfs` is v0.0.x. `rapidfuzz` changes distribution on 2.0. The Offline bundle pins exact binaries, so the workshop is insulated from this; take-homes on 2.0 are not.
6. **R on Windows uses a different extension platform** (`windows_amd64_mingw`), and `aws` is missing there, so R cannot use the `credential_chain` S3 provider. Document `PROVIDER config` for R.
7. **Do not mix `.duckdb` files between R/Python 2.0 and the 1.5.6 UI**; share Parquet instead.

---

## Sources

- DuckDB docs (2.0 is the current docs version; `/stable/` redirects there): [installing extensions](https://duckdb.org/docs/2.0/extensions/installing_extensions.html), [UI](https://duckdb.org/docs/2.0/core_extensions/ui.html), [excel](https://duckdb.org/docs/2.0/core_extensions/excel.html), [full-text search](https://duckdb.org/docs/2.0/core_extensions/full_text_search.html), [S3 API](https://duckdb.org/docs/2.0/core_extensions/httpfs/s3api.html), [secrets manager](https://duckdb.org/docs/2.0/configuration/secrets_manager.html), [concurrency](https://duckdb.org/docs/2.0/connect/concurrency.html), [Python](https://duckdb.org/docs/2.0/clients/python/overview.html), [R](https://duckdb.org/docs/2.0/clients/r.html)
- Release info: [DuckDB 2.0.0 announcement](https://duckdb.org/2026/10/21/announcing-duckdb-200.html), [DuckDB 1.5.0 announcement](https://duckdb.org/2026/03/09/announcing-duckdb-150.html), [release calendar](https://duckdb.org/release_calendar), [v1.5.6 release assets](https://github.com/duckdb/duckdb/releases/tag/v1.5.6), [duckdb#28370](https://github.com/duckdb/duckdb/issues/28370)
- Community extensions: [list](https://duckdb.org/community_extensions/list_of_extensions), [community-extensions repo descriptors](https://github.com/duckdb/community-extensions/tree/main/extensions), plus the per-extension pages and repos linked in section 2
- UI: [duckdb-ui README](https://github.com/duckdb/duckdb-ui), issues [#62](https://github.com/duckdb/duckdb-ui/issues/62), [#258](https://github.com/duckdb/duckdb-ui/issues/258), [#262](https://github.com/duckdb/duckdb-ui/issues/262)
- Clients: [duckdb-python](https://github.com/duckdb/duckdb-python), [PyPI duckdb](https://pypi.org/project/duckdb/), [CRAN duckdb](https://cran.r-project.org/package=duckdb), [CRAN duckplyr](https://cran.r-project.org/package=duckplyr), [duckplyr repo](https://github.com/tidyverse/duckplyr), [duckdb-r extensions handbook](https://github.com/duckdb/duckdb-r/blob/main/handbook/usage/extensions/README.md), [duckdb r-universe](https://duckdb.r-universe.dev)
- Also queried through Context7: `/duckdb/duckdb-web`, `/duckdb/duckdb-python`, `/tidyverse/duckplyr`
