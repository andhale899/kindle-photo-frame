#!/usr/bin/env python3
"""
scrape_album.py
---------------
Scrapes a Google Photos shared album page and extracts direct
high-resolution image URLs. Best-effort — Google may change their
page structure, but this approach has been stable for public albums.
"""

import re
import sys
import json
import random
import logging
import argparse
import urllib.request
import urllib.error

logging.basicConfig(level=logging.INFO, format="[scrape] %(message)s")
log = logging.getLogger(__name__)


def fetch_page(url: str) -> str:
    """Download the HTML of a shared Google Photos album page."""
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (X11; Linux x86_64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/122.0.0.0 Safari/537.36"
            )
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        log.error("HTTP %s fetching album: %s", e.code, url)
        sys.exit(1)
    except urllib.error.URLError as e:
        log.error("URL error fetching album: %s", e.reason)
        sys.exit(1)


def extract_image_urls(html: str) -> list[str]:
    """
    Extract unique high-res image base URLs from the page source.
    Google Photos embeds image URLs like:
      https://lh3.googleusercontent.com/XXXXX
    We strip the size suffix so we can request our own dimensions.
    """
    # Pattern matches lh3.googleusercontent.com URLs inside JS data blobs
    pattern = r'https://lh3\.googleusercontent\.com/[A-Za-z0-9_\-]+'
    raw = re.findall(pattern, html)

    # Deduplicate while preserving order
    seen = set()
    unique = []
    for url in raw:
        # Skip tiny thumbnails and avatars (they appear multiple times small)
        if url in seen:
            continue
        seen.add(url)
        unique.append(url)

    log.info("Found %d unique image base URLs", len(unique))
    return unique


def build_download_url(base_url: str, width: int, height: int) -> str:
    """
    Append Google's image sizing parameters to get a specific resolution.
    =wWIDTH-hHEIGHT-no  →  exact crop
    =wWIDTH-hHEIGHT     →  fit within box
    """
    return f"{base_url}=w{width}-h{height}"


def main():
    parser = argparse.ArgumentParser(description="Scrape Google Photos shared album")
    parser.add_argument("--url", required=True, help="Shared album URL")
    parser.add_argument("--count", type=int, default=15, help="Number of photos to pick")
    parser.add_argument("--width", type=int, default=1072, help="Target image width")
    parser.add_argument("--height", type=int, default=1448, help="Target image height")
    parser.add_argument("--output", default="image_urls.json", help="Output JSON file")
    args = parser.parse_args()

    log.info("Fetching album: %s", args.url)
    html = fetch_page(args.url)

    base_urls = extract_image_urls(html)

    if not base_urls:
        log.error(
            "No image URLs found. The album may be private, empty, or "
            "Google may have changed their page structure."
        )
        sys.exit(1)

    # Randomly pick `count` images (or all if fewer available)
    pick_count = min(args.count, len(base_urls))
    selected = random.sample(base_urls, pick_count)
    log.info("Selected %d / %d images", pick_count, len(base_urls))

    # Build full download URLs at the target resolution
    download_urls = [
        build_download_url(u, args.width, args.height) for u in selected
    ]

    with open(args.output, "w") as f:
        json.dump(download_urls, f, indent=2)

    log.info("Written %d URLs to %s", len(download_urls), args.output)


if __name__ == "__main__":
    main()
