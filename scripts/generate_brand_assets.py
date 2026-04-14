from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Real O Who" / "Assets.xcassets"
APP_ICON_PATH = ASSETS / "AppIcon.appiconset" / "AppIcon.png"
BRAND_MARK_PATH = ASSETS / "BrandMark.imageset"
BRANDING_OUTPUT = ROOT / "branding" / "generated"
DOCS_OUTPUT = ROOT / "docs" / "real-o-who"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
ANDROID_FOREGROUND_PATH = ANDROID_RES / "drawable" / "ic_launcher_foreground.png"

SIZE = 1024
ANDROID_FOREGROUND_SIZE = 432
FONT_PATH = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

HOUSE = (23, 96, 188, 255)
HOUSE_DARK = (14, 73, 150, 255)
BACKGROUND = (246, 248, 251, 255)
TRANSPARENT = (0, 0, 0, 0)
WHITE = (255, 255, 255, 255)
STROKE = (255, 255, 255, 230)

ANDROID_LAUNCHER_SIZES = {
    "mipmap-ldpi": 36,
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def main() -> None:
    BRANDING_OUTPUT.mkdir(parents=True, exist_ok=True)
    BRAND_MARK_PATH.mkdir(parents=True, exist_ok=True)
    DOCS_OUTPUT.mkdir(parents=True, exist_ok=True)
    ANDROID_FOREGROUND_PATH.parent.mkdir(parents=True, exist_ok=True)

    app_icon = draw_mark(size=SIZE, include_background=True)
    brand_mark = draw_mark(size=SIZE, include_background=False)
    android_foreground = draw_mark(size=ANDROID_FOREGROUND_SIZE, include_background=False)

    app_icon.save(APP_ICON_PATH)
    app_icon.save(BRANDING_OUTPUT / "real-o-who-app-icon-1024.png")
    brand_mark.save(BRANDING_OUTPUT / "real-o-who-brand-mark-1024.png")
    brand_mark.save(DOCS_OUTPUT / "brand-mark.png")
    android_foreground.save(ANDROID_FOREGROUND_PATH)

    for px in (128, 256, 384):
        resized = brand_mark.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(BRAND_MARK_PATH / f"brand-mark-{px}.png")

    for directory, px in ANDROID_LAUNCHER_SIZES.items():
        resized = app_icon.resize((px, px), Image.Resampling.LANCZOS)
        target_dir = ANDROID_RES / directory
        target_dir.mkdir(parents=True, exist_ok=True)
        resized.save(target_dir / "ic_launcher.png")
        resized.save(target_dir / "ic_launcher_round.png")


def draw_mark(*, size: int, include_background: bool) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), TRANSPARENT if not include_background else BACKGROUND)
    draw = ImageDraw.Draw(canvas)

    roof = [
        (size * 0.20, size * 0.43),
        (size * 0.50, size * 0.18),
        (size * 0.80, size * 0.43),
    ]
    body = (
        size * 0.27,
        size * 0.40,
        size * 0.73,
        size * 0.78,
    )
    chimney = (
        size * 0.62,
        size * 0.22,
        size * 0.68,
        size * 0.35,
    )
    radius = int(size * 0.055)
    stroke_width = max(2, int(size * 0.028))

    draw.rectangle(chimney, fill=HOUSE_DARK)
    draw.polygon(roof, fill=HOUSE, outline=STROKE, width=stroke_width)
    draw.rounded_rectangle(body, radius=radius, fill=HOUSE, outline=STROKE, width=stroke_width)

    font = ImageFont.truetype(FONT_PATH, int(size * 0.29))
    draw.text((size * 0.50, size * 0.585), "$", font=font, fill=WHITE, anchor="mm")

    if include_background:
        return canvas.convert("RGB")
    return canvas


if __name__ == "__main__":
    main()
