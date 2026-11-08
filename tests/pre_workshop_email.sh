#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2088 # backticks and ~ below are literal text to find
# The pre-workshop email and the setup card, as the facilitator sends them and a
# Participant reads them (#19). The email is rendered by `build.sh email`; its
# steps 3-5 and Mac block come from the setup card, so the text is written once.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root" || exit 1
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
bad() { echo "FAIL: $*"; fail=1; }
ok() { echo "ok: $*"; }

card=cards/setup.md

if ! DIST_DIR="$tmp" BUNDLE_DATE=20261109 DRIVE_LINK=https://drive.example/folder \
     ./build.sh email >"$tmp/build.log" 2>&1; then
  bad "build.sh email failed:"; sed 's/^/  /' "$tmp/build.log"; exit 1
fi
email="$tmp/pre-workshop-email.md"
[ -f "$email" ] || { bad "no $email"; exit 1; }

# ---- Six numbered steps, in order ------------------------------------------
steps="$(grep -oE '^[0-9]+\. ' "$email" | tr -d '. ' | xargs)"
if [ "$steps" = "1 2 3 4 5 6" ]; then ok "email has steps 1-6 in order"
else bad "email step numbers are '$steps', want '1 2 3 4 5 6'"; fi

# ---- Steps 3-5 and the Mac block are the card's text -----------------------
between() { # between <file> <begin regex> <end regex>: lines strictly between
  awk -v b="$2" -v e="$3" 'f && $0 ~ e { exit } f { print } $0 ~ b { f = 1 }' "$1"
}
card_section() { between "$card" "^<!-- begin $1 -->$" "^<!-- end $1 -->$"; }
unnumber() { sed -E 's/^[0-9]+\. //'; }

card_home="$(card_section at-home | unnumber)"
email_home="$(between "$email" '^2\. ' '^6\. ' | unnumber)"
if [ -n "$card_home" ] && [ "$card_home" = "$email_home" ]; then
  ok "email steps 3-5 are the setup card's at-home steps"
else
  bad "email steps 3-5 differ from the card's at-home section:"
  diff <(echo "$card_home") <(echo "$email_home") | sed 's/^/  /'
fi
if [ "$(card_section at-home | grep -cE '^[0-9]+\. ')" = 3 ]; then ok "card has three at-home steps"
else bad "card's at-home section should have exactly three numbered steps"; fi

card_mac="$(card_section mac)"
if [ -n "$card_mac" ] && [[ "$(cat "$email")" == *"$card_mac"* ]]; then ok "email has the card's Mac block"
else bad "email does not contain the card's Mac block"; fi
for s in '~/duckdb-bundle' 'start-workshop.command' 'xattr -dr com.apple.quarantine'; do
  grep -qF -- "$s" <<<"$card_mac" || bad "Mac block lacks '$s'"
done

# ---- What else the email must say (#14, #15, #9) ---------------------------
need() { # need <label> <fixed string>
  if grep -qF -- "$2" "$email"; then ok "email: $1"; else bad "email lacks $1 ('$2')"; fi
}
need "reply: laptop"     'Laptop: Windows x64 / Windows ARM / Mac Apple Silicon / Mac Intel / government-managed'
need "reply: banner"     'Banner: <paste the SETUP line>'
need "reply: first cell" 'First cell: rows / <exact error text, or a screenshot>'
need "reply: Drive"      'MyGovUC Drive link opened: yes / no'
need "reply: experience" 'DuckDB/SQL experience: none / some / use it regularly'
need "deadline"          '10 Nov, 12.00'
need "8.30 instruction"  'arrive at **8.30**'
need "laptop and charger" 'Bring only the laptop and its charger'
need "hotspot line"      'Bring a phone with mobile data that can share a hotspot'
need "updates line"      'Later updates go into the `updates` folder.'
need "bundle file name"  'duckdb-bundle-20261109.zip'
need "Drive link"        'https://drive.example/folder'
if grep -qE '\{\{|<!--' "$email"; then bad "email has an unfilled placeholder or comment"
else ok "email has no placeholders or comments left"; fi

# ---- Fix sheet: a row for every banner code, plus the non-code rows (#11) --
fix="$(awk '/^## Fix sheet/ { f = 1 } f' "$card")"
row() { grep -E "^\| [^|]*$1" <<<"$fix" >/dev/null; } # $1 in a row's first cell
# The decided codes, plus any code the setup check can print; every E-<ext>
# shares one row.
for code in $( { printf '%s\n' V1 D1 W1 W2 F1 C1 U1
                 grep -oE "'(V1|E-[a-z_]+|[A-Z][0-9])'" setup/smoke_test.sql | tr -d "'" \
                   | sed 's/^E-.*/E-<ext>/'; echo 'E-<ext>'; } | sort -u); do
  row "\`$code\`" || bad "Fix sheet has no row for $code"
done
for p in 'UI won.t load' 'Windows on ARM' 'Mac \(Apple Silicon\)' 'Intel Mac' \
    'Windows protected your PC' 'Bundle zip downloaded from Drive' '`.bat` blocked' \
    'No bundle' 'no admin rights'; do
  row "$p" || bad "Fix sheet has no row for: $p"
done
[ "$fail" = 0 ] && ok "Fix sheet has a row for every banner code and every non-code problem"
if grep -qF 'Relaunching? Close the DuckDB UI tab and window first.' <<<"$fix"; then
  ok "Fix sheet has the relaunch line"
else bad "Fix sheet lacks 'Relaunching? Close the DuckDB UI tab and window first.'"; fi

# ---- First cells: at home reads data/open/ and returns rows; Day 1 reads data/warmup/
first_cell() { # first_cell <section text>: the one FROM ... LIMIT line
  grep -E "^ *FROM '[^']+' LIMIT [0-9]+;$" | sed -E 's/^ +//'
}
home_cell="$(card_section at-home | first_cell)"
day1_cell="$(awk '/^## Day 1/ { f = 1 } /^## Fix sheet/ { f = 0 } f' "$card" | first_cell)"
run_cell() { # run_cell <sql>: prints the row count it returns
  "$DUCKDB" -csv -noheader :memory: -c "SELECT count(*) FROM (${1%;});"
}
case "$home_cell" in
  "FROM 'data/open/"*)
    n="$(run_cell "$home_cell" 2>&1)"
    if [ "${n:-0}" -gt 0 ] 2>/dev/null; then ok "at-home first cell returns $n rows: $home_cell"
    else bad "at-home first cell returned no rows: $home_cell ($n)"; fi ;;
  *) bad "at-home first cell should read data/open/, got '$home_cell'" ;;
esac
case "$day1_cell" in
  "FROM 'data/warmup/"*)
    file="$(sed -E "s/^FROM '([^']+)'.*/\1/" <<<"$day1_cell")"
    if [ -e "$file" ]; then
      n="$(run_cell "$day1_cell" 2>&1)"
      if [ "${n:-0}" -gt 0 ] 2>/dev/null; then ok "Day 1 first cell returns $n rows: $day1_cell"
      else bad "Day 1 first cell returned no rows: $day1_cell ($n)"; fi
    else
      ok "Day 1 first cell reads data/warmup/ ($file is not built yet, #21)"
    fi ;;
  *) bad "Day 1 first cell should read data/warmup/, got '$day1_cell'" ;;
esac

# ---- No spoiler: neither names the repo (#15) ------------------------------
if leaks="$(grep -l -i -e 'drmayu7' -e 'duckdb_advance_workshop' -e 'duckdb-advance-workshop' \
    -e 'github\.com' "$card" docs/pre-workshop-email.md "$email")"; then
  bad "repo URL or name found in: $leaks"
else ok "no repo URL or name in the card or the email"; fi

exit $fail
