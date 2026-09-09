#!/usr/bin/env python3
"""Render anatomy campaign JSON into a model-focused demo video."""
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

IN_JSON = Path("/opt/cursor/artifacts/anatomy_campaign_frames.json")
OUT_MP4 = Path("/opt/cursor/artifacts/anatomy_model_demo.mp4")
OUT_STRIP = Path("/opt/cursor/artifacts/anatomy_model_demo_strip.png")
OUT_INTRO = Path("/opt/cursor/artifacts/anatomy_model_demo_intro.png")
OUT_WALL = Path("/opt/cursor/artifacts/anatomy_model_demo_wall.png")


def font(size: int):
    for name in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def kind_style(kind: str, wet: float, crack: float):
    wet = max(0.0, min(1.0, wet or 0.0))
    crack = max(0.0, min(1.0, crack or 0.0))
    if kind == "bone":
        if crack > 0.35:
            return (255, 210, 140, 230), 5
        return (235, 225, 205, 200), 4
    if kind == "organ":
        return (200, 70, 90, 210), 6
    if kind == "flesh":
        return (160, 55, 70, 160), 4
    # skin
    r = int(200 + wet * 40)
    g = int(140 - wet * 50)
    b = int(120 - wet * 40)
    return (r, g, b, 150 + int(wet * 50)), 4


def draw_frame(fr: dict, w: int, h: int) -> Image.Image:
    img = Image.new("RGB", (w, h), (18, 20, 28))
    d = ImageDraw.Draw(img, "RGBA")

    # Floor grid for depth
    for i in range(0, w, 48):
        d.line([(i, h - 40), (i + 20, h)], fill=(40, 44, 58), width=1)
    d.rectangle([0, h - 36, w, h], fill=(28, 30, 40))

    # Wall plane
    wall = fr.get("wall")
    if wall and wall.get("pts") and len(wall["pts"]) >= 4:
        pts = [(p["x"], p["y"]) for p in wall["pts"]]
        alpha = 70 if not wall.get("broken") else 30
        d.polygon(pts, fill=(150, 150, 155, alpha))
        # studs
        if len(pts) >= 4:
            x0 = min(p[0] for p in pts)
            x1 = max(p[0] for p in pts)
            y0 = min(p[1] for p in pts)
            y1 = max(p[1] for p in pts)
            for t in (0.25, 0.5, 0.75):
                x = x0 + (x1 - x0) * t
                d.line([(x, y0), (x, y1)], fill=(110, 80, 45, 180), width=3)

    # Soft-body nodes — anatomy model hero
    for n in fr.get("nodes") or []:
        rgba, rad = kind_style(n.get("kind") or "skin", n.get("wet") or 0, n.get("crack") or 0)
        x, y = n["x"], n["y"]
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=rgba)

    # Organs as larger translucent blobs + labels on intro/slow frames
    for org in fr.get("organs") or []:
        integ = float(org.get("integrity") or 1)
        r = int(org.get("r", 0.7) * 255)
        g = int(org.get("g", 0.3) * 255)
        b = int(org.get("b", 0.3) * 255)
        rad = 10 + int((1.0 - integ) * 6)
        x, y = org["x"], org["y"]
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=(r, g, b, int(90 + 100 * integ)))
        if fr.get("tag") in ("model_intro", "stage_intro", "impact", "follow"):
            d.text((x + 8, y - 6), str(org.get("name") or ""), fill=(240, 230, 230, 200), font=font(11))

    # Blood
    for p in fr.get("blood") or []:
        free = p.get("free")
        fluid = p.get("fluid") or "blood"
        if fluid == "bile":
            col = (180, 190, 60, 180 if free else 120)
        else:
            col = (200, 30, 40, 200 if free else 130)
        rad = 3 if free else 2
        d.ellipse([p["x"] - rad, p["y"] - rad, p["x"] + rad, p["y"] + rad], fill=col)

    # Trail — thick bright red for demo readability
    trail = fr.get("trail") or []
    if len(trail) >= 2:
        for i in range(1, len(trail)):
            a, b = trail[i - 1], trail[i]
            t = i / len(trail)
            width = 2 + int(3 * t)
            d.line([(a["x"], a["y"]), (b["x"], b["y"])], fill=(255, 50 + int(40 * t), 50, 90 + int(140 * t)), width=width)

    # Bullet — high-contrast yellow core + white rim
    bul = fr.get("bullet")
    if bul:
        x, y = bul["x"], bul["y"]
        rad = int(bul.get("r") or 7)
        d.ellipse([x - rad - 3, y - rad - 3, x + rad + 3, y + rad + 3], fill=(255, 255, 220, 120))
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=(255, 230, 40, 255))
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(255, 255, 255, 255))

    # HUD
    stage = fr.get("stage") or 1
    rng = fr.get("rangeFeet")
    fps = fr.get("fps") or 0
    ftlb = fr.get("ftlb") or 0
    hr = fr.get("hr") or 0
    brain = (fr.get("brain") or 0) * 100
    mode = fr.get("mode") or ""
    tag = fr.get("tag") or ""
    wall_bit = fr.get("throughWall")
    title = "ANATOMY MODEL DEMO"
    if tag == "model_intro":
        title = "ANATOMY MODEL · soft-body showcase"
    line1 = f"STAGE {stage}  ·  {rng} ft" if not wall_bit else f"STAGE {stage}  ·  WALL"
    line2 = f".22 LR  {fps:.0f} fps  ·  {ftlb:.0f} ft·lbf"
    if wall_bit:
        line2 += f"  (Δv −{fr.get('wallDelta') or 0:.0f})"
    line3 = f"HR {hr:.0f}   Brain {brain:.0f}%   mode {mode}"
    d.rectangle([12, 12, 520, 108], fill=(12, 14, 20, 210))
    d.text((22, 18), title, fill=(255, 240, 230), font=font(16))
    d.text((22, 42), line1, fill=(220, 220, 235), font=font(14))
    d.text((22, 62), line2, fill=(180, 210, 255), font=font(13))
    d.text((22, 82), line3, fill=(200, 180, 160), font=font(13))

    nodes = fr.get("nodeCount") or len(fr.get("nodes") or [])
    d.text((w - 210, 18), f"model nodes {nodes}", fill=(160, 170, 190), font=font(12))
    return img.convert("RGB")


def main() -> None:
    data = json.loads(IN_JSON.read_text())
    frames = data["frames"]
    w, h = int(data["width"]), int(data["height"])
    print(f"Rendering {len(frames)} frames {w}x{h}")

    imgs = [draw_frame(fr, w, h) for fr in frames]

    # Key stills
    intro = next((i for i, fr in enumerate(frames) if fr.get("tag") == "model_intro"), 0)
    wall_i = next((i for i, fr in enumerate(frames) if fr.get("throughWall")), len(frames) - 1)
    imgs[intro].save(OUT_INTRO)
    imgs[wall_i].save(OUT_WALL)

    # Strip of stage intros
    stage_idxs = []
    seen = set()
    for i, fr in enumerate(frames):
        if fr.get("tag") == "stage_intro" and fr.get("stage") not in seen:
            seen.add(fr["stage"])
            stage_idxs.append(i)
    if not stage_idxs:
        stage_idxs = [0, len(frames) // 2, len(frames) - 1]
    thumbs = [imgs[i].resize((320, 180)) for i in stage_idxs[:7]]
    strip = Image.new("RGB", (320 * len(thumbs), 180), (10, 10, 14))
    for i, th in enumerate(thumbs):
        strip.paste(th, (i * 320, 0))
    strip.save(OUT_STRIP)

    try:
        import imageio.v2 as imageio
    except ImportError:
        import imageio  # type: ignore

    # ~18 fps for readable motion
    imageio.mimsave(OUT_MP4, imgs, fps=18)
    print(f"Wrote {OUT_MP4}")
    print(f"Wrote {OUT_INTRO}")
    print(f"Wrote {OUT_WALL}")
    print(f"Wrote {OUT_STRIP}")
    print("summary", data.get("summary"))


if __name__ == "__main__":
    main()
