import requests
import urllib.parse
import json

def debug_geocoding(location: str):
    url = f"https://geocoding-api.open-meteo.com/v1/search?name={urllib.parse.quote(location)}&count=1&language=en&format=json"
    print(f"URL: {url}")
    try:
        resp = requests.get(url, timeout=10)
        print(f"Status: {resp.status_code}")
        print(f"Body: {resp.text}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    debug_geocoding("Ahmednagar")
    print("-" * 20)
    debug_geocoding("Ahmednagar, India")
