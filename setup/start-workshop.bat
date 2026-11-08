@echo off
rem Double-click to check this laptop, then open the DuckDB UI on my_work.duckdb.
rem
rem It checks offline first and prints one line: SETUP OK, or SETUP FAILED with the
rem codes to look up on the Fix sheet. Problems go to setup.log in this folder.
rem Check only, without opening the UI:  set WORKSHOP_CHECK_ONLY=1 then start-workshop.bat
setlocal EnableExtensions DisableDelayedExpansion

rem Every path on the cards is relative to this folder.
cd /d "%~dp0" || exit /b 1
rem The banner is UTF-8.
chcp 65001 >nul
set "DUCKDB=bin\windows_amd64\duckdb.exe"

rem F1: OneDrive syncing can corrupt my_work.duckdb. (Substitution ignores case.)
set "WORKSHOP_F1=0"
if not "%CD:OneDrive=%"=="%CD%" set "WORKSHOP_F1=1"

rem setup.log goes next to the bundle, or to the temp folder if this one is read-only.
set "LOG=setup.log"
(type nul >"%LOG%") 2>nul || set "LOG=%TEMP%\duckdb-setup.log"
set "BANNER=%TEMP%\duckdb-setup-banner.txt"

rem Content releases dropped unopened into updates\ are applied in name order, over
rem this folder (overwrite, never delete), then moved to updates\applied\ so they are
rem never applied again over newer files. One that fails stays in updates\ and is U1.
set "WORKSHOP_U1=0"
for /f "delims=" %%Z in ('dir /b /a-d /on "updates\*.zip" 2^>nul') do call :apply "%%Z"

"%DUCKDB%" :memory: -f install.sql >>"%LOG%" 2>&1
"%DUCKDB%" :memory: -f smoke_test.sql >"%BANNER%" 2>>"%LOG%"
findstr /b /c:"SETUP " "%BANNER%" >nul 2>&1 || >"%BANNER%" echo SETUP FAILED: the setup check could not run, see setup.log

echo.
type "%BANNER%"
echo.

set "OK=0"
findstr /b /c:"SETUP OK" "%BANNER%" >nul 2>&1 && set "OK=1"

if "%WORKSHOP_CHECK_ONLY%"=="1" (
  if "%OK%"=="1" exit /b 0
  exit /b 1
)

if "%OK%"=="0" (
  echo Press any key to open the DuckDB UI anyway...
  pause >nul
)

"%DUCKDB%" -ui my_work.duckdb
if errorlevel 1 pause
exit /b

rem apply <zip name>: extract one Content release over the bundle (Windows tar reads zip).
:apply
>>"%LOG%" echo Applying updates\%~1
tar -xf "updates\%~1" >>"%LOG%" 2>&1 || goto apply_failed
if not exist "updates\applied" mkdir "updates\applied"
move /y "updates\%~1" "updates\applied\" >>"%LOG%" 2>&1 || goto apply_failed
exit /b 0
:apply_failed
>>"%LOG%" echo U1: could not apply updates\%~1
set "WORKSHOP_U1=1"
exit /b 0
