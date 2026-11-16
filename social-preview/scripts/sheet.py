# Contact sheet: lays images out in a captioned grid as an HTML page, then prints the shot.sh line to render it.
#
#   python3 -I sheet.py <out.html> [--cols 2] [--width 640] IMAGE "caption" [IMAGE "caption" ...]
#
# Use it for the final overview (current image first, then each variant) and for picking among generated
# options (seeds, timings, palettes) at a glance. In a caption like "2 · Silk · citrus wallpaper" the part after
# the last " · " is set in a muted colour.
import html
import os
import sys

args = sys.argv[1:]
if not args:
    sys.exit('usage: sheet.py <out.html> [--cols N] [--width PX] IMAGE CAPTION [IMAGE CAPTION ...]')
out, rest = args[0], args[1:]
cols, width = 2, 640
while rest and rest[0].startswith('--'):
    if len(rest) < 2 or not rest[1].isdigit():
        sys.exit(f'{rest[0]} needs a number')
    flag, val, rest = rest[0], int(rest[1]), rest[2:]
    if flag == '--cols':
        cols = val
    elif flag == '--width':
        width = val
    else:
        sys.exit(f'unknown flag {flag}')
if not rest or len(rest) % 2:
    sys.exit('give IMAGE CAPTION pairs')
items = list(zip(rest[0::2], rest[1::2]))

height = width // 2
pad, gap_x, gap_y, cap = 28, 24, 28, 40
rows = (len(items) + cols - 1) // cols
page_w = pad * 2 + cols * width + (cols - 1) * gap_x
page_h = pad * 2 + rows * (height + cap) + (rows - 1) * gap_y

figs = []
for path, caption in items:
    src = 'file://' + os.path.abspath(path)
    head, _, tail = caption.rpartition(' · ')
    text = html.escape(head) + f' <span>· {html.escape(tail)}</span>' if head else html.escape(tail)
    figs.append(f'<figure><img src="{html.escape(src)}"><figcaption>{text}</figcaption></figure>')

page = f'''<!doctype html><html><head><meta charset="utf-8"><style>
html,body{{margin:0;background:#1b1b1d;font:600 22px -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif;color:#e8e8ea}}
.g{{display:grid;grid-template-columns:repeat({cols},{width}px);gap:{gap_y}px {gap_x}px;padding:{pad}px}}
figure{{margin:0}}
img{{width:{width}px;height:{height}px;object-fit:contain;background:#000;display:block;border-radius:10px;box-shadow:0 0 0 1px rgba(255,255,255,.08)}}
figcaption{{height:{cap}px;padding-top:10px;box-sizing:border-box;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}}
figcaption span{{color:#9a9aa0;font-weight:500}}
</style></head><body><div class="g">
{chr(10).join(figs)}
</div></body></html>
'''
os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
open(out, 'w').write(page)
here = os.path.dirname(os.path.abspath(__file__))
print(f'{here}/shot.sh {out} {os.path.splitext(out)[0]}.png {page_w} {page_h}')
