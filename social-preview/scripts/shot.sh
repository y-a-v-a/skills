#!/bin/sh
# Screenshot a local HTML page with headless Chrome.
#
# usage: shot.sh <page.html | http(s)://url> <out.png> [width height]      (default 1280 640)
#
# Writes <out.png> plus <out>-half.png at 50 % (what most viewers actually see), checks the size, prints
# the byte count and warns above 990,000 bytes (GitHub requires < 1 MB). Runs on macOS and Linux (python3 needed, sips optional).
#
# env:  SHOT_TIMEOUT=90   hard timeout in seconds, so a runaway canvas script can't hang the session
#       SHOT_BUDGET=5000  --virtual-time-budget in ms (webfonts, timers)
#       SHOT_WEBGL=1      enable WebGL/WebGL2 (GPU, or SwiftShader where there is none) instead of --disable-gpu
#       SHOT_SCALE=2      integer device scale factor: a w×h viewport captured at 2× pixels (e.g. a real UI as a 2× layer)
set -eu

[ $# -ge 2 ] || { echo "usage: shot.sh <page.html> <out.png> [width height]" >&2; exit 2; }
html=$1 out=$2 w=${3:-1280} h=${4:-640}
here=$(cd "$(dirname "$0")" && pwd)

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || CHROME=$(command -v google-chrome || command -v chromium || command -v chromium-browser || true)
[ -n "$CHROME" ] || { echo "no Chrome or Chromium found" >&2; exit 1; }
case $html in
  http://*|https://*) url=$html ;;
  *) [ -f "$html" ] || { echo "no such page: $html" >&2; exit 1; }
     url="file://$(cd "$(dirname "$html")" && pwd)/$(basename "$html")" ;;
esac
mkdir -p "$(dirname "$out")"
rm -f "$out"

gpu=--disable-gpu
scale=${SHOT_SCALE:-1}
case $scale in ''|*[!0-9]*|0) echo "SHOT_SCALE must be a whole number (got $scale)" >&2; exit 2 ;; esac
[ "${SHOT_WEBGL:-0}" = 1 ] && gpu=--enable-unsafe-swiftshader

# --allow-file-access-from-files: canvas code that reads local images (getImageData) or fetches files.
perl -e 'alarm shift; exec @ARGV' "${SHOT_TIMEOUT:-90}" "$CHROME" --headless "$gpu" \
  --screenshot="$out" --window-size="$w,$h" --force-device-scale-factor="$scale" --hide-scrollbars \
  --virtual-time-budget="${SHOT_BUDGET:-5000}" --allow-file-access-from-files \
  "$url" 2>/dev/null || true

if [ ! -s "$out" ]; then
  echo "no screenshot: Chrome failed or hit the ${SHOT_TIMEOUT:-90}s timeout (too much JS work?)." >&2
  echo "leftover processes: pgrep -fl 'Chrome.*--headless'" >&2
  exit 1
fi

dims=$(python3 -I -c 'import struct,sys; print("%dx%d" % struct.unpack(">II", open(sys.argv[1],"rb").read(24)[16:24]))' "$out")
bytes=$(wc -c < "$out" | tr -d ' ')
half="${out%.png}-half.png"
pw=$((w * scale)) ph=$((h * scale))
if command -v sips >/dev/null 2>&1; then
  sips -z $((ph / 2)) $((pw / 2)) "$out" --out "$half" >/dev/null
else
  python3 -I "$here/pngtool.py" half "$out" "$half" >/dev/null
fi

echo "$out: $dims, $bytes bytes"
[ "$dims" = "${pw}x${ph}" ] || { echo "WRONG SIZE: expected ${pw}x${ph}" >&2; exit 1; }
if [ "$pw" = 1280 ] && [ "$ph" = 640 ] && [ "$bytes" -ge 990000 ]; then
  echo "above 990,000 bytes (GitHub's limit is 1 MB): run pngtool.py opt, then see craft.md > File size" >&2
fi
