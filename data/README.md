# Workshop data

> **Synthetic data, not real hospital performance.** Patients and admissions in this workshop are synthetic (generated, not real MyHDW records). They are paired with real MoH facility names, so any rate, count or ranking you compute describes the synthetic data only. Do not read clinical or hospital-performance meaning into it.

## Warm-up extract (`data/warmup/`)

A clean, synthetic 2017 extract for the Warm-up Challenge (`cards/w-warmup.md`). Both files are generated, not downloaded.

| File | What it is |
|---|---|
| `admission_2017.parquet` | Every 2017 admission (about 5,000): `admission_id`, `patient_id`, `facility_code`, `facility_name`, `facility_state`, `admit_date`, `discharge_date`, `principal_dx`, `discharge_status`. The hospital's name and state come from the MoH facility list, already cleaned. |
| `patient_2017.parquet` | One row per patient admitted in 2017: `patient_id`, `mykad`, `name`, `sex`, `dob`, `state`, `district`, `postcode`. `state` and `district` are where the patient lives, as MoH health districts. |

Synthetic ICs follow the MyKad format `YYMMDD-PB-###G`, but the last four digits always start with `9`, so they are recognisably workshop data.

## Raw extract 2018–2020 (`data/raw/`)

The synthetic admission export that Module 1 starts from (`cards/c01-read-csv.md` onwards): one row per admission, with the patient's details repeated on every row, in one file per admit month. The hospitals changed systems twice, so each year comes in its own format. The files carry deliberate data-quality problems, as a real export would; the Challenges find and fix them. All files are generated, not downloaded.

| Files | Source system | Format |
|---|---|---|
| `2018-01.csv` … `2018-12.csv` | Old HIS | CSV with a header row and Malay column names (`no_mrn`, `no_kp`, `nama`, `tarikh_lahir`, `jantina`, `negeri`, `daerah`, `poskod`, `alamat`, `kod_fasiliti`, `tarikh_masuk`, `tarikh_keluar`, `status_discaj`, `dx_utama`, `dx_sekunder`, `dikemaskini`). Dates are `DD/MM/YYYY`. |
| `2019-01.json` … `2019-12.json` | Interim system | Newline-delimited JSON, one object per admission, every value a string or null: `mrn`, `mykad`, `name`, `dob`, `sex`, `state`, `district`, `postcode`, `address`, `facility_code`, `admit_date`, `discharge_date`, `discharge_status`, `principal_dx`, `secondary_dx`, `updated_at`. Dates are `YYYY-MM-DD`. |
| `2020-01.parquet` … `2020-12.parquet` | New system | Parquet with the interim system's columns, except that `dob` is a `DATE` and the admission is timed: `admit_ts` and `discharge_ts` (`TIMESTAMP`) replace `admit_date` and `discharge_date`. Two columns are new: `ward` and `admission_type`. |
| `manifest.csv` | – | `file`, `rows`: how many records each file holds. A careful read of each file gives exactly this many rows. |

`state`, `district`, `postcode` and `address` are where the patient lives. `secondary_dx` lists secondary diagnoses as ICD-10 codes separated by `; `.

## Open data (`data/open/`)

Real Malaysian open data, used as reference tables to join to. Every file reads directly in DuckDB 1.5.6, for example `FROM 'data/open/population_state.parquet'` or `FROM read_json('data/open/facilities.json')`.

These are **frozen copies** downloaded on 2026-11-08. The sources are live or archived and may change or disappear. The facilitator refreshes them only on purpose, with `./build.sh open-data`.

| File | What it is | Publisher and source | Licence |
|---|---|---|---|
| `population_state.parquet` | Population by state × year × sex × age group × ethnicity, 1970–2026. `population` is in **thousands**. Unchanged. | Department of Statistics Malaysia (DOSM), https://storage.dosm.gov.my/population/population_state.parquet (catalogue: https://data.gov.my/data-catalogue/population_state) | CC BY 4.0 |
| `population_district.parquet` | Population by administrative district × year × sex × age group × ethnicity, 2020–2026, in **thousands**. 160 districts to 2024, 166 from 2025. Unchanged. | DOSM, https://storage.dosm.gov.my/population/population_district.parquet (catalogue: https://data.gov.my/data-catalogue/population_district) | CC BY 4.0 |
| `facilities.json` | MoH public health facilities as registered on 31 Dec 2025: 5,160 facilities, 166 of them hospitals (`KATEGORI_FASILITI = 'HOSPITAL'`). Re-serialised from CSV to a JSON array, with every value kept as text except `LATITUD`/`LONGITUD`, and the CSV's row-number column `Index` dropped. Nothing else is cleaned. | Ministry of Health Malaysia (KKM), https://github.com/MoH-Malaysia/data-resources-public (`facilities_master.csv`) | No licence file. The publisher asks users to attribute the Ministry of Health Malaysia, under Government of Malaysia open-data policy |
| `bed_utilisation.csv` | Beds, ICU beds, ventilators and their utilisation for 149 hospitals, by hospital **name** (no facility code). Unchanged. | Ministry of Health Malaysia, https://github.com/MoH-Malaysia/data-resources-public (`bedutil_facility.csv`) | As `facilities.json`: attribute the Ministry of Health Malaysia |
| `geo_state.geojson` | 16 state boundaries (EPSG:4326), with `state` and `code_state` (1–16). Unchanged. | DOSM, https://github.com/dosm-malaysia/data-open (`datasets/geodata/administrative_1_state.geojson`) | DOSM Open Data Licence (https://github.com/dosm-malaysia/data-open/blob/main/LICENSE.md): copy, adapt and use with attribution, no implied endorsement |
| `geo_district.geojson` | 160 administrative district boundaries (EPSG:4326), from 2022. The 6 districts created since have no polygon. Unchanged. | DOSM, https://github.com/dosm-malaysia/data-open (`datasets/geodata/administrative_2_district.geojson`) | DOSM Open Data Licence, as above |
| `dengue_state_age_2018_2021.csv` | Annual dengue cases by state and age group, 2018–2021, wide (one column per state; Putrajaya absent). Malay column names. Unchanged. | MoH Disease Control Division, via the data.gov.my archive, https://archive.data.gov.my/data/dataset/b36d588f-ced4-4c16-ba9a-021e9bf38ae5 ("Bilangan kes penyakit denggi tahunan mengikut negeri dan kumpulan umur") | Creative Commons Attribution (CC BY) |
| `ref_icd10.csv` | 150 ICD-10 codes for the Scenario: `icd10`, `category`, `title_en`, `scenario_group` (`diabetes` = E10–E14, `dengue` = A97.x plus legacy A90/A91, and others), `source`. Titles are WHO's. A90 and A91 were removed from WHO ICD-10 in its 2016 update and are kept as legacy dengue codes, titled from the 2010 edition. | World Health Organization, ICD-10 Version 2019 (and 2010 for A90/A91), https://icd.who.int/browse10/2019/en | © World Health Organization. WHO states no open licence for ICD-10; this is a small curated subset for training, attributed to WHO. Sharing it beyond the workshop may need WHO permission |

### Known real mess (kept on purpose)

The open data is used as found, because cleaning it is part of the Challenges:

- `facilities.json` has 17 spellings of `NEGERI`, including the merged pseudo-state `WILAYAH PERSEKUTUAN KUALA LUMPUR DAN PUTRAJAYA`.
- Some facility names contain newlines, for example `HOSPITAL ENCHE' BESAR HAJJAH\n KHALSOM`.
- Facility `DAERAH` values are health districts, which do not always match DOSM administrative districts (`JAJAHAN KOTA BHARU`, `KULAIJAYA`, `TITIWANGSA`).
- MoH files use upper-case state names (`WILAYAH PERSEKUTUAN KUALA LUMPUR`), and DOSM files use `W.P. Kuala Lumpur`.
- `bed_utilisation.csv` names hospitals without codes: 130 of its 149 names match a facility `NAMA` exactly after upper-casing.
- `dengue_state_age_2018_2021.csv` has inconsistent age labels (`0-4`, `" 5 - 9"`, `>75`) and writes Kuala Lumpur as `WP KUALA LUMPUR`.
