#!/usr/bin/env python3
"""
process_photos.py
-----------------
Downloads images, converts to Kindle grayscale PNGs (1072x1448),
overlays weather via wttr.in (no API key) + date/time.

Local usage:
    python3 scripts/process_photos.py \
        --urls-file /tmp/urls.json \
        --config    config/config.yml \
        --output-dir ./output

Dry-run (no downloads — generates grey test cards):
    python3 scripts/process_photos.py \
        --urls-file /tmp/urls.json \
        --config    config/config.yml \
        --output-dir ./output \
        --dry-run
"""

import io
import json
import logging
import math
import os
import sys
import argparse
import urllib.parse
from datetime import datetime
from pathlib import Path

import pytz
import requests
import yaml
from PIL import Image, ImageDraw, ImageFont, ImageFilter

logging.basicConfig(level=logging.INFO, format="[process] %(message)s")
log = logging.getLogger(__name__)


# ── Font fallback chain ───────────────────────────────────────────────────────
FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "/System/Library/Fonts/Arial.ttf",
]


def get_font(size: int):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    log.warning("No TrueType font found, using bitmap fallback")
    return ImageFont.load_default()


# ── Weather via wttr.in (no API key required) ─────────────────────────────────
def fetch_weather(location: str, units: str) -> str:
    """
    Returns a one-line weather string using wttr.in free JSON endpoint.
    Falls back to empty string on any failure.
    """
    unit_param = "m" if units == "metric" else "u"
    url = f"https://wttr.in/{urllib.parse.quote(location)}?format=j1&{unit_param}"
    try:
        resp = requests.get(
            url, timeout=10,
            headers={"User-Agent": "kindle-photo-frame/1.0"},
        )
        resp.raise_for_status()
        data = resp.json()
        current  = data["current_condition"][0]
        temp     = current["temp_C"] if units == "metric" else current["temp_F"]
        unit_sym = "C" if units == "metric" else "F"
        desc     = current["weatherDesc"][0]["value"]
        code     = int(current.get("weatherCode", 0))

        if code == 113:                     icon = "Sunny"
        elif code in (116, 119, 122):       icon = "Cloudy"
        elif 176 <= code <= 308:            icon = "Rain"
        elif code in (200, 386, 389):       icon = "Storm"
        elif 179 <= code <= 377:            icon = "Snow"
        elif code in (143, 248, 260):       icon = "Fog"
        else:                               icon = ""

        parts = [p for p in [icon, f"{temp}{unit_sym}", desc] if p]
        return "  ".join(parts)

    except Exception as e:
        log.warning("wttr.in weather fetch failed (%s) — overlay skipped", e)
        return ""


# ── Image download ────────────────────────────────────────────────────────────
def download_image(url: str):
    try:
        resp = requests.get(url, timeout=30, stream=True)
        resp.raise_for_status()
        return Image.open(io.BytesIO(resp.content)).convert("RGB")
    except Exception as e:
        log.warning("Download failed: %s — %s", url, e)
        return None


def make_test_card(width: int, height: int, idx: int) -> Image.Image:
    """Grey placeholder card for --dry-run mode."""
    shade = 60 + (idx * 18) % 120
    img   = Image.new("RGB", (width, height), color=(shade, shade, shade))
    draw  = ImageDraw.Draw(img)
    font  = get_font(56)
    label = f"TEST CARD {idx:02d}"
    bb    = draw.textbbox((0, 0), label, font=font)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    draw.text(((width - tw) // 2, (height - th) // 2), label, font=font, fill=(190, 190, 190))
    return img


# ── Kindle processing ─────────────────────────────────────────────────────────
def fit_and_crop(img: Image.Image, width: int, height: int) -> Image.Image:
    src_w, src_h = img.size
    scale = max(width / src_w, height / src_h)
    nw, nh = math.ceil(src_w * scale), math.ceil(src_h * scale)
    img  = img.resize((nw, nh), Image.LANCZOS)
    left = (nw - width) // 2
    top  = (nh - height) // 2
    return img.crop((left, top, left + width, top + height))


def to_kindle_grayscale(img: Image.Image) -> Image.Image:
    gray = img.convert("L")
    return gray.filter(ImageFilter.UnsharpMask(radius=1.2, percent=110, threshold=3))


def draw_overlay(img: Image.Image, date_text: str, weather_text: str, cfg: dict) -> Image.Image:
    draw = ImageDraw.Draw(img, "RGBA")
    w, h = img.size
    pad  = cfg["padding"]

    font_date    = get_font(cfg["font_size_date"])
    font_weather = get_font(cfg["font_size_weather"])

    _, _, _, date_h = draw.textbbox((0, 0), date_text or " ", font=font_date)
    _, _, _, wx_h   = draw.textbbox((0, 0), weather_text or " ", font=font_weather)

    has_weather = bool(weather_text)
    bar_h   = date_h + (wx_h if has_weather else 0) + pad * (3 if has_weather else 2)
    bar_top = h - bar_h if cfg["position"] == "bottom" else 0

    alpha = int(cfg["background_opacity"] * 255)
    draw.rectangle([(0, bar_top), (w, bar_top + bar_h)], fill=(0, 0, 0, alpha))

    y = bar_top + pad
    if date_text:
        draw.text((pad, y), date_text, font=font_date, fill=(255, 255, 255, 240))
        y += date_h + pad // 2
    if has_weather:
        draw.text((pad, y), weather_text, font=font_weather, fill=(210, 210, 210, 220))

    return img


# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="Process photos for Kindle Paperwhite")
    parser.add_argument("--urls-file",  required=True)
    parser.add_argument("--config",     required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Skip downloads; generate grey test cards (for local testing)",
    )
    args = parser.parse_args()

    with open(args.config) as f:
        cfg = yaml.safe_load(f)
    with open(args.urls_file) as f:
        urls = json.load(f)

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    k_cfg  = cfg["kindle"]
    ov_cfg = cfg["overlay"]
    dt_cfg = cfg["datetime"]
    wx_cfg = cfg["weather"]

    # Date string
    tz        = pytz.timezone(dt_cfg["timezone"])
    now       = datetime.now(tz)
    date_text = now.strftime(dt_cfg["format"]) if dt_cfg["enabled"] else ""

    # Weather string — wttr.in, zero config
    weather_text = ""
    if wx_cfg["enabled"]:
        if args.dry_run:
            weather_text = "Sunny  28C  Clear sky (dry-run)"
        else:
            weather_text = fetch_weather(wx_cfg["location"], wx_cfg["units"])

    log.info("Mode    : %s", "DRY RUN" if args.dry_run else "live")
    log.info("Date    : %s", date_text or "(disabled)")
    log.info("Weather : %s", weather_text or "(none)")
    log.info("Photos  : %d URLs", len(urls))
    log.info("Output  : %s", output_dir)

    success = 0
    for idx, url in enumerate(urls, start=1):
        action = "test card" if args.dry_run else "download"
        log.info("[%02d/%02d] %s", idx, len(urls), action)

        if args.dry_run:
            img = make_test_card(k_cfg["width"], k_cfg["height"], idx)
        else:
            img = download_image(url)
            if img is None:
                continue

        img   = fit_and_crop(img, k_cfg["width"], k_cfg["height"])
        img   = to_kindle_grayscale(img)
        img   = img.convert("RGBA")

        if date_text or weather_text:
            img = draw_overlay(img, date_text, weather_text, ov_cfg)

        final    = img.convert("L")
        out_path = output_dir / f"photo_{idx:02d}.{k_cfg['output_format']}"
        final.save(str(out_path), dpi=(k_cfg["dpi"], k_cfg["dpi"]))
        log.info("       saved -> %s", out_path.name)
        success += 1

    log.info("=" * 50)
    log.info("Done: %d / %d photos written to %s", success, len(urls), output_dir)

    if success == 0 and not args.dry_run:
        log.error("No photos processed — check album URL and network.")
        sys.exit(1)


if __name__ == "__main__":
    main()
