#!/usr/bin/env python3
"""
Generate an IBM mainframe-style .icns icon for the Zowe MVS Editor bundle.

Design:
  • Dark navy chassis (rounded rectangle)
  • Left vertical stripe with IBM-style 8-bar motif (blue with cut-through gaps)
  • Bold "Z" below the bars  (z/OS reference)
  • Right panel: ventilation grills, 4 drive bays with LEDs, control strip
"""

from PIL import Image, ImageDraw
import os, shutil, subprocess

# ---------------------------------------------------------------------------
def make(size: int) -> Image.Image:
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d   = ImageDraw.Draw(img)
    S   = size / 256.0          # master grid is 256 × 256

    def px(v):   return max(1, round(v * S))
    def col(r,g,b,a=255): return (r, g, b, a)

    # ── palette ──────────────────────────────────────────────────────────
    CHASSIS   = col(18,  28,  45)
    PANEL     = col(26,  40,  62)
    IBM_BLUE  = col( 0, 107, 166)
    IBM_LITE  = col(65, 152, 212)
    SLOT_BG   = col( 9,  16,  28)
    VENT      = col( 7,  12,  22)
    LED_GRN   = col( 0, 210,  80)
    LED_AMB   = col(255, 160,  0)
    LED_DIM   = col( 0,  60,  25)
    CHROME    = col(140, 165, 195)
    WHITE     = col(225, 238, 255)

    W = H = size
    m   = px(12)    # outer margin
    rad = px(20)    # corner radius
    ip  = px(5)     # inner panel inset

    # ── drop shadow ──────────────────────────────────────────────────────
    sh = px(5)
    d.rounded_rectangle([m+sh, m+sh, W-m+sh, H-m+sh],
                         radius=rad, fill=col(0,0,0,55))

    # ── chassis body ─────────────────────────────────────────────────────
    d.rounded_rectangle([m, m, W-m, H-m], radius=rad, fill=CHASSIS)

    # ── front-panel inset ────────────────────────────────────────────────
    d.rounded_rectangle([m+ip, m+ip, W-m-ip, H-m-ip],
                         radius=max(1, rad-3), fill=PANEL)

    # ── IBM 8-bar left stripe ────────────────────────────────────────────
    sw   = px(52)           # stripe width
    sx1  = m + ip
    sx2  = sx1 + sw
    sy1  = m + ip
    sy2  = H - m - ip
    sh_  = sy2 - sy1        # stripe height

    # solid blue backing
    d.rounded_rectangle([sx1, sy1, sx2, sy2],
                         radius=max(1, rad-4), fill=IBM_BLUE)
    d.rectangle([sx2-px(18), sy1, sx2, sy2], fill=IBM_BLUE)

    # cut 8 horizontal gaps into the top ~55% of the stripe
    if size >= 32:
        bars_h  = round(sh_ * 0.52)
        n_bars  = 8
        slot_h  = max(1, round(bars_h / (n_bars * 2 - 1)))
        bar_h   = slot_h
        gap_h   = slot_h
        bar_top = sy1 + px(4)
        for i in range(n_bars):
            by  = bar_top + i * (bar_h + gap_h)
            bym = by + bar_h
            # cut gap below this bar (expose chassis colour)
            if i < n_bars - 1:
                d.rectangle([sx1, bym, sx2, bym + gap_h], fill=PANEL)
                d.rectangle([sx2-px(18), bym, sx2, bym + gap_h], fill=PANEL)
        # top bar gets a lighter shade
        d.rectangle([sx1, sy1, sx2, bar_top + bar_h],
                     fill=IBM_LITE)
        d.rectangle([sx2-px(18), sy1, sx2, bar_top + bar_h],
                     fill=IBM_LITE)
        # re-apply rounded top-left corner clip
        corner_mask = Image.new('RGBA', (size, size), (0,0,0,0))
        cm = ImageDraw.Draw(corner_mask)
        cm.rounded_rectangle([sx1, sy1, sx2, sy2],
                              radius=max(1, rad-4), fill=(255,255,255,255))
        cm.rectangle([sx2-px(18), sy1, sx2, sy2], fill=(255,255,255,255))
        # bottom rounded corner
        cm.rounded_rectangle([sx1, sy1, sx2, sy2],
                              radius=max(1, rad-4), fill=(255,255,255,255))

    # ── "Z" logo below the bars ──────────────────────────────────────────
    if size >= 48:
        zx  = sx1 + px(9)
        zy  = sy1 + round(sh_ * 0.58)
        zw  = sw - px(18)
        zh  = round(zw * 1.05)
        zt  = max(2, px(8))
        # top bar
        d.line([(zx, zy + zt//2), (zx+zw, zy + zt//2)],
               fill=WHITE, width=zt)
        # bottom bar
        d.line([(zx, zy+zh - zt//2), (zx+zw, zy+zh - zt//2)],
               fill=WHITE, width=zt)
        # diagonal  (top-right → bottom-left)
        d.line([(zx+zw, zy + zt//2), (zx, zy+zh - zt//2)],
               fill=WHITE, width=zt)

    # ── right-panel content ───────────────────────────────────────────────
    rx1 = sx2 + px(8)
    rx2 = W - m - ip - px(4)

    # ventilation grills
    vy      = m + ip + px(7)
    g_h     = max(2, px(4))
    g_gap   = max(1, px(3))
    n_grls  = 5 if size >= 128 else 3
    for i in range(n_grls):
        gy = vy + i*(g_h + g_gap)
        d.rounded_rectangle([rx1, gy, rx2, gy+g_h],
                             radius=max(1,px(2)), fill=VENT)
        if size >= 64:
            d.line([(rx1, gy), (rx2, gy)], fill=CHROME, width=1)

    # drive bays
    bay_top = vy + n_grls*(g_h + g_gap) + px(9)
    b_h     = max(5, px(26))
    b_gap   = max(2, px(6))
    n_bays  = 4 if size >= 128 else (2 if size >= 48 else 1)

    for i in range(n_bays):
        by  = bay_top + i*(b_h + b_gap)

        # slot recess
        d.rounded_rectangle([rx1, by, rx2, by+b_h],
                             radius=max(1,px(4)), fill=SLOT_BG)
        # face-plate
        if size >= 64:
            fw = round((rx2-rx1)*0.66)
            d.rounded_rectangle([rx1+px(3), by+px(3),
                                  rx1+fw,    by+b_h-px(3)],
                                 radius=max(1,px(3)),
                                 fill=col(16,26,42))
        # activity LED
        ld  = max(3, px(8))
        lx  = rx2 - ld - px(5)
        ly  = by  + (b_h - ld)//2
        lc  = LED_GRN if i == 0 else (LED_AMB if i == 1 else LED_DIM)
        d.ellipse([lx, ly, lx+ld, ly+ld], fill=lc)

    # control strip at bottom of right panel
    if size >= 64:
        ct  = bay_top + n_bays*(b_h + b_gap) + px(9)
        c_h = max(8, px(30))
        d.rounded_rectangle([rx1, ct, rx2, ct+c_h],
                             radius=max(1,px(5)),
                             fill=col(12, 20, 34))
        if size >= 128:
            btn_cols = [LED_AMB, col(200,55,55), IBM_LITE, IBM_LITE]
            bs  = max(4, px(9))
            bty = ct + (c_h - bs)//2
            bx  = rx1 + px(7)
            for bc in btn_cols:
                d.rounded_rectangle([bx, bty, bx+bs, bty+bs],
                                     radius=max(1,px(2)), fill=bc)
                bx += bs + px(5)
        # power LED (large, green, right)
        pd  = max(6, px(15))
        plx = rx2 - pd - px(5)
        ply = ct  + (c_h - pd)//2
        d.ellipse([plx, ply, plx+pd, ply+pd], fill=LED_GRN)

    return img

# ---------------------------------------------------------------------------
def main():
    ICONSET = 'AppIcon.iconset'
    ICNS    = 'AppIcon.icns'
    os.makedirs(ICONSET, exist_ok=True)

    # (filename, actual_pixel_size)
    entries = [
        ('icon_16x16.png',       16),
        ('icon_16x16@2x.png',    32),
        ('icon_32x32.png',       32),
        ('icon_32x32@2x.png',    64),
        ('icon_128x128.png',    128),
        ('icon_128x128@2x.png', 256),
        ('icon_256x256.png',    256),
        ('icon_256x256@2x.png', 512),
        ('icon_512x512.png',    512),
        ('icon_512x512@2x.png',1024),
    ]

    # Draw at native size for small icons; for large ones scale from 1024
    master = make(1024)

    for fname, px_size in entries:
        if px_size <= 64:
            img = make(px_size)
        else:
            img = master.resize((px_size, px_size), Image.LANCZOS)
        out = os.path.join(ICONSET, fname)
        img.save(out)
        print(f'  {fname}  ({px_size}px)')

    subprocess.run(['iconutil', '-c', 'icns', ICONSET, '-o', ICNS], check=True)
    print(f'Created {ICNS}')

    # Install into bundle
    res_dir = 'editor.app/Contents/Resources'
    os.makedirs(res_dir, exist_ok=True)
    shutil.copy(ICNS, os.path.join(res_dir, ICNS))
    print(f'Installed → {res_dir}/{ICNS}')

if __name__ == '__main__':
    main()
