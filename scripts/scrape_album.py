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


def fetch_page(url: str, retries: int = 3) -> str:
    """Download the HTML of a shared Google Photos album page with retries."""
    for i in range(retries):
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
        except (urllib.error.HTTPError, urllib.error.URLError) as e:
            if i == retries - 1:
                log.error("Failed to fetch album after %d attempts: %s", retries, str(e))
                sys.exit(1)
            log.warning("Attempt %d failed, retrying in 5s... (%s)", i + 1, str(e))
            import time
            time.sleep(5)
    return ""  # Should be unreachable due to sys.exit(1) above


def extract_image_urls(html: str) -> list[str]:
    """
    Extract unique high-res image base URLs using the AF_initDataCallback JSON.
    This bypasses lazy-loading limits of 30-31 photos.
    """
    # 1. Broad regex to find all potential image base URLs
    # Pattern: lh3.googleusercontent.com/pw/XXXXX
    pattern = r'https://lh3\.googleusercontent\.com/pw/[A-Za-z0-9_\-]+'
    
    # 2. Look for the actual JSON data blob where Google stores internal IDs
    # This usually exists in a script tag like: AF_initDataCallback({key: 'ds:1', ... data: [...]})
    # We find the one with ds:1 as it's the main album content
    ds1_match = re.search(r'AF_initDataCallback\(\{key: \'ds:1\'.*?data:(.*?)\}\);</script>', html, re.DOTALL)
    
    found_urls = []
    if ds1_match:
        data_str = ds1_match.group(1).strip()
        # Google's JS object isn't strictly valid JSON (unquoted keys), but the inner list often is
        # We rely on the regex above but deduplicate them while respecting the JSON structure if possible.
        # However, for simplicity and robustness against Google's changes, 
        # combining the ds:1 search with the URL pattern is most effective.
        found_urls = re.findall(pattern, ds1_match.group(0))
    else:
        # Fallback to general page-wide regex if ds:1 is missing
        found_urls = re.findall(pattern, html)

    # Deduplicate while preserving order
    seen = set()
    unique = []
    for url in found_urls:
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
