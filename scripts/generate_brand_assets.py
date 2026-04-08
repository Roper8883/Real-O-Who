from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Real O Who" / "Assets.xcassets"
APP_ICON_PATH = ASSETS / "AppIcon.appiconset" / "AppIcon.png"
BRAND_MARK_PATH = ASSETS / "BrandMark.imageset"
BRANDING_OUTPUT = ROOT / "branding" / "generated"
DOCS_OUTPUT = ROOT / "docs" / "real-o-who"

SIZE = 1024
ICON_RADIUS = 232

NAVY = (11, 55, 82, 255)
TEAL = (26, 147, 145, 255)
SKY = (99, 204, 236, 255)
MIST = (240, 249, 255, 255)
WHITE = (255, 255, 255, 255)
SLATE = (39, 77, 100, 255)
GOLD = (255, 197, 76, 255)
GOLD_DEEP = (240, 154, 48, 255)
CORAL = (255, 99, 88, 255)
MINT = (130, 221, 190, 255)


def main() -> None:
    BRANDING_OUTPUT.mkdir(parents=True, exist_ok=True)
    BRAND_MARK_PATH.mkdir(parents=True, exist_ok=True)

    app_icon = draw_mark(include_background=True)
    brand_mark = draw_mark(include_background=False)

    app_icon.save(APP_ICON_PATH)
    app_icon.save(BRANDING_OUTPUT / "real-o-who-app-icon-1024.png")
    brand_mark.save(BRANDING_OUTPUT / "real-o-who-brand-mark-1024.png")
    brand_mark.save(DOCS_OUTPUT / "brand-mark.png")

    for px in (128, 256, 384):
        resized = brand_mark.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(BRAND_MARK_PATH / f"brand-mark-{px}.png")


def draw_mark(*, include_background: bool) -> Image.Image:
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    if include_background:
        background = build_background()
        canvas.alpha_composite(background)

    shadows = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_sign_post(shadows, shadow=True)
    draw_house(shadows, shadow=True)
    draw_coin(shadows, shadow=True)
    draw_badge(shadows, shadow=True)
    shadows = shadows.filter(ImageFilter.GaussianBlur(radius=20))
    canvas.alpha_composite(ImageChops.multiply(shadows, Image.new("RGBA", (SIZE, SIZE), (90, 110, 120, 120))))

    draw_coin(canvas, shadow=False)
    draw_sign_post(canvas, shadow=False)
    draw_house(canvas, shadow=False)
    draw_badge(canvas, shadow=False)

    if include_background:
        sheen = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        draw = ImageDraw.Draw(sheen)
        draw.rounded_rectangle((64, 64, 960, 960), radius=ICON_RADIUS, outline=(255, 255, 255, 60), width=6)
        canvas.alpha_composite(sheen)

    return canvas


def build_background() -> Image.Image:
    gradient = vertical_gradient(SIZE, (8, 66, 90), (44, 182, 190))

    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(highlight)
    draw.ellipse((150, -40, 910, 680), fill=(255, 255, 255, 72))
    draw.ellipse((80, 540, 680, 1120), fill=(255, 220, 116, 55))
    draw.ellipse((480, 180, 1100, 820), fill=(85, 205, 240, 65))
    highlight = highlight.filter(ImageFilter.GaussianBlur(radius=18))
    gradient.alpha_composite(highlight)

    glaze = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glaze)
    draw.rounded_rectangle((96, 96, 928, 928), radius=ICON_RADIUS - 32, fill=(255, 255, 255, 24))
    glaze = glaze.filter(ImageFilter.GaussianBlur(radius=14))
    gradient.alpha_composite(glaze)

    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle((32, 32, 992, 992), radius=ICON_RADIUS, fill=255)
    gradient.putalpha(mask)
    return gradient


def vertical_gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pixels = image.load()
    for y in range(size):
        ratio = y / (size - 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * ratio) for i in range(3))
        for x in range(size):
            pixels[x, y] = (*color, 255)
    return image


def draw_coin(target: Image.Image, *, shadow: bool) -> None:
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    if shadow:
        draw.ellipse((554, 112, 874, 432), fill=(0, 0, 0, 165))
        target.alpha_composite(layer, dest=(0, 0))
        return

    draw.ellipse((542, 104, 864, 426), fill=GOLD)
    draw.ellipse((566, 128, 840, 402), outline=(255, 239, 186, 255), width=16)
    draw.arc((606, 166, 820, 380), start=210, end=340, fill=(255, 235, 170, 255), width=18)
    draw.arc((592, 142, 786, 336), start=25, end=108, fill=(236, 146, 38, 210), width=14)

    draw.rounded_rectangle((666, 186, 734, 350), radius=34, fill=WHITE)
    draw.arc((620, 152, 778, 252), start=30, end=180, fill=WHITE, width=20)
    draw.arc((620, 274, 778, 374), start=190, end=342, fill=WHITE, width=20)

    sparkle = [(770, 132, 814, 176), (806, 188, 838, 220)]
    for left, top, right, bottom in sparkle:
        draw.line(((left, (top + bottom) // 2), (right, (top + bottom) // 2)), fill=WHITE, width=8)
        draw.line((((left + right) // 2, top), ((left + right) // 2, bottom)), fill=WHITE, width=8)

    target.alpha_composite(layer, dest=(0, 0))


def draw_house(target: Image.Image, *, shadow: bool) -> None:
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    if shadow:
        draw.rounded_rectangle((212, 342, 760, 864), radius=112, fill=(0, 0, 0, 185))
        draw.polygon(((190, 448), (486, 208), (812, 448)), fill=(0, 0, 0, 185))
        target.alpha_composite(layer, dest=(18, 22))
        return

    draw.polygon(((196, 446), (488, 202), (828, 446)), fill=TEAL)
    draw.polygon(((240, 446), (488, 240), (784, 446)), fill=SKY)
    draw.rounded_rectangle((236, 430, 782, 826), radius=112, fill=WHITE)
    draw.rounded_rectangle((262, 454, 756, 800), radius=94, outline=(210, 232, 242, 255), width=8)

    draw.rounded_rectangle((456, 542, 604, 826), radius=74, fill=GOLD)
    draw.ellipse((550, 660, 568, 678), fill=(255, 238, 208, 255))

    for x0 in (320, 630):
        draw.rounded_rectangle((x0, 536, x0 + 106, 642), radius=28, fill=MIST)
        draw.line(((x0 + 53, 542), (x0 + 53, 638)), fill=(188, 214, 225, 255), width=8)
        draw.line(((x0 + 8, 589), (x0 + 98, 589)), fill=(188, 214, 225, 255), width=8)

    draw.rounded_rectangle((356, 726, 704, 776), radius=24, fill=(229, 243, 246, 255))

    target.alpha_composite(layer, dest=(0, 0))


def draw_sign_post(target: Image.Image, *, shadow: bool) -> None:
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    if shadow:
        draw.rounded_rectangle((164, 394, 198, 830), radius=18, fill=(0, 0, 0, 170))
        draw.rounded_rectangle((178, 408, 414, 444), radius=18, fill=(0, 0, 0, 170))
        draw.rounded_rectangle((166, 442, 414, 630), radius=46, fill=(0, 0, 0, 170))
        target.alpha_composite(layer, dest=(10, 18))
        return

    draw.rounded_rectangle((156, 384, 192, 820), radius=18, fill=SLATE)
    draw.rounded_rectangle((170, 402, 428, 438), radius=18, fill=SLATE)
    draw.rounded_rectangle((170, 442, 430, 632), radius=46, fill=WHITE)
    draw.rounded_rectangle((170, 442, 430, 498), radius=46, fill=CORAL)
    draw.ellipse((204, 518, 244, 558), fill=GOLD)
    draw.line(((270, 540), (372, 540)), fill=(216, 229, 236, 255), width=18)
    draw.line(((270, 578), (350, 578)), fill=(216, 229, 236, 255), width=16)

    target.alpha_composite(layer, dest=(0, 0))


def draw_badge(target: Image.Image, *, shadow: bool) -> None:
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    if shadow:
        draw.ellipse((662, 700, 930, 968), fill=(0, 0, 0, 180))
        target.alpha_composite(layer, dest=(10, 20))
        return

    draw.ellipse((648, 686, 916, 954), fill=CORAL)
    draw.ellipse((674, 712, 890, 928), outline=(255, 215, 213, 255), width=10)
    draw.ellipse((716, 756, 762, 802), outline=WHITE, width=10)
    draw.ellipse((804, 840, 850, 886), outline=WHITE, width=10)
    draw.line(((734, 870), (836, 772)), fill=WHITE, width=18)

    target.alpha_composite(layer, dest=(0, 0))


if __name__ == "__main__":
    main()
