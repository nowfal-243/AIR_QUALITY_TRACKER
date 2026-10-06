-- Stage 4: SQL Analysis and View Creation
USE air_quality;

-- ============================================================================
-- Query 1: Daily Average AQI per City
-- Business Question: What is the average AQI per city for each day to track daily trends?
-- ============================================================================
SELECT 
    c.city_name,
    DATE(r.reading_time) AS reading_date,
    ROUND(AVG(r.us_aqi), 2) AS avg_daily_aqi,
    ROUND(AVG(r.pm2_5), 2) AS avg_daily_pm2_5
FROM readings r
JOIN cities c ON r.city_id = c.city_id
GROUP BY c.city_name, DATE(r.reading_time)
ORDER BY c.city_name, reading_date;


-- ============================================================================
-- Query 2: Peak Pollution Hour per City
-- Business Question: When was the worst air quality recorded for each city?
-- ============================================================================
WITH RankedReadings AS (
    SELECT 
        c.city_name,
        r.reading_time,
        r.us_aqi,
        r.pm2_5,
        r.pm10,
        ROW_NUMBER() OVER (PARTITION BY c.city_id ORDER BY r.us_aqi DESC, r.reading_time DESC) AS rnk
    FROM readings r
    JOIN cities c ON r.city_id = c.city_id
)
SELECT 
    city_name,
    reading_time AS peak_pollution_time,
    us_aqi AS peak_aqi,
    pm2_5,
    pm10
FROM RankedReadings
WHERE rnk = 1
ORDER BY peak_aqi DESC;


-- ============================================================================
-- Query 3: 7-Day Rolling Average AQI
-- Business Question: What is the smoothed 7-day moving average of AQI per city to filter out hourly spikes?
-- ============================================================================
WITH DailyAvg AS (
    SELECT 
        city_id,
        DATE(reading_time) AS reading_date,
        AVG(us_aqi) AS daily_aqi
    FROM readings
    GROUP BY city_id, DATE(reading_time)
)
SELECT 
    c.city_name,
    d.reading_date,
    ROUND(d.daily_aqi, 2) AS daily_aqi,
    ROUND(AVG(d.daily_aqi) OVER (
        PARTITION BY d.city_id 
        ORDER BY d.reading_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_7day_avg_aqi
FROM DailyAvg d
JOIN cities c ON d.city_id = c.city_id
ORDER BY c.city_name, d.reading_date;


-- ============================================================================
-- Query 4: Hours with AQI Above 200 per City
-- Business Question: How many hazardous/unhealthy hours (AQI > 200) did each city experience?
-- ============================================================================
SELECT 
    c.city_name,
    COUNT(r.reading_id) AS total_hours_monitored,
    COUNT(CASE WHEN r.us_aqi > 200 THEN 1 END) AS hours_above_200_aqi,
    ROUND(COUNT(CASE WHEN r.us_aqi > 200 THEN 1 END) * 100.0 / COUNT(r.reading_id), 2) AS pct_hours_above_200,
    MAX(r.us_aqi) AS max_aqi_recorded
FROM cities c
LEFT JOIN readings r ON c.city_id = r.city_id
GROUP BY c.city_id, c.city_name
ORDER BY hours_above_200_aqi DESC, max_aqi_recorded DESC;


-- ============================================================================
-- Query 5: Weekday vs Weekend AQI Comparison
-- Business Question: Is air pollution significantly different on weekends compared to weekdays due to traffic/industrial variations?
-- ============================================================================
SELECT 
    c.city_name,
    ROUND(AVG(CASE WHEN DAYOFWEEK(r.reading_time) BETWEEN 2 AND 6 THEN r.us_aqi END), 2) AS weekday_avg_aqi,
    ROUND(AVG(CASE WHEN DAYOFWEEK(r.reading_time) IN (1, 7) THEN r.us_aqi END), 2) AS weekend_avg_aqi,
    ROUND(
        AVG(CASE WHEN DAYOFWEEK(r.reading_time) IN (1, 7) THEN r.us_aqi END) - 
        AVG(CASE WHEN DAYOFWEEK(r.reading_time) BETWEEN 2 AND 6 THEN r.us_aqi END), 2
    ) AS diff_weekend_minus_weekday
FROM readings r
JOIN cities c ON r.city_id = c.city_id
GROUP BY c.city_name
ORDER BY weekday_avg_aqi DESC;


-- ============================================================================
-- Query 6: Database View v_air_quality for Power BI
-- Business Question: Unified analytical view for reporting tools joining dimension and fact tables with calculated attributes.
-- ============================================================================
CREATE OR REPLACE VIEW v_air_quality AS
SELECT 
    r.reading_id,
    c.city_id,
    c.city_name,
    c.latitude,
    c.longitude,
    r.reading_time,
    DATE(r.reading_time) AS reading_date,
    HOUR(r.reading_time) AS reading_hour,
    DAYNAME(r.reading_time) AS day_of_week,
    CASE 
        WHEN DAYOFWEEK(r.reading_time) IN (1, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END AS day_type,
    r.pm2_5,
    r.pm10,
    r.no2,
    r.ozone,
    r.us_aqi,
    CASE 
        WHEN r.us_aqi <= 50 THEN 'Good'
        WHEN r.us_aqi <= 100 THEN 'Moderate'
        WHEN r.us_aqi <= 150 THEN 'Unhealthy for Sensitive Groups'
        WHEN r.us_aqi <= 200 THEN 'Unhealthy'
        WHEN r.us_aqi <= 300 THEN 'Very Unhealthy'
        ELSE 'Hazardous'
    END AS aqi_category,
    r.temperature,
    r.humidity,
    r.wind_speed
FROM readings r
JOIN cities c ON r.city_id = c.city_id;

-- Sample query from the view
SELECT * FROM v_air_quality LIMIT 10;
