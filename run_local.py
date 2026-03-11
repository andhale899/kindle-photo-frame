#!/usr/bin/env python3
"""
run_local.py  —  Test the full pipeline locally (Windows / Mac / Linux)
=======================================================================

Usage:
    python run_local.py                  # full run (scrapes + downloads)
    python run_local.py --dry-run        # test cards only, zero network needed
    python run_local.py --count 3        # only process 3 photos
    python run_local.py --dry-run --count 5

Output lands in:  output_local/
"""

import argparse
import json
import subprocess
import sys
import os
from pathlib import Path
import shutil

# ── Paths (all relative to this file's directory) ────────────────────────────
ROOT        = Path(__file__).parent.resolve()
CONFIG      = ROOT / "config" / "config.yml"
SCRIPTS     = ROOT / "scripts"
URLS_FILE   = ROOT / "output_local" / "_urls.json"
OUTPUT_DIR  = ROOT / "output_local"


def info(msg):  print(f"  [ok]  {msg}")
def warn(msg):  print(f"  [!!]  {msg}")
def step(msg):  print(f"\n{'='*55}\n  {msg}\n{'='*55}")
def die(msg):   print(f"\n  [ERR] {msg}"); sys.exit(1)


def run(cmd: list[str], **kwargs):
    """Run a subprocess, streaming output, raise on failure."""
    result = subprocess.run(cmd, **kwargs)
    if result.returncode != 0:
        die(f"Command failed (exit {result.returncode}): {' '.join(str(c) for c in cmd)}")


def install_deps():
    step("Installing / verifying dependencies")
    run([sys.executable, "-m", "pip", "install", "-q", "-r", str(ROOT / "requirements.txt")])
    info("Dependencies OK")


def read_config() -> dict:
    """Read config.yml without importing yaml (which may not be installed yet)."""
    # yaml is installed by install_deps(), so import after that call
    import yaml
    with open(CONFIG) as f:
        return yaml.safe_load(f)


def make_dummy_urls(count: int, path: Path):
    urls = [f"https://example.com/photo_{i}.jpg" for i in range(1, count + 1)]
    path.write_text(json.dumps(urls, indent=2))
    info(f"Written {count} dummy URLs to {path.name}")


def open_folder(path: Path):
    """Best-effort: open the output folder in the OS file explorer."""
    try:
        if sys.platform == "win32":
            os.startfile(str(path))
        elif sys.platform == "darwin":
            subprocess.Popen(["open", str(path)])
        else:
            subprocess.Popen(["xdg-open", str(path)])
    except Exception:
        pass  # non-critical


def main():
    parser = argparse.ArgumentParser(
        description="Local test runner for kindle-photo-frame",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--dry-run", action="store_true",
                        help="Skip all downloads; generate grey test cards instead")
    parser.add_argument("--count", type=int, default=None,
                        help="Override pick_count from config")
    args = parser.parse_args()

    print("\n  Kindle Photo Frame — Local Runner")
    print(f"  Root : {ROOT}")
    print(f"  Mode : {'DRY RUN (no network)' if args.dry_run else 'LIVE'}")

    # 1. Deps
    install_deps()

    # 2. Config
    step("Reading config")
    cfg        = read_config()
    album_url  = cfg["album"]["url"]
    pick_count = args.count or cfg["album"]["pick_count"]
    width      = cfg["kindle"]["width"]
    height     = cfg["kindle"]["height"]

    info(f"Album  : {album_url}")
    info(f"Photos : {pick_count}  |  {width}x{height}px")
    info(f"Output : {OUTPUT_DIR}")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    URLS_FILE.parent.mkdir(parents=True, exist_ok=True)

    # 3. Scrape (or dummy)
    if args.dry_run:
        step("Generating dummy URLs (dry-run — no network)")
        make_dummy_urls(pick_count, URLS_FILE)
    else:
        step("Step 1 / 2  —  Scraping Google Photos album")
        run([
            sys.executable, str(SCRIPTS / "scrape_album.py"),
            "--url",    album_url,
            "--count",  str(pick_count),
            "--width",  str(width),
            "--height", str(height),
            "--output", str(URLS_FILE),
        ])

    # 4. Process
    step("Step 2 / 2  —  Processing photos")
    cmd = [
        sys.executable, str(SCRIPTS / "process_photos.py"),
        "--urls-file",  str(URLS_FILE),
        "--config",     str(CONFIG),
        "--output-dir", str(OUTPUT_DIR),
    ]
    if args.dry_run:
        cmd.append("--dry-run")
    run(cmd)

    # 5. Summary
    pngs = sorted(OUTPUT_DIR.glob("photo_*.png"))
    print(f"\n{'='*55}")
    print(f"  Done!  {len(pngs)} photo(s) written to:")
    print(f"  {OUTPUT_DIR}")
    print(f"{'='*55}\n")
    for p in pngs:
        size_kb = p.stat().st_size // 1024
        print(f"    {p.name}  ({size_kb} KB)")

    if pngs:
        print()
        info("Opening output folder…")
        open_folder(OUTPUT_DIR)


if __name__ == "__main__":
    main()
