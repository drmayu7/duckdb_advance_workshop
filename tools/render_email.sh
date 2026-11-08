#!/usr/bin/env bash
# Renders the pre-workshop email (#19) to stdout from its template.
#   tools/render_email.sh <template>
# - Drops the template's leading HTML comment (notes for the facilitator).
# - Replaces each `<!-- include <file>#<section> -->` line with the text between
#   `<!-- begin <section> -->` and `<!-- end <section> -->` in <file>, so the
#   setup card and the email share one copy. Numbered steps in an included
#   section continue the numbering of the step just before the include.
# - Fills {{BUNDLE_DATE}} (default: today) and {{DRIVE_LINK}} (default: a
#   placeholder, with a warning).
set -euo pipefail
template="$1"
BUNDLE_DATE="${BUNDLE_DATE:-$(date +%Y%m%d)}"
if [ -z "${DRIVE_LINK:-}" ]; then
  echo "render_email.sh: DRIVE_LINK is not set; the email says <DRIVE LINK>" >&2
  DRIVE_LINK="<DRIVE LINK>"
fi

section() { # section <file> <name>: the lines between the markers, or fail
  local out
  out="$(awk -v s="$2" '
    $0 == "<!-- end " s " -->" { inside = 0; done = 1 }
    inside { print }
    $0 == "<!-- begin " s " -->" { inside = 1 }
    END { if (!done) exit 1 }' "$1")" || {
    echo "render_email.sh: no section '$2' in $1" >&2; exit 1; }
  printf '%s\n' "$out"
}

{
  in_header=1
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$in_header" = 1 ]; then
      case "$line" in
        "<!--"*) in_header=2; continue ;;
      esac
    fi
    if [ "$in_header" = 2 ]; then
      case "$line" in *"-->") in_header=0 ;; esac
      continue
    fi
    in_header=0
    if [[ "$line" =~ ^\<!--\ include\ ([^#]+)#([^ ]+)\ --\>$ ]]; then
      printf '%s\n' "<!-- section ${BASH_REMATCH[2]} -->"
      section "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
      printf '%s\n' "<!-- end-section -->"
    else
      printf '%s\n' "$line"
    fi
  done <"$template"
} | awk -v date="$BUNDLE_DATE" -v link="$DRIVE_LINK" '
  BEGIN { gsub(/&/, "\\\\&", link) } # a literal & in the replacement
  # Renumber steps inside an included section, carrying on from the last step.
  /^<!-- section .* -->$/ { inc = 1; n = last; next }
  /^<!-- end-section -->$/ { inc = 0; last = n; next }
  match($0, /^[0-9]+\. /) {
    if (inc) { n++; $0 = n ". " substr($0, RLENGTH + 1) }
    else { last = substr($0, 1, RLENGTH - 2) + 0 }
  }
  { gsub(/\{\{BUNDLE_DATE\}\}/, date); gsub(/\{\{DRIVE_LINK\}\}/, link); print }'
