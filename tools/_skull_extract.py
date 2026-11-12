"""从按钮贴图提取骷髅轮廓，生成 C5 镂空版 death.svg。

用法:
  python tools/_skull_extract.py            # 打印连通域信息
  python tools/_skull_extract.py --write    # 生成 SVG
"""

import struct
import sys
import zlib

SRC = r"d:\Windows\GreenSweet\Game\Tasks\Mario Forever\Mario Forever Party：King Designer\mario-forever-party--king-designer\sprite\on_screen_controls\button_restart.png"
OUT = r"d:\Windows\GreenSweet\Game\Tasks\Mario Forever\Mario Forever Party：King Designer\mario-forever-party--king-designer\sprite\ui\adventure\set_c5_cutout\death.svg"

PLATE = "M20 6h24a14 14 0 0 1 14 14v24a14 14 0 0 1-14 14H20a14 14 0 0 1-14-14V20A14 14 0 0 1 20 6Z"

ALPHA_THRESHOLD = 128
RDP_EPS = 0.9
TARGET_MIN = 10.0
TARGET_MAX = 54.0


def load_png(path):
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit("not a png")
    pos = 8
    width = height = 0
    color_type = 6
    bit_depth = 8
    idat = b""
    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        ctype = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        if ctype == b"IHDR":
            width, height, bit_depth, color_type = struct.unpack(">IIBB", chunk[:10])
        elif ctype == b"IDAT":
            idat += chunk
        elif ctype == b"IEND":
            break
        pos += 12 + length
    raw = zlib.decompress(idat)
    channels = 4 if color_type == 6 else 3
    stride = width * channels
    out = bytearray()
    prev = bytearray(stride)
    p = 0
    for _ in range(height):
        filt = raw[p]
        p += 1
        line = bytearray(raw[p : p + stride])
        p += stride
        if filt == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 255
        elif filt == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif filt == 3:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif filt == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                pa = abs(b - c)
                pb = abs(a - c)
                pc = abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out += line
        prev = line
    return width, height, channels, bytes(out)


def build_mask(width, height, channels, pixels):
    mask = [False] * (width * height)
    for y in range(height):
        for x in range(width):
            alpha = pixels[(y * width + x) * channels + (channels - 1)]
            mask[y * width + x] = alpha >= ALPHA_THRESHOLD
    return mask


def components(mask, width, height):
    labels = [-1] * (width * height)
    comps = []
    for start in range(width * height):
        if not mask[start] or labels[start] >= 0:
            continue
        stack = [start]
        labels[start] = len(comps)
        pixels = []
        while stack:
            p = stack.pop()
            pixels.append(p)
            x = p % width
            y = p // width
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    nx = x + dx
                    ny = y + dy
                    if 0 <= nx < width and 0 <= ny < height:
                        q = ny * width + nx
                        if mask[q] and labels[q] < 0:
                            labels[q] = len(comps)
                            stack.append(q)
        comps.append(pixels)
    return comps


def boundary_edges(mask, width, height):
    edges = {}
    for y in range(height):
        for x in range(width):
            if not mask[y * width + x]:
                continue
            if y == 0 or not mask[(y - 1) * width + x]:
                edges.setdefault((x, y), []).append((x + 1, y))
            if x == width - 1 or not mask[y * width + x + 1]:
                edges.setdefault((x + 1, y), []).append((x + 1, y + 1))
            if y == height - 1 or not mask[(y + 1) * width + x]:
                edges.setdefault((x + 1, y + 1), []).append((x, y + 1))
            if x == 0 or not mask[y * width + x - 1]:
                edges.setdefault((x, y + 1), []).append((x, y))
    return edges


def trace_rings(edges):
    remaining = set()
    for a, targets in edges.items():
        for b in targets:
            remaining.add((a, b))
    rings = []
    while remaining:
        a, b = next(iter(remaining))
        ring = [a]
        remaining.discard((a, b))
        current = b
        guard = 0
        while current != a and guard < 100000:
            guard += 1
            ring.append(current)
            nxt = None
            for candidate in edges.get(current, []):
                if (current, candidate) in remaining:
                    nxt = candidate
                    break
            if nxt is None:
                break
            remaining.discard((current, nxt))
            current = nxt
        if len(ring) >= 3:
            rings.append(ring)
    return rings


def dist2(a, b):
    dx = a[0] - b[0]
    dy = a[1] - b[1]
    return dx * dx + dy * dy


def rdp_open(points, eps):
    if len(points) < 3:
        return list(points)
    first = points[0]
    last = points[-1]
    index = -1
    best = -1.0
    for i in range(1, len(points) - 1):
        p = points[i]
        dx = last[0] - first[0]
        dy = last[1] - first[1]
        length = (dx * dx + dy * dy) ** 0.5
        if length < 1e-9:
            d = dist2(p, first) ** 0.5
        else:
            d = abs(dy * p[0] - dx * p[1] + last[0] * first[1] - last[1] * first[0]) / length
        if d > best:
            best = d
            index = i
    if best <= eps:
        return [first, last]
    left = rdp_open(points[: index + 1], eps)
    right = rdp_open(points[index:], eps)
    return left[:-1] + right


def simplify_closed(ring, eps):
    if len(ring) < 5:
        return ring
    far = max(range(len(ring)), key=lambda i: dist2(ring[i], ring[0]))
    if far < 2 or far > len(ring) - 2:
        return rdp_open(ring + [ring[0]], eps)[:-1]
    seg1 = rdp_open(ring[: far + 1], eps)
    seg2 = rdp_open(ring[far:] + [ring[0]], eps)
    return seg1[:-1] + seg2[:-1]


def ring_area(ring):
    area = 0.0
    for i in range(len(ring)):
        x1, y1 = ring[i]
        x2, y2 = ring[(i + 1) % len(ring)]
        area += x1 * y2 - x2 * y1
    return abs(area) * 0.5


def main():
    width, height, channels, pixels = load_png(SRC)
    mask = build_mask(width, height, channels, pixels)
    comps = components(mask, width, height)
    print(f"image {width}x{height}, comps={len(comps)}")
    infos = []
    for index, pixels_list in enumerate(comps):
        xs = [p % width for p in pixels_list]
        ys = [p // width for p in pixels_list]
        infos.append((index, len(pixels_list), min(xs), min(ys), max(xs), max(ys)))
    for info in infos:
        print(f"  comp {info[0]}: px={info[1]} bbox=({info[2]},{info[3]})-({info[4]},{info[5]})")

    # 骷髅 = 所有不贴图像边缘的连通域（头轮廓线 + 两只眼窝 + 鼻子），外框是贴边的那块
    chosen = []
    target = None
    for info in infos:
        if info[2] > 4 and info[3] > 4 and info[4] < width - 5 and info[5] < height - 5:
            chosen.append(info[0])
            if target is None:
                target = info
            else:
                target = (
                    min(target[0], info[0]),
                    target[1] + info[1],
                    min(target[2], info[2]),
                    min(target[3], info[3]),
                    max(target[4], info[4]),
                    max(target[5], info[5]),
                )
    if target is None:
        raise SystemExit("skull component not found")
    print(f"chosen comps {chosen}: bbox=({target[2]},{target[3]})-({target[4]},{target[5]})")

    only = [False] * (width * height)
    for comp_index in chosen:
        for p in comps[comp_index]:
            only[p] = True

    rings = trace_rings(boundary_edges(only, width, height))
    print(f"rings={len(rings)}")

    min_x, min_y, max_x, max_y = target[2], target[3], target[4] + 1, target[5] + 1
    skull_w = max_x - min_x
    skull_h = max_y - min_y
    span = TARGET_MAX - TARGET_MIN
    scale = min(span / skull_w, span / skull_h)
    offset_x = TARGET_MIN + (span - skull_w * scale) * 0.5 - min_x * scale
    offset_y = TARGET_MIN + (span - skull_h * scale) * 0.5 - min_y * scale
    print(f"skull {skull_w}x{skull_h} scale={scale:.4f} offset=({offset_x:.2f},{offset_y:.2f})")

    parts = [PLATE]
    total_points = 0
    for ring in rings:
        simplified = simplify_closed(ring, RDP_EPS)
        if len(simplified) < 3 or ring_area(simplified) < 1.5:
            continue
        total_points += len(simplified)
        coords = []
        for (px, py) in simplified:
            x = px * scale + offset_x
            y = py * scale + offset_y
            coords.append(f"{x:.2f} {y:.2f}")
        parts.append("M" + " ".join(coords) + "Z")
    print(f"paths={len(parts)} points={total_points}")

    d = "".join(parts)
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64">\n'
        f'  <path fill-rule="evenodd" fill="#F2F4F8" fill-opacity="0.22" d="{d}"/>\n'
        "</svg>\n"
    )
    if "--write" in sys.argv:
        with open(OUT, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(svg)
        print(f"written {OUT} ({len(svg)} bytes)")
    else:
        print("dry run, pass --write to save")


if __name__ == "__main__":
    main()
