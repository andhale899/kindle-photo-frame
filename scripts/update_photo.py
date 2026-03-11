import os
import json
import requests
import re
from datetime import datetime, timedelta
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont
import icalendar
import dateutil.rrule

# --- Configuration ---
CONFIG_FILE = os.path.join(os.path.dirname(__file__), 'config.json')

def load_config():
    with open(CONFIG_FILE, 'r') as f:
        return json.load(f)

# --- 1. Fetch Image from Google Photos ---
def get_latest_image_url(album_url, fallback_url):
    print(f"Fetching album page: {album_url}")
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }
    
    try:
        response = requests.get(album_url, headers=headers, timeout=10)
        response.raise_for_status()
        
        # Regex to find high-res Google Photos URLs
        pattern = r'(https:\/\/lh3\.googleusercontent\.com\/[a-zA-Z0-9_-]+)'
        matches = re.findall(pattern, response.text)
        
        if not matches:
             raise Exception("No image URLs found in album HTML.")
             
        unique_urls = list(dict.fromkeys(matches))
        invalid_endings = ('/a', '/pw', '/ogw', '/s')
        
        photo_urls = []
        for url in unique_urls:
            hash_part = url.split('/')[-1]
            if len(hash_part) > 50 and not any(url.endswith(e) for e in invalid_endings):
                photo_urls.append(url)
                
        if not photo_urls:
            photo_urls = [u for u in unique_urls if len(u.split('/')[-1]) > 50]
            
        if not photo_urls:
            raise Exception("No valid high-res photo URLs found.")
            
        base_url = photo_urls[-1]
        download_url = f"{base_url}=w2000-h2000"
        print(f"Found latest image URL.")
        return download_url
        
    except Exception as e:
        print(f"Failed to scrape Google Photos: {e}. Using fallback image.")
        return fallback_url

# --- 2. Fetch Weather from Open-Meteo (No API key needed) ---
def get_weather(config):
    weather_cfg = config.get('weather', {})
    if not weather_cfg.get('enabled', False):
        return None
        
    lat = weather_cfg.get('latitude', 51.5)
    lon = weather_cfg.get('longitude', -0.1)
    
    url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current_weather=true"
    
    try:
        response = requests.get(url, timeout=5)
        response.raise_for_status()
        data = response.json()
        current = data.get('current_weather', {})
        
        temp = current.get('temperature', '?')
        code = current.get('weathercode', 0)
        
        # very basic weather code mapping
        weather_desc = "Clear"
        if code in [1, 2, 3]: weather_desc = "Cloudy"
        elif code in [45, 48]: weather_desc = "Fog"
        elif 50 <= code <= 69: weather_desc = "Rain"
        elif 70 <= code <= 79: weather_desc = "Snow"
        elif code >= 80: weather_desc = "Storm"
            
        unit = "C" if weather_cfg.get('units', 'celsius') == 'celsius' else "F"
        
        return f"{temp}°{unit} | {weather_desc}"
    except Exception as e:
        print(f"Weather fetch failed: {e}")
        return "Weather Unavailable"

# --- 3. Fetch Calendar Events ---
def get_calendar_events(config):
    cal_cfg = config.get('calendar', {})
    if not cal_cfg.get('enabled', False):
        return []
        
    events = []
    now = datetime.now()
    limit_date = now + timedelta(days=cal_cfg.get('max_days_ahead', 7))
    
    # We'll stub this out for now to avoid complex iCal parsing without valid URLs
    urls = cal_cfg.get('ics_urls', [])
    if urls and urls[0] != "https://p01-calendars.icloud.com/published/2/example":
       # Note: full implementation would parse icalendar here.
       pass
    
    return events

# --- 4. Process and Composite Image ---
def process_image(image_url, config):
    display_cfg = config.get('display', {})
    target_w = display_cfg.get('width', 1072)
    target_h = display_cfg.get('height', 1448)
    
    print("Downloading base image...")
    response = requests.get(image_url)
    response.raise_for_status()
    
    img = Image.open(BytesIO(response.content)).convert('RGB')
    
    # Crop to aspect ratio
    target_aspect = target_w / target_h
    img_aspect = img.width / img.height
    
    if img_aspect > target_aspect:
        new_w = int(target_aspect * img.height)
        offset = (img.width - new_w) / 2
        img = img.crop((offset, 0, img.width - offset, img.height))
    else:
        new_h = int(img.width / target_aspect)
        offset = (img.height - new_h) / 2
        img = img.crop((0, offset, img.width, img.height - offset))
        
    # Resize
    img = img.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    # Draw Overlays
    draw = ImageDraw.Draw(img)
    
    # Bottom Bar Background
    bar_height = 120
    draw.rectangle(
        [(0, target_h - bar_height), (target_w, target_h)],
        fill=(0, 0, 0)
    )
    
    # Weather Text
    weather_text = get_weather(config)
    if weather_text:
        # Using default font since we don't have TTF files locally
        # In a real setup, download a nice TTF font and use ImageFont.truetype
        font = ImageFont.load_default()
        draw.text((40, target_h - 80), weather_text, fill=(255, 255, 255), font=font)
    
    # Date Text
    date_str = datetime.now().strftime("%A, %B %d")
    font = ImageFont.load_default()
    draw.text((target_w - 200, target_h - 80), date_str, fill=(255, 255, 255), font=font)
    
    # Convert to Grayscale for Kindle
    if display_cfg.get('grayscale', True):
        img = img.convert('L')
        
    output_path = "screensaver.png"
    img.save(output_path, "PNG", optimize=True)
    print(f"Saved optimized Kindle image to: {output_path}")

if __name__ == "__main__":
    try:
        config = load_config()
        gphotos_cfg = config.get('google_photos', {})
        url = get_latest_image_url(
            gphotos_cfg.get('album_url'),
            gphotos_cfg.get('fallback_image_url')
        )
        process_image(url, config)
    except Exception as e:
        import traceback
        print("ERROR:", e)
        traceback.print_exc()
        exit(1)
