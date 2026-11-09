#!/usr/bin/env bash
# ok/bad for tests/*.sh. Source it near the top, end the test with `finish`:
#
#   . "$(dirname "$0")/lib/check.sh"
#   if ...; then ok "what holds"; else bad "what broke"; fi
#   finish
#
# bad records the failure in a file, not a variable, so it counts wherever it
# is raised: inside $(...), a pipeline or a subshell. Its message goes to
# stderr, so a $(...) that captures stdout still shows it. finish exits 1 if
# anything failed, else 0; use it in place of every exit after sourcing.
#
# A summary line for one section: `mark` at its start, then at its end
#   failed || ok "every card has a banner"
# so a failure in an earlier section doesn't hide this one's ok.
CHECK_FAILURES="$(mktemp)"
ok()     { echo "ok: $*"; }
bad()    { echo "FAIL: $*" >&2; echo "$*" >>"$CHECK_FAILURES"; }
# failed: any failure since the last mark (or since the start).
mark()   { CHECK_MARK="$(wc -l <"$CHECK_FAILURES")"; }
failed() { [ "$(wc -l <"$CHECK_FAILURES")" -gt "${CHECK_MARK:-0}" ]; }
finish() {
  local rc=0
  [ -s "$CHECK_FAILURES" ] && rc=1
  rm -f "$CHECK_FAILURES"
  exit "$rc"
}
