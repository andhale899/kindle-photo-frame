#!/usr/bin/env python3
"""
process_photos.py
-----------------
Downloads images, converts to Kindle grayscale PNGs (1072x1448),
overlays weather via wttr.in (no API key) + date/time.
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
    "C:\\Windows\\Fonts\\arialbd.ttf",
    "C:\\Windows\\Fonts\\arial.ttf",
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
def fetch_weather_complex(location: str, units: str):
    """
    Returns (temp, desc) using wttr.in.
    Includes validation to prevent showing '0' for transient errors.
    """
    unit_param = "m" if units == "metric" else "u"
    url = f"https://wttr.in/{urllib.parse.quote(location)}?format=j1&{unit_param}"
    try:
        resp = requests.get(url, timeout=15, headers={"User-Agent": "kindle-photo-frame/1.1"})
        resp.raise_for_status()
        data = resp.json()
        current = data["current_condition"][0]
        temp = current["temp_C"] if units == "metric" else current["temp_F"]
        desc = current["weatherDesc"][0]["value"]
        
        # Validating temperature: 0 is mathematically possible but highly suspicious 
        # in some regions (like Ahmednagar, India) if it's the only value returned.
        # We check weatherCode or desc to see if it makes sense.
        if str(temp) == "0" and "Cloudy" not in desc and "Clear" not in desc:
            log.warning("Weather caught returning '0' suspiciously. Using None to trigger default/hide.")
            return None, None
            
        return str(temp), str(desc)
    except Exception as e:
        log.error("Weather fetch failed: %s", e)
        return None, None


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


def draw_overlay(img: Image.Image, now: datetime, temp: str, desc: str, cfg: dict, force_position=None) -> Image.Image:
    draw = ImageDraw.Draw(img, "RGBA")
    w, h = img.size
    pad  = cfg["padding"]
    position = force_position or cfg["position"]

    # Font sizes
    font_day     = get_font(cfg.get("font_size_date", 80))
    font_date    = get_font(cfg.get("font_size_desc", 40)) 
    font_temp    = get_font(cfg.get("font_size_weather", 150))
    font_weather = get_font(cfg.get("font_size_desc", 40))
    font_sync    = get_font(cfg.get("font_size_sync", 32))

    shadow_fill = (0, 0, 0, 220)
    white = (255, 255, 255, 255)
    off_white = (230, 230, 230, 255)

    def draw_text_with_shadow(draw, pos, text, font, fill, shadow_fill=(0, 0, 0, 220), anchor=None):
        if not text: return
        x, y = pos
        if anchor == "ra":
            bbox = draw.textbbox((0, 0), text, font=font)
            tw = bbox[2] - bbox[0]
            x -= tw

        for dx in [-2, -1, 0, 1, 2]:
            for dy in [-2, -1, 0, 1, 2]:
                if dx == 0 and dy == 0: continue
                draw.text((x + dx, y + dy), text, font=font, fill=shadow_fill)
        draw.text((x, y), text, font=font, fill=fill)

    # Positioning logic
    overlay_h = 240
    if position == "bottom":
        y_top = h - overlay_h - pad
    else:
        y_top = pad

    # 1. Left Side: Weekday & Date
    day_str  = now.strftime("%A")
    date_str = now.strftime("%B %d")
    draw_text_with_shadow(draw, (pad, y_top), day_str, font=font_day, fill=white)
    draw_text_with_shadow(draw, (pad, y_top + cfg.get("font_size_date", 80) - 5), date_str, font=font_date, fill=off_white)

    # 2. Right Side: Temperature (Gigantic)
    if temp:
        temp_text = f"{temp}°"
        draw_text_with_shadow(draw, (w - pad, y_top - 20), temp_text, font=font_temp, fill=white, anchor="ra")
        if desc:
            draw_text_with_shadow(draw, (w - pad, y_top + cfg.get("font_size_weather", 150) - 45), desc, font=font_weather, fill=off_white, anchor="ra")

    # 3. Bottom Center: Sync Status
    sync_str = f"Updated: {now.strftime('%H:%M')}"
    bbox = draw.textbbox((0, 0), sync_str, font=font_sync)
    sw = bbox[2] - bbox[0]
    draw_text_with_shadow(draw, ((w - sw) // 2, h - pad), sync_str, font=font_sync, fill=(180, 180, 180, 160))

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

    # Weather data
    temp, desc = (None, None)
    if wx_cfg["enabled"]:
        if args.dry_run:
            temp, desc = ("28", "Clear sky (dry-run)")
        else:
            temp, desc = fetch_weather_complex(wx_cfg["location"], wx_cfg["units"])

    log.info("Mode    : %s", "DRY RUN" if args.dry_run else "live")
    log.info("Temp    : %s°", temp or "(none)")
    log.info("Desc    : %s", desc or "(none)")
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

        # Enhanced overlay
        current_pos = "top" if idx % 2 == 0 else "bottom"
        img = draw_overlay(img, now, temp, desc, ov_cfg, force_position=current_pos)

        # Kindle compatibility hardening: 
        # Convert to 'L' (8-bit grayscale) and ensure no transparency or metadata
        final = img.convert("L")
        out_path = output_dir / f"photo_{idx:02d}.{k_cfg['output_format']}"
        
        # Explicitly save without ICC profile or extra chunks to prevent Kindle errors
        final.save(
            str(out_path), 
            dpi=(k_cfg["dpi"], k_cfg["dpi"]),
            icc_profile=None,
            pnginfo=None,
            optimize=True
        )
        log.info("       saved -> %s (hardened)", out_path.name)
        success += 1

    log.info("=" * 50)
    log.info("Done: %d / %d photos written to %s", success, len(urls), output_dir)

    if success == 0 and not args.dry_run:
        log.error("No photos processed — check album URL and network.")
        sys.exit(1)


if __name__ == "__main__":
    main()
