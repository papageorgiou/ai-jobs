# /// script
# dependencies = ["pillow"]
# ///
"""Build the presentable deck from the slide PNGs and the narration script.

One source of truth for the words: OBSIDIAN/@INBOX/ai-jobs-video-script.md. This
reads the per-slide blocks out of it and emits slides.qmd, so editing the script
and re-running this keeps the speaker notes correct. Writing the narration into
the qmd by hand would give it a second home and the two would drift.

Outputs:
  slides.qmd   -> quarto render -> slides.html  (revealjs, press S for notes)
  slides.pdf                                    (one page per slide, 16:9)
"""
import re, pathlib, sys
from PIL import Image

ROOT   = pathlib.Path(__file__).parent
SLIDES = sorted((ROOT / "output_v2/slides_video").glob("*.png"))
SCRIPT = pathlib.Path("/Users/alexp/gd_alpapag/apclients/OBSIDIAN/@INBOX/ai-jobs-video-script.md")

body = SCRIPT.read_text().split("## The script")[1].split("## Timing")[0]
notes = dict(re.findall(r"\*\*(\w+)\*\*\n\n(.+?)(?=\n\n\*\*|\Z)", body, re.S))

missing = [p.stem for p in SLIDES if p.stem not in notes]
if missing:
    sys.exit(f"no narration for: {', '.join(missing)}")

out = ["""---
title: "The AI job title nobody was tracking"
format:
  revealjs:
    theme: simple
    width: 1920
    height: 1080
    margin: 0
    controls: true
    progress: true
    slide-number: false
    embed-resources: true
    background-color: "#FAF8F5"
---
"""]
for p in SLIDES:
    out.append(f'## {{background-image="{p.relative_to(ROOT)}" background-size="contain" '
               f'background-color="#FAF8F5"}}\n\n'
               f'::: {{.notes}}\n{notes[p.stem].strip()}\n:::\n')
(ROOT / "slides.qmd").write_text("\n".join(out))
print(f"wrote slides.qmd ({len(SLIDES)} slides)")

imgs = [Image.open(p).convert("RGB") for p in SLIDES]
imgs[0].save(ROOT / "slides.pdf", save_all=True, append_images=imgs[1:], resolution=150.0)
print(f"wrote slides.pdf ({len(imgs)} pages)")
