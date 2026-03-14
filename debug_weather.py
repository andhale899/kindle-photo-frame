import requests
import urllib.parse
import json

def fetch_weather_open_meteo(location: str):
    try:
        search_name = location.split(",")[0].strip()
        geo_url = f"https://geocoding-api.open-meteo.com/v1/search?name={urllib.parse.quote(search_name)}&count=1&language=en&format=json"
        geo_resp = requests.get(geo_url, timeout=10)
        geo_data = geo_resp.json()
        if not geo_data.get("results"):
            return None, None
        result = geo_data["results"][0]
        lat, lon = result["latitude"], result["longitude"]
        wx_url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,weather_code&timezone=auto"
        wx_resp = requests.get(wx_url, timeout=10)
        wx_data = wx_resp.json()["current"]
        temp = int(round(wx_data["temperature_2m"]))
        code = wx_data["weather_code"]
        descriptions = {0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast", 45: "Foggy", 48: "Depositing rime fog", 51: "Light drizzle", 53: "Moderate drizzle", 55: "Dense drizzle", 61: "Slight rain", 63: "Moderate rain", 65: "Heavy rain", 71: "Slight snow", 73: "Moderate snow", 75: "Heavy snow", 80: "Slight rain showers", 81: "Moderate rain showers", 82: "Violent rain showers", 95: "Thunderstorm"}
        desc = descriptions.get(code, "Clear")
        return str(temp), str(desc)
    except Exception as e:
        print(f"OM Error: {e}")
        return None, None

if __name__ == "__main__":
    t, d = fetch_weather_open_meteo("Ahmednagar, IN")
    print(f"Open-Meteo Result: Temp={t}, Desc={d}")
