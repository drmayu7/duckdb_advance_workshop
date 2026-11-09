#!/usr/bin/env bash
# The probe bodies are shell code for the probe scripts, so they stay unexpanded.
# shellcheck disable=SC2016

# The shell tests' shared ok/bad (tests/lib/check.sh) count a failure wherever
# it is raised: inside $(...), a pipeline or a subshell, where a fail=1
# variable would be lost (#31's retro: capstone_defects.sh once called bad
# inside $(run ...), and a failed pipeline went uncounted). And every
# tests/*.sh uses them rather than its own copy, so the hole stays closed.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
res=0
say_ok()  { echo "ok: $*"; }
say_bad() { echo "FAIL: $*"; res=1; }

# probe <name> <body>: a test script that sources the helpers and runs body.
probe() {
  printf '%s\n' '#!/usr/bin/env bash' 'set -u' \
    ". \"$root/tests/lib/check.sh\"" "$2" 'finish' >"$tmp/$1.sh"
  out="$(bash "$tmp/$1.sh" 2>&1)"; rc=$?
}

probe clean 'ok "one"; ok "two"'
if [ "$rc" = 0 ]; then say_ok "a test with no failure exits 0"
else say_bad "a clean test exited $rc: $out"; fi

for where in 'x="$(bad "in a command substitution")"' \
             'echo hi | while read -r _; do bad "in a pipeline"; done' \
             '( bad "in a subshell" )' \
             'bad "at top level"'; do
  probe raised "$where"
  if [ "$rc" = 1 ]; then say_ok "a failure counts: $where"
  else say_bad "a failure did not count (exit $rc): $where"; fi
  if grep -q '^FAIL: ' <<<"$out"; then say_ok "and its message is shown: $where"
  else say_bad "its message was swallowed: $where (output: $out)"; fi
done

probe later 'x="$(bad "first")"; if failed; then ok "failed sees it"; fi'
if grep -q '^ok: failed sees it' <<<"$out"; then say_ok "failed reports a failure raised in \$(...)"
else say_bad "failed missed a failure raised in \$(...): $out"; fi

probe marked 'bad "an earlier section"; mark; if ! failed; then ok "a new section starts clean"; fi'
if grep -q '^ok: a new section starts clean' <<<"$out" && [ "$rc" = 1 ]; then
  say_ok "mark starts a section clean, and finish still fails for the earlier failure"
else say_bad "mark: exit $rc, output: $out"; fi

# Every shell test sources the helpers and keeps no copy of its own.
n=0
for t in "$root"/tests/*.sh; do
  n=$((n + 1)); name="${t#"$root"/}"
  [ "$name" = tests/check_helpers.sh ] && continue
  if grep -qE '^[[:space:]]*(ok|bad)\(\)|(^|[[:space:];{])fail=' "$t"; then
    say_bad "$name defines its own ok/bad or fail=: source tests/lib/check.sh instead"
  fi
  if grep -qE '^bad |[;{&|][[:space:]]*bad |^[[:space:]]+bad ' "$t" && ! grep -q 'lib/check.sh' "$t"; then
    say_bad "$name calls bad without sourcing tests/lib/check.sh"
  fi
done
[ "$n" -gt 10 ] || say_bad "found only $n shell tests"
[ "$res" = 0 ] && say_ok "every shell test uses tests/lib/check.sh"
exit $res
