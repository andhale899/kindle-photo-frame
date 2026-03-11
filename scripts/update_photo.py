import os
import json
import requests
import re
from datetime import datetime
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont
import icalendar
from dateutil import rrule
import traceback

# --- Configuration ---
CONFIG_FILE = os.path.join(os.path.dirname(__file__), 'config.json')

def load_config():
    with open(CONFIG_FILE, 'r') as f:
        return json.load(f)

# --- 1. Fetch Images from Google Photos ---
def get_photo_urls(config):
    gp_cfg = config.get('google_photos', {})
    album_url = gp_cfg.get('album_url')
    max_images = gp_cfg.get('max_images', 15)
    fallback_url = gp_cfg.get('fallback_image_url')

    print(f"Fetching album page: {album_url}")
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    
    try:
        response = requests.get(album_url, headers=headers, timeout=15)
        response.raise_for_status()
        
        # Google Photos stores image data in a Wiz.data block (script tags)
        # We search for strings that look like high-res LH3 URLs
        # These URLs usually follow the pattern: https://lh3.googleusercontent.com/pw/[hash]
        # or https://lh3.googleusercontent.com/[hash]
        pattern = r'(https:\/\/lh3\.googleusercontent\.com\/[a-zA-Z0-9_-]+)'
        matches = re.findall(pattern, response.text)
        
        if not matches:
             raise Exception("No image URLs found in the album HTML.")
             
        # Extract unique high-res URLs
        unique_urls = list(dict.fromkeys(matches))
        
        # Filter for actual photos (usually long hashes, avoid avatars/UI icons)
        # Avatars often end in /a or have short hashes
        photo_urls = []
        for url in unique_urls:
            hash_part = url.split('/')[-1]
            if len(hash_part) > 50 and not url.endswith(('/a', '/pw', '/ogw', '/s')):
                photo_urls.append(url)
        
        if not photo_urls:
            # Fallback to any long hash if specific filtering is too tight
            photo_urls = [u for u in unique_urls if len(u.split('/')[-1]) > 50]

        if not photo_urls:
            raise Exception("No valid high-res photo URLs found.")

        # Real photos in the album are typically listed multiple times or in reverse order.
        # We take the last unique ones as they usually represent the most recent additions.
        selected_urls = photo_urls[::-1][:max_images]
        
        # Format for high quality (w2000-h2000) - Only for Google Photos
        final_urls = []
        for url in selected_urls:
            if 'googleusercontent.com' in url:
                final_urls.append(f"{url}=w2000-h2000")
            else:
                final_urls.append(url)
        
        print(f"Successfully identified {len(final_urls)} photos.")
        return final_urls

    except Exception as e:
        print(f"Warning: Failed to fetch Google Photos album: {e}")
        return [fallback_url]

# --- 2. Fetch Weather ---
def get_weather_info(config):
    w_cfg = config.get('weather', {})
    if not w_cfg.get('enabled'):
        return None
        
    lat, lon = w_cfg.get('latitude'), w_cfg.get('longitude')
    unit = w_cfg.get('units', 'celsius')
    
    url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current_weather=true"
    try:
        res = requests.get(url, timeout=5)
        res.raise_for_status()
        data = res.json().get('current_weather', {})
        temp = data.get('temperature', '?')
        code = data.get('weathercode', 0)
        
        # Simple weather code to text mapping
        desc = "Clear"
        if 1 <= code <= 3: desc = "Partly Cloudy"
        elif code in (45, 48): desc = "Fog"
        elif 51 <= code <= 67: desc = "Rain"
        elif 71 <= code <= 77: desc = "Snow"
        elif code >= 80: desc = "Storm"
        
        u_symbol = "°C" if unit == 'celsius' else "°F"
        return f"{temp}{u_symbol} | {desc}"
    except Exception as e:
        print(f"Weather fetch failed: {e}")
        return "Weather N/A"

# --- 3. Process Image ---
def process_single_image(url, index, config, info_text):
    print(f"Processing image {index}: {url[:60]}...")
    d_cfg = config.get('display', {})
    target_w, target_h = d_cfg.get('width', 1072), d_cfg.get('height', 1448)
    
    try:
        res = requests.get(url, timeout=20)
        res.raise_for_status()
        img = Image.open(BytesIO(res.content)).convert('RGB')
        
        # Resizing and center cropping
        target_ratio = target_w / target_h
        img_ratio = img.width / img.height
        
        if img_ratio > target_ratio:
            new_w = int(target_ratio * img.height)
            left = (img.width - new_w) / 2
            img = img.crop((left, 0, img.width - left, img.height))
        else:
            new_h = int(img.width / target_ratio)
            top = (img.height - new_h) / 2
            img = img.crop((0, top, img.width, img.height - top))
            
        img = img.resize((target_w, target_h), Image.Resampling.LANCZOS)
        
        # Drawing Overlays
        draw = ImageDraw.Draw(img)
        # Using a dark strip at the bottom for readability
        bar_h = 100
        # draw.rectangle([0, target_h - bar_h, target_w, target_h], fill=(0, 0, 0))
        # Semi-transparent overlay would be nicer but Kindle is grayscale - black is best
        draw.rectangle([(0, target_h - bar_h), (target_w, target_h)], fill=(0, 0, 0))
        
        # Font - using default as we don't know local paths
        try:
            # Try to load a generic TTF if it exists on the runner
            font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
            font = ImageFont.truetype(font_path, 40)
        except:
            font = ImageFont.load_default()
            
        # Draw Left Info (Weather/Date)
        draw.text((20, target_h - 70), info_text, fill=(255, 255, 255), font=font)
        
        # Draw Right Info (Image Index)
        idx_text = f"{index+1:02d}"
        draw.text((target_w - 70, target_h - 70), idx_text, fill=(255, 255, 255), font=font)
        
        # Final Conversion
        if d_cfg.get('grayscale', True):
            img = img.convert('L')
            
        out_name = f"bg_ss{index:02d}.png"
        img.save(out_name, "PNG", optimize=True)
        print(f"Generated {out_name}")
        
    except Exception as e:
        print(f"Error processing image {index}: {e}")

# --- Main Execution ---
if __name__ == "__main__":
    try:
        cfg = load_config()
        urls = get_photo_urls(cfg)
        weather = get_weather_info(cfg)
        date_str = datetime.now().strftime("%d %b %H:%M")
        
        full_info = f"{date_str}  |  {weather if weather else ''}"
        
        # Clean up old images before starting
        for f in os.listdir('.'):
            if f.startswith('bg_ss') and f.endswith('.png'):
                os.remove(f)

        for i, url in enumerate(urls):
            process_single_image(url, i, cfg, full_info)
            
    except Exception:
        traceback.print_exc()
        exit(1)
