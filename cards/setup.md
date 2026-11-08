---
id: setup
title: Setup check and Fix sheet
module: setup
timebox: 20 min
input: data/open/
output: none
---

# Setup check and Fix sheet

> **Synthetic data, not real hospital performance.** The workshop's hospital data is made up. Only `data/open/` is real public data.

The launcher checks your laptop offline, prints one banner line, then opens the DuckDB UI on your Work database, `my_work.duckdb`. A first query in the UI proves the rest. If anything fails, look up each code from the banner in the **Fix sheet** below.

## At home (before 10 Nov, 12.00)

Steps 1–2 are in the pre-workshop email: use the laptop you'll bring, and download `duckdb-bundle-YYYYMMDD.zip` from the MyGovUC Drive link. Then, on Windows:

<!-- begin at-home -->
1. Right-click the zip → **Properties** → tick **Unblock** → **OK**. Then extract it to the folder `duckdb-bundle` in your user folder (`%USERPROFILE%\duckdb-bundle`, for example `C:\Users\<you>\duckdb-bundle`). Never use Desktop, Documents or OneDrive, and don't move the folder afterwards.
2. Double-click `start-workshop.bat` in that folder (if SmartScreen appears: **More info** → **Run anyway**) and note the banner line it prints, `SETUP OK (n/n) · Content none` or `SETUP FAILED (k/n): …`.
3. In the DuckDB UI that opens in your browser, paste this into the first cell and run it. If rows come back, you're done.

   ```sql
   FROM 'data/open/population_state.parquet' LIMIT 5;
   ```
<!-- end at-home -->

<!-- begin mac -->
- **On a Mac (Apple Silicon):** extract the zip to the folder `duckdb-bundle` in your home folder (`~/duckdb-bundle`): double-click the zip in Finder (Safari may have extracted it already), rename the new folder to `duckdb-bundle` and drag it onto your home folder. Never use Desktop or Documents.
- Then right-click `start-workshop.command` → **Open** → **Open**. If macOS still says it can't be opened, run this once in Terminal and double-click again: `xattr -dr com.apple.quarantine ~/duckdb-bundle`
- The banner and the first cell are the same as on Windows.
- **On an Intel Mac**, the bundle won't run. Say so in your reply, and you'll get the online-only steps.
<!-- end mac -->

## Day 1 setup check (9.00–9.20)

0. Drop the latest Content release zip (`duckdb-content-YYYYMMDD-HHMM.zip`, from Drive, or from USB at 8.30), **unopened**, into the `updates` folder inside `duckdb-bundle`.
1. Close any DuckDB UI tab and launcher window, then double-click `start-workshop`. The banner should end `· Content <id>`, the same id as on the facilitator's slide.
2. In the DuckDB UI, paste this into the first cell and run it:

   ```sql
   FROM 'data/warmup/admission_2017.parquet' LIMIT 5;
   ```

3. Rows came back: put the **green** sticky note on your laptop lid. Anything else: find your row in the Fix sheet and try it, then put up the **red** note.
4. At 9.20 the Series 1 refresher starts regardless. If you're still red, pair with a neighbour; the facilitator comes to you during the Warm-up.

On Days 2 and 3, do the same every morning with that day's Content release.

## Fix sheet

**Relaunching? Close the DuckDB UI tab and window first.** Otherwise the check fails with `W2`.

| Banner code or problem | Try first | Next fallback |
|---|---|---|
| `V1`: not DuckDB v1.5.6 | Start with `start-workshop` in the bundle folder, not a `duckdb` you installed yourself | — |
| `E-<ext>` (for example `E-spatial`): an extension did not load | Re-extract the bundle (Unblock first) | Copy the pre-extracted folder from USB |
| `D1`: `data/open` missing or incomplete | Double-click the launcher inside the bundle folder, not a copy of it | Re-extract the whole zip (it was probably a partial extract) |
| `W1`: the bundle folder is not writable | Move the bundle folder to `%USERPROFILE%\duckdb-bundle` (Mac: `~/duckdb-bundle`) | — |
| `W2`: `my_work.duckdb` is open in another DuckDB window | Close the other DuckDB or UI window (and the launcher window), then relaunch | — |
| `F1`: the bundle folder is under OneDrive, Desktop or Documents | Move the folder to `%USERPROFILE%\duckdb-bundle` (Mac: `~/duckdb-bundle`) | — |
| `U1`: an update could not be applied | Copy the Content release zip from USB into `updates` and relaunch | Extract it by hand over the bundle folder: Windows Explorer → Extract All → choose the bundle folder → **Replace all**; Mac: `ditto -x -k <the zip> ~/duckdb-bundle` |
| `C1`: content incomplete (a file is missing or the wrong size) | Copy the Content release zip from USB into `updates` and relaunch | Extract it by hand, as for `U1` |
| **UI won't load** (network or SSL inspection) | Switch from the venue network to your **phone hotspot**. You need it only to open the UI: once the page is up the hotspot can go off, but don't reload the tab or open a new one without it (also each morning) | Government laptop with SSL inspection, **only if its IT allows it**, in PowerShell in the bundle folder: `$env:ui_disable_server_certificate_verification=1; .\bin\windows_amd64\duckdb.exe -ui my_work.duckdb` → the **CLI** (`.\bin\windows_amd64\duckdb.exe my_work.duckdb`, Mac `./bin/osx_arm64/duckdb my_work.duckdb`; the card SQL works the same) → pair with a neighbour |
| **Windows on ARM** | Use the normal launcher: Windows runs the x64 files under emulation | CLI → pair |
| **Mac (Apple Silicon): "can't be opened"** | Right-click `start-workshop.command` → Open, or `xattr -dr com.apple.quarantine ~/duckdb-bundle` | CLI → pair |
| **Intel Mac** | Online only: download `duckdb_cli-osx-universal.zip` over the hotspot and let the extensions install from the internet | Pair |
| **"Windows protected your PC"** (SmartScreen) | **More info** → **Run anyway** | Next row |
| **Bundle zip downloaded from Drive** | Right-click the zip → Properties → **Unblock** *before* extracting (or in PowerShell: `Get-ChildItem -Recurse <folder> \| Unblock-File`) | Copy the pre-extracted folder from USB |
| **`.bat` blocked outright** (Smart App Control or IT policy) | Open PowerShell in the bundle folder and type the launcher's two commands (below) | Pair |
| **No bundle** | Copy the **pre-extracted folder** from one of the 3 USB sticks (no unzip, no Unblock needed) | MyGovUC Drive is for before and after the workshop, not the room |
| **Can't create the folder, or no admin rights** | Nothing needs installing. The bundle runs from any folder you can write to, because the launcher moves to its own folder and every card path is relative | — |

The launcher's two commands, for PowerShell in the bundle folder:

```powershell
.\bin\windows_amd64\duckdb.exe :memory: -f install.sql
```

```powershell
.\bin\windows_amd64\duckdb.exe -ui my_work.duckdb
```
