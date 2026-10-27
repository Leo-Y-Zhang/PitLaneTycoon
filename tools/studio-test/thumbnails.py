"""Turn run.py --photos shots into Roblox thumbnails (1280x720) and an icon (512x512).

    python tools/studio-test/thumbnails.py SHOTS_DIR OUT_DIR

Finds Studio's game view by its blue outline, crops below Roblox's menu buttons, and adds
the title in big type (the launch plan: big readable title, no small text). Needs Pillow.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

FONT = Path("C:/Windows/Fonts/ariblk.ttf")  # Arial Black ships with Windows
GOLD, INK = (255, 205, 60), (17, 20, 24)


def viewport(im: Image.Image) -> Image.Image:
    """The game view inside Studio's blue outline."""
    rgb = im.convert("RGB")
    w, h = rgb.size

    def blue(p):
        return p[2] > 180 and p[0] < 90 and 60 < p[1] < 170

    col = int(w * 0.75)
    ys = [y for y in range(h) if blue(rgb.getpixel((col, y)))]
    top, bottom = ys[0] + 3, ys[-1] - 2
    row = (top + bottom) // 2
    xs = [x for x in range(w) if blue(rgb.getpixel((x, row)))]
    right = xs[-1] - 2
    # the left outline: the last blue run before the middle of the window
    left = max(x for x in xs if x < w // 2) + 3
    return rgb.crop((left, top, right, bottom))


def titled(shot: Image.Image, size: tuple[int, int], title: str, sub: str | None) -> Image.Image:
    img = ImageOps.fit(shot, size, Image.LANCZOS, centering=(0.5, 0.6))
    d = ImageDraw.Draw(img)
    big = ImageFont.truetype(str(FONT), size[1] // 7)
    x, y = size[0] // 22, size[1] // 16
    d.text((x, y), title, font=big, fill=GOLD, stroke_width=size[1] // 90, stroke_fill=INK)
    if sub:
        small = ImageFont.truetype(str(FONT), size[1] // 16)
        top = y + big.size + size[1] // 30
        d.text((x, top), sub, font=small, fill=(255, 255, 255), stroke_width=size[1] // 140, stroke_fill=INK)
    return img


def car_icon(view: Image.Image) -> Image.Image:
    """A square crop round the show car: its red bodywork, ignoring the wall lettering above."""
    w, h = view.size
    px = view.load()
    xs, ys = [], []
    for y in range(int(h * 0.15), h, 2):
        for x in range(0, w, 2):
            r, g, b = px[x, y]
            if r > 170 and g < 70 and b < 70:
                xs.append(x)
                ys.append(y)
    cx, cy = (min(xs) + max(xs)) // 2, (min(ys) + max(ys)) // 2
    side = int(max(max(xs) - min(xs), max(ys) - min(ys)) * 1.25)
    side = min(side, w, h)
    left = min(max(cx - side // 2, 0), w - side)  # keep the square inside the picture
    top = min(max(cy - side // 2, 0), h - side)
    box = (left, top, left + side, top + side)
    return view.crop(box).resize((512, 512), Image.LANCZOS)


def main() -> None:
    shots, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    views = {}
    for name in ("race", "hero", "car", "line", "paddock", "night", "dusk"):
        vp = viewport(Image.open(shots / f"{name}.png"))
        views[name] = vp.crop((0, int(vp.height * 0.17), vp.width, vp.height))  # below the menu buttons
    titled(views["race"], (1280, 720), "PIT LANE TYCOON", "Drive your own F1 car").save(out / "thumbnail-1.png")
    titled(views["hero"], (1280, 720), "PIT LANE TYCOON", "Build your F1 factory").save(out / "thumbnail-2.png")
    titled(views["line"], (1280, 720), "PIT LANE TYCOON", "Every part pays").save(out / "thumbnail-3.png")
    titled(views["paddock"], (1280, 720), "PIT LANE TYCOON", "Six teams. One trophy.").save(out / "thumbnail-4.png")
    titled(views["night"], (1280, 720), "PIT LANE TYCOON", "A new look in season 3").save(out / "thumbnail-5.png")
    titled(views["dusk"], (1280, 720), "PIT LANE TYCOON", "Racing day and night").save(out / "thumbnail-6.png")
    icon = car_icon(views["race"])  # the car alone on track: the garage shot has the crew behind it
    icon.save(out / "icon.png")
    for f in sorted(out.glob("*.png")):
        print(f.name, Image.open(f).size)


if __name__ == "__main__":
    main()
