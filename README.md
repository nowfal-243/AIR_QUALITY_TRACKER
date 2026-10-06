# Real-Time Air Quality & Meteorological Analytics Tracker

An end-to-end automated data pipeline, relational database, exploratory data analysis, predictive model, and visual reporting solution for tracking global Air Quality Index (US AQI), fine particulate matter (PM2.5, PM10, NO2, Ozone), and meteorological interactions across major global cities.

---

## 📌 Problem Statement
Urban air pollution presents severe public health risks and economic burdens worldwide. However, environmental monitoring data is often siloed, unstandardized, or lack integrated meteorological context. 

This project solves this challenge by establishing an automated, resilient data pipeline that ingests real-time air quality and weather parameters, stores structured historical records in a relational database, performs advanced SQL and Python exploratory analytics, forecasts short-term AQI levels, and renders interactive business dashboards for civic decision-makers.

---

## 🏗️ System Architecture

```
                                  SYSTEM ARCHITECTURE
  +-----------------------+     +-----------------------+     +-----------------------+
  | Open-Meteo Air Quality|     |  Open-Meteo Weather   |     | Windows Task Scheduler|
  |          API          |     |          API          |     |     (Hourly Cron)     |
  +-----------+-----------+     +-----------+-----------+     +-----------+-----------+
              |                             |                             |
              +--------------+--------------+                             |
                             |                                            |
                             v                                            v
                   +-------------------+                        +-------------------+
                   | Pandas Data Engine| <--------------------- | script/collect.py |
                   | (Merge & Filter)  |                        +-------------------+
                   +---------+---------+
                             |
                             v
                   +-------------------+
                   |  MySQL Database   |
                   |   (air_quality)   |
                   +---------+---------+
                             |
              +--------------+--------------+
              |                             |
              v                             v
   +-------------------+         +-------------------+
   | Python EDA / ML   |         | Power BI & Excel  |
   | (notebooks/eda)   |         |  (v_air_quality)  |
   +-------------------+         +-------------------+
```

### Data Pipeline Flow:
1. **API Ingestion**: Python `script/collect.py` fetches hourly pollutant data (`pm2_5`, `pm10`, `no2`, `ozone`, `us_aqi`) and weather data (`temperature`, `humidity`, `wind_speed`) from Open-Meteo REST APIs.
2. **ETL & Data Cleaning**: Pandas merges endpoints on hourly timestamps, filters past/current hours, drops null pollution records, and prepares tuples.
3. **Relational Storage**: Inserts cleaned records into MySQL `readings` table using `INSERT IGNORE` to guarantee idempotency and zero duplicates.
4. **Automated Scheduling**: Windows Task Scheduler triggers `script/collect.py` every hour using `python3.13.exe`.
5. **SQL & Python EDA**: SQL window functions and Python notebook (`notebooks/eda.ipynb`) calculate rolling averages, peak hours, weather correlations, and train a Linear Regression short-term AQI forecast engine.
6. **Business Intelligence**: Power BI connects to MySQL view `v_air_quality` to display executive KPI cards, spatial maps, trend lines, and weather correlation scatter plots.

---

## 🛠️ Tools & Technologies
- **Programming & Data Ingestion**: Python 3.13, Pandas, Requests, Python-Dotenv
- **Relational Database**: MySQL 8.0, SQLAlchemy, PyMySQL, MySQL-Connector-Python
- **Exploratory Data Analysis & ML**: Jupyter Notebook, Matplotlib, Seaborn, Scikit-Learn
- **Business Intelligence & Reporting**: Microsoft Power BI Desktop, Microsoft Excel
- **Automation & System OS**: Windows Task Scheduler, Windows PowerShell

---

## 📁 Repository Structure
```
d:\AIR_QUALITY_TRACKER\
├── .env                  # Environment database credentials (git-ignored)
├── .env.example          # Environment variable template
├── .gitignore            # Excluded files and folders
├── README.md             # Complete project documentation & guide
├── requirements.txt      # Python library dependencies
├── data/
│   ├── collector.log     # Automated data ingestion log file
│   └── air_quality_export.csv # CSV export of v_air_quality view
├── notebooks/
│   └── eda.ipynb         # Executed Jupyter Notebook with charts & ML model
├── script/
│   ├── collect.py        # Main Python ETL data collection script
│   └── setup_task.ps1    # PowerShell script to register Windows Scheduled Task
└── sql/
    ├── schema.sql        # Database creation, tables DDL, and city seeds
    └── analysis.sql      # Analytical queries, window functions, and view DDL
```

---

## 🚀 How to Run the Project

### 1. Database Setup
Ensure MySQL Server 8.0 is running locally. Execute `sql/schema.sql` to build the database, tables, foreign keys, and seed the 8 target cities:
```bash
python -c "
import mysql.connector
conn = mysql.connector.connect(host='localhost', user='root', password='YOUR_PASSWORD')
cursor = conn.cursor()
with open('sql/schema.sql', 'r') as f:
    statements = f.read().split(';')
for stmt in statements:
    if stmt.strip():
        cursor.execute(stmt)
conn.commit()
conn.close()
"
```

### 2. Configure Environment Variables
Copy `.env.example` to `.env` and fill in your MySQL credentials:
```env
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=root123
DB_NAME=air_quality
```

### 3. Install Python Dependencies
```bash
pip install -r requirements.txt
```

### 4. Run Manual Ingestion & Verify
Run the collector script manually to populate historical data:
```bash
python script/collect.py
```
Output:
```text
New Delhi: 186 rows processed
Mumbai: 186 rows processed
Bengaluru: 186 rows processed
London: 186 rows processed
New York: 186 rows processed
Tokyo: 186 rows processed
Beijing: 186 rows processed
Sydney: 186 rows processed
```

### 5. Automated Scheduling (Windows Task Scheduler)
Option A: Run the provided PowerShell setup script (as Administrator):
```powershell
powershell -ExecutionPolicy Bypass -File d:\AIR_QUALITY_TRACKER\script\setup_task.ps1
```
Option B: Manual Windows Task Scheduler Configuration:
1. Open **Task Scheduler** -> Click **Create Task...**.
2. Name: `AirQualityCollector`.
3. Trigger: **Daily** -> Repeat task every **1 hour** indefinitely.
4. Action: **Start a program** -> Program: `C:\Users\vstru\AppData\Local\Programs\Python\Python313\python.exe` -> Arguments: `script\collect.py` -> Start in: `d:\AIR_QUALITY_TRACKER`.

**Verification Query**:
```sql
SELECT c.city_name, MAX(r.reading_time) AS latest_reading 
FROM readings r JOIN cities c USING (city_id) GROUP BY c.city_name;
```

---

## 📊 SQL Analysis Queries (`sql/analysis.sql`)
The repository includes 6 commented SQL analytical queries:
1. **Daily Average AQI per City**: Aggregates AQI by date to evaluate day-over-day progression.
2. **Peak Pollution Hour per City**: Uses `ROW_NUMBER() OVER (PARTITION BY city_id ORDER BY us_aqi DESC)` to identify maximum pollution timestamps.
3. **7-Day Rolling Average AQI**: Uses window function `ROWS BETWEEN 6 PRECEDING AND CURRENT ROW` on daily averages to smooth hourly spikes.
4. **Hours with AQI > 200**: Counts critical hazardous/unhealthy hours per city.
5. **Weekday vs Weekend Comparison**: Evaluates traffic impact on air quality.
6. **View `v_air_quality`**: Joins `cities` and `readings`, computing time attributes (`reading_date`, `reading_hour`, `day_of_week`, `day_type`) and `aqi_category`.

---

## 📈 Python Exploratory Data Analysis & Machine Learning (`notebooks/eda.ipynb`)
- **Data Quality Audit**: Verified 1,488 rows with 0 missing values in critical pollution columns and 0 duplicates.
- **Hourly Pattern Analysis**: Highlights morning rush hour (8:00 AM) and evening peak (7:00 PM) AQI elevations.
- **Meteorological Heatmap**: Establishes strong inverse relationship between wind speed and PM2.5 concentrations.
- **Linear Regression Forecast Engine**:
  - Model: Predicts next-hour AQI using `aqi_lag1`, `temperature`, `humidity`, `wind_speed`, and `reading_hour`.
  - **Mean Absolute Error (MAE)**: `2.54 AQI points` ($R^2 > 0.98$).
  - **Plain-Words MAE Explanation**: On average, the predictive model's AQI estimate deviates from actual measurements by only 2.54 index points on a 0-500 AQI scale (< 3% variance), enabling reliable short-term public health warnings.

---

## 📈 Power BI & Excel Dashboards

### Excel Pivot Validation Guide
1. Import `data/air_quality_export.csv` into Excel.
2. Insert Pivot Table: `reading_hour` on Rows, `city_name` on Columns, `Average of us_aqi` on Values.
3. Apply Conditional Formatting -> Color Scale (Green for low AQI, Red/Maroon for high AQI).
4. Verify numbers match SQL query output.

### Power BI Implementation & DAX Measures
Connect Power BI Desktop to MySQL database `air_quality` and import view `v_air_quality`.
Create `DateTable` using DAX:
```dax
DateTable = CALENDAR(MIN(v_air_quality[reading_date]), MAX(v_air_quality[reading_date]))
```

#### Key DAX Measures:
```dax
Avg AQI = AVERAGE(v_air_quality[us_aqi])

AQI Category = 
VAR CurrentAQI = [Avg AQI]
RETURN
    SWITCH(
        TRUE(),
        CurrentAQI <= 50, "Good",
        CurrentAQI <= 100, "Moderate",
        CurrentAQI <= 150, "Unhealthy for Sensitive Groups",
        CurrentAQI <= 200, "Unhealthy",
        CurrentAQI <= 300, "Very Unhealthy",
        "Hazardous"
    )

% Hours Above Limit = 
VAR HoursAbove = CALCULATE(COUNT(v_air_quality[reading_id]), v_air_quality[us_aqi] > 200)
VAR TotalHours = COUNT(v_air_quality[reading_id])
RETURN DIVIDE(HoursAbove, TotalHours, 0)

7-Day Moving Avg = 
CALCULATE(
    [Avg AQI],
    DATESINPERIOD('DateTable'[Date], MAX('DateTable'[Date]), -7, DAY)
)

Change vs Last Week = 
VAR CurrentAQI = [Avg AQI]
VAR PreviousAQI = CALCULATE([Avg AQI], DATEADD('DateTable'[Date], -7, DAY))
RETURN IF(ISBLANK(PreviousAQI), BLANK(), DIVIDE(CurrentAQI - PreviousAQI, PreviousAQI, 0))
```

---

## 🖼️ Dashboard Screenshots Placeholders

### Overview Page
![Overview Page Placeholder](https://via.placeholder.com/1000x550.png?text=Power+BI+Overview+Page+-+KPIs,+Map,+and+City+Rankings)

### Trends Page
![Trends Page Placeholder](https://via.placeholder.com/1000x550.png?text=Power+BI+Trends+Page+-+Hourly+and+Daily+Line+Charts+with+Slicers)

### Weather Impact Page
![Weather Impact Page Placeholder](https://via.placeholder.com/1000x550.png?text=Power+BI+Weather+Impact+-+Pollution+vs+Meteorology+Scatter+Plots)

---

## 💡 Key Findings & Actionable Business Recommendations

1. **Diurnal Commute Pollution Peaks**:
   - **Finding**: AQI spikes consistently during morning (8-10 AM) and evening (6-9 PM) rush hours in high-density metropolitan areas.
   - **Recommendation**: Urban transport boards should enforce dynamic congestion tolling during rush hours and expand electric bus fleets along high-traffic corridors.

2. **Wind Speed Dispersion Effect**:
   - **Finding**: Low wind speeds (< 5 km/h) strongly correlate with PM2.5 accumulation, whereas higher wind speeds dissipate particulates rapidly.
   - **Recommendation**: City planners should mandate ventilation corridors and bio-shield green belts along industrial corridors situated in low-wind topographies.

3. **High Baseline Variance in Metropolitan Centers**:
   - **Finding**: Industrial and inland cities (New Delhi, Mumbai) maintain elevated baseline AQI (> 140) compared to coastal/low-density cities (Sydney < 45).
   - **Recommendation**: Regional environmental protection agencies must enforce Low Emission Zones (LEZs) restricting heavy diesel vehicles from entering city cores during high-baseline days.

4. **Humidity-Induced Particulate Retention**:
   - **Finding**: High relative humidity (> 80%) combined with low wind traps fine particulates near ground level.
   - **Recommendation**: Deploy automated water-misting cannons and road-sweeping fleets on high-humidity mornings to suppress airborne particulate resuspension.

5. **Short-Term Predictive Warning System**:
   - **Finding**: Linear Regression model achieves a low MAE of 2.54 AQI points using 1-hour lag and weather parameters.
   - **Recommendation**: Municipal health agencies should integrate this prediction pipeline into mobile public health applications to issue early advisories for sensitive populations.

---

## 🐙 Git Publishing Commands
To initialize and push this repository to GitHub:
```bash
git init
git add .
git commit -m "Initial commit: Air Quality & Weather Data Pipeline, SQL Schema, EDA, and Power BI Reporting"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/air-quality-tracker.git
git push -u origin main
```

---
*Created as part of the Real-Time Air Quality Analytics Architecture.*
