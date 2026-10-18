# Real app screenshots

`usage-light.png` is an actual capture of the running macOS app supplied by the maintainer.
Only the account email was replaced with `personal@example.com`. Quota values, reset times,
controls, typography, panel geometry, and shadows come from the original capture.

- `account-selector.png`, `quota-windows.png`, and `earned-reset.png` are exact crops of that sanitized capture.
- All exports are PNGs with the original alpha channel and without EXIF, XMP, ICC, timestamps, or source-path metadata.
- The original unredacted screenshot stays outside this repository. It is not copied into the app, website, or brand pack.
- No generative image editing, reconstructed product UI, or invented dark-mode screenshots are used.

## Sanitizing a matching capture

Install Pillow locally, then use `scripts/sanitize-screenshot.py` with the original file path.
The script accepts only the reviewed 492 × 572 layout; other dimensions require an explicit
coordinate review. It permanently overwrites the email pixels before exporting and cropping.
Review every resulting image before publication. Do not commit the original input.
