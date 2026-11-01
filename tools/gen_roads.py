#!/usr/bin/env python3
"""สร้างผังถนนแบบโตเกียว (กริดไม่เท่ากัน ซอยตัน T-junction ถนนเหลื่อม) แล้วเขียนทับบล็อก
-- BEGIN GENERATED / -- END GENERATED ใน src/shared/World.luau  (seed คงที่ = ผลลัพธ์เหมือนเดิมทุกครั้ง)
ใช้: python tools/gen_roads.py [--png out.png]
ถนนแนวแกนเท่านั้น (เข้ากับ TerrainBake / BK.road): {x1,z1,x2,z2,กว้าง,ชนิด}  ชนิด A=สายหลัก L=ถนนย่าน B=ซอย Y=โยโกะโจะ T=ทางป่า
"""
import random, re, sys, zlib, struct, os

R = random.Random(20261101)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

roads = []  # (x1,z1,x2,z2,w,kind)

def add(x1, z1, x2, z2, w, k):
    roads.append((round(x1), round(z1), round(x2), round(z2), w, k))

# ------------------------------------------------------------ พื้นที่ห้ามมีถนน/ตึก (เติม keep-out ให้ทุกจุดที่มี hand-built)
# (x1,x2,z1,z2,tag)
keep = [
    (-226, 226, -186, 346, "school"),
    (-2000, 2000, 396, 444, "river"),          # แม่น้ำคิโซ (สะพานอยู่บนถนนสายหลัก)
    (100, 245, 606, 716, "station"),           # สถานี + ชานชาลา + ราง + ลานหน้าสถานี
    (8, 72, 468, 532, "tower"),                # หอคอยซูซู
    (-518, -442, 62, 128, "pond"),             # สระน้ำสวนซากุระ + สะพาน
    (-400, -360, 106, 140, "gazebo"),
    (-368, -308, 216, 266, "playground"),
    (-720, -560, -190, -10, "campsite"),       # ค่ายในป่า
    (596, 724, -222, -92, "hill"),             # เนินศาลเจ้า + บันได
    (-624, -418, 602, 756, "kurogane"),        # โรงเรียนคุโรกาเนะ (ใต้ถนน z=600)
    (628, 800, 400, 860, "bay"),               # อ่าว + ท่าเทียบ + เรือ
]
plazas = [  # ลานโล่ง 40x40 ให้ค่ายศัตรู (CampService) ใช้ + ทำสวนสาธารณะ/ที่จอดรถในซอย
    (-150, -110, 668, 708, "Downtown", "park"),
    (92, 132, 506, 546, "Downtown", "lot"),
    (352, 392, 108, 148, "Shotengai", "lot"),
    (468, 508, 206, 246, "Shotengai", "park"),
    (478, 518, 470, 510, "Docks", "yard"),
    (590, 630, 660, 700, "Docks", "yard"),
]
for p in plazas:
    keep.append((p[0], p[1], p[2], p[3], "plaza"))

# ------------------------------------------------------------ ถนนที่กำหนดเอง
# สายหลัก
add(-800, 170, -235, 170, 22, "A")
add(-235, 170, 235, 170, 16, "A")
add(235, 170, 290, 170, 22, "A")
add(290, 170, 560, 170, 16, "A")      # ถนนการค้า (ใต้หลังคา)
add(560, 170, 800, 170, 22, "A")
for x, w in ((-370, 16), (-90, 18)):
    add(x, 170, x, 394, w, "A")
    add(x, 394, x, 446, 14, "A")      # สะพาน
    add(x, 446, x, 800, w, "A")
add(570, -150, 570, 394, 18, "A")
add(570, 394, 570, 446, 14, "A")
add(570, 446, 570, 780, 16, "A")
add(-680, 600, 700, 600, 20, "A")
# ค่ายป่า + ทางขึ้นเหนือ + ทางขึ้นศาลเจ้า
add(-560, -100, -560, 170, 14, "A")
add(-640, -100, -560, -100, 12, "L")
add(570, -86, 660, -86, 10, "L")
# โรงเรียน: ถนนวงแหวนกว้างไม่เท่ากัน
add(-235, -190, -235, 350, 11, "L")
add(235, -190, 235, 350, 13, "L")
add(-235, -190, 235, -190, 12, "L")
add(-235, 350, 235, 350, 9, "L")
# ริมแม่น้ำ
add(-370, 458, 570, 458, 10, "B")
add(-560, 384, 680, 384, 8, "B")
# ซอยหน้าศาลเจ้า (ร้านขายของที่ระลึก)
add(588, -86, 588, -22, 7, "Y")
add(588, -34, 646, -34, 7, "Y")
# ทางป่าลูกรัง
add(-640, -100, -640, -200, 5, "T")
add(-640, -100, -740, -100, 5, "T")
add(-740, -100, -740, -30, 5, "T")
add(-600, -100, -600, -210, 5, "T")

N_FIXED = len(roads)


def clip_against_keep(seg, margin=2.0, only=None):
    """ตัดส่วนของถนนที่ทับ keep-out ออก คืนรายการ segment ที่เหลือ"""
    x1, z1, x2, z2, w, k = seg
    horiz = abs(x2 - x1) >= abs(z2 - z1)
    lo, hi = (min(x1, x2), max(x1, x2)) if horiz else (min(z1, z2), max(z1, z2))
    fixed = z1 if horiz else x1
    cut = []
    for (kx1, kx2, kz1, kz2, tag) in keep:
        if tag == "river" or (only is not None and tag not in only):
            continue
        hw = w / 2 + margin
        if horiz:
            if kz1 - hw < fixed < kz2 + hw:
                cut.append((kx1 - 0.5, kx2 + 0.5))
        else:
            if kx1 - hw < fixed < kx2 + hw:
                cut.append((kz1 - 0.5, kz2 + 0.5))
    cut.sort()
    pieces, cur = [], lo
    for a, b in cut:
        if b <= cur or a >= hi:
            continue
        if a > cur:
            pieces.append((cur, a))
        cur = max(cur, b)
    if cur < hi:
        pieces.append((cur, hi))
    out = []
    for a, b in pieces:
        if b - a >= 16:
            out.append((a, fixed, b, fixed, w, k) if horiz else (fixed, a, fixed, b, w, k))
    return out


def generate_region(x1, x2, z1, z2, xs, zs, wmajor, wminor, p_alley, p_stagger, p_skip, p_dead, avoid, major_every=3, vbias=None):
    """กริดเหลื่อม: เส้นนอน (ต่อเนื่อง ตัดเป็นช่วงสุ่มทิ้ง) + เส้นตั้ง (ตัดที่เส้นนอน เหลื่อมซ้ายขวาแบบ T สองตัวหรือตรง 4 แยก)"""
    # เส้นนอน (z)
    zl, z = [], z1 + R.uniform(zs[0] * 0.5, zs[1] * 0.8)
    while z < z2 - 20:
        if all(abs(z - a) > 24 for a in avoid[1]):
            zl.append(z)
        z += R.uniform(*zs)
    xl, x = [], x1 + R.uniform(xs[0] * 0.4, xs[1] * 0.8)
    while x < x2 - 20:
        if all(abs(x - a) > 26 for a in avoid[0]):
            xl.append(x)
        x += R.uniform(*xs)

    def width(i):
        if i % major_every == 1:
            return R.choice(wmajor), "L"
        if R.random() < p_alley:
            return R.choice((6, 7)), "Y"
        return R.choice(wminor), "B"

    # เส้นนอน: ตัดเป็นช่วงตามแนวตั้ง
    hsegs = []
    for i, z in enumerate(zl):
        w, k = width(i)
        a = x1 if R.random() > p_dead else x1 + R.uniform(30, 80)
        b = x2 if R.random() > p_dead else x2 - R.uniform(30, 80)
        zz = z + R.uniform(-3, 3)
        hsegs.append((a, zz, b, zz, w, k))
    for s in hsegs:
        add(*s)
    # เส้นตั้ง
    for j, x in enumerate(xl):
        w, k = width(j + 1)
        # หาตำแหน่งที่ตัดเส้นนอน
        bounds = [z1] + [s[1] for s in hsegs if s[0] - 1 <= x <= s[2] + 1] + [z2]
        bounds = sorted(set(bounds))
        cx = x
        for a, b in zip(bounds, bounds[1:]):
            if b - a < 12:
                continue
            if R.random() < p_skip:
                continue
            ea, eb = a, b
            if R.random() < p_dead:  # ซอยตัน ไม่ถึงเส้นนอนฝั่งหนึ่ง
                if R.random() < 0.5:
                    ea = a + (b - a) * R.uniform(0.3, 0.55)
                else:
                    eb = b - (b - a) * R.uniform(0.3, 0.55)
            add(cx, ea, cx, eb, w, k)
            if R.random() < p_stagger:
                cx = x + R.choice((-1, 1)) * R.uniform(7, 13)


generate_region(-370, 400, 462, 800, (34, 62), (38, 64), (14, 16), (9, 10, 11, 12), 0.35, 0.55, 0.10, 0.14, ([-90, -370, 570], [600, 458, 384]))
generate_region(400, 680, 462, 790, (50, 80), (46, 70), (12, 14), (10, 12), 0.05, 0.5, 0.08, 0.1, ([570], [600, 458]), major_every=2)
generate_region(-680, -370, 462, 800, (34, 58), (32, 52), (12, 14), (8, 9, 10), 0.3, 0.5, 0.12, 0.14, ([-370], [600, 458]))
generate_region(290, 570, 40, 300, (28, 46), (36, 50), (10, 12), (7, 8, 9, 10), 0.45, 0.45, 0.10, 0.14, ([570], [170]))
generate_region(570, 800, 60, 380, (34, 60), (36, 56), (10, 12), (8, 9, 10), 0.3, 0.5, 0.12, 0.16, ([570], [170, 384]), major_every=4)
generate_region(-800, -560, 60, 380, (34, 60), (36, 56), (10, 12), (8, 9, 10), 0.3, 0.5, 0.12, 0.16, ([-560], [170, 384]), major_every=4)
generate_region(-330, -236, -190, 380, (30, 50), (40, 60), (10, 12), (7, 8, 9), 0.35, 0.5, 0.10, 0.14, ([-235], [170, 350, -190, 384]))
generate_region(236, 290, -190, 380, (30, 50), (40, 60), (10, 12), (7, 8, 9), 0.35, 0.5, 0.10, 0.14, ([235], [170, 350, -190, 384]))
generate_region(-560, -330, 40, 300, (90, 130), (70, 100), (10, 12), (7, 8), 0.4, 0.4, 0.25, 0.3, ([-560], [170]))

# ------------------------------------------------------------ ตัดเส้นที่ทับ keep-out + กรองเส้นขนานซ้อนกัน
def horiz(s):
    return abs(s[2] - s[0]) >= abs(s[3] - s[1])


def rect(s, pad=0.0):
    x1, z1, x2, z2, w, _ = s
    if horiz(s):
        return (min(x1, x2), max(x1, x2), z1 - w / 2 - pad, z1 + w / 2 + pad)
    return (x1 - w / 2 - pad, x1 + w / 2 + pad, min(z1, z2), max(z1, z2))


def conflicts(a, b):
    if horiz(a) != horiz(b):
        return False
    fa = a[1] if horiz(a) else a[0]
    fb = b[1] if horiz(b) else b[0]
    la = (min(a[0], a[2]), max(a[0], a[2])) if horiz(a) else (min(a[1], a[3]), max(a[1], a[3]))
    lb = (min(b[0], b[2]), max(b[0], b[2])) if horiz(b) else (min(b[1], b[3]), max(b[1], b[3]))
    if la[1] - 8 <= lb[0] or lb[1] - 8 <= la[0]:
        return False
    return abs(fa - fb) < (a[4] + b[4]) / 2 + 9


fixed_roads = [p for s in roads[:N_FIXED] for p in clip_against_keep(s, 2.0, ("bay",))]
kept = list(fixed_roads)
for s in roads[N_FIXED:]:
    for piece in clip_against_keep(s):
        if not any(conflicts(piece, k) for k in kept):
            kept.append(piece)
final = kept

# ปัดปลายเส้นที่ลอย: ปลายที่ห่างจากถนนอื่นไม่เกิน 14 ให้ต่อเข้ากึ่งกลางถนนนั้น (กลายเป็น T-junction)
def snap(final):
    out = []
    for s in final:
        x1, z1, x2, z2, w, k = s
        h = horiz(s)
        pts = [[x1, z1], [x2, z2]]
        for p in pts:
            best = None
            for o in final:
                if o is s or horiz(o) == h:
                    continue
                # o ตั้งฉากกับ s: ปลาย p ของ s ควรชนเส้นกลางของ o
                if h:
                    ox = o[0]
                    oz1, oz2 = min(o[1], o[3]), max(o[1], o[3])
                    if oz1 - 1 <= p[1] <= oz2 + 1 and abs(p[0] - ox) <= 14:
                        d = abs(p[0] - ox)
                        if best is None or d < best[0]:
                            best = (d, ox)
                else:
                    oz = o[1]
                    ox1, ox2 = min(o[0], o[2]), max(o[0], o[2])
                    if ox1 - 1 <= p[0] <= ox2 + 1 and abs(p[1] - oz) <= 14:
                        d = abs(p[1] - oz)
                        if best is None or d < best[0]:
                            best = (d, oz)
            if best:
                if h:
                    p[0] = best[1]
                else:
                    p[1] = best[1]
        out.append((pts[0][0], pts[0][1], pts[1][0], pts[1][1], w, k))
    return out

final = [tuple(map(lambda v: round(v) if isinstance(v, float) else v, s)) for s in snap(final)]
final = [s for s in final if (abs(s[2] - s[0]) + abs(s[3] - s[1])) >= 14]


# ------------------------------------------------------------ สถิติ
def stats(final):
    n = len(final)
    alleys = sum(1 for s in final if s[4] <= 10 and s[5] != "T")
    t = cross = dead = 0
    for s in final:
        h = horiz(s)
        for p in ((s[0], s[1]), (s[2], s[3])):
            hit = False
            for o in final:
                if o is s or horiz(o) == h:
                    continue
                r = rect(o)
                if r[0] - 0.6 <= p[0] <= r[1] + 0.6 and r[2] - 0.6 <= p[1] <= r[3] + 0.6:
                    hit = True
                    break
            if hit:
                t += 1
            else:
                dead += 1
    for i, a in enumerate(final):
        for b in final[i + 1:]:
            if horiz(a) == horiz(b):
                continue
            ha, va = (a, b) if horiz(a) else (b, a)
            vx, hz = va[0], ha[1]
            if min(ha[0], ha[2]) + 1 < vx < max(ha[0], ha[2]) - 1 and min(va[1], va[3]) + 1 < hz < max(va[1], va[3]) - 1:
                cross += 1
    return n, alleys, t, cross, dead


n, alleys, t, cross, dead = stats(final)
print(f"roads={n} alleys(w<=10)={alleys} T-ends={t} 4way={cross} dead-ends={dead}")

# ------------------------------------------------------------ zones (โปรไฟล์ตึก + พื้นที่บังคับเรียบใน TerrainBake)
zones = [
    (-560, -330, 40, 300, "park"),
    (-330, -240, -200, 392, "resi"),
    (240, 290, -200, 392, "resi"),
    (-240, 240, 352, 394, "resi"),
    (290, 570, 112, 232, "shop"),
    (290, 570, 40, 112, "resi"),
    (290, 570, 232, 300, "resi"),
    (570, 800, 60, 380, "resi"),
    (-800, -560, 60, 380, "resi"),
    (-250, 330, 450, 760, "down"),
    (-370, -250, 450, 800, "resi"),
    (-250, 400, 760, 800, "resi"),
    (330, 400, 450, 760, "resi"),
    (-680, -370, 450, 800, "resi"),
    (400, 680, 450, 800, "ind"),
    (575, 650, -92, -14, "monzen"),
]

# ------------------------------------------------------------ เขียนลง World.luau
def fmt_roads(rs):
    lines = []
    for s in rs:
        lines.append(f'\t{{ {s[0]}, {s[1]}, {s[2]}, {s[3]}, {s[4]}, "{s[5]}" }},')
    return "\n".join(lines)


block = ["-- BEGIN GENERATED (tools/gen_roads.py — อย่าแก้มือ รันสคริปต์ใหม่)"]
block.append("local Roads = {")
block.append(fmt_roads(final))
block.append("}")
block.append("")
block.append("-- พื้นที่ห้ามสร้างตึก/ถนน {x1, x2, z1, z2, tag}")
block.append("local KeepOut = {")
for k in keep:
    block.append(f'\t{{ {k[0]}, {k[1]}, {k[2]}, {k[3]}, "{k[4]}" }},')
block.append("}")
block.append("")
block.append("-- ลานโล่ง 40x40 (ค่ายศัตรู + สวนสาธารณะ/ที่จอดรถ): {x1, x2, z1, z2, ย่าน, ชนิด}")
block.append("local Plazas = {")
for p in plazas:
    block.append(f'\t{{ {p[0]}, {p[1]}, {p[2]}, {p[3]}, "{p[4]}", "{p[5]}" }},')
block.append("}")
block.append("")
block.append("-- โซนโปรไฟล์ตึก (และพื้นที่ที่ TerrainBake บังคับให้เรียบ): {x1, x2, z1, z2, โปรไฟล์}")
block.append("local Zones = {")
for z in zones:
    block.append(f'\t{{ {z[0]}, {z[1]}, {z[2]}, {z[3]}, "{z[4]}" }},')
block.append("}")
block.append(f"-- stats: roads={n} alleys={alleys} T={t} 4way={cross} dead={dead}")
block.append("-- END GENERATED")
text = "\n".join(block)

path = os.path.join(ROOT, "src", "shared", "World.luau")
src = open(path, encoding="utf-8").read()
if "-- BEGIN GENERATED" in src:
    src = re.sub(r"-- BEGIN GENERATED.*?-- END GENERATED", lambda m: text, src, flags=re.S)
    open(path, "w", encoding="utf-8", newline="\n").write(src)
    print("wrote", path)
else:
    print("World.luau has no GENERATED markers; printing block only")

# ------------------------------------------------------------ PNG พรีวิว
if "--png" in sys.argv:
    out = sys.argv[sys.argv.index("--png") + 1]
    S = 0.5
    X0, Z0, X1, Z1 = -820, -460, 820, 910
    W, H = int((X1 - X0) * S), int((Z1 - Z0) * S)
    img = bytearray([30] * (W * H * 3))

    def fill(x1, x2, z1, z2, c):
        for iz in range(max(0, int((z1 - Z0) * S)), min(H, int((z2 - Z0) * S) + 1)):
            for ix in range(max(0, int((x1 - X0) * S)), min(W, int((x2 - X0) * S) + 1)):
                o = (iz * W + ix) * 3
                img[o:o + 3] = bytes(c)

    fill(-200, 200, -150, 340, (70, 90, 60))
    fill(-2000, 2000, 396, 444, (40, 70, 130))
    for k in keep:
        if k[4] not in ("river", "school"):
            fill(k[0], k[1], k[2], k[3], (90, 70, 40))
    for s in final:
        r = rect(s)
        col = {"A": (200, 200, 200), "L": (170, 170, 170), "B": (230, 200, 90), "Y": (240, 120, 60), "T": (120, 90, 60)}[s[5]]
        fill(r[0], r[1], r[2], r[3], col)

    def png(w, h, data):
        raw = b"".join(b"\x00" + bytes(data[y * w * 3:(y + 1) * w * 3]) for y in range(h))
        def chunk(t, d):
            c = struct.pack(">I", len(d)) + t + d
            return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
        return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
    open(out, "wb").write(png(W, H, img))
    print("png", out)
