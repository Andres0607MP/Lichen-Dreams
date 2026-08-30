from datetime import datetime, timezone, timedelta
from typing import Optional
import requests
import time


class WeatherService:
    @staticmethod
    def get_humidity(latitude: float, longitude: float, when: datetime) -> Optional[float]:
        """
        Obtain relative humidity (%) for given latitude, longitude and datetime from Open-Meteo.
        Returns None if any error occurs or data not available.
        Implements retry logic for transient network errors.
        """
        max_attempts = 3
        backoff_factors = [1, 2]  # seconds to wait between attempts
        for attempt in range(max_attempts):
            try:
                # Ensure UTC
                if when.tzinfo is None:
                    when = when.replace(tzinfo=timezone.utc)
                else:
                    when = when.astimezone(timezone.utc)

                # Round to nearest hour
                if when.minute < 30:
                    rounded = when.replace(minute=0, second=0, microsecond=0)
                else:
                    rounded = when.replace(minute=0, second=0, microsecond=0) + timedelta(hours=1)

                date_str = rounded.strftime("%Y-%m-%d")
                hour_str = rounded.strftime("%H:%M")
                # Open-Meteo expects hourly time in format "YYYY-MM-DDTHH:MM"
                target_time = f"{date_str}T{hour_str}"

                url = "https://api.open-meteo.com/v1/forecast"
                params = {
                    "latitude": latitude,
                    "longitude": longitude,
                    "hourly": "relativehumidity_2m",
                    "start_date": date_str,
                    "end_date": date_str,
                    "timezone": "UTC",
                }
                response = requests.get(url, params=params, timeout=8)
                response.raise_for_status()
                data = response.json()

                hourly = data.get("hourly", {})
                times = hourly.get("time", [])
                humidities = hourly.get("relativehumidity_2m", [])
                if not times or not humidities:
                    return None
                # Find index of target_time
                try:
                    idx = times.index(target_time)
                except ValueError:
                    return None
                value = humidities[idx]
                if value is None:
                    return None
                return float(value)
            except requests.RequestException as e:
                # Transient network error: retry if attempts remain
                if attempt < max_attempts - 1:
                    # Wait before retry
                    time.sleep(backoff_factors[attempt] if attempt < len(backoff_factors) else backoff_factors[-1])
                    continue
                else:
                    # Exhausted attempts
                    return None
            except (ValueError, KeyError, AttributeError):
                # Non-recoverable errors (e.g., JSON parsing, missing keys, attribute issues)
                return None
        return None