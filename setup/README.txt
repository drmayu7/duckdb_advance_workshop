DuckDB Workshop Series 2: Offline bundle (Setup release)
=========================================================

This folder holds everything the workshop needs on your laptop: DuckDB v1.5.6,
its extensions, and Malaysian open data. Nothing needs installing and you need no
admin rights.

Where to keep it
  Windows: %USERPROFILE%\duckdb-bundle
  Mac:     ~/duckdb-bundle
  Never under Desktop, Documents or OneDrive, and don't move it afterwards.

Start
  Windows: double-click start-workshop.bat
           (SmartScreen: More info > Run anyway)
  Mac:     right-click start-workshop.command > Open
           (or first run: xattr -dr com.apple.quarantine ~/duckdb-bundle)

The launcher checks your laptop offline and prints one line:
  SETUP OK (n/n) · Content none
or
  SETUP FAILED (k/n): <code> <reason>; ...      (k of n checks passed)
Look up each code on the Fix sheet in the setup instructions. Details go to
setup.log in this folder. Then the DuckDB UI opens in your browser, on your Work
database my_work.duckdb, which keeps your tables from day to day.

Relaunching? Close the DuckDB UI tab and window first.

What is here
  start-workshop.bat / start-workshop.command   the launchers
  install.sql, smoke_test.sql                   run by the launchers for you
  bin/                                          DuckDB v1.5.6 for Windows x64 and Apple Silicon
  repo/                                         the extensions, installed from here offline
  data/open/                                    real Malaysian open data
  updates/                                      later Content releases go here, unopened

Open data sources (frozen copies, 8 Nov 2026)
  Population by state and district: Department of Statistics Malaysia (DOSM),
    CC BY 4.0.
  State and district boundaries: DOSM, DOSM Open Data Licence, with attribution.
  Health facilities and bed utilisation: Ministry of Health Malaysia (KKM);
    attribute the Ministry of Health Malaysia.
  Dengue cases by state and age group: MoH Disease Control Division, via the
    data.gov.my archive, CC BY.
  ICD-10 titles (ref_icd10.csv): (c) World Health Organization, ICD-10 Version
    2019 (2010 for A90/A91). A small subset for training only.
