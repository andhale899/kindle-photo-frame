# Kindle Photo Frame — GitHub App

Scrapes a Google Photos shared album, picks 15 random photos each hour,
converts them to Kindle Paperwhite 7th gen grayscale PNGs (1072×1448),
overlays weather + date, and pushes them to a `processed-photos` branch
via GitHub Actions.

**No API keys required.** Weather is fetched from [wttr.in](https://wttr.in) for free.

---

## Files

```
├── .github/workflows/refresh_photos.yml   ← hourly GitHub Actions job
├── config/config.yml                       ← all settings live here
├── scripts/
│   ├── scrape_album.py                     ← Google Photos scraper
│   └── process_photos.py                   ← image processor
├── run_local.py                            ← local test runner (Windows/Mac/Linux)
└── requirements.txt
```

---

## Local Testing (Windows)

Requires **Python 3.10+**. Check with: `python --version`

```bat
# Clone / download the repo, then open a terminal in the folder

# Dry run — generates grey test cards, no internet needed
python run_local.py --dry-run

# Full run — scrapes album and downloads real photos
python run_local.py

# Process only 3 photos (faster for testing)
python run_local.py --dry-run --count 3
```

Output lands in `output_local\` — the folder opens automatically when done.

---

## GitHub Setup (2 steps)

### 1. Push this repo to GitHub

### 2. Enable Actions

Go to the **Actions** tab → click **"I understand my workflows, enable them"**

The workflow runs **every hour automatically**. You can also run it on-demand:
**Actions → Kindle Photo Refresh → Run workflow** (with optional dry-run toggle).

---

## Configuration

Everything is in `config/config.yml`:

```yaml
album:
  url: "https://photos.app.goo.gl/..."   # your Google Photos shared album
  pick_count: 15

weather:
  location: "Mumbai, IN"    # change to your city
  units: "metric"           # metric = C, imperial = F

datetime:
  timezone: "Asia/Kolkata"  # IANA timezone
  format: "%d %b %Y  |  %H:%M"

overlay:
  position: "bottom"        # top | bottom
  background_opacity: 0.55
```

---

## Kindle Integration

Processed photos are pushed to the `processed-photos` branch under `photos/`.

For a public repo, raw URLs follow this pattern:
```
https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/processed-photos/photos/photo_01.png
```

Point your Kindle's hourly poll at these URLs (or at a Cloudflare R2 bucket
if you're using the composite-image pipeline).

---

## Google Photos Scraping Note

The scraper parses `lh3.googleusercontent.com` URLs from the album's HTML.
This is best-effort — if Google changes their page structure it may break.
Check the Actions logs (`[scrape]` lines) if photos stop updating.
