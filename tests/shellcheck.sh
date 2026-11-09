#!/usr/bin/env bash
# Every shell script in the repo passes shellcheck. A missing shellcheck fails
# the test rather than skipping it (install: brew install shellcheck).
set -u
cd "$(dirname "$0")/.." || exit 1
command -v shellcheck >/dev/null || { echo "FAIL: shellcheck is not installed"; exit 1; }
# The tests run on macOS's bash 3.2, and shellcheck doesn't know the version, so
# bash 4 features fail here instead of at run time: mapfile/readarray, declare -A,
# ${v,,} and ${v^^}. (Also on 3.2: the printf builtin ignores LC_ALL=... printf.)
rc=0
git ls-files -co --exclude-standard -z -- '*.sh' '*.command' '.githooks/*' | xargs -0 shellcheck -x || rc=1
if hits="$(git ls-files -co --exclude-standard -z -- '*.sh' '*.command' '.githooks/*' | xargs -0 grep -n -E '^[^#]*(\b(mapfile|readarray|declare -A|local -A)\b|\$\{[A-Za-z_][A-Za-z0-9_]*(,,|\^\^)\})')"; then
  echo "FAIL: bash 4 features, which macOS's bash 3.2 lacks:"; printf '  %s\n' "$hits"; rc=1
fi
exit "$rc"
