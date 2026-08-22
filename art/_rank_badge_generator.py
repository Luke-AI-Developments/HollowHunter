from PIL import Image, ImageDraw, ImageFont, ImageFilter

S, OUT = 1200, 512
CYAN = (34, 211, 238); ICY = (170, 245, 255); DARK = (8, 17, 25)
FONT = "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf"

def shield(cx, top, bottom, halfw, n=400):
    p = []
    for i in range(n + 1):
        t = i / n
        p.append((cx - halfw * (1 - t ** 2.6), top + t * (bottom - top)))
    for i in range(n, -1, -1):
        t = i / n
        p.append((cx + halfw * (1 - t ** 2.6), top + t * (bottom - top)))
    return p

def make(letter, path):
    cx = S / 2
    top, bot, hw = S * 0.10, S * 0.94, S * 0.375

    body = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    # rim = big cyan shield, then dark shield inset on top (clean edges, no polyline artifacts)
    d.polygon(shield(cx, top, bot, hw), fill=CYAN + (255,))
    d.polygon(shield(cx, top + S*0.028, bot - S*0.038, hw * 0.925), fill=DARK + (255,))
    # inner hairline
    d.polygon(shield(cx, top + S*0.060, bot - S*0.082, hw * 0.845), fill=CYAN + (90,))
    d.polygon(shield(cx, top + S*0.068, bot - S*0.094, hw * 0.825), fill=DARK + (255,))

    f = ImageFont.truetype(FONT, int(S * 0.40))
    tl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    td = ImageDraw.Draw(tl)
    l, t_, r, b = td.textbbox((0, 0), letter, font=f)
    td.text(((S - (r - l)) / 2 - l, (S * 0.90 - (b - t_)) / 2 - t_), letter, font=f, fill=ICY + (255,))

    art  = Image.alpha_composite(body, tl)
    glow = art.filter(ImageFilter.GaussianBlur(S * 0.022))
    out  = Image.alpha_composite(Image.new("RGBA", (S, S), (0, 0, 0, 0)), glow)
    out  = Image.alpha_composite(out, art)
    out.resize((OUT, OUT), Image.LANCZOS).save(path)

for L in "EDCBAS":
    make(L, f"ui_rank_{L.lower()}.png")
print("rendered")
