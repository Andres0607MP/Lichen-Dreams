import logging
from datetime import datetime, timezone, timedelta
from typing import Optional
import requests
import time

logger = logging.getLogger("lichdreams.weather")


class WeatherService:
    @staticmethod
    def get_humidity(latitude: float, longitude: float, when: datetime) -> Optional[float]:
        """
        Obtain relative humidity (%) for given latitude, longitude and datetime from Open-Meteo.
        Returns None if any error occurs or data not available.
        Implements retry logic for transient network errors.
        """
        max_attempts = 3
        backoff_factors = [1, 2]
        for attempt in range(max_attempts):
            try:
                if when.tzinfo is None:
                    when = when.replace(tzinfo=timezone.utc)
                else:
                    when = when.astimezone(timezone.utc)

                if when.minute < 30:
                    rounded = when.replace(minute=0, second=0, microsecond=0)
                else:
                    rounded = when.replace(minute=0, second=0, microsecond=0) + timedelta(hours=1)

                date_str = rounded.strftime("%Y-%m-%d")
                hour_str = rounded.strftime("%H:%M")
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
                    logger.warning(
                        "Open-Meteo response missing hourly data for %s",
                        date_str,
                    )
                    return None
                try:
                    idx = times.index(target_time)
                except ValueError:
                    logger.warning(
                        "Open-Meteo response does not contain target time %s (available: first=%s, last=%s)",
                        target_time,
                        times[0] if times else "none",
                        times[-1] if times else "none",
                    )
                    return None
                value = humidities[idx]
                if value is None:
                    return None
                return float(value)
            except requests.RequestException as e:
                if attempt < max_attempts - 1:
                    logger.warning(
                        "Open-Meteo request failed (attempt %d/%d): %s",
                        attempt + 1,
                        max_attempts,
                        type(e).__name__,
                    )
                    time.sleep(backoff_factors[attempt] if attempt < len(backoff_factors) else backoff_factors[-1])
                    continue
                else:
                    logger.error(
                        "Open-Meteo request exhausted retries: %s",
                        type(e).__name__,
                    )
                    return None
            except (ValueError, KeyError, AttributeError) as e:
                logger.error("Open-Meteo response parsing error: %s", type(e).__name__)
                return None
        return None