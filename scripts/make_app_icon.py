from PIL import Image, ImageDraw, ImageFilter

SS = 4                      # supersample
S = 1024 * SS              # canvas size
def px(v): return int(round(v * SS))

def lerp(a, b, t): return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))

# --- Background: vertical brand-green gradient ---------------------------------
top = (36, 126, 95)        # #247e5f
bot = (20, 84, 62)         # #14543e
bg = Image.new("RGB", (S, S), top)
bd = ImageDraw.Draw(bg)
for y in range(S):
    bd.line([(0, y), (S, y)], fill=lerp(top, bot, y / (S - 1)))

# Soft highlight glow, upper-left, for a little depth
glow = Image.new("L", (S, S), 0)
gd = ImageDraw.Draw(glow)
gd.ellipse([px(-260), px(-360), px(720), px(360)], fill=90)
glow = glow.filter(ImageFilter.GaussianBlur(px(120)))
white = Image.new("RGB", (S, S), (255, 255, 255))
bg = Image.composite(white, bg, glow.point(lambda a: int(a * 0.5)))

base = bg.convert("RGBA")

# --- Geometry (logical 1024 coords), vertically centered ----------------------
baseline = 834
bar_w = 124
gap = 58
heights = [267, 384, 534]
colors = [(244, 241, 234), (191, 224, 207), (155, 210, 184)]  # cream, mint, greenAccent
radius = 28
start_x = 512 - (3 * bar_w + 2 * gap) / 2

bars = []
for i, h in enumerate(heights):
    x = start_x + i * (bar_w + gap)
    bars.append((x, baseline - h, x + bar_w, baseline))

# clay accent dot above the tallest bar
tall = bars[-1]
dot_cx = (tall[0] + tall[2]) / 2
dot_r = 46
dot_cy = tall[1] - 18 - dot_r
clay = (189, 90, 60)

def draw_shapes(draw, fill_bars, fill_dot):
    for (x0, y0, x1, y1), col in zip(bars, fill_bars):
        draw.rounded_rectangle([px(x0), px(y0), px(x1), px(y1)], radius=px(radius), fill=col)
    draw.ellipse([px(dot_cx - dot_r), px(dot_cy - dot_r),
                  px(dot_cx + dot_r), px(dot_cy + dot_r)], fill=fill_dot)

# --- Soft drop shadow ---------------------------------------------------------
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
# offset shapes downward for the shadow
off = 16
sbars = [(x0, y0 + off, x1, y1 + off) for (x0, y0, x1, y1) in bars]
for (x0, y0, x1, y1) in sbars:
    sd.rounded_rectangle([px(x0), px(y0), px(x1), px(y1)], radius=px(radius), fill=(9, 40, 30, 120))
sd.ellipse([px(dot_cx - dot_r), px(dot_cy - dot_r + off),
            px(dot_cx + dot_r), px(dot_cy + dot_r + off)], fill=(9, 40, 30, 120))
shadow = shadow.filter(ImageFilter.GaussianBlur(px(14)))
base = Image.alpha_composite(base, shadow)

# --- Real shapes --------------------------------------------------------------
fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
fd = ImageDraw.Draw(fg)
draw_shapes(fd, colors, clay + (255,))
base = Image.alpha_composite(base, fg)

# --- Downscale + save (opaque RGB, no alpha for app icons) --------------------
out = base.convert("RGB").resize((1024, 1024), Image.LANCZOS)
dst = "/home/user/FinancialPlanner/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
out.save(dst, "PNG")
print("wrote", dst, out.size)
