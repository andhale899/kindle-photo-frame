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
def fetch_weather_open_meteo(location: str):
    """
    Returns (temp, desc) using Open-Meteo + Geocoding API.
    No API key required.
    """
    try:
        # 1. Geocoding: Resolve location string to coordinates
        # Strip suffix like ", IN" or ", India" as the API prefers just the name
        search_name = location.split(",")[0].strip()
        geo_url = f"https://geocoding-api.open-meteo.com/v1/search?name={urllib.parse.quote(search_name)}&count=1&language=en&format=json"
        geo_resp = requests.get(geo_url, timeout=10)
        geo_resp.raise_for_status()
        geo_data = geo_resp.json()
        
        if not geo_data.get("results"):
            log.warning("Open-Meteo Geocoding failed for: %s", location)
            return None, None
            
        result = geo_data["results"][0]
        lat, lon = result["latitude"], result["longitude"]
        
        # 2. Forecast: Get current weather
        # We map the weather code to a description roughly
        wx_url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,weather_code&timezone=auto"
        wx_resp = requests.get(wx_url, timeout=10)
        wx_resp.raise_for_status()
        wx_data = wx_resp.json()["current"]
        
        temp = int(round(wx_data["temperature_2m"]))
        code = wx_data["weather_code"]
        
        # Simple mapping for common codes (WMO Weather interpretation codes)
        descriptions = {
            0: "Clear sky",
            1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
            45: "Foggy", 48: "Depositing rime fog",
            51: "Light drizzle", 53: "Moderate drizzle", 55: "Dense drizzle",
            61: "Slight rain", 63: "Moderate rain", 65: "Heavy rain",
            71: "Slight snow", 73: "Moderate snow", 75: "Heavy snow",
            80: "Slight rain showers", 81: "Moderate rain showers", 82: "Violent rain showers",
            95: "Thunderstorm",
        }
        desc = descriptions.get(code, "Clear")
        
        log.info("Open-Meteo Success: %sC, %s", temp, desc)
        return str(temp), str(desc)
    except Exception as e:
        log.warning("Open-Meteo fetch failed: %s", e)
        return None, None

def fetch_weather_complex(location: str, units: str):
    """
    Tries multiple weather sources for maximum reliability.
    1. Open-Meteo (Primary)
    2. wttr.in (Fallback)
    """
    # Try Open-Meteo first
    temp, desc = fetch_weather_open_meteo(location)
    if temp is not None:
        return temp, desc

    # Fallback to wttr.in
    log.info("Open-Meteo failed or returned 0, attempting wttr.in fallback...")
    unit_param = "m" if units == "metric" else "u"
    url = f"https://wttr.in/{urllib.parse.quote(location)}?format=j1&{unit_param}"
    try:
        resp = requests.get(url, timeout=15, headers={"User-Agent": "kindle-photo-frame/1.1"})
        resp.raise_for_status()
        data = resp.json()
        current = data["current_condition"][0]
        temp = current["temp_C"] if units == "metric" else current["temp_F"]
        desc = current["weatherDesc"][0]["value"]
        
        if str(temp) == "0" and "Cloudy" not in desc and "Clear" not in desc:
            log.warning("wttr.in returned suspicious '0'.")
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
            # Fixed overlap by reducing the negative offset (was -45, now -20)
            draw_text_with_shadow(draw, (w - pad, y_top + cfg.get("font_size_weather", 150) - 20), desc, font=font_weather, fill=off_white, anchor="ra")

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
