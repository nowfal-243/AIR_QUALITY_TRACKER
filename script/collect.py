import os
import sys
import logging
from datetime import datetime
import requests
import pandas as pd
import mysql.connector
from dotenv import load_dotenv

# Ensure data directory exists
os.makedirs("data", exist_ok=True)

# Configure logging
log_file = os.path.join("data", "collector.log")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(log_file, encoding="utf-8"),
        logging.StreamHandler(sys.stdout)
    ]
)

# Load environment variables
load_dotenv()

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", 3306))
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "air_quality")

def get_db_connection():
    return mysql.connector.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME
    )

def fetch_city_data(lat, lon):
    # Air Quality Endpoint
    aq_url = f"https://air-quality-api.open-meteo.com/v1/air-quality?latitude={lat}&longitude={lon}&hourly=pm2_5,pm10,nitrogen_dioxide,ozone,us_aqi&past_days=7"
    aq_resp = requests.get(aq_url, timeout=15)
    aq_resp.raise_for_status()
    aq_json = aq_resp.json()
    df_aq = pd.DataFrame(aq_json.get("hourly", {}))

    # Weather Endpoint
    weather_url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m&past_days=7"
    w_resp = requests.get(weather_url, timeout=15)
    w_resp.raise_for_status()
    w_json = w_resp.json()
    df_w = pd.DataFrame(w_json.get("hourly", {}))

    if df_aq.empty or df_w.empty:
        return pd.DataFrame()

    # Merge on timestamp
    df_merged = pd.merge(df_aq, df_w, on="time", how="inner")
    return df_merged

def process_and_insert():
    logging.info("Starting data collection process...")
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
    except Exception as e:
        logging.error(f"Failed to connect to MySQL database: {e}")
        return

    # Fetch active cities
    cursor.execute("SELECT city_id, city_name, latitude, longitude FROM cities")
    cities = cursor.fetchall()
    
    insert_sql = """
        INSERT IGNORE INTO readings 
        (city_id, reading_time, pm2_5, pm10, no2, ozone, us_aqi, temperature, humidity, wind_speed)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """

    now = datetime.now()

    for city in cities:
        city_id = city["city_id"]
        city_name = city["city_name"]
        lat = float(city["latitude"])
        lon = float(city["longitude"])

        try:
            df = fetch_city_data(lat, lon)
            if df.empty:
                logging.warning(f"No data returned for {city_name}")
                print(f"{city_name}: 0 rows processed")
                continue

            # Parse time column
            df["reading_time"] = pd.to_datetime(df["time"])
            
            # Keep only past and current hours
            df = df[df["reading_time"] <= now]
            
            # Drop rows with missing pm2_5 or us_aqi
            df = df.dropna(subset=["pm2_5", "us_aqi"])

            if df.empty:
                logging.info(f"No valid rows after filtering for {city_name}")
                print(f"{city_name}: 0 rows processed")
                continue

            # Prepare records
            records = []
            for _, row in df.iterrows():
                r_time = row["reading_time"].strftime("%Y-%m-%d %H:%M:%S")
                pm2_5 = float(row["pm2_5"]) if pd.notnull(row["pm2_5"]) else None
                pm10 = float(row["pm10"]) if pd.notnull(row["pm10"]) else None
                no2 = float(row["nitrogen_dioxide"]) if pd.notnull(row["nitrogen_dioxide"]) else None
                ozone = float(row["ozone"]) if pd.notnull(row["ozone"]) else None
                us_aqi = int(row["us_aqi"]) if pd.notnull(row["us_aqi"]) else None
                temp = float(row["temperature_2m"]) if pd.notnull(row["temperature_2m"]) else None
                hum = float(row["relative_humidity_2m"]) if pd.notnull(row["relative_humidity_2m"]) else None
                wind = float(row["wind_speed_10m"]) if pd.notnull(row["wind_speed_10m"]) else None

                records.append((city_id, r_time, pm2_5, pm10, no2, ozone, us_aqi, temp, hum, wind))

            cursor.executemany(insert_sql, records)
            conn.commit()

            processed_count = len(records)
            logging.info(f"Successfully processed {processed_count} rows for {city_name}")
            print(f"{city_name}: {processed_count} rows processed")

        except Exception as city_err:
            logging.error(f"Error processing city {city_name}: {city_err}")
            print(f"{city_name}: 0 rows processed (Error)")

    cursor.close()
    conn.close()
    logging.info("Data collection process finished.")

if __name__ == "__main__":
    process_and_insert()
