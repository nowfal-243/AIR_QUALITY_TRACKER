-- Stage 1: Database Setup and Schema Creation
-- Create Database
CREATE DATABASE IF NOT EXISTS air_quality;
USE air_quality;

-- Table: cities
DROP TABLE IF EXISTS readings;
DROP TABLE IF EXISTS cities;

CREATE TABLE cities (
    city_id INT AUTO_INCREMENT PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL UNIQUE,
    latitude DECIMAL(9, 6) NOT NULL,
    longitude DECIMAL(9, 6) NOT NULL
);

-- Table: readings
CREATE TABLE readings (
    reading_id INT AUTO_INCREMENT PRIMARY KEY,
    city_id INT NOT NULL,
    reading_time DATETIME NOT NULL,
    pm2_5 FLOAT DEFAULT NULL,
    pm10 FLOAT DEFAULT NULL,
    no2 FLOAT DEFAULT NULL,
    ozone FLOAT DEFAULT NULL,
    us_aqi INT DEFAULT NULL,
    temperature FLOAT DEFAULT NULL,
    humidity FLOAT DEFAULT NULL,
    wind_speed FLOAT DEFAULT NULL,
    CONSTRAINT fk_readings_cities FOREIGN KEY (city_id) REFERENCES cities(city_id) ON DELETE CASCADE,
    CONSTRAINT uq_city_reading_time UNIQUE (city_id, reading_time)
);

-- Insert 8 Cities
INSERT INTO cities (city_name, latitude, longitude) VALUES
('New Delhi', 28.613900, 77.209000),
('Mumbai', 19.076000, 72.877700),
('Bengaluru', 12.971600, 77.594600),
('London', 51.507400, -0.127800),
('New York', 40.712800, -74.006000),
('Tokyo', 35.676200, 139.650300),
('Beijing', 39.904200, 116.407400),
('Sydney', -33.868800, 151.209300);

-- Check query to verify 8 rows inserted
SELECT city_id, city_name, latitude, longitude FROM cities;
