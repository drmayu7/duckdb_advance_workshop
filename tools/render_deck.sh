#!/usr/bin/env bash
# render_deck.sh <deck.pptx> <out-dir> [slides]: the visual QA for a deck (ADR 0004).
# Renders the deck with LibreOffice to <out-dir>/<deck>.pdf, then one image per
# slide (s-NN.jpg) and contact sheets of nine slides each (sheet-N.png), and
# prints the sheets' paths. Look at every sheet; open a single slide image to
# check a detail. After a fix, pass the slides you changed (e.g. 4,14,22) to get
# one sheet of just those, sheet-picked.png. Needs LibreOffice, poppler (pdftoppm) and uv.
set -euo pipefail

[ "$#" -eq 2 ] || [ "$#" -eq 3 ] || { echo "usage: tools/render_deck.sh <deck.pptx> <out-dir> [slide,slide,...]" >&2; exit 2; }
pptx="$1"; out="$2"; picked="${3:-}"
[[ "$picked" =~ ^([0-9]+(,[0-9]+)*)?$ ]] || { echo "render_deck.sh: slides are numbers with commas, like 4,14,22" >&2; exit 2; }
[ -f "$pptx" ] || { echo "render_deck.sh: no such deck: $pptx" >&2; exit 1; }

soffice="$(command -v soffice || true)"
[ -n "$soffice" ] || soffice=/Applications/LibreOffice.app/Contents/MacOS/soffice
[ -x "$soffice" ] || { echo "render_deck.sh: LibreOffice not found (macOS: brew install --cask libreoffice)" >&2; exit 1; }
command -v pdftoppm >/dev/null || { echo "render_deck.sh: pdftoppm not found (brew install poppler)" >&2; exit 1; }
command -v uv >/dev/null || { echo "render_deck.sh: uv not found (brew install uv)" >&2; exit 1; }

name="$(basename "$pptx" .pptx)"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
rm -f "$out"/s-*.jpg "$out"/sheet-*.png "$out/$name.pdf"

# A private LibreOffice profile, so an open LibreOffice window can't block the conversion.
profile="$(mktemp -d)"
trap 'rm -rf "$profile"' EXIT
"$soffice" "-env:UserInstallation=file://$profile" --headless --convert-to pdf --outdir "$out" "$pptx" >/dev/null 2>&1
[ -f "$out/$name.pdf" ] || { echo "render_deck.sh: LibreOffice did not convert $pptx" >&2; exit 1; }
pdftoppm -jpeg -r 60 "$out/$name.pdf" "$out/s"

uv run -q --no-project --with pillow python - "$out" "$picked" <<'EOF'
import glob, os, re, sys
from PIL import Image, ImageDraw
out, picked = sys.argv[1], sys.argv[2]
files = sorted(glob.glob(os.path.join(out, "s-*.jpg")))
number = lambda f: int(re.search(r"s-0*(\d+)\.jpg$", f).group(1))
if picked:
    want = [int(n) for n in picked.split(",")]
    missing = [n for n in want if n not in map(number, files)]
    if missing:
        sys.exit("render_deck.sh: no slide %s in this deck" % ", ".join(map(str, missing)))
    files = [f for f in files if number(f) in want]
for k in range(0, len(files), 9):
    ims = [Image.open(f) for f in files[k:k + 9]]
    w, h = ims[0].size
    sheet = Image.new("RGB", (3 * w + 20, 3 * h + 20), "white")
    for i, im in enumerate(ims):
        x, y = (i % 3) * (w + 10), (i // 3) * (h + 10)
        sheet.paste(im, (x, y))
        ImageDraw.Draw(sheet).text((x + 5, y + 5), "slide %d" % number(files[k + i]), fill="red")
    path = os.path.join(out, "sheet-%s.png" % ("picked" if picked and len(files) <= 9 else k // 9 + 1))
    sheet.save(path)
    print(path)
EOF
echo "render_deck.sh: $(find "$out" -name 's-*.jpg' | wc -l | tr -d ' ') slides from $pptx"
