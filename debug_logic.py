import requests
import urllib.parse
import re
import json

def fetch_weather_complex(location: str, units: str):
    unit_param = "m" if units == "metric" else "u"
    url = f"https://wttr.in/{urllib.parse.quote(location)}?format=j1&{unit_param}"
    print(f"Fetching weather from: {url}")
    try:
        resp = requests.get(url, timeout=10, headers={"User-Agent": "kindle-photo-frame/1.0"})
        resp.raise_for_status()
        data = resp.json()
        current = data["current_condition"][0]
        temp = current["temp_C"] if units == "metric" else current["temp_F"]
        desc = current["weatherDesc"][0]["value"]
        return str(temp), str(desc)
    except Exception as e:
        print(f"Weather error: {e}")
        return None, None

def test_scraper(album_url):
    print(f"Testing scraper for: {album_url}")
    headers = {
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    }
    try:
        resp = requests.get(album_url, headers=headers, timeout=30)
        resp.raise_for_status()
        html = resp.text
        pattern = r'https://lh3\.googleusercontent\.com/pw/[A-Za-z0-9_\-]+'
        raw = re.findall(pattern, html)
        unique = list(dict.fromkeys(raw))
        print(f"Found {len(unique)} unique photo URLs.")
        # Print first few to see pattern
        for u in unique[:3]:
            print(f"  {u}")
    except Exception as e:
        print(f"Scraper error: {e}")

if __name__ == "__main__":
    t, d = fetch_weather_complex("Ahmednagar, IN", "metric")
    print(f"Result: Temp={t}, Desc={d}")
    
    test_scraper("https://photos.app.goo.gl/yBPwxSGuEEnwnhGk9")
