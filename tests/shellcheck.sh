#!/usr/bin/env bash
# Every shell script in the repo passes shellcheck. A missing shellcheck fails
# the test rather than skipping it (install: brew install shellcheck).
set -u
cd "$(dirname "$0")/.." || exit 1
command -v shellcheck >/dev/null || { echo "FAIL: shellcheck is not installed"; exit 1; }
git ls-files -co --exclude-standard -z -- '*.sh' '*.command' '.githooks/*' | xargs -0 shellcheck -x
