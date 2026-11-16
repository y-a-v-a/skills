"""PNG helper with the Python stdlib only (run with python3 -I). Works on any OS.

  pngtool.py info  <png>...                       size, colour type, bytes, whether alpha is in use
  pngtool.py probe <png> x,y [x,y,w,h] ...        RGBA at a pixel, or the mean over a w×h box
  pngtool.py crop  <in.png> x,y,w,h <out.png> [zoom]   cut out a region, optionally enlarged (nearest neighbour)
  pngtool.py half  <in.png> <out.png>             2×2 box downscale: what most viewers see of a 1280×640 card
  pngtool.py opt   <in.png> <out.png>             lossless squeeze: drop constant alpha, adaptive row filters, zlib 9

Probe before trusting your eyes: a large downscaled preview can misrepresent dark tones, a probe can't.
info/probe/crop/half read 8- and 16-bit grey, RGB, palette and alpha PNGs (not interlaced) and write 8-bit.
`opt` takes 8-bit RGB/RGBA only, typically saves 2-7 % on Chrome screenshots and takes ~10 s at 1280×640;
re-encoding with sips/ImageIO comes out bigger.
"""
import struct
import sys
import zlib

SIG = b'\x89PNG\r\n\x1a\n'
CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}


def chunks(d):
    i = 8
    while i < len(d):
        n, = struct.unpack('>I', d[i:i + 4])
        yield d[i + 4:i + 8], d[i + 8:i + 8 + n]
        i += 12 + n


def unfilter(raw, h, stride, fbpp):
    rows, prev, o = [], bytearray(stride), 0
    for _ in range(h):
        f = raw[o]
        line = bytearray(raw[o + 1:o + 1 + stride])
        o += 1 + stride
        if f == 1:
            for x in range(fbpp, stride):
                line[x] = (line[x] + line[x - fbpp]) & 255
        elif f == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride):
                line[x] = (line[x] + ((line[x - fbpp] if x >= fbpp else 0) + prev[x]) // 2) & 255
        elif f == 4:
            for x in range(stride):
                a = line[x - fbpp] if x >= fbpp else 0
                b = prev[x]
                c = prev[x - fbpp] if x >= fbpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        rows.append(line)
        prev = line
    return rows


def decode(path):
    """Returns (w, h, ctype, depth, raw rows) with filters undone, plus palette and tRNS for conversion."""
    d = open(path, 'rb').read()
    if d[:8] != SIG:
        sys.exit(f'{path}: not a PNG')
    ihdr, idat, plte, trns = None, [], None, None
    for t, body in chunks(d):
        if t == b'IHDR':
            ihdr = struct.unpack('>IIBBBBB', body)
        elif t == b'IDAT':
            idat.append(body)
        elif t == b'PLTE':
            plte = body
        elif t == b'tRNS':
            trns = body
    w, h, depth, ctype, _, _, interlace = ihdr
    if interlace:
        sys.exit(f'{path}: interlaced PNGs are not supported')
    bits = CHANNELS[ctype] * depth
    stride = (w * bits + 7) // 8
    rows = unfilter(zlib.decompress(b''.join(idat)), h, stride, max(1, bits // 8))
    return w, h, ctype, depth, rows, plte, trns


def to_rgba(w, ctype, depth, rows, plte, trns):
    out = []
    for r in rows:
        if depth == 16:
            r = r[0::2]
        elif depth < 8:
            per = 8 // depth
            mask = (1 << depth) - 1
            r = bytearray((r[i // per] >> (8 - depth * (i % per + 1))) & mask for i in range(w))
            if ctype == 0:
                r = bytearray(v * 255 // mask for v in r)
        px = bytearray(w * 4)
        if ctype == 6:
            px[:] = r[:w * 4]
        elif ctype == 2:
            px[0::4], px[1::4], px[2::4] = r[0::3], r[1::3], r[2::3]
            px[3::4] = b'\xff' * w
        elif ctype == 4:
            px[0::4] = px[1::4] = px[2::4] = r[0::2]
            px[3::4] = r[1::2]
        elif ctype == 0:
            px[0::4] = px[1::4] = px[2::4] = r[:w]
            px[3::4] = b'\xff' * w
        else:
            for x in range(w):
                i = r[x]
                px[x * 4:x * 4 + 3] = plte[i * 3:i * 3 + 3]
                px[x * 4 + 3] = trns[i] if trns and i < len(trns) else 255
        out.append(px)
    return out


def read_rgba(path):
    w, h, ctype, depth, rows, plte, trns = decode(path)
    return w, h, to_rgba(w, ctype, depth, rows, plte, trns)


def chunk(t, body):
    return struct.pack('>I', len(body)) + t + body + struct.pack('>I', zlib.crc32(t + body) & 0xffffffff)


def write_png(path, w, h, bpp, idat):
    png = SIG + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2 if bpp == 3 else 6, 0, 0, 0)) \
        + chunk(b'sRGB', b'\x00') + chunk(b'IDAT', idat) + chunk(b'IEND', b'')
    open(path, 'wb').write(png)
    return len(png)


def write_rgba(path, w, h, rows):
    """Quick writer for previews: RGB when fully opaque, no row filters."""
    opaque = all(all(v == 255 for v in r[3::4]) for r in rows)
    data = bytearray()
    for r in rows:
        data.append(0)
        if opaque:
            rgb = bytearray(w * 3)
            rgb[0::3], rgb[1::3], rgb[2::3] = r[0::4], r[1::4], r[2::4]
            data += rgb
        else:
            data += r
    return write_png(path, w, h, 3 if opaque else 4, zlib.compress(bytes(data), 6))


def filter_rows(rows, bpp, mode):
    out, prev = bytearray(), bytearray(len(rows[0]))
    for line in rows:
        n = len(line)
        cands = {}
        if mode in ('adaptive', 0):
            cands[0] = bytes(line)
        if mode in ('adaptive', 1):
            cands[1] = bytes(line[:bpp]) + bytes((line[x] - line[x - bpp]) & 255 for x in range(bpp, n))
        if mode in ('adaptive', 2):
            cands[2] = bytes((line[x] - prev[x]) & 255 for x in range(n))
        if mode in ('adaptive', 3):
            cands[3] = bytes((line[x] - (((line[x - bpp] if x >= bpp else 0) + prev[x]) >> 1)) & 255 for x in range(n))
        if mode in ('adaptive', 4):
            r = bytearray(n)
            for x in range(n):
                a = line[x - bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x - bpp] if x >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                r[x] = (line[x] - (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
            cands[4] = bytes(r)
        best = min(cands, key=lambda k: sum(v if v < 128 else 256 - v for v in cands[k]))
        out.append(best)
        out += cands[best]
        prev = line
    return bytes(out)


def cmd_info(paths):
    for path in paths:
        w, h, ctype, depth, rows, plte, trns = decode(path)
        rgba = to_rgba(w, ctype, depth, rows, plte, trns)
        transparent = not all(all(v == 255 for v in r[3::4]) for r in rgba)
        kind = {0: 'grey', 2: 'RGB', 3: 'palette', 4: 'grey+alpha', 6: 'RGBA'}[ctype]
        size = len(open(path, 'rb').read())
        print(f'{path}: {w}x{h}, {kind} {depth}-bit, {"TRANSPARENT pixels" if transparent else "opaque"}, {size} bytes')


def cmd_probe(path, specs):
    w, h, rows = read_rgba(path)
    for s in specs:
        v = [int(t) for t in s.split(',')]
        x, y = v[0], v[1]
        bw, bh = (v[2], v[3]) if len(v) == 4 else (1, 1)
        acc, n = [0] * 4, 0
        for yy in range(max(0, y), min(h, y + bh)):
            r = rows[yy]
            for xx in range(max(0, x), min(w, x + bw)):
                for c in range(4):
                    acc[c] += r[xx * 4 + c]
                n += 1
        if n == 0:
            print(f'{s}: outside {w}x{h}')
            continue
        print(f'{s}: ' + ' '.join(str(round(a / n)) for a in acc))


def cmd_crop(src, spec, dst, zoom=1):
    w, h, rows = read_rgba(src)
    x, y, cw, ch = [int(t) for t in spec.split(',')]
    x0, y0 = max(0, x), max(0, y)
    cw, ch = min(x + cw, w) - x0, min(y + ch, h) - y0
    x, y = x0, y0
    if cw <= 0 or ch <= 0:
        sys.exit(f'{spec}: outside {w}x{h}')
    out = []
    for r in rows[y:y + ch]:
        seg = r[x * 4:(x + cw) * 4]
        if zoom > 1:
            seg = bytearray(b''.join(bytes(seg[i * 4:i * 4 + 4]) * zoom for i in range(cw)))
        out.extend([seg] * zoom)
    write_rgba(dst, cw * zoom, ch * zoom, out)
    print(f'{dst}: {cw * zoom}x{ch * zoom}')


def cmd_half(src, dst):
    w, h, rows = read_rgba(src)
    hw, hh = w // 2, h // 2
    out = []
    for y in range(hh):
        a, b = rows[2 * y], rows[2 * y + 1]
        line = bytearray(hw * 4)
        for x in range(hw):
            i = x * 8
            for c in range(4):
                line[x * 4 + c] = (a[i + c] + a[i + 4 + c] + b[i + c] + b[i + 4 + c] + 2) >> 2
        out.append(line)
    write_rgba(dst, hw, hh, out)
    print(f'{dst}: {hw}x{hh}')


def cmd_opt(src, dst):
    w, h, ctype, depth, rows, _, _ = decode(src)
    if depth != 8 or ctype not in (2, 6):
        sys.exit(f'{src}: opt takes 8-bit RGB/RGBA only (this is type {ctype}, {depth}-bit); leave it as it is')
    bpp = CHANNELS[ctype]
    if bpp == 4 and all(all(v == 255 for v in r[3::4]) for r in rows):
        rows = [bytearray(b for i, b in enumerate(r) if i % 4 != 3) for r in rows]
        bpp = 3
    best = None
    for mode in ('adaptive', 4, 1):
        data = filter_rows(rows, bpp, mode)
        for strat in (zlib.Z_DEFAULT_STRATEGY, zlib.Z_FILTERED):
            c = zlib.compressobj(9, zlib.DEFLATED, 15, 9, strat)
            z = c.compress(data) + c.flush()
            if best is None or len(z) < len(best):
                best = z
    before = len(open(src, 'rb').read())
    after = write_png(dst, w, h, bpp, best)
    print(f'{src}: {before} -> {after} bytes')


if __name__ == '__main__':
    a = sys.argv[1:]
    if len(a) >= 2 and a[0] == 'info':
        cmd_info(a[1:])
    elif len(a) >= 3 and a[0] == 'probe':
        cmd_probe(a[1], a[2:])
    elif len(a) in (4, 5) and a[0] == 'crop':
        cmd_crop(a[1], a[2], a[3], int(a[4]) if len(a) == 5 else 1)
    elif len(a) == 3 and a[0] == 'half':
        cmd_half(a[1], a[2])
    elif len(a) == 3 and a[0] == 'opt':
        cmd_opt(a[1], a[2])
    else:
        sys.exit(__doc__)
