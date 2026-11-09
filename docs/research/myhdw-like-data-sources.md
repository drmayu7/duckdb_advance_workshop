# MyHDW-like dataset: open data sources and synthetic-data approach

Research for issue #4. Checked on 2026-11-08. Every dataset in section 1 was loaded with DuckDB v1.5.5 straight from the URL given, unless marked otherwise. Items marked **UNVERIFIED** could not be confirmed from a primary source.

## TL;DR

- **Enrichment data.** Use DOSM population (state and district, CC BY 4.0, Parquet), MoH bed counts (CC BY 4.0, Parquet), the MoH `facilities_master.csv` (5,160 public facilities, 166 of them hospitals, with lat/long), DOSM state and district GeoJSON, and the archived MoH dengue tables (state × age group × year, 2018–2021, CC BY). The new data.gov.my catalogue has **no dengue dataset**.
- **Generator.** Use plain DuckDB SQL: `range()` plus a `hash(id, salt)` uniform macro, with the open data as weighting tables. A measured run made 30M admissions, 12M patients and 60M diagnosis rows in **20 s**, giving **626 MB** of zstd Parquet (Apple M3, 8 GB, 4 threads). Faker and Synthea do not fit (see section 2).
- **ICD-10.** Malaysia-style coding should follow **WHO ICD-10 (2019)**, for example dengue `A97.x`. WHO publishes no explicit open licence for ICD-10, so use a small hand-curated subset with attribution. The **CMS ICD-10-CM 2027** file (74,879 codes, free download) is the bulk option. Its US-only codes (`E11.65`) make a realistic "wrong code system" defect.
- **The real open data is already messy.** For example: 17 spellings of the state field, health-district names that do not match DOSM districts, newlines inside facility names, and 166 districts in the 2025+ population data against 160 polygons. Use these real defects in the cleaning exercises alongside the injected ones.

---

## 1. Open datasets

Licences: data.gov.my catalogue pages state *"This data is made open under the Creative Commons Attribution 4.0 International License (CC BY 4.0)"* ([population_district](https://data.gov.my/data-catalogue/population_district), [population_state](https://data.gov.my/data-catalogue/population_state), [hospital_beds](https://data.gov.my/data-catalogue/hospital_beds)). Archive datasets are tagged "Creative Commons Attribution" in the CKAN API (`license_url` = opendefinition.org cc-by), e.g. [package_show?id=penyakit-denggi](https://archive.data.gov.my/data/api/3/action/package_show?id=penyakit-denggi).

| # | Dataset | Publisher | URL | Format | Licence | Granularity / coverage | Joins to synthetic data via |
|---|---|---|---|---|---|---|---|
| D1 | Population: states | DOSM | https://storage.dosm.gov.my/population/population_state.parquet (also `.csv`) | Parquet, CSV | CC BY 4.0 | 16 states × year (1970–2026) × sex × age group × ethnicity. **`population` is in thousands.** 270,063 rows | `state` name → `ref_state`. Weights patient state of residence, age/sex/ethnicity mix. Denominator for rates per 100k |
| D2 | Population: administrative districts | DOSM | https://storage.dosm.gov.my/population/population_district.parquet (also `.csv`) | Parquet, CSV | CC BY 4.0 | District × year (2020–2026) × sex × 5-yr age group (to 85+) × ethnicity, in thousands. 451,668 rows. **160 districts for 2020–2024, 166 for 2025–2026** | `(state, district)` → `ref_district`. Weights patient district. District-level rates for maps |
| D3 | Hospital beds | MoH (via data.gov.my) | https://storage.data.gov.my/healthcare/hospital_beds.parquet (also `.csv`) | Parquet, CSV | CC BY 4.0 | Year (2015–2024) × national/state/district × type (`hospital_moh`, `hospital_non_moh`, `special_medical_institution`). 6,828 rows | `(state, district)`. Caps admissions per district in proportion to beds. Occupancy exercises |
| D4 | Public health facilities master | MoH (KKM) | https://github.com/MoH-Malaysia/data-resources-public/blob/main/facilities_master.csv (raw: `https://raw.githubusercontent.com/MoH-Malaysia/data-resources-public/main/facilities_master.csv`) | CSV (UTF-8, Malay column names) | **No explicit licence.** README: "subject to the terms of this repository and applicable Government of Malaysia open data policies. Please attribute the Ministry of Health Malaysia" | 5,160 facilities "as registered on 31 December 2025". `KOD_FASILITI`, `NEGERI`, `DAERAH`, `KATEGORI_FASILITI` (166 `HOSPITAL`), `JENIS_FASILITI`, `NAMA`, `POSKOD`, `LATITUD`/`LONGITUD` (WGS84) | `KOD_FASILITI` becomes `admission.facility_code`. Lat/long gives point-in-polygon to D7. 164 of the 166 hospitals fall inside a DOSM district polygon (tested with `ST_Contains`) |
| D5 | Bed / ICU / ventilator capacity per hospital | MoH (KKM) | https://raw.githubusercontent.com/MoH-Malaysia/data-resources-public/main/bedutil_facility.csv, `bedutil_state.csv` | CSV | as D4 | 149 hospitals (`beds_nonicu`, `util_nonicu`, `beds_icu`, `vent`, ...), 17 state rows | Hospital **name** only. 130/149 match `upper(hospital) = NAMA` exactly, 132 after whitespace cleanup. A fuzzy-join exercise |
| D6 | State boundaries | DOSM | https://raw.githubusercontent.com/dosm-malaysia/data-open/main/datasets/geodata/administrative_1_state.geojson | GeoJSON (EPSG:4326, 392 KB) | DOSM Open Data Licence ([LICENSE.md](https://github.com/dosm-malaysia/data-open/blob/main/LICENSE.md)): copy, adapt, use commercially. No implied endorsement. Defers to Pekeliling Data Terbuka Bil.1/2015 App. B | 16 polygons. `state`, `code_state` (1–16) | `code_state` = MyKad birthplace code and ISO 3166-2:MY suffix (see section 4). Choropleths |
| D7 | District boundaries | DOSM | https://raw.githubusercontent.com/dosm-malaysia/data-open/main/datasets/geodata/administrative_2_district.geojson (+ `state_district.csv`) | GeoJSON (948 KB) | as D6 | **160** polygons. `state`, `district`, `code_state`, `code_district`, `code_state_district`. Repo last pushed 2022 | `(state, district)` → D2. **6 districts in D2 (2025+) have no polygon**: Sarawak Sebuyau, Gedong, Siburan, Pantu, Lingga; Sabah Membakut |
| D8 | Dengue cases: annual by state and age group | MoH Disease Control Division (archive.data.gov.my) | https://archive.data.gov.my/data/dataset/b36d588f-ced4-4c16-ba9a-021e9bf38ae5/resource/216eb37a-d676-4c53-9f54-878e91a98e47/download/_202301090525170_bilangan-kes-penyakit-denggi-tahunan-mengikut-negeri-dan-kumpulan-umur.csv (XLSX per year 2010–2017 in same package) | CSV (wide: one column per state) | CC BY | 2018–2021 × 16 age groups × 15 state columns (Putrajaya absent; KL "WP KUALA LUMPUR"). Age labels inconsistent: `0-4`, `" 5 - 9"`, `>75` | UNPIVOT → `(year, state, age_band, cases)`. Weights dengue admissions by state/age/year. Real wrangling exercise |
| D9 | DHF cases: weekly by state | MoH Disease Control Division (archive) | https://archive.data.gov.my/data/dataset/0e34a58f-909e-4ec2-85ab-8633830be91c/resource/86fa02b3-75ab-4589-bedf-4f79de7756c0/download/_202301090523420_bilangan-kes-penyakit-dengue-haemorrhagic-fever-mingguan-mengikut-negeri.csv | CSV (wide) | CC BY | 2018–2021 × epi week (`MINGGU EPID`) × state. Counts are small (DHF only) | **Seasonality shape** for dengue admission dates (epi week → date) |
| D10 | Postcodes | MCMC (via data.gov.my) | https://storage.data.gov.my/dictionaries/postcodes.parquet (also `.csv`) | Parquet, CSV | CC BY 4.0 (data.gov.my catalogue; page not individually checked) | 2,932 rows `(state, city, postcode)`. Postcode is VARCHAR with leading zero (`01000`) | Patient address postcode. Postcode/state consistency checks. Leading-zero-loss exercise |
| D11 | Deaths and births by district and sex | JPN, DOSM | https://storage.dosm.gov.my/demography/death_district_sex.parquet, https://storage.dosm.gov.my/demography/birth_district_sex.parquet | Parquet | CC BY 4.0 (catalogue ids `deaths_district_sex`, `births_district_sex`; pages not individually checked) | 2020–2025 | Optional: sanity-check in-hospital death and delivery volumes |
| D12 | COVID-19 epidemic data | MoH | https://github.com/MoH-Malaysia/covid19-public | CSV | Repo LICENSE.md: "may be used per the terms of reference found in Appendix B of the Pekeliling Pelaksanaan Data Terbuka Bil.1/2015" | 2020+ (state level) | Not needed for the Scenario. Listed for completeness |
| D13 | KKMNOW dashboard extracts | MoH | https://github.com/MoH-Malaysia/kkmnow-data (e.g. `facilities_01_table.parquet`, `bedutil_02_timeseries_state.parquet`) | Parquet | Repo licence MIT (GitHub API). It is unclear whether this covers the data | Dashboard-shaped tables | Fallback mirror for D4/D5 in Parquet. Not inspected in depth |

Other checks:
- The data.gov.my catalogue metadata repo [`data-gov-my/datagovmy-meta/data-catalogue/`](https://github.com/data-gov-my/datagovmy-meta/tree/main/data-catalogue) lists every catalogue id. None contains "dengue"/"denggi" or any hospital admission or diagnosis data. Health ids present include `hospital_beds`, `healthcare_staff`, `blood_donations`, `organ_pledges`, `pekab40_screenings`, `covid_*`.
- Other archived dengue packages with CC BY (search: [package_search?q=denggi](https://archive.data.gov.my/data/api/3/action/package_search?q=denggi)): dengue hotspot localities lists (XLSX, 2010–2015, 2019), Pahang dengue by district, KL dengue by parliament constituency. Use them only if district-level dengue is needed. They have not been inspected.
- The current national dengue figures come from KKM press releases and iDengue (https://idengue.mysa.gov.my). No bulk open download was found (**UNVERIFIED**).
- Data.gov.my also has a JSON API, for example `https://api.data.gov.my/data-catalogue?id=population_state&limit=2` (follow the 301 redirect). It returned `age = "overall_age"` where the Parquet file has `"overall"`. Use the Parquet files and don't mix the two sources.

### Real data-quality issues already present in the open data (verified)

These need no injection and make good opening cleaning exercises:

| Source | Issue | Example |
|---|---|---|
| D4 | State field has 17 distinct values, including a merged pseudo-state | `WILAYAH PERSEKUTUAN KUALA LUMPUR DAN PUTRAJAYA` alongside `WILAYAH PERSEKUTUAN KUALA LUMPUR` and `WILAYAH PERSEKUTUAN PUTRAJAYA` |
| D4 vs D7 | Health-district names ≠ DOSM administrative districts: 311 facilities in 39 `(NEGERI, DAERAH)` pairs fail an upper-case name join | `JAJAHAN KOTA BHARU`, `KULAIJAYA`, `BANDAR KUALA LUMPUR`, `TITIWANGSA`, `MUKIM SENA`, `GEMAS` |
| D4 | Embedded newlines inside quoted names (10 rows) | `HOSPITAL ENCHE' BESAR HAJJAH\n KHALSOM` |
| D4 | 2 facilities have coordinates outside a Malaysia bounding box (lat 0.8–7.5, lon 99.5–119.5) | (check before mapping) |
| D4 vs D6/D7 | Case and wording differ | `JOHOR` vs `Johor`. `WILAYAH PERSEKUTUAN KUALA LUMPUR` vs `W.P. Kuala Lumpur` |
| D2 vs D7 | Boundary vintage lag: 6 districts without polygons | `Sarawak / Sebuyau` |
| D1, D2 | Units: population in thousands | Johor 2026 (D1, both sexes, all ages) = `4224.3` |
| D8 | Wide layout, inconsistent age labels, different top band from DOSM | `" 5 - 9"`, `>75` vs DOSM `85+`. `WP KUALA LUMPUR` |
| D10 | Postcodes need VARCHAR | `01000` → `1000` if read as an integer |

---

## 2. Generation approach

### Recommendation: DuckDB SQL only, seeded from the open data, generated once and shipped as Parquet

**How it works**
1. Load the reference tables (D1, D2, D4, D7, D8 and an ICD-10 subset) into small `ref_*` tables, and build cumulative-weight (CDF) columns from them.
2. Generate rows with `FROM range(n)`. Draw uniforms with a deterministic macro:
   ```sql
   CREATE MACRO u(id, salt) AS (hash(id, salt) % 1000000)::DOUBLE / 1000000;
   ```
3. Pick categories with `ASOF JOIN ref_cdf ON u(...) <= cum`. This gives population-weighted state, district, age and sex, plus diagnosis mix. Use `-ln(1-u)*mean` for an exponential length of stay, and `unnest(range(1, k))` for 1–4 secondary diagnoses per admission.
4. Build the **clean truth** tables first. Then derive the **messy extract** with a defect-injection step that also writes an answer-key table (`dq_answer_key`). Section 4 lists the defects.
5. Export with `COPY ... TO '...parquet' (FORMAT parquet, COMPRESSION zstd)`. Set `preserve_insertion_order = false` for parallel writes ([DuckDB 0.7.0 notes](https://github.com/duckdb/duckdb-web/blob/main/_posts/2023-02-13-announcing-duckdb-070.md)) and `memory_limit`.

**Why `hash()` rather than `setseed()` + `random()`.** I tested both. `hash`-based tables gave an identical checksum with `threads = 1` and with `threads = 4`. `setseed(0.42)` with `random()` gave a different float sum on a repeat run (2500854.211378228 vs 2500854.2113782237), so row-to-value assignment is not stable under parallelism. DuckDB's own blog uses `hash(rowid + 42)` "for consistency across re-runs" ([advanced sorting post](https://github.com/duckdb/duckdb-web/blob/main/_posts/2025-06-06-advanced-sorting-for-fast-selective-queries.md)). Hash outputs could change between DuckDB versions (**UNVERIFIED**). So pin the version used to generate, and **ship the generated Parquet** rather than having participants regenerate it.

**Measured prototype**

The prototype script was not committed. It generates patient (dob, sex, birth state, MyKad), admission (patient, facility, dates, principal dx, discharge status) and diagnosis tables. Machine: Apple M3, 8 GB RAM, `threads = 4`, `memory_limit = 6GB`, DuckDB v1.5.5.

| Size | Rows (patient / admission / diagnosis) | Wall time (generate + export) | Parquet zstd total |
|---|---|---|---|
| Small | 400k / 1M / 2M | 0.53 s | 20 MB (admission 10.7 MB) |
| Large | 12M / 30M / 60M | 20.4 s | 626 MB (admission 339 MB, diagnosis 145 MB, patient 142 MB) |

The ~100k-admission exercise size will take well under 1 s and come to about 2 MB.

**Estimates for the full schema (not measured).** Adding names, addresses, free-text diagnosis and the messy string variants could roughly double to triple the bytes per row. That puts **~1.2–2 GB for 30M admissions**, inside the 3 GB budget. Generation on a typical Windows laptop with 8–16 GB RAM should take **about 1–3 minutes**. Generate the large set on the instructor machine and distribute it. Participants only query it.

**Measured with the real generator (9 Nov, #25).** `./build.sh large` makes 30.1M admissions in about 6.5 min on the 8 GB build Mac, giving 742 MB of Parquet. A `memory_limit` and a `temp_directory` alone did **not** stop it running out of memory. Four things did, and `build_large` in `build.sh` and `generator/truth.sql` now do all four:

- **A database file, not `:memory:`.** In memory, the ~35M-row intermediate tables (`a0`…`a6`) cannot be evicted.
- **`preserve_insertion_order = false`.** With it on, the join that builds `a6` ran out of memory. Every output is written with an explicit `ORDER BY`, so the files stay byte-identical.
- **No window over the whole table on wide rows.** A single `row_number() OVER (ORDER BY …)` across every admission column ran out of memory. Number a narrow `(key, sort columns)` table and join the number back.
- **No per-row window across a joined lookup.** A weighted pick over every hospital in the state (admissions × hospitals rows) took two thirds of the run time. Precompute running weights per residence and ASOF-join the threshold.

A scaled-down memory test (10× the small data, with a proportionally smaller limit) does not reproduce these failures, so the only real check is a full `./build.sh large`.

### Alternatives considered

| Option | Verdict | Evidence |
|---|---|---|
| **DuckDB SQL only** | **Recommended.** No extra install. Fast. The generator itself can be a "what DuckDB can do" demo. Open-data weights load directly from URLs | Measured above |
| Python Faker | **Not recommended as the core.** Faker has **no Malaysian person or ID provider**: `faker/providers/person` and `faker/providers/ssn` have no `ms_MY`/`en_MS` locale. Only `faker/providers/address/en_MS` exists, which gives Malaysian addresses with state abbreviations like `SGR`, `NSN`. Per-row Python generation of 30M rows would be much slower than set-based SQL (**UNVERIFIED**, not benchmarked). Licence MIT | [joke2k/faker providers](https://github.com/joke2k/faker/tree/master/faker/providers) |
| Synthea | **Not recommended.** Needs Java JDK 17+. Simulates whole lifetimes per patient ("Generating the population one at a time"). US-centric: `synthea-international` has configs for European countries, Japan and New Zealand, **none for Malaysia**. Outputs US codes (SNOMED/RxNorm and others). Licence Apache-2.0 | [synthea README](https://github.com/synthetichealth/synthea), [synthea-international](https://github.com/synthetichealth/synthea-international) |
| Hybrid | Optional. A tiny Python or hand-written seed list of Malay, Chinese and Indian given names and surnames, loaded as a `ref_name` table and sampled in SQL. No open, licensed Malaysian name-frequency dataset was found (**UNVERIFIED**), so hand-curate ~200 tokens | (none) |

### Realism rules for the Scenario

These are design suggestions, not sourced facts:
- **Readmission.** Give each patient a latent "frailty" uniform. Patients with chronic diabetes or CKD get 2–6 admissions with gaps drawn from an exponential, so a meaningful share falls within 30 days of the previous discharge. Single-visit obstetric and trauma patients make up the bulk.
- **Diabetes.** Use E11.x as principal or secondary diagnosis, increasing with age. Raise the readmission propensity.
- **Dengue.** Use A97.x. Scale admission volume by state and age from D8 (2018–2021) and time it with D9 epi-week shape. Place admission dates in 2018–2021 so the real dengue denominators line up, or reuse the shape for later years.
- **Facility assignment.** Admit to a hospital in the patient's district or state from D4, weighted by D3/D5 beds.

---

## 3. ICD-10 sources and licences

| Source | What you get | Licence / terms | Fit |
|---|---|---|---|
| **WHO ICD-10 2019** browser, https://icd.who.int/browse10/2019/en | Code + title, browsable. A JSON endpoint works without login, e.g. `https://icd.who.int/browse10/2019/en/JsonGetChildrenConcepts?ConceptId=A97&useHtml=false` returns `A97.0 Dengue without warning signs`, `A97.1 Dengue with warning signs`, `A97.2 Severe Dengue`, `A97.9 Dengue, unspecified` | **No explicit open licence found for ICD-10.** WHO's licensing page covers ICD-11 only ([who.int licensing/classifications](https://www.who.int/about/licensing/classifications/en/)). CDC states "The World Health Organization (WHO), which owns and publishes ICD-10, authorized NCHS to develop ICD-10-CM" ([CDC ICD-10-CM](https://www.cdc.gov/nchs/icd/icd-10-cm/index.html)). **Risk:** a bulk copy of the full classification may need WHO permission. A small curated code list for training, with attribution, is lower risk but still **UNVERIFIED** | **Best match for Malaysian practice.** That KKM codes inpatient diagnoses in WHO ICD-10 rather than ICD-10-CM is **UNVERIFIED** in this research and should be confirmed with the MyHDW team |
| **CMS ICD-10-CM FY2027** "Code Descriptions in Tabular Order", https://www.cms.gov/files/zip/2027-code-descriptions-tabular-order.zip (listed on [cms.gov ICD-10 codes](https://www.cms.gov/medicare/coding-billing/icd-10-codes)) | 2.2 MB zip. `icd10cm_codes_2027.txt` has **74,879** codes in fixed-width `code<spaces>title` format, no dot (e.g. `E119`, `E1165`). Also order files and addenda | US federal publication. **No copyright or terms statement on the CMS or CDC pages** (both checked). It is commonly treated as public domain, but that is **UNVERIFIED** here | Free and complete, but a US clinical modification. Dengue is `A90`/`A91` only (no `A97`). Many 5–7 character codes (`E11.65`) don't exist in WHO ICD-10 |
| **WHO ICD-11** | Codes via API (registration at https://icd.who.int/icdapi) | **CC BY-ND 3.0 IGO**: "may be used for commercial and non-commercial purposes, provided there is no adaptation of the codes and the work is appropriately cited". Software has a separate royalty-free licence ([who.int licensing/classifications](https://www.who.int/about/licensing/classifications/en/)) | Not what MyHDW uses (**UNVERIFIED**). Out of scope |

**Recommendation.** Hand-curate a `ref_icd10` table of about 100–200 WHO ICD-10 codes covering the Scenario: E10–E14, I10–I25, I60–I64, J18, J44–J45, N17–N18, A09, A90–A91 (legacy dengue), A97, O80–O84, S72 and common surgical diagnoses. Record `source = 'WHO ICD-10 2019'` and attribute WHO in the dataset README. Use ICD-10-CM codes only as an *injected defect*, for example a US-style `E11.65` or `E1165` that fails validation against `ref_icd10`.

---

## 4. Malaysian identifier and code facts used by the generator

- **MyKad number**: 12 digits, `YYMMDD-PB-###G`. The first 6 digits are the date of birth and `PB` is the place-of-birth code ([Microsoft Purview, Malaysia ID card number SIT](https://learn.microsoft.com/en-us/purview/sit-defn-malaysia-identification-card-number); [Wikipedia, Malaysian identity card](https://en.wikipedia.org/wiki/Malaysian_identity_card)). Last digit **odd = male, even = female**. This is a convention with known exceptions ([Borneo Post 2017](https://www.theborneopost.com/2017/11/09/womans-mykad-with-odd-number-for-last-digit-needs-to-be-corrected-immediately-says-voon/)), and JPN doesn't confirm it on its site (**UNVERIFIED** against JPN).
- **Place-of-birth (state) codes** from JPN ([jpn.gov.my/my/kod-negeri](https://www.jpn.gov.my/my/kod-negeri)): Johor 01, 21–24 · Kedah 02, 25–27 · Kelantan 03, 28–29 · Melaka 04, 30 · N. Sembilan 05, 31, 59 · Pahang 06, 32–33 · P. Pinang 07, 34–35 · Perak 08, 36–39 · Perlis 09, 40 · Selangor 10, 41–44 · Terengganu 11, 45–46 · Sabah 12, 47–49 · Sarawak 13, 50–53 · WP KL 14, 54–57 · WP Labuan 15, 58 · WP Putrajaya 16 · unknown state 82. Foreign-born codes are listed separately ([jpn.gov.my/my/kod-negara](https://www.jpn.gov.my/my/kod-negara), 294 records, e.g. Brunei 60, Indonesia 61, Singapura 66, China 74). Codes 17–20 are not assigned.
- **State codes line up.** The JPN primary codes 01–16, DOSM GeoJSON `code_state` 1–16 (D6) and ISO 3166-2:MY `MY-01`…`MY-16` ([Wikipedia ISO 3166-2:MY](https://en.wikipedia.org/wiki/ISO_3166-2:MY)) use the same numbering. One `ref_state` table can carry all three.

---

## 5. Catalogue of data-quality problems to inject

Each defect is applied to a seeded fraction of rows in the messy extract and logged in `dq_answer_key (table, row_id, column, defect_code, clean_value)`. Suggested rates are 0.5–5% per defect, with free-text and format variants higher (20–40%). The rates are design choices, not sourced.

| Code | Area | Problem | Realistic dirty example → clean |
|---|---|---|---|
| ID01 | MyKad | Dash/space variants | `850312105523`, `850312 10 5523`, `850312-10-5523 ` → `850312-10-5523` |
| ID02 | MyKad | Leading zero lost when stored as a number (born 2000–2009) | `50312105524` (11 digits) → `050312-10-5524` |
| ID03 | MyKad | DOB part disagrees with `dob` column, or is an impossible date | `851332-10-5523`. `dob = 1985-03-21` with IC `850312-…` |
| ID04 | MyKad | Sex digit parity disagrees with `sex` | IC ends `…5524` (even) with `sex = 'L'` |
| ID05 | MyKad | Invalid or unknown PB code | `850312-17-5523` (17 unassigned), `850312-82-5523` (unknown state) |
| ID06 | ID type | Non-MyKad identifiers in the IC column | old IC `A1234567`, passport `K12345678`, police/army `RF123456`, `TIADA`, `-` |
| PT01 | Patient | Same person, several records/MRNs across facilities | `Muhammad Faiz bin Ahmad` / `MOHD FAIZ B. AHMAD` / `Muhd Faiz Ahmad`, same IC with or without dashes |
| PT02 | Names | Malay, Indian and Chinese name conventions | `bin`/`b.`/`B`, `binti`/`bt`/`bte`. `a/l`, `A/L`, `anak lelaki`. `Tan Wei Ming` vs `Wei Ming Tan`. Honorifics `Hj.`, `Datuk` |
| PT03 | Sex | Mixed coding | `L`/`P` (Lelaki/Perempuan), `M`/`F`, `1`/`2`, `Male`, `lelaki`, `U` |
| PT04 | Ethnicity | Mixed Malay/English, granularity | `Melayu`, `Malay`, `MLY`, `Cina`, `Chinese`, `India`, `Bumiputera Sabah`, `Kadazan`, `Lain-lain`, `Others` |
| GE01 | State | Name variants | `Pulau Pinang`/`P. Pinang`/`Penang`/`PNG`. `Negeri Sembilan`/`N. Sembilan`/`Negri Sembilan`. `W.P. Kuala Lumpur`/`WP KL`/`Kuala Lumpur`/`WILAYAH PERSEKUTUAN KUALA LUMPUR`. Numeric `10`, `MY-10`, Faker-style `SGR` |
| GE02 | District | Health vs administrative names, renamed districts | `Kulaijaya` → `Kulai`. `Jajahan Kota Bharu` → `Kota Bharu`. A new Sarawak district (`Sebuyau`) with no polygon. (Real, from D4/D7) |
| GE03 | Postcode | Leading zero lost, or wrong state | `1000` → `01000` (Kangar). `50450` with state `Johor` |
| GE04 | Address | Free text with embedded commas or newlines that break naive CSV parsing | `NO 12, JALAN 3/4,\nTAMAN SRI MUDA` |
| DT01 | Dates | Mixed formats in one column | `03/04/2024`, `2024-04-03`, `3-Apr-24`, `03.04.2024`, `20240403` |
| DT02 | Dates | DD/MM vs MM/DD ambiguity | `04/03/2024` from a US-locale export |
| DT03 | Dates | Excel serial numbers | `45385` → `2024-04-03` |
| DT04 | Dates | Two-digit years | `03/04/24`. Birth `01/01/30` meaning 1930, not 2030 |
| DT05 | Dates | Placeholder or sentinel dates | `1900-01-01`, `01/01/1970`, `9999-12-31` |
| DT06 | Dates | Logical errors | discharge before admission, admission before DOB, admission after today, LOS of 400 days |
| DT07 | Time | Time formats | `2359`, `23:59`, `11:59 PM`, `23.59` |
| DX01 | ICD-10 | Formatting | `E11.9`, `E119`, `e11.9`, `E11.9 `, `E11.90` |
| DX02 | ICD-10 | Wrong code system | ICD-10-CM `E11.65`/`E1165`. Legacy dengue `A90` mixed with `A97.0`. ICD-9 `250.00` |
| DX03 | ICD-10 | Invalid or placeholder codes | `E11.X`, `R69` overuse, `000`, empty |
| DX04 | Diagnosis | Free-text instead of a code, mixed Malay and English | `DM tak terkawal`, `T2DM`, `kencing manis`, `Denggi dgn tanda amaran`, `dengue fever w warning signs`, `DHF`, `AGE` (acute gastroenteritis), `CAP` |
| DX05 | Diagnosis | Principal diagnosis duplicated as secondary, or secondary seq gaps | seq `1, 2, 4` |
| AD01 | Admission | Exact duplicate rows from re-export | same row twice |
| AD02 | Admission | Near-duplicates or corrected versions | same episode, later `updated_at`, different discharge date |
| AD03 | Admission | Inter-hospital transfer split into two episodes that inflates readmissions | discharge 2024-04-03 from Hospital A, admit 2024-04-03 to Hospital B |
| AD04 | Discharge | Mixed outcome text | `Discaj`, `Balik rumah`, `Home`, `AOR`, `Discharge at own risk`, `Mati`, `Meninggal dunia`, `Died`, `Transfer`, `Pindah` |
| AD05 | Facility | Code format variants, name instead of code | `11-01030012` vs `1101030012`. `HOSPITAL ENCHE' BESAR HAJJAH\n KHALSOM` |
| NU01 | Numeric | Out-of-range or sentinel values | age `-1`, `150`. Weight `0`, `999` |
| NU02 | Nulls | Many null spellings | `''`, `NULL`, `N/A`, `NA`, `-`, `TIADA`, `Tidak diketahui`, `Unknown` |
| TX01 | Text | Whitespace, case, non-breaking space, mojibake | `" Selangor"`, `SELANGOR`, `Selangor `, `Nurâ€™ain` for `Nur'ain` |
| SH01 | Shape | Wide-format source tables that need UNPIVOT | D8 dengue (states as columns) |

---

## 6. Suggested first-cut table list

The `ref_*` and `geo_*` tables come from open data (section 1). The core tables are synthetic. All tables are stored as Parquet.

| Table | Grain | Key columns | Source |
|---|---|---|---|
| `ref_state` | state | `code_state` (1–16), `iso_code` (`MY-10`), `name_dosm`, `name_moh` (upper case), `alt_names` (list), `jpn_pb_codes` (list) | D6 + JPN + ISO |
| `ref_district` | district (166) | `code_state_district`, `state`, `district`, `has_polygon`, `health_district_name` | D2 + D7 + D4 (mapping table built in a cleaning exercise) |
| `ref_population` | year × state × district × sex × age band × ethnicity | `population_k` | D1, D2 |
| `ref_facility` | facility | `facility_code` (`KOD_FASILITI`), name, type, state, district, lat, lon, beds | D4 + D5 + D3 |
| `ref_icd10` | ICD-10 code | `icd10`, `title_en`, `title_ms` (hand-written), `chapter`, `scenario_group` (`diabetes`, `dengue`, ...) | WHO ICD-10 2019 subset |
| `ref_dengue_state_year` | year × state × age band | `cases` | D8 (unpivoted) |
| `geo_state`, `geo_district` | polygon | geometry (EPSG:4326) + codes | D6, D7 |
| `patient` | person | `patient_id`, `mykad`, `name`, `dob`, `sex`, `ethnicity`, `state_res`, `district_res`, `postcode` | synthetic |
| `admission` | inpatient episode | `admission_id`, `patient_id`, `facility_code`, `admit_ts`, `discharge_ts`, `admit_type`, `discharge_status`, `principal_dx`, `principal_dx_text`, `ward` | synthetic |
| `diagnosis` | admission × seq | `admission_id`, `seq`, `icd10`, `dx_text` | synthetic |
| `raw_admission_extract` | messy flat export (CSV, small size only) | all of the above as VARCHAR with the section 5 defects | derived from the clean truth |
| `dq_answer_key` | injected defect | `table`, `row_id`, `column`, `defect_code`, `clean_value` | derived (instructor only) |

Size targets: small has ~40k patients, 100k admissions and ~200k diagnoses, plus the raw CSV extract. Large has ~12–20M patients, 30–50M admissions and ~60–100M diagnoses, as clean Parquet with the messy columns kept. The measured 30M run supports this (section 2).

## 7. Licence and availability risks

1. **WHO ICD-10 has no explicit open licence.** Keep the code list small and attributed, and confirm with WHO or KKM if the dataset will be redistributed beyond the workshop.
2. **CMS ICD-10-CM terms are not stated** on cms.gov or cdc.gov. They are probably public domain but this is unverified.
3. **`MoH-Malaysia/data-resources-public` (D4, D5) has no LICENSE file.** The README only asks for attribution under government open-data policy. Attribute MoH, and keep a frozen copy because it is a live repo.
4. **Boundaries (D6, D7) are from 2022 and have 160 districts**, while population data from 2025 onward has 166. Either use 2024 population for maps or treat the gap as an exercise.
5. **No current open dengue time series.** The new data.gov.my catalogue has none, and the archive tables stop at 2021 (D8, D9). archive.data.gov.my may be retired at any time, so freeze copies now.
6. **DuckDB `hash()` stability across versions is unverified.** Ship the generated Parquet and pin the generator's DuckDB version.
7. **Generation and size figures** come from an Apple M3, not the Windows target laptops. The full-schema size and time are estimates.
