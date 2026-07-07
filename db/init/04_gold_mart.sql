-- GOLD MART
-- 1. gold.daily_trip_summary
TRUNCATE TABLE gold.daily_trip_summary;

INSERT INTO gold.daily_trip_summary (
    pickup_date, total_trips, total_revenue,
    avg_fare, avg_distance, avg_duration_minutes
)
SELECT
    pickup_date,
    COUNT(*)                             AS total_trips,
    ROUND(SUM(total_amount), 2)          AS total_revenue,
    ROUND(AVG(fare_amount), 2)           AS avg_fare,
    ROUND(AVG(trip_distance), 2)         AS avg_distance,
    ROUND(AVG(trip_duration_minutes), 2) AS avg_duration_minutes
FROM silver.taxi_trips_cleaned
GROUP BY pickup_date
ORDER BY pickup_date;

-- 2. gold.hourly_demand_summary
CREATE TABLE IF NOT EXISTS gold.hourly_demand_summary (
    pickup_hour          INTEGER PRIMARY KEY,
    total_trips          BIGINT NOT NULL,
    total_revenue        NUMERIC NOT NULL,
    avg_fare             NUMERIC,
    avg_duration_minutes NUMERIC
);

TRUNCATE TABLE gold.hourly_demand_summary;

INSERT INTO gold.hourly_demand_summary (
    pickup_hour, total_trips, total_revenue,
    avg_fare, avg_duration_minutes
)
SELECT
    pickup_hour,
    COUNT(*)                             AS total_trips,
    ROUND(SUM(total_amount), 2)          AS total_revenue,
    ROUND(AVG(fare_amount), 2)           AS avg_fare,
    ROUND(AVG(trip_duration_minutes), 2) AS avg_duration_minutes
FROM silver.taxi_trips_cleaned
GROUP BY pickup_hour
ORDER BY pickup_hour;

-- 3. gold.zone_performance_summary
-- Dipisah jadi dua CTE supaya tidak double JOIN tabel besar
CREATE TABLE IF NOT EXISTS gold.zone_performance_summary (
    location_id         INTEGER PRIMARY KEY,
    borough             TEXT,
    zone                TEXT,
    total_pickup_trips  BIGINT,
    total_dropoff_trips BIGINT,
    total_revenue       NUMERIC,
    avg_fare            NUMERIC,
    avg_tip             NUMERIC
);

TRUNCATE TABLE gold.zone_performance_summary;

INSERT INTO gold.zone_performance_summary (
    location_id, borough, zone,
    total_pickup_trips, total_dropoff_trips,
    total_revenue, avg_fare, avg_tip
)
WITH pickup_stats AS (
    -- Hitung statistik dari sisi pickup
    SELECT
        pickup_location_id          AS location_id,
        COUNT(*)                    AS total_pickup_trips,
        ROUND(SUM(total_amount), 2) AS total_revenue,
        ROUND(AVG(fare_amount), 2)  AS avg_fare,
        ROUND(AVG(tip_amount), 2)   AS avg_tip
    FROM silver.taxi_trips_cleaned
    GROUP BY pickup_location_id
),
dropoff_stats AS (
    -- Hitung statistik dari sisi dropoff (terpisah, tidak di-JOIN bersamaan)
    SELECT
        dropoff_location_id         AS location_id,
        COUNT(*)                    AS total_dropoff_trips
    FROM silver.taxi_trips_cleaned
    GROUP BY dropoff_location_id
)
SELECT
    z.location_id,
    z.borough,
    z.zone,
    COALESCE(p.total_pickup_trips, 0)   AS total_pickup_trips,
    COALESCE(d.total_dropoff_trips, 0)  AS total_dropoff_trips,
    COALESCE(p.total_revenue, 0)        AS total_revenue,
    p.avg_fare,
    p.avg_tip
FROM silver.taxi_zones z
LEFT JOIN pickup_stats  p ON z.location_id = p.location_id
LEFT JOIN dropoff_stats d ON z.location_id = d.location_id
ORDER BY total_revenue DESC;

-- 4. gold.payment_behavior_summary
CREATE TABLE IF NOT EXISTS gold.payment_behavior_summary (
    payment_type_label TEXT PRIMARY KEY,
    total_trips        BIGINT NOT NULL,
    total_revenue      NUMERIC NOT NULL,
    avg_fare           NUMERIC,
    avg_tip            NUMERIC,
    pct_of_total_trips NUMERIC
);

TRUNCATE TABLE gold.payment_behavior_summary;

INSERT INTO gold.payment_behavior_summary (
    payment_type_label, total_trips, total_revenue,
    avg_fare, avg_tip, pct_of_total_trips
)
SELECT
    payment_type_label,
    COUNT(*)                                           AS total_trips,
    ROUND(SUM(total_amount), 2)                        AS total_revenue,
    ROUND(AVG(fare_amount), 2)                         AS avg_fare,
    ROUND(AVG(tip_amount), 2)                          AS avg_tip,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total_trips
FROM silver.taxi_trips_cleaned
GROUP BY payment_type_label
ORDER BY total_trips DESC;

-- 5. gold.route_performance_summary (dibatasi TOP 1000 rute supaya tidak terlalu berat prosesnya)
CREATE TABLE IF NOT EXISTS gold.route_performance_summary (
    pickup_zone    TEXT,
    dropoff_zone   TEXT,
    pickup_borough TEXT,
    dropoff_borough TEXT,
    total_trips    BIGINT NOT NULL,
    total_revenue  NUMERIC,
    avg_fare       NUMERIC
);

TRUNCATE TABLE gold.route_performance_summary;

INSERT INTO gold.route_performance_summary (
    pickup_zone, dropoff_zone,
    pickup_borough, dropoff_borough,
    total_trips, total_revenue, avg_fare
)
SELECT
    pz.zone                       AS pickup_zone,
    dz.zone                       AS dropoff_zone,
    pz.borough                    AS pickup_borough,
    dz.borough                    AS dropoff_borough,
    COUNT(*)                      AS total_trips,
    ROUND(SUM(t.total_amount), 2) AS total_revenue,
    ROUND(AVG(t.fare_amount), 2)  AS avg_fare
FROM silver.taxi_trips_cleaned t
JOIN silver.taxi_zones pz ON t.pickup_location_id  = pz.location_id
JOIN silver.taxi_zones dz ON t.dropoff_location_id = dz.location_id
GROUP BY pz.zone, dz.zone, pz.borough, dz.borough
ORDER BY total_trips DESC
LIMIT 1000;