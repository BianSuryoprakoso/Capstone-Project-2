-- SILVER TRANSFORM: Bronze -> Silver

-- Load silver.taxi_zones dari bronze.raw_taxi_zones
TRUNCATE TABLE silver.taxi_zones RESTART IDENTITY CASCADE;

INSERT INTO silver.taxi_zones (location_id, borough, zone, service_zone)
SELECT
    locationid,
    borough,
    zone,
    service_zone
FROM bronze.raw_taxi_zones
WHERE locationid IS NOT NULL;


-- STEP 2: Load silver.data_quality_issues
TRUNCATE TABLE silver.data_quality_issues RESTART IDENTITY;

-- 2a. Trip dengan fare_amount negatif
INSERT INTO silver.data_quality_issues
    (error_type, description, pickup_datetime, dropoff_datetime,
     pulocation_id, dolocation_id, fare_amount, total_amount)
SELECT
    'negative_fare',
    'fare_amount bernilai negatif',
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    pulocation_id,
    dolocation_id,
    fare_amount,
    total_amount
FROM bronze.raw_taxi_trips
WHERE fare_amount < 0;

-- 2b. Trip dengan total_amount negatif
INSERT INTO silver.data_quality_issues
    (error_type, description, pickup_datetime, dropoff_datetime,
     pulocation_id, dolocation_id, fare_amount, total_amount)
SELECT
    'negative_total_amount',
    'total_amount bernilai negatif',
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    pulocation_id,
    dolocation_id,
    fare_amount,
    total_amount
FROM bronze.raw_taxi_trips
WHERE total_amount < 0;

-- 2c. Trip dengan trip_distance negatif atau nol
INSERT INTO silver.data_quality_issues
    (error_type, description, pickup_datetime, dropoff_datetime,
     pulocation_id, dolocation_id, fare_amount, total_amount)
SELECT
    'invalid_distance',
    'trip_distance bernilai nol atau negatif',
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    pulocation_id,
    dolocation_id,
    fare_amount,
    total_amount
FROM bronze.raw_taxi_trips
WHERE trip_distance <= 0;

-- 2d. Trip dengan pickup_datetime > dropoff_datetime (tidak logis)
INSERT INTO silver.data_quality_issues
    (error_type, description, pickup_datetime, dropoff_datetime,
     pulocation_id, dolocation_id, fare_amount, total_amount)
SELECT
    'invalid_datetime',
    'pickup_datetime lebih besar dari dropoff_datetime',
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    pulocation_id,
    dolocation_id,
    fare_amount,
    total_amount
FROM bronze.raw_taxi_trips
WHERE tpep_pickup_datetime >= tpep_dropoff_datetime;

-- 2e. Trip dengan payment_type = 0 (tidak dikenali)
INSERT INTO silver.data_quality_issues
    (error_type, description, pickup_datetime, dropoff_datetime,
     pulocation_id, dolocation_id, fare_amount, total_amount)
SELECT
    'unknown_payment_type',
    'payment_type bernilai 0 (tidak dikenali)',
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    pulocation_id,
    dolocation_id,
    fare_amount,
    total_amount
FROM bronze.raw_taxi_trips
WHERE payment_type = 0;

-- STEP 3: Load silver.taxi_trips_cleaned (baris yang valid)
TRUNCATE TABLE silver.taxi_trips_cleaned RESTART IDENTITY;

INSERT INTO silver.taxi_trips_cleaned (
    vendor_id,
    pickup_datetime,
    dropoff_datetime,
    pickup_date,
    pickup_hour,
    pickup_day_name,
    is_weekend,
    time_period,
    trip_duration_minutes,
    passenger_count,
    trip_distance,
    pickup_location_id,
    dropoff_location_id,
    payment_type_label,
    fare_amount,
    tip_amount,
    total_amount
)
SELECT
    vendor_id,

    --Datetime
    tpep_pickup_datetime AS pickup_datetime,
    tpep_dropoff_datetime AS dropoff_datetime,

    --Kolom turunan dari pickup_datetime
    tpep_pickup_datetime::DATE AS pickup_date,
    EXTRACT(HOUR FROM tpep_pickup_datetime)::INTEGER AS pickup_hour,
    TO_CHAR(tpep_pickup_datetime, 'Day') AS pickup_day_name,

    --is_weekend: True Sabtu (6) atau Minggu (0)
    EXTRACT(DOW FROM tpep_pickup_datetime) IN (0, 6) AS is_weekend,

    --time_period: pembagian waktu dalam sehari
    CASE
        WHEN EXTRACT(HOUR FROM tpep_pickup_datetime) BETWEEN 5  AND 11 THEN 'Morning'
        WHEN EXTRACT(HOUR FROM tpep_pickup_datetime) BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN EXTRACT(HOUR FROM tpep_pickup_datetime) BETWEEN 17 AND 20 THEN 'Evening'
        ELSE 'Night'
    END AS time_period,

    --Durasi trip dalam menit
    ROUND(
        EXTRACT(EPOCH FROM (tpep_dropoff_datetime - tpep_pickup_datetime)) / 60.0,
        2
    ) AS trip_duration_minutes,

    --Info penumpang & jarak
    CASE 
    WHEN passenger_count::TEXT = 'NaN' THEN NULL
    ELSE passenger_count::INTEGER 
    END AS passenger_count,
    trip_distance,

    --Lokasi pickup & dropoff
    pulocation_id AS pickup_location_id,
    dolocation_id AS dropoff_location_id,

    --Mapping payment_type ke label
    CASE payment_type
        WHEN 1 THEN 'Credit Card'
        WHEN 2 THEN 'Cash'
        WHEN 3 THEN 'No Charge'
        WHEN 4 THEN 'Dispute'
        ELSE 'Unknown'
    END AS payment_type_label,

    --Biaya
    fare_amount,
    tip_amount,
    total_amount

FROM bronze.raw_taxi_trips

--Filter: hanya ambil data yang valid
WHERE fare_amount       >= 0
  AND total_amount      >= 0
  AND trip_distance     > 0
  AND tpep_pickup_datetime < tpep_dropoff_datetime

  -- Pastikan location_id ada di silver.taxi_zones (foreign key valid)
  AND pulocation_id IN (SELECT location_id FROM silver.taxi_zones)
  AND dolocation_id IN (SELECT location_id FROM silver.taxi_zones);