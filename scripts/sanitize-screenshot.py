#!/usr/bin/env python3
"""Redact one known email field in a real Usage Desk screenshot, without AI.

Input stays outside the repository. This script accepts only the reviewed
492 x 572 layout. Review different layouts and adjust the redaction rectangle
explicitly rather than assuming all screenshots have the same positions.
Requires Pillow (pip install Pillow). No OCR, uploads, or external services.
"""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("source", type=Path, help="Local original screenshot (never copied into the repo)")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
output = root / "assets/screenshots"
output.mkdir(parents=True, exist_ok=True)
original = Image.open(args.source).convert("RGBA")
if original.size != (492, 572):
    raise SystemExit("Unexpected dimensions. Review redaction coordinates for this screenshot before proceeding.")
# Replace the complete email field with opaque pixels. This is permanent
# redaction, not a reversible overlay or a blur that might reveal characters.
box = (94, 110, 280, 128)
font_file = Path("/System/Library/Fonts/SFNS.ttf")
if not font_file.exists():
    raise SystemExit("macOS system font unavailable. Choose a matching local font explicitly.")
scale = 4
patch = Image.new("RGBA", ((box[2]-box[0])*scale, (box[3]-box[1])*scale), "white")
draw = ImageDraw.Draw(patch)
font = ImageFont.truetype(str(font_file), 10*scale)
draw.text(((96-box[0])*scale, (122-box[1])*scale), "personal@example.com", font=font, fill="#686868", anchor="ls")
patch = patch.resize((box[2]-box[0], box[3]-box[1]), Image.Resampling.LANCZOS)
sanitized = Image.frombytes("RGBA", original.size, original.tobytes())
sanitized.paste(patch, box[:2])
# Create new images from pixel bytes so EXIF, XMP, ICC, source paths, and
# timestamps are not inherited. Preserve the original alpha/shadow pixels.
def save_clean(image, destination):
    clean = Image.frombytes("RGBA", image.size, image.tobytes())
    clean.save(destination, format="PNG", optimize=True)
    assert not Image.open(destination).info
save_clean(sanitized, output / "usage-light.png")
for name, crop in {
    "account-selector.png": (50, 88, 441, 132),
    "quota-windows.png": (50, 194, 441, 347),
    "earned-reset.png": (50, 354, 441, 392),
}.items():
    save_clean(sanitized.crop(crop), output / name)
print("Saved the anonymized real app capture and three exact crops. No source metadata retained.")
